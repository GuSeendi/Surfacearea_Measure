import Foundation

enum CaptureQualityEvaluator {
    static let minimumDistance = 0.30
    static let maximumDistance = 3.00
    static let maximumSpeed = 0.38
    static let minimumFrontalScore = 0.42

    static func evaluate(_ telemetry: FrameTelemetry) -> CaptureQuality {
        var issues: [QualityIssue] = []

        if telemetry.tracking != .normal { issues.append(.tracking) }
        if telemetry.depth < .medium { issues.append(.depth) }

        if let distance = telemetry.distanceMeters {
            if distance < minimumDistance { issues.append(.tooClose) }
            if distance > maximumDistance { issues.append(.tooFar) }
        }
        if telemetry.speedMetersPerSecond > maximumSpeed {
            issues.append(.movingTooFast)
        }
        if let frontalScore = telemetry.frontalScore,
           frontalScore < minimumFrontalScore {
            issues.append(.obliqueView)
        }
        // `.serious` can be reported during sustained camera/LiDAR use or a debug
        // session even while the enclosure still feels cool. Keep measuring and let
        // iOS throttle nonessential work; block capture only at the critical state.
        if telemetry.thermalState == .critical {
            issues.append(.thermal)
        }

        let motionPenalty = max(0, telemetry.speedMetersPerSecond - 0.08) * 0.012
        let anglePenalty: Double
        if let frontalScore = telemetry.frontalScore {
            anglePenalty = max(0, 1 - frontalScore) * 0.008
        } else {
            anglePenalty = 0.004
        }

        return CaptureQuality(
            tracking: telemetry.tracking,
            depth: telemetry.depth,
            distanceMeters: telemetry.distanceMeters,
            speedMetersPerSecond: telemetry.speedMetersPerSecond,
            frontalScore: telemetry.frontalScore,
            uncertaintyMeters: telemetry.depthUncertaintyMeters + motionPenalty + anglePenalty,
            issues: issues
        )
    }
}
