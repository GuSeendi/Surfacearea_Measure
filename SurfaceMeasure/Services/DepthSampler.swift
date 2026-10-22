@preconcurrency import ARKit
import CoreVideo
import Foundation
import simd

struct DepthFrameSample: Sendable {
    var timestamp: TimeInterval
    var cameraTransform: simd_float4x4
    var tracking: TrackingGrade
    var worldPoint: SIMD3<Float>?
    var depthGrade: DepthGrade
    var depthUncertaintyMeters: Double
}

enum DepthSampler {
    static func sampleCenter(of frame: ARFrame) -> DepthFrameSample {
        let tracking = trackingGrade(frame.camera.trackingState)
        guard let depth = frame.sceneDepth ?? frame.smoothedSceneDepth,
              let sample = robustCenterDepth(
                depthMap: depth.depthMap,
                confidenceMap: depth.confidenceMap
              )
        else {
            return DepthFrameSample(
                timestamp: frame.timestamp,
                cameraTransform: frame.camera.transform,
                tracking: tracking,
                worldPoint: nil,
                depthGrade: .unavailable,
                depthUncertaintyMeters: 0.03
            )
        }

        let depthWidth = Float(CVPixelBufferGetWidth(depth.depthMap))
        let depthHeight = Float(CVPixelBufferGetHeight(depth.depthMap))
        let imageResolution = frame.camera.imageResolution
        let scaleX = depthWidth / Float(imageResolution.width)
        let scaleY = depthHeight / Float(imageResolution.height)
        let intrinsics = frame.camera.intrinsics
        let fx = intrinsics.columns.0.x * scaleX
        let fy = intrinsics.columns.1.y * scaleY
        let cx = intrinsics.columns.2.x * scaleX
        let cy = intrinsics.columns.2.y * scaleY
        let pixelX = (depthWidth - 1) * 0.5
        let pixelY = (depthHeight - 1) * 0.5
        let z = sample.depth

        guard fx > 0, fy > 0, z.isFinite, z > 0 else {
            return DepthFrameSample(
                timestamp: frame.timestamp,
                cameraTransform: frame.camera.transform,
                tracking: tracking,
                worldPoint: nil,
                depthGrade: .unavailable,
                depthUncertaintyMeters: 0.03
            )
        }

        let cameraPoint = SIMD4<Float>(
            (pixelX - cx) * z / fx,
            -(pixelY - cy) * z / fy,
            -z,
            1
        )
        let world = frame.camera.transform * cameraPoint
        let uncertainty: Double = switch sample.grade {
        case .high: max(0.0035, Double(z) * 0.003)
        case .medium: max(0.008, Double(z) * 0.006)
        case .low: max(0.018, Double(z) * 0.012)
        case .unavailable: 0.03
        }

        return DepthFrameSample(
            timestamp: frame.timestamp,
            cameraTransform: frame.camera.transform,
            tracking: tracking,
            worldPoint: SIMD3(world.x, world.y, world.z),
            depthGrade: sample.grade,
            depthUncertaintyMeters: uncertainty
        )
    }

    private static func robustCenterDepth(
        depthMap: CVPixelBuffer,
        confidenceMap: CVPixelBuffer?
    ) -> (depth: Float, grade: DepthGrade)? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        if let confidenceMap { CVPixelBufferLockBaseAddress(confidenceMap, .readOnly) }
        defer {
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            if let confidenceMap { CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly) }
        }

        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let depthStride = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float32>.size
        let depths = depthBase.assumingMemoryBound(to: Float32.self)
        let confidenceBase: UnsafeMutablePointer<UInt8>?
        if let confidenceMap, let base = CVPixelBufferGetBaseAddress(confidenceMap) {
            confidenceBase = base.assumingMemoryBound(to: UInt8.self)
        } else {
            confidenceBase = nil
        }
        let confidenceStride = confidenceMap.map(CVPixelBufferGetBytesPerRow) ?? 0
        let centerX = width / 2
        let centerY = height / 2
        var preferred: [(Float, UInt8)] = []
        var fallback: [(Float, UInt8)] = []

        for y in max(0, centerY - 2)...min(height - 1, centerY + 2) {
            for x in max(0, centerX - 2)...min(width - 1, centerX + 2) {
                let value = depths[y * depthStride + x]
                guard value.isFinite, value > 0.05, value < 8 else { continue }
                let confidence = confidenceBase.map { $0[y * confidenceStride + x] } ?? 1
                fallback.append((value, confidence))
                if confidence >= 1 { preferred.append((value, confidence)) }
            }
        }

        let values = preferred.count >= 3 ? preferred : fallback
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted { $0.0 < $1.0 }
        let median = sorted[sorted.count / 2].0
        let sortedConfidence = values.map(\.1).sorted()
        let confidence = sortedConfidence[sortedConfidence.count / 2]
        let grade = DepthGrade(rawValue: Int(confidence)) ?? .low
        return (median, grade)
    }

    private static func trackingGrade(_ state: ARCamera.TrackingState) -> TrackingGrade {
        switch state {
        case .normal: .normal
        case .limited: .limited
        case .notAvailable: .unavailable
        }
    }
}
