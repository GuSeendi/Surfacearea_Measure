@preconcurrency import ARKit
import AVFoundation
import Combine
import Foundation
import RealityKit
import UIKit
import simd

private struct PointRefinement {
    var initialPosition: SIMD3<Float>
    var displayedPosition: SIMD3<Float>
    var previousCandidate: SIMD3<Float>?
    var stableUpdateCount: Int
    let maxCorrectionMeters: Float
}

@MainActor
final class ARSessionController: NSObject, ObservableObject {
    let session = ARSession()

    @Published private(set) var phase: MeasurementPhase = .preparing
    @Published private(set) var authorization: CameraAuthorizationState = .unknown
    @Published private(set) var quality = CaptureQuality()
    @Published private(set) var currentCursor: CursorSample?
    @Published private(set) var plane: MeasurementPlane?
    @Published private(set) var segments: [ProfileSegment] = []
    @Published private(set) var result: ShadowMeasurementResult?
    @Published private(set) var statusText = "กำลังเตรียมกล้อง…"
    @Published private(set) var lastActionText: String?
    @Published var traceMode: TraceMode = .automatic {
        didSet {
            previewGeometry = nil
            resetPreviewClassification()
            renderOverlay()
        }
    }

    private weak var arView: ARView?
    private var overlayRenderer: BoundaryOverlayRenderer?
    private var firstPoint: PlanarPoint?
    private var currentStart: PlanarPoint?
    private var strokeObservations: [PlanarObservation] = []
    private var firstWorldPoint: SIMD3<Float>?
    private var currentStartWorldPoint: SIMD3<Float>?
    private var strokeWorldPoints: [SIMD3<Float>] = []
    private var committedWorldPaths: [[SIMD3<Float>]] = []
    private var pointAnchors: [ARAnchor] = []
    private var anchorWorldPositions: [UUID: SIMD3<Float>] = [:]
    private var pointTrackedRaycasts: [UUID: ARTrackedRaycast] = [:]
    private var pointRefinements: [UUID: PointRefinement] = [:]
    private var lastCameraPosition: SIMD3<Float>?
    private var lastCameraTimestamp: TimeInterval?
    private var lastCameraTransform = matrix_identity_float4x4
    private var lastProcessedTimestamp: TimeInterval = 0
    private var lastPreviewTimestamp: TimeInterval = 0
    private var previewGeometry: SegmentGeometry?
    private var stablePreviewKind: TraceMode = .line
    private var pendingPreviewKind: TraceMode?
    private var pendingPreviewFrames = 0
    private var endpointFilter = TemporalPointFilter()
    private var wasNearStart = false
    private let feedback = UINotificationFeedbackGenerator()
    private let impact = UIImpactFeedbackGenerator(style: .light)

    override init() {
        super.init()
        session.delegate = self
    }

    var hasStartPoint: Bool { firstPoint != nil }
    var canUndo: Bool { firstPoint != nil || !segments.isEmpty }
    var canPlacePoint: Bool {
        phase == .tracing && quality.isAcceptable && currentCursor?.planarPoint != nil
    }
    var closureDistance: Double? {
        guard let firstPoint, let cursor = currentCursor?.planarPoint else { return nil }
        return cursor.distance(to: firstPoint)
    }
    var closureTolerance: Double {
        let perimeter = segments.reduce(0.0) { $0 + $1.length }
        return min(0.05, max(0.015, perimeter * 0.01))
    }
    var closureScreenDistance: CGFloat? {
        guard let arView,
              let firstWorldPoint = anchoredPoint(at: 0),
              let firstScreenPoint = arView.project(firstWorldPoint)
        else { return nil }
        return hypot(
            firstScreenPoint.x - arView.bounds.midX,
            firstScreenPoint.y - arView.bounds.midY
        )
    }
    var isNearStart: Bool {
        guard segments.count >= 2, let distance = closureDistance else { return false }
        if distance <= closureTolerance { return true }
        guard let screenDistance = closureScreenDistance else { return false }
        let screenAligned = screenDistance <= 52
        let safePlanarDistance = distance <= max(0.06, closureTolerance * 1.5)
        return screenAligned && safePlanarDistance
    }
    var canClose: Bool {
        quality.isAcceptable && isNearStart
    }

    func attach(to arView: ARView) {
        self.arView = arView
        arView.automaticallyConfigureSession = false
        arView.session = session
        arView.renderOptions.insert(.disableMotionBlur)
        let renderer = BoundaryOverlayRenderer(arView: arView)
        overlayRenderer = renderer
        renderOverlay()
    }

    func prepare() async {
        guard ARWorldTrackingConfiguration.isSupported else {
            phase = .unavailable("อุปกรณ์นี้ไม่รองรับ AR world tracking")
            return
        }
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
                || ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth)
        else {
            phase = .unavailable("ต้องใช้อุปกรณ์ที่มี LiDAR และรองรับ Scene Depth")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorization = .authorized
            startSession(resetTracking: true)
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorization = granted ? .authorized : .denied
            if granted {
                startSession(resetTracking: true)
            } else {
                phase = .unavailable("กรุณาอนุญาตการใช้กล้องใน Settings")
            }
        default:
            authorization = .denied
            phase = .unavailable("กรุณาอนุญาตการใช้กล้องใน Settings")
        }
    }

    func startSession(resetTracking: Bool) {
        guard authorization == .authorized else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.isAutoFocusEnabled = true
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        }

        let options: ARSession.RunOptions = resetTracking
            ? [.resetTracking, .removeExistingAnchors]
            : []
        session.run(configuration, options: options)
        if result != nil {
            phase = .result
            statusText = "พื้นที่เงาพร้อมตรวจสอบ"
        } else if plane != nil {
            phase = .tracing
            statusText = firstPoint == nil
                ? "วางจุดแรกที่ขอบชิ้นงาน"
                : "ลากเป้าตามขอบ แล้วกดเพิ่มจุด"
        } else {
            phase = .findingPlane
            statusText = "เล็งกลางชิ้นงาน แล้วล็อกระนาบเงา"
        }
    }

    func pause() {
        session.pause()
    }

    func lockPlane() {
        guard phase == .findingPlane,
              quality.isAcceptable,
              let cursor = currentCursor
        else {
            feedback.notificationOccurred(.warning)
            return
        }

        let cameraPosition = translation(of: lastCameraTransform)
        var origin = cursor.rawWorldPoint
        var normal: SIMD3<Float>
        var axisU: SIMD3<Float>

        if let arView,
           let query = arView.makeRaycastQuery(
                from: CGPoint(x: arView.bounds.midX, y: arView.bounds.midY),
                allowing: .estimatedPlane,
                alignment: .any
           ),
           let hit = session.raycast(query).first {
            origin = cursor.rawWorldPoint
            normal = normalized(SIMD3<Float>(
                hit.worldTransform.columns.1.x,
                hit.worldTransform.columns.1.y,
                hit.worldTransform.columns.1.z
            ))
            axisU = normalized(SIMD3<Float>(
                hit.worldTransform.columns.0.x,
                hit.worldTransform.columns.0.y,
                hit.worldTransform.columns.0.z
            ))
        } else {
            normal = normalized(cameraPosition - origin)
            let cameraRight = SIMD3<Float>(
                lastCameraTransform.columns.0.x,
                lastCameraTransform.columns.0.y,
                lastCameraTransform.columns.0.z
            )
            axisU = normalized(cameraRight - simd_dot(cameraRight, normal) * normal)
        }

        if simd_dot(normal, cameraPosition - origin) < 0 { normal = -normal }
        axisU = normalized(axisU - simd_dot(axisU, normal) * normal)
        let axisV = normalized(simd_cross(normal, axisU))
        guard axisU != .zero, axisV != .zero, normal != .zero else {
            feedback.notificationOccurred(.error)
            return
        }

        plane = MeasurementPlane(origin: origin, normal: normal, axisU: axisU, axisV: axisV)
        phase = .tracing
        statusText = "วางจุดแรกที่ขอบชิ้นงาน"
        impact.impactOccurred()
    }

    func placePoint() {
        guard canPlacePoint,
              let sampledCursor = currentCursor
        else {
            feedback.notificationOccurred(.warning)
            return
        }
        guard let stableCursor = endpointFilter.stableEstimate(
            near: sampledCursor,
            plane: plane
        ) else {
            feedback.notificationOccurred(.warning)
            lastActionText = "ถือกล้องนิ่งสักครู่ก่อนวางจุด"
            statusText = "รอให้เป้านิ่งและ depth หลายเฟรมตรงกัน"
            return
        }
        let cursor = placementCursor(from: stableCursor)
        guard let point = cursor.planarPoint else {
            feedback.notificationOccurred(.warning)
            return
        }

        if firstPoint == nil {
            firstPoint = point
            currentStart = point
            strokeObservations = [observation(from: cursor, forcing: point)]
            firstWorldPoint = cursor.rawWorldPoint
            currentStartWorldPoint = cursor.rawWorldPoint
            strokeWorldPoints = [cursor.rawWorldPoint]
            resetPreviewClassification()
            addPointAnchor(at: cursor.rawWorldPoint)
            endpointFilter.reset()
            endpointFilter.append(cursor)
            lastActionText = "จุดเริ่ม"
            statusText = "ลากเป้าตามขอบ แล้วกดเพิ่มจุด"
            impact.impactOccurred()
            renderOverlay()
            return
        }

        guard let currentStart, currentStart.distance(to: point) >= 0.002 else {
            feedback.notificationOccurred(.warning)
            lastActionText = "จุดใกล้กันเกินไป"
            return
        }

        _ = commitSegment(to: point, cursor: cursor)
    }

    func closeProfile() {
        guard canClose,
              let firstPoint,
              let cursor = currentCursor,
              let closureDistance
        else {
            feedback.notificationOccurred(.warning)
            return
        }

        guard commitSegment(to: firstPoint, cursor: cursor, isClosing: true) else {
            return
        }
        if !segments.isEmpty {
            segments[segments.count - 1].meanObservationUncertainty = max(
                segments[segments.count - 1].meanObservationUncertainty,
                closureDistance
            )
        }
        do {
            result = try ShadowAreaCalculator.calculate(segments: segments)
            phase = .result
            statusText = "พื้นที่เงาพร้อมตรวจสอบ"
            feedback.notificationOccurred(.success)
        } catch {
            result = nil
            if !segments.isEmpty { segments.removeLast() }
            let removedWorldPath = committedWorldPaths.popLast()
            currentStart = segments.last?.geometry.end ?? firstPoint
            currentStartWorldPoint = removedWorldPath?.first ?? firstWorldPoint
            strokeObservations = currentStart.map {
                [PlanarObservation(point: $0, uncertainty: quality.uncertaintyMeters, timestamp: cursor.timestamp)]
            } ?? []
            strokeWorldPoints = currentStartWorldPoint.map { [$0] } ?? []
            lastActionText = message(for: error)
            feedback.notificationOccurred(.error)
        }
        previewGeometry = nil
        resetPreviewClassification()
        renderOverlay()
    }

    func undo() {
        if let removed = segments.popLast() {
            currentStart = removed.geometry.start
            currentStartWorldPoint = committedWorldPaths.popLast()?.first ?? firstWorldPoint
            removeLastPointAnchorIfNeeded()
            strokeObservations = [PlanarObservation(
                point: removed.geometry.start,
                uncertainty: max(removed.meanObservationUncertainty, 0.004),
                timestamp: currentCursor?.timestamp ?? 0
            )]
            strokeWorldPoints = currentStartWorldPoint.map { [$0] } ?? []
            lastActionText = "ย้อนกลับ 1 ด้าน"
        } else if firstPoint != nil {
            firstPoint = nil
            currentStart = nil
            strokeObservations.removeAll(keepingCapacity: true)
            firstWorldPoint = nil
            currentStartWorldPoint = nil
            strokeWorldPoints.removeAll(keepingCapacity: true)
            committedWorldPaths.removeAll(keepingCapacity: true)
            removeAllPointAnchors()
            lastActionText = "ลบจุดเริ่มแล้ว"
        }
        result = nil
        previewGeometry = nil
        resetPreviewClassification()
        statusText = firstPoint == nil ? "วางจุดแรกที่ขอบชิ้นงาน" : "ลากเป้าตามขอบ แล้วกดเพิ่มจุด"
        impact.impactOccurred()
        renderOverlay()
    }

    func resetMeasurement() {
        plane = nil
        segments.removeAll(keepingCapacity: true)
        firstPoint = nil
        currentStart = nil
        strokeObservations.removeAll(keepingCapacity: true)
        firstWorldPoint = nil
        currentStartWorldPoint = nil
        strokeWorldPoints.removeAll(keepingCapacity: true)
        committedWorldPaths.removeAll(keepingCapacity: true)
        removeAllPointAnchors()
        previewGeometry = nil
        resetPreviewClassification()
        result = nil
        currentCursor = nil
        lastActionText = nil
        lastCameraPosition = nil
        lastCameraTimestamp = nil
        wasNearStart = false
        quality = CaptureQuality()
        endpointFilter.reset()
        overlayRenderer?.clear()
        startSession(resetTracking: true)
    }

    private func commitSegment(
        to end: PlanarPoint,
        cursor: CursorSample,
        isClosing: Bool = false
    ) -> Bool {
        guard let start = currentStart else { return false }
        var observations = strokeObservations
        if observations.first?.point != start {
            observations.insert(observation(from: cursor, forcing: start), at: 0)
        }
        observations.append(observation(from: cursor, forcing: end))

        do {
            let fit = try ProfileFitter.fit(observations: observations, mode: traceMode)
            let segment = ProfileSegment(
                geometry: fit.geometry,
                fitRMS: fit.rmsError,
                meanObservationUncertainty: fit.meanObservationUncertainty,
                observationCount: fit.observationCount
            )
            segments.append(segment)
            let endWorldPoint = isClosing
                ? (firstWorldPoint ?? cursor.rawWorldPoint)
                : cursor.rawWorldPoint
            committedWorldPaths.append(displayPath(
                for: fit.geometry,
                endWorldPoint: endWorldPoint
            ))
            if !isClosing {
                addPointAnchor(at: endWorldPoint)
            }
            currentStart = end
            currentStartWorldPoint = endWorldPoint
            strokeObservations = [observation(from: cursor, forcing: end)]
            strokeWorldPoints = [endWorldPoint]
            endpointFilter.reset()
            endpointFilter.append(cursor)
            lastActionText = fit.usedFallback
                ? "โค้งไม่เสถียร ใช้เส้นตรง"
                : (fit.geometry.kind == .arc ? "เพิ่มเส้นโค้ง" : "เพิ่มเส้นตรง")
            if !isClosing {
                statusText = canClose ? "เข้าใกล้จุดเริ่มแล้ว กดปิดพื้นที่" : "เก็บขอบด้านถัดไป"
                impact.impactOccurred()
            }
            previewGeometry = nil
            resetPreviewClassification()
            renderOverlay()
            return true
        } catch {
            lastActionText = "วางจุดไม่สำเร็จ ลองขยับให้ห่างขึ้น"
            feedback.notificationOccurred(.warning)
            previewGeometry = nil
            resetPreviewClassification()
            renderOverlay()
            return false
        }
    }

    private func consume(_ sample: DepthFrameSample) {
        guard sample.timestamp - lastProcessedTimestamp >= 1.0 / 30.0 else { return }
        lastProcessedTimestamp = sample.timestamp
        lastCameraTransform = sample.cameraTransform
        let cameraPosition = translation(of: sample.cameraTransform)
        let speed = cameraSpeed(position: cameraPosition, timestamp: sample.timestamp)

        var distance: Double?
        var frontalScore: Double?
        if let plane {
            distance = Double(abs(simd_dot(cameraPosition - plane.origin, plane.normal)))
            let forward = normalized(-SIMD3<Float>(
                sample.cameraTransform.columns.2.x,
                sample.cameraTransform.columns.2.y,
                sample.cameraTransform.columns.2.z
            ))
            frontalScore = Double(abs(simd_dot(forward, plane.normal)))
        } else if let worldPoint = sample.worldPoint {
            distance = Double(simd_distance(cameraPosition, worldPoint))
        }

        let telemetry = FrameTelemetry(
            tracking: sample.tracking,
            depth: sample.depthGrade,
            distanceMeters: distance,
            speedMetersPerSecond: speed,
            frontalScore: frontalScore,
            depthUncertaintyMeters: sample.depthUncertaintyMeters,
            thermalState: ProcessInfo.processInfo.thermalState
        )
        quality = CaptureQualityEvaluator.evaluate(telemetry)

        if let worldPoint = sample.worldPoint {
            let projection = plane?.project(worldPoint)
            let cursor = CursorSample(
                rawWorldPoint: worldPoint,
                planarPoint: projection?.point,
                planeResidualMeters: projection?.residual,
                uncertaintyMeters: quality.uncertaintyMeters,
                timestamp: sample.timestamp
            )
            currentCursor = cursor
            if quality.isAcceptable {
                endpointFilter.append(cursor)
            }
            collectStrokeObservation(cursor)
        } else {
            currentCursor = nil
        }

        let nearStart = isNearStart
        if nearStart && !wasNearStart {
            impact.impactOccurred(intensity: 0.8)
        }
        wasNearStart = nearStart
        statusText = guidanceText()
        updatePreviewIfNeeded(timestamp: sample.timestamp)
        renderOverlay()
    }

    private func collectStrokeObservation(_ cursor: CursorSample) {
        guard phase == .tracing,
              quality.isAcceptable,
              currentStart != nil,
              let point = cursor.planarPoint
        else { return }

        if let last = strokeObservations.last, last.point.distance(to: point) < 0.0015 {
            return
        }
        if strokeObservations.count >= 512 {
            let endpoint = strokeObservations.removeLast()
            let worldEndpoint = strokeWorldPoints.removeLast()
            strokeObservations = stride(from: 0, to: strokeObservations.count, by: 2)
                .map { strokeObservations[$0] }
            strokeWorldPoints = stride(from: 0, to: strokeWorldPoints.count, by: 2)
                .map { strokeWorldPoints[$0] }
            strokeObservations.append(endpoint)
            strokeWorldPoints.append(worldEndpoint)
        }
        strokeObservations.append(observation(from: cursor, forcing: point))
        strokeWorldPoints.append(cursor.rawWorldPoint)
    }

    private func updatePreviewIfNeeded(timestamp: TimeInterval) {
        guard timestamp - lastPreviewTimestamp >= 1.0 / 15.0 else { return }
        lastPreviewTimestamp = timestamp
        guard phase == .tracing,
              let currentStart,
              let cursor = currentCursor,
              let point = cursor.planarPoint,
              currentStart.distance(to: point) >= 0.002
        else {
            previewGeometry = nil
            return
        }

        var observations = strokeObservations
        observations.append(observation(from: cursor, forcing: point))
        guard let proposed = try? ProfileFitter.fit(
            observations: observations,
            mode: traceMode
        ) else {
            previewGeometry = .line(start: currentStart, end: point)
            return
        }

        guard traceMode == .automatic else {
            previewGeometry = proposed.geometry
            return
        }
        previewGeometry = stabilizedAutomaticPreview(
            proposed: proposed.geometry,
            observations: observations,
            start: currentStart,
            end: point
        )
    }

    private func guidanceText() -> String {
        if case .result = phase { return "พื้นที่เงาพร้อมตรวจสอบ" }
        if isNearStart && !quality.isAcceptable {
            return "ถึงจุดเริ่มแล้ว ถือกล้องนิ่งเพื่อปิดพื้นที่"
        }
        if !quality.isAcceptable { return quality.headline }
        switch phase {
        case .findingPlane: return "พร้อมแล้ว กดล็อกระนาบเงา"
        case .tracing where firstPoint == nil: return "พร้อมแล้ว วางจุดเริ่ม"
        case .tracing where canClose: return "กลับถึงจุดเริ่มแล้ว กดปิดและคำนวณพื้นที่"
        case .tracing:
            switch traceMode {
            case .arc: return "ลากเป้าตามส่วนโค้ง แล้วกดเพิ่มจุดปลาย"
            case .line: return "เล็งจุดปลายเส้นตรง แล้วกดเพิ่มจุด"
            case .automatic where previewGeometry?.kind == .arc:
                return "ตรวจพบเส้นโค้ง — ลากตามขอบแล้วกดเพิ่มจุด"
            case .automatic: return "ลากเป้าตามขอบ ระบบเลือกเส้นให้อัตโนมัติ"
            }
        default: return statusText
        }
    }

    private func renderOverlay() {
        overlayRenderer?.render(
            committedWorldPaths: resolvedCommittedWorldPaths,
            previewWorldPath: previewWorldPath,
            committedMeasurementTexts: segments.map { MeasurementReport.length($0.length) },
            previewMeasurementText: previewGeometry.map { MeasurementReport.length($0.length) },
            anchorWorldPoints: pointAnchors.compactMap { anchorWorldPosition(for: $0) },
            closureReady: canClose,
            isClosed: phase == .result,
            reticleReady: quality.isAcceptable,
            reticleVisible: phase != .result
        )
    }

    private var resolvedCommittedWorldPaths: [[SIMD3<Float>]] {
        committedWorldPaths.enumerated().map { index, storedPath in
            var path = storedPath
            guard !path.isEmpty else { return path }
            if let anchoredStart = anchoredPoint(at: index) {
                path[0] = anchoredStart
            }
            if let anchoredEnd = anchoredPoint(at: index + 1) {
                path[path.count - 1] = anchoredEnd
            } else if phase == .result, let anchoredStart = anchoredPoint(at: 0) {
                path[path.count - 1] = anchoredStart
            }
            return path
        }
    }

    private var previewWorldPath: [SIMD3<Float>] {
        guard phase == .tracing,
              firstPoint != nil,
              let start = anchoredPoint(at: pointAnchors.count - 1) ?? currentStartWorldPoint,
              let cursor = currentCursor,
              previewGeometry != nil
        else { return [] }

        guard let previewGeometry else { return [] }
        return fittedWorldPath(
            for: previewGeometry,
            startWorldPoint: start,
            endWorldPoint: cursor.rawWorldPoint
        )
    }

    private func addPointAnchor(at worldPoint: SIMD3<Float>) {
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4(worldPoint.x, worldPoint.y, worldPoint.z, 1)
        let anchor = ARAnchor(name: "SurfaceMeasurePoint", transform: transform)
        pointAnchors.append(anchor)
        anchorWorldPositions[anchor.identifier] = worldPoint
        pointRefinements[anchor.identifier] = PointRefinement(
            initialPosition: worldPoint,
            displayedPosition: worldPoint,
            previousCandidate: nil,
            stableUpdateCount: 0,
            maxCorrectionMeters: trackedRaycastCorrectionLimit(for: worldPoint)
        )
        session.add(anchor: anchor)
        startTrackedRaycast(for: anchor.identifier)
    }

    private func removeLastPointAnchorIfNeeded() {
        let expectedCount = segments.count + (firstPoint == nil ? 0 : 1)
        guard pointAnchors.count > expectedCount, let anchor = pointAnchors.popLast() else { return }
        pointTrackedRaycasts.removeValue(forKey: anchor.identifier)?.stopTracking()
        pointRefinements.removeValue(forKey: anchor.identifier)
        anchorWorldPositions.removeValue(forKey: anchor.identifier)
        session.remove(anchor: anchor)
    }

    private func removeAllPointAnchors() {
        pointTrackedRaycasts.values.forEach { $0.stopTracking() }
        pointTrackedRaycasts.removeAll(keepingCapacity: true)
        pointRefinements.removeAll(keepingCapacity: true)
        pointAnchors.forEach(session.remove)
        pointAnchors.removeAll(keepingCapacity: true)
        anchorWorldPositions.removeAll(keepingCapacity: true)
    }

    private func anchoredPoint(at index: Int) -> SIMD3<Float>? {
        guard pointAnchors.indices.contains(index) else { return nil }
        return anchorWorldPosition(for: pointAnchors[index])
    }

    private func anchorWorldPosition(for anchor: ARAnchor) -> SIMD3<Float> {
        pointRefinements[anchor.identifier]?.displayedPosition
            ?? anchorWorldPositions[anchor.identifier]
            ?? translation(of: anchor.transform)
    }

    private func updateAnchorWorldPositions(_ updates: [(UUID, SIMD3<Float>)]) {
        var changed = false
        for (identifier, position) in updates where anchorWorldPositions[identifier] != nil {
            if let previousAnchorPosition = anchorWorldPositions[identifier],
               var refinement = pointRefinements[identifier] {
                // Carry ARKit's world-map correction into the refined point. This keeps the
                // point attached during relocalization without discarding raycast refinement.
                let worldCorrection = position - previousAnchorPosition
                refinement.initialPosition += worldCorrection
                refinement.displayedPosition += worldCorrection
                if let previousCandidate = refinement.previousCandidate {
                    refinement.previousCandidate = previousCandidate + worldCorrection
                }
                pointRefinements[identifier] = refinement
            }
            anchorWorldPositions[identifier] = position
            changed = true
        }
        if changed {
            firstWorldPoint = anchoredPoint(at: 0) ?? firstWorldPoint
            currentStartWorldPoint = anchoredPoint(at: pointAnchors.count - 1) ?? currentStartWorldPoint
            renderOverlay()
        }
    }

    private func startTrackedRaycast(for identifier: UUID) {
        guard let arView else { return }
        let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        guard let query = arView.makeRaycastQuery(
            from: center,
            allowing: .estimatedPlane,
            alignment: .any
        ) else { return }

        pointTrackedRaycasts[identifier] = session.trackedRaycast(query) { [weak self] results in
            guard let result = results.first else { return }
            let column = result.worldTransform.columns.3
            let candidate = SIMD3<Float>(column.x, column.y, column.z)
            Task { @MainActor [weak self] in
                self?.refinePoint(identifier: identifier, candidate: candidate)
            }
        }
    }

    private func refinePoint(identifier: UUID, candidate: SIMD3<Float>) {
        guard let frame = session.currentFrame,
              case .normal = frame.camera.trackingState,
              var refinement = pointRefinements[identifier],
              candidate.x.isFinite,
              candidate.y.isFinite,
              candidate.z.isFinite,
              simd_distance(candidate, refinement.initialPosition) <= refinement.maxCorrectionMeters
        else { return }

        let candidateDelta = refinement.previousCandidate.map {
            simd_distance($0, candidate)
        } ?? .infinity
        refinement.stableUpdateCount = candidateDelta <= 0.012
            ? refinement.stableUpdateCount + 1
            : 1
        refinement.previousCandidate = candidate

        // Tiny corrections are safe immediately. Larger depth corrections need two
        // consistent tracked-raycast results so a transient plane never moves a saved point.
        let correction = simd_distance(refinement.displayedPosition, candidate)
        if correction <= 0.008 || refinement.stableUpdateCount >= 2 {
            refinement.displayedPosition = correction <= 0.002
                ? candidate
                : refinement.displayedPosition + (candidate - refinement.displayedPosition) * 0.55
        }
        pointRefinements[identifier] = refinement
        firstWorldPoint = anchoredPoint(at: 0) ?? firstWorldPoint
        currentStartWorldPoint = anchoredPoint(at: pointAnchors.count - 1) ?? currentStartWorldPoint
        renderOverlay()
    }

    private func trackedRaycastCorrectionLimit(for worldPoint: SIMD3<Float>) -> Float {
        let cameraDistance = simd_distance(translation(of: lastCameraTransform), worldPoint)
        return min(0.08, max(0.03, cameraDistance * 0.06))
    }

    private func displayPath(
        for geometry: SegmentGeometry,
        endWorldPoint: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        guard let start = currentStartWorldPoint else { return [endWorldPoint] }
        return fittedWorldPath(
            for: geometry,
            startWorldPoint: start,
            endWorldPoint: endWorldPoint
        )
    }

    private func fittedWorldPath(
        for geometry: SegmentGeometry,
        startWorldPoint: SIMD3<Float>,
        endWorldPoint: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        guard geometry.kind == .arc, let plane else {
            return [startWorldPoint, endWorldPoint]
        }

        let planarPoints = geometry.tessellated(maximumChordError: 0.00075)
        guard planarPoints.count >= 2 else { return [startWorldPoint, endWorldPoint] }
        let planarStart = plane.worldPoint(for: geometry.start)
        let planarEnd = plane.worldPoint(for: geometry.end)
        let startDepth = simd_dot(startWorldPoint - planarStart, plane.normal)
        let endDepth = simd_dot(endWorldPoint - planarEnd, plane.normal)
        var path = planarPoints.enumerated().map { index, point in
            let fraction = Float(index) / Float(planarPoints.count - 1)
            let depth = startDepth + (endDepth - startDepth) * fraction
            return plane.worldPoint(for: point) + plane.normal * depth
        }
        path[0] = startWorldPoint
        path[path.count - 1] = endWorldPoint
        return path
    }

    private func stabilizedAutomaticPreview(
        proposed: SegmentGeometry,
        observations: [PlanarObservation],
        start: PlanarPoint,
        end: PlanarPoint
    ) -> SegmentGeometry {
        let proposedKind = proposed.kind
        if proposedKind == stablePreviewKind {
            pendingPreviewKind = nil
            pendingPreviewFrames = 0
            return proposed
        }

        if pendingPreviewKind == proposedKind {
            pendingPreviewFrames += 1
        } else {
            pendingPreviewKind = proposedKind
            pendingPreviewFrames = 1
        }

        let framesNeeded = proposedKind == .arc ? 3 : 5
        if pendingPreviewFrames >= framesNeeded {
            stablePreviewKind = proposedKind
            pendingPreviewKind = nil
            pendingPreviewFrames = 0
            return proposed
        }

        if stablePreviewKind == .arc,
           let forcedArc = try? ProfileFitter.fit(observations: observations, mode: .arc),
           forcedArc.geometry.kind == .arc {
            return forcedArc.geometry
        }
        return .line(start: start, end: end)
    }

    private func resetPreviewClassification() {
        stablePreviewKind = .line
        pendingPreviewKind = nil
        pendingPreviewFrames = 0
    }

    private func placementCursor(from sampledCursor: CursorSample) -> CursorSample {
        guard let worldPoint = raycastCenterWorldPoint(near: sampledCursor.rawWorldPoint) else {
            return sampledCursor
        }
        let projection = plane?.project(worldPoint)
        return CursorSample(
            rawWorldPoint: worldPoint,
            planarPoint: projection?.point,
            planeResidualMeters: projection?.residual,
            uncertaintyMeters: min(sampledCursor.uncertaintyMeters, 0.006),
            timestamp: sampledCursor.timestamp
        )
    }

    private func raycastCenterWorldPoint(near fallback: SIMD3<Float>) -> SIMD3<Float>? {
        guard let arView else { return nil }
        let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        let cameraPosition = translation(of: lastCameraTransform)
        let fallbackDistance = simd_distance(cameraPosition, fallback)
        let tolerance = min(0.04, max(0.012, fallbackDistance * 0.02))
        let targets: [ARRaycastQuery.Target] = [.existingPlaneGeometry, .estimatedPlane]

        for target in targets {
            guard let query = arView.makeRaycastQuery(
                from: center,
                allowing: target,
                alignment: .any
            ) else { continue }
            for hit in session.raycast(query) {
                let candidate = translation(of: hit.worldTransform)
                let candidateDistance = simd_distance(cameraPosition, candidate)
                if abs(candidateDistance - fallbackDistance) <= tolerance {
                    return candidate
                }
            }
        }
        return nil
    }

    private func observation(from cursor: CursorSample, forcing point: PlanarPoint) -> PlanarObservation {
        PlanarObservation(
            point: point,
            uncertainty: cursor.uncertaintyMeters,
            timestamp: cursor.timestamp
        )
    }

    private func cameraSpeed(position: SIMD3<Float>, timestamp: TimeInterval) -> Double {
        defer {
            lastCameraPosition = position
            lastCameraTimestamp = timestamp
        }
        guard let previous = lastCameraPosition,
              let previousTimestamp = lastCameraTimestamp,
              timestamp > previousTimestamp
        else { return 0 }
        return Double(simd_distance(position, previous)) / (timestamp - previousTimestamp)
    }

    private func translation(of transform: simd_float4x4) -> SIMD3<Float> {
        SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }

    private func normalized(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)
        return length > 1e-6 ? vector / length : .zero
    }

    private func message(for error: Error) -> String {
        switch error {
        case ShadowAreaError.selfIntersection: "เส้นตัดกัน กรุณาย้อนกลับและแก้ขอบ"
        case ShadowAreaError.negligibleArea: "พื้นที่เล็กเกินกว่าจะคำนวณได้"
        case let ShadowAreaError.openProfile(gap):
            "วงยังไม่ปิด ช่องว่าง \(MeasurementReport.length(gap))"
        default: "ยังคำนวณไม่ได้ กรุณาตรวจเส้นขอบ"
        }
    }
}

extension ARSessionController: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let sample = DepthSampler.sampleCenter(of: frame)
        Task { @MainActor [weak self] in
            self?.consume(sample)
        }
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        updateAnchorPositions(from: anchors)
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        updateAnchorPositions(from: anchors)
    }

    nonisolated private func updateAnchorPositions(from anchors: [ARAnchor]) {
        let updates = anchors.map { anchor in
            let column = anchor.transform.columns.3
            return (anchor.identifier, SIMD3<Float>(column.x, column.y, column.z))
        }
        Task { @MainActor [weak self] in
            self?.updateAnchorWorldPositions(updates)
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor [weak self] in
            self?.endpointFilter.reset()
            self?.statusText = "การติดตามถูกพัก กรุณาถือกล้องนิ่ง"
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor [weak self] in
            self?.resetMeasurement()
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.phase = .unavailable("ARKit หยุดทำงาน: \(error.localizedDescription)")
        }
    }
}
