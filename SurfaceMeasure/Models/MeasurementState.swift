import Foundation
import simd

enum MeasurementPhase: Equatable {
    case preparing
    case findingPlane
    case tracing
    case result
    case unavailable(String)
}

enum CameraAuthorizationState: Equatable {
    case unknown
    case authorized
    case denied
}

struct MeasurementPlane: Sendable {
    var origin: SIMD3<Float>
    var normal: SIMD3<Float>
    var axisU: SIMD3<Float>
    var axisV: SIMD3<Float>

    func project(_ worldPoint: SIMD3<Float>) -> (point: PlanarPoint, residual: Double) {
        let delta = worldPoint - origin
        let residual = simd_dot(delta, normal)
        let flattened = delta - residual * normal
        return (
            PlanarPoint(
                x: Double(simd_dot(flattened, axisU)),
                y: Double(simd_dot(flattened, axisV))
            ),
            Double(residual)
        )
    }

    func worldPoint(for point: PlanarPoint) -> SIMD3<Float> {
        origin + axisU * Float(point.x) + axisV * Float(point.y)
    }
}

struct CursorSample: Sendable {
    var rawWorldPoint: SIMD3<Float>
    var planarPoint: PlanarPoint?
    var planeResidualMeters: Double?
    var uncertaintyMeters: Double
    var timestamp: TimeInterval
}

struct TemporalPointFilter: Sendable {
    private var samples: [CursorSample] = []
    private let maximumSampleCount = 15
    private let maximumAge: TimeInterval = 0.28
    private let minimumSampleCount = 5
    private let maximumClusterRadius: Float = 0.018

    mutating func append(_ sample: CursorSample) {
        guard sample.rawWorldPoint.x.isFinite,
              sample.rawWorldPoint.y.isFinite,
              sample.rawWorldPoint.z.isFinite
        else { return }

        samples.removeAll { sample.timestamp - $0.timestamp > maximumAge }
        samples.append(sample)
        if samples.count > maximumSampleCount {
            samples.removeFirst(samples.count - maximumSampleCount)
        }
    }

    mutating func reset() {
        samples.removeAll(keepingCapacity: true)
    }

    func stableEstimate(
        near reference: CursorSample,
        plane: MeasurementPlane?
    ) -> CursorSample? {
        let referenceUncertainty = Float(max(reference.uncertaintyMeters, 0.0025))
        let neighborhoodRadius = min(
            0.03,
            max(0.012, referenceUncertainty * 3)
        )
        let recent = samples.filter {
            reference.timestamp - $0.timestamp >= 0
                && reference.timestamp - $0.timestamp <= maximumAge
                && simd_distance($0.rawWorldPoint, reference.rawWorldPoint) <= neighborhoodRadius
        }
        guard recent.count >= minimumSampleCount,
              let firstTimestamp = recent.first?.timestamp,
              let lastTimestamp = recent.last?.timestamp,
              lastTimestamp - firstTimestamp >= 0.08
        else { return nil }

        let medianPoint = SIMD3<Float>(
            median(recent.map { $0.rawWorldPoint.x }),
            median(recent.map { $0.rawWorldPoint.y }),
            median(recent.map { $0.rawWorldPoint.z })
        )
        let medianUncertainty = median(recent.map { Float(max($0.uncertaintyMeters, 0.0025)) })
        let inlierRadius = min(
            maximumClusterRadius,
            max(0.006, medianUncertainty * 2.5)
        )
        let inliers = recent.filter {
            simd_distance($0.rawWorldPoint, medianPoint) <= inlierRadius
        }
        guard inliers.count >= minimumSampleCount else { return nil }

        var weightedPoint = SIMD3<Float>(repeating: 0)
        var totalWeight: Float = 0
        for sample in inliers {
            let uncertainty = Float(max(sample.uncertaintyMeters, 0.0025))
            let weight = 1 / (uncertainty * uncertainty)
            weightedPoint += sample.rawWorldPoint * weight
            totalWeight += weight
        }
        guard totalWeight.isFinite, totalWeight > 0 else { return nil }
        weightedPoint /= totalWeight

        let squaredDistances = inliers.map {
            let distance = simd_distance($0.rawWorldPoint, weightedPoint)
            return distance * distance
        }
        let rmsSpread = sqrt(squaredDistances.reduce(0, +) / Float(squaredDistances.count))
        let permittedSpread = min(
            maximumClusterRadius * 0.65,
            max(0.004, medianUncertainty * 1.5)
        )
        guard rmsSpread <= permittedSpread,
              simd_distance(weightedPoint, reference.rawWorldPoint)
                <= max(0.012, medianUncertainty * 2)
        else { return nil }

        let projection = plane?.project(weightedPoint)
        return CursorSample(
            rawWorldPoint: weightedPoint,
            planarPoint: projection?.point,
            planeResidualMeters: projection?.residual,
            uncertaintyMeters: max(
                max(Double(medianUncertainty), Double(rmsSpread)),
                0.0025
            ),
            timestamp: reference.timestamp
        )
    }

    private func median(_ values: [Float]) -> Float {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) * 0.5
        }
        return sorted[middle]
    }
}
