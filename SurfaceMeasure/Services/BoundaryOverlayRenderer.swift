import Combine
import QuartzCore
import RealityKit
import UIKit

@MainActor
final class BoundaryOverlayRenderer {
    private weak var arView: ARView?
    private let overlay = BoundaryOverlayView()
    private var sceneUpdateSubscription: (any Cancellable)?
    private var committedWorldPaths: [[SIMD3<Float>]] = []
    private var previewWorldPath: [SIMD3<Float>] = []
    private var committedMeasurementTexts: [String] = []
    private var previewMeasurementText: String?
    private var anchorWorldPoints: [SIMD3<Float>] = []
    private var closureReady = false
    private var isClosed = false
    private var reticleReady = false
    private var reticleVisible = true

    init(arView: ARView) {
        self.arView = arView
        overlay.frame = arView.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.isUserInteractionEnabled = false
        arView.addSubview(overlay)
        sceneUpdateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.drawCurrentFrame()
            }
        }
    }

    func render(
        committedWorldPaths: [[SIMD3<Float>]],
        previewWorldPath: [SIMD3<Float>],
        committedMeasurementTexts: [String],
        previewMeasurementText: String?,
        anchorWorldPoints: [SIMD3<Float>],
        closureReady: Bool,
        isClosed: Bool,
        reticleReady: Bool,
        reticleVisible: Bool
    ) {
        self.committedWorldPaths = committedWorldPaths
        self.previewWorldPath = previewWorldPath
        self.committedMeasurementTexts = committedMeasurementTexts
        self.previewMeasurementText = previewMeasurementText
        self.anchorWorldPoints = anchorWorldPoints
        self.closureReady = closureReady
        self.isClosed = isClosed
        self.reticleReady = reticleReady
        self.reticleVisible = reticleVisible
        // SceneEvents.Update re-projects once per rendered frame. Drawing here as
        // well would duplicate overlay work whenever a depth sample arrives.
    }

    private func drawCurrentFrame() {
        guard let arView else { return }

        let committedWorldPoints = committedWorldPaths.enumerated().flatMap { index, path in
            index == 0 ? path : Array(path.dropFirst())
        }
        let committed = committedWorldPoints.compactMap(arView.project)
        var preview = previewWorldPath.dropLast().compactMap(arView.project)
        if !preview.isEmpty, previewWorldPath.count >= 2 {
            // The visual reticle and the AR raycast both use the exact center of ARView.
            // Never re-project the live endpoint through camera intrinsics/display crop.
            preview.append(CGPoint(x: arView.bounds.midX, y: arView.bounds.midY))
        }
        let anchors = anchorWorldPoints.compactMap(arView.project)
        let committedMeasurements = zip(committedWorldPaths, committedMeasurementTexts).compactMap {
            path, text -> ScreenMeasurementLabel? in
            let projectedPath = path.compactMap(arView.project)
            guard let position = polylineMidpoint(projectedPath) else { return nil }
            return ScreenMeasurementLabel(position: position, text: text)
        }
        let previewMeasurement = previewMeasurementText.flatMap { text in
            polylineMidpoint(preview).map { ScreenMeasurementLabel(position: $0, text: text) }
        }

        overlay.update(
            committed: committed,
            preview: preview,
            points: anchors,
            committedMeasurements: committedMeasurements,
            previewMeasurement: previewMeasurement,
            closureReady: closureReady,
            isClosed: isClosed,
            reticleReady: reticleReady,
            reticleVisible: reticleVisible
        )
    }

    func clear() {
        committedWorldPaths = []
        previewWorldPath = []
        committedMeasurementTexts = []
        previewMeasurementText = nil
        anchorWorldPoints = []
        closureReady = false
        isClosed = false
        reticleReady = false
        reticleVisible = true
        overlay.update(
            committed: [], preview: [], points: [],
            committedMeasurements: [], previewMeasurement: nil,
            closureReady: false, isClosed: false,
            reticleReady: false, reticleVisible: true
        )
    }

    private func polylineMidpoint(_ points: [CGPoint]) -> CGPoint? {
        guard let first = points.first else { return nil }
        guard points.count > 1 else { return first }

        let lengths = zip(points, points.dropFirst()).map { start, end in
            hypot(end.x - start.x, end.y - start.y)
        }
        let totalLength = lengths.reduce(0, +)
        guard totalLength > 0.5 else { return first }

        let target = totalLength * 0.5
        var travelled: CGFloat = 0
        for (index, length) in lengths.enumerated() {
            if travelled + length >= target {
                let fraction = (target - travelled) / max(length, 0.001)
                let start = points[index]
                let end = points[index + 1]
                return CGPoint(
                    x: start.x + (end.x - start.x) * fraction,
                    y: start.y + (end.y - start.y) * fraction
                )
            }
            travelled += length
        }
        return points.last
    }
}

private struct ScreenMeasurementLabel {
    let position: CGPoint
    let text: String
}

private final class BoundaryOverlayView: UIView {
    private let fillLayer = CAShapeLayer()
    private let committedLayer = CAShapeLayer()
    private let previewLayer = CAShapeLayer()
    private let pointLayer = CAShapeLayer()
    private let startPointLayer = CAShapeLayer()
    private let reticleLayer = CAShapeLayer()
    private let reticleDotLayer = CAShapeLayer()
    private var committedBadges: [MeasurementBadgeView] = []
    private let previewBadge = MeasurementBadgeView(style: .preview)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        [fillLayer, committedLayer, previewLayer, pointLayer, startPointLayer, reticleLayer, reticleDotLayer]
            .forEach(layer.addSublayer)
        committedLayer.fillColor = UIColor.clear.cgColor
        committedLayer.strokeColor = UIColor.systemCyan.cgColor
        committedLayer.lineWidth = 3
        committedLayer.lineCap = .round
        committedLayer.lineJoin = .round
        previewLayer.fillColor = UIColor.clear.cgColor
        previewLayer.lineWidth = 3
        previewLayer.lineDashPattern = [7, 5]
        previewLayer.lineCap = .round
        pointLayer.fillColor = UIColor.white.cgColor
        pointLayer.strokeColor = UIColor.systemCyan.cgColor
        pointLayer.lineWidth = 2
        startPointLayer.fillColor = UIColor.clear.cgColor
        startPointLayer.lineWidth = 3
        fillLayer.fillColor = UIColor.systemGreen.withAlphaComponent(0.20).cgColor
        reticleLayer.fillColor = UIColor.clear.cgColor
        reticleLayer.lineWidth = 2
        reticleLayer.lineCap = .round
        addSubview(previewBadge)
        previewBadge.isHidden = true
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        [fillLayer, committedLayer, previewLayer, pointLayer, startPointLayer, reticleLayer, reticleDotLayer]
            .forEach { $0.frame = bounds }
        CATransaction.commit()
    }

    func update(
        committed: [CGPoint],
        preview: [CGPoint],
        points: [CGPoint],
        committedMeasurements: [ScreenMeasurementLabel],
        previewMeasurement: ScreenMeasurementLabel?,
        closureReady: Bool,
        isClosed: Bool,
        reticleReady: Bool,
        reticleVisible: Bool
    ) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let committedPath = path(points: committed, close: isClosed)
        committedLayer.path = committedPath.cgPath
        fillLayer.path = isClosed ? committedPath.cgPath : nil

        let previewPath = path(points: preview, close: false)
        previewLayer.path = previewPath.cgPath
        previewLayer.strokeColor = (closureReady ? UIColor.systemGreen : UIColor.systemYellow).cgColor

        let anchors = UIBezierPath()
        for point in points where bounds.insetBy(dx: -30, dy: -30).contains(point) {
            anchors.append(UIBezierPath(ovalIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)))
        }
        pointLayer.path = anchors.cgPath

        updateCommittedBadges(committedMeasurements)
        updatePreviewBadge(previewMeasurement, closureReady: closureReady)

        if let startPoint = points.first,
           bounds.insetBy(dx: -30, dy: -30).contains(startPoint) {
            startPointLayer.path = UIBezierPath(
                ovalIn: CGRect(x: startPoint.x - 9, y: startPoint.y - 9, width: 18, height: 18)
            ).cgPath
            startPointLayer.strokeColor = (closureReady ? UIColor.systemGreen : UIColor.systemCyan).cgColor
            startPointLayer.isHidden = false
        } else {
            startPointLayer.path = nil
            startPointLayer.isHidden = true
        }

        let reticleColor = closureReady
            ? UIColor.systemGreen
            : (reticleReady ? UIColor.systemCyan : UIColor.systemYellow)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let reticle = UIBezierPath(
            ovalIn: CGRect(x: center.x - 17, y: center.y - 17, width: 34, height: 34)
        )
        reticle.move(to: CGPoint(x: center.x, y: center.y - 27))
        reticle.addLine(to: CGPoint(x: center.x, y: center.y + 27))
        reticle.move(to: CGPoint(x: center.x - 27, y: center.y))
        reticle.addLine(to: CGPoint(x: center.x + 27, y: center.y))
        reticleLayer.path = reticle.cgPath
        reticleLayer.strokeColor = reticleColor.cgColor
        reticleLayer.isHidden = !reticleVisible
        reticleDotLayer.path = UIBezierPath(
            ovalIn: CGRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5)
        ).cgPath
        reticleDotLayer.fillColor = reticleColor.cgColor
        reticleDotLayer.isHidden = !reticleVisible

        CATransaction.commit()
    }

    private func updateCommittedBadges(_ measurements: [ScreenMeasurementLabel]) {
        while committedBadges.count < measurements.count {
            let badge = MeasurementBadgeView(style: .committed)
            committedBadges.append(badge)
            addSubview(badge)
        }

        for (index, badge) in committedBadges.enumerated() {
            guard measurements.indices.contains(index) else {
                badge.isHidden = true
                continue
            }
            let measurement = measurements[index]
            badge.setText(measurement.text)
            position(badge, at: measurement.position)
            badge.isHidden = !bounds.insetBy(dx: -60, dy: -40).contains(measurement.position)
        }
    }

    private func updatePreviewBadge(
        _ measurement: ScreenMeasurementLabel?,
        closureReady: Bool
    ) {
        guard let measurement else {
            previewBadge.isHidden = true
            return
        }
        previewBadge.setText(measurement.text)
        previewBadge.setHighlighted(closureReady)
        position(previewBadge, at: measurement.position)
        previewBadge.isHidden = !bounds.insetBy(dx: -60, dy: -40).contains(measurement.position)
    }

    private func position(_ badge: MeasurementBadgeView, at point: CGPoint) {
        let size = badge.intrinsicContentSize
        badge.bounds = CGRect(origin: .zero, size: size)
        let horizontalInset = size.width * 0.5 + 8
        let verticalInset = size.height * 0.5 + 8
        badge.center = CGPoint(
            x: min(max(point.x, horizontalInset), max(horizontalInset, bounds.width - horizontalInset)),
            y: min(max(point.y, verticalInset), max(verticalInset, bounds.height - verticalInset))
        )
    }

    private func path(points: [CGPoint], close: Bool) -> UIBezierPath {
        let path = UIBezierPath()
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach(path.addLine)
        if close { path.close() }
        return path
    }
}

private final class MeasurementBadgeView: UILabel {
    enum Style {
        case committed
        case preview
    }

    private let style: Style

    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        textAlignment = .center
        textColor = .black
        backgroundColor = UIColor.white.withAlphaComponent(style == .preview ? 0.94 : 0.88)
        layer.cornerRadius = 10
        layer.borderWidth = style == .preview ? 1 : 0
        layer.borderColor = UIColor.systemYellow.withAlphaComponent(0.85).cgColor
        clipsToBounds = true
        isUserInteractionEnabled = false
        accessibilityTraits = .staticText
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: CGSize {
        let content = super.intrinsicContentSize
        return CGSize(width: content.width + 16, height: content.height + 8)
    }

    func setText(_ value: String) {
        guard text != value else { return }
        text = value
        invalidateIntrinsicContentSize()
        accessibilityLabel = "ความยาว \(value)"
    }

    func setHighlighted(_ highlighted: Bool) {
        guard style == .preview else { return }
        layer.borderColor = (highlighted ? UIColor.systemGreen : UIColor.systemYellow)
            .withAlphaComponent(0.9).cgColor
    }
}
