import Foundation

enum ShadowAreaError: Error, Equatable {
    case tooFewSegments
    case openProfile(gap: Double)
    case selfIntersection
    case negligibleArea
    case numericalMismatch
}

enum ShadowAreaCalculator {
    static func calculate(
        segments: [ProfileSegment],
        closureTolerance: Double = 0.003
    ) throws -> ShadowMeasurementResult {
        guard segments.count >= 2 else { throw ShadowAreaError.tooFewSegments }

        let maximumGap = ProfileValidator.maximumConnectionGap(segments)
        guard maximumGap <= closureTolerance else {
            throw ShadowAreaError.openProfile(gap: maximumGap)
        }
        guard !ProfileValidator.hasSelfIntersection(segments) else {
            throw ShadowAreaError.selfIntersection
        }

        let signedArea = segments.reduce(0.0) {
            $0 + $1.geometry.signedAreaContribution
        }
        let area = abs(signedArea)
        guard area >= 0.000_001 else { throw ShadowAreaError.negligibleArea }

        let perimeter = segments.reduce(0.0) { $0 + $1.length }
        let tessellated = ProfileValidator.tessellatedPolyline(
            segments,
            close: true,
            maximumChordError: 0.0001
        )
        let shoelaceArea = abs(zip(tessellated, tessellated.dropFirst()).reduce(0.0) {
            $0 + 0.5 * $1.0.cross($1.1)
        })
        let crossCheckTolerance = max(1e-8, perimeter * 0.0002)
        guard abs(area - shoelaceArea) <= crossCheckTolerance else {
            throw ShadowAreaError.numericalMismatch
        }

        let meanUncertainty = segments.reduce(0.0) {
            $0 + max($1.meanObservationUncertainty, $1.fitRMS)
        } / Double(segments.count)
        // First-order boundary perturbation bound, expanded to an approximate 95% interval.
        // This remains an engineering estimate until physical validation is complete.
        let uncertainty95 = max(0.000_001, 2 * perimeter * meanUncertainty)

        return ShadowMeasurementResult(
            areaSquareMeters: area,
            perimeterMeters: perimeter,
            uncertainty95SquareMeters: uncertainty95,
            segmentCount: segments.count,
            maximumFitRMS: segments.map(\.fitRMS).max() ?? 0
        )
    }
}
