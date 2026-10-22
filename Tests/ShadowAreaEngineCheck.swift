import Foundation
import simd

@main
enum ShadowAreaEngineCheck {
    static func main() throws {
        print("check: rectangle")
        try rectangleAreaIsExact()
        print("check: orientation")
        try orientationDoesNotChangeArea()
        print("check: circle")
        try circularArcAreaIsExact()
        print("check: crossing")
        try selfIntersectionIsRejected()
        print("check: overlap")
        try overlappingEdgeIsRejected()
        print("check: line fit")
        try automaticFitRecognizesLine()
        print("check: arc fit")
        try automaticFitRecognizesArc()
        print("check: noisy arc with depth spike")
        try robustArcFitRejectsOutlier()
        print("check: straight trace with spike")
        try straightTraceWithOutlierStaysLine()
        print("check: temporal endpoint filter")
        temporalEndpointFilterRejectsDepthSpike()
        print("check: moving endpoint rejection")
        temporalEndpointFilterRejectsMotion()
        print("ShadowAreaEngineCheck: all checks passed")
    }

    private static func rectangleAreaIsExact() throws {
        let points = [
            PlanarPoint(x: 0, y: 0),
            PlanarPoint(x: 2, y: 0),
            PlanarPoint(x: 2, y: 1),
            PlanarPoint(x: 0, y: 1)
        ]
        let result = try ShadowAreaCalculator.calculate(segments: polygon(points))
        assertNear(result.areaSquareMeters, 2, tolerance: 1e-12, "rectangle area")
        assertNear(result.perimeterMeters, 6, tolerance: 1e-12, "rectangle perimeter")
    }

    private static func orientationDoesNotChangeArea() throws {
        let points = [
            PlanarPoint(x: 0, y: 0),
            PlanarPoint(x: 0, y: 1),
            PlanarPoint(x: 2, y: 1),
            PlanarPoint(x: 2, y: 0)
        ]
        let result = try ShadowAreaCalculator.calculate(segments: polygon(points))
        assertNear(result.areaSquareMeters, 2, tolerance: 1e-12, "clockwise area")
    }

    private static func circularArcAreaIsExact() throws {
        let center = PlanarPoint.zero
        let segments = [
            segment(.arc(center: center, radius: 1, startAngle: 0, sweep: .pi)),
            segment(.arc(center: center, radius: 1, startAngle: .pi, sweep: .pi))
        ]
        let result = try ShadowAreaCalculator.calculate(segments: segments)
        assertNear(result.areaSquareMeters, .pi, tolerance: 1e-10, "circle area")
        assertNear(result.perimeterMeters, 2 * .pi, tolerance: 1e-10, "circle perimeter")
    }

    private static func selfIntersectionIsRejected() throws {
        let bowTie = polygon([
            PlanarPoint(x: 0, y: 0),
            PlanarPoint(x: 1, y: 1),
            PlanarPoint(x: 0, y: 1),
            PlanarPoint(x: 1, y: 0)
        ])
        do {
            _ = try ShadowAreaCalculator.calculate(segments: bowTie)
            fatalError("self-intersecting profile was accepted")
        } catch ShadowAreaError.selfIntersection {
            return
        }
    }

    private static func overlappingEdgeIsRejected() throws {
        let overlap = polygon([
            PlanarPoint(x: 0, y: 0),
            PlanarPoint(x: 2, y: 0),
            PlanarPoint(x: 1, y: 0),
            PlanarPoint(x: 1, y: 1),
            PlanarPoint(x: 0, y: 1)
        ])
        do {
            _ = try ShadowAreaCalculator.calculate(segments: overlap)
            fatalError("overlapping boundary was accepted")
        } catch ShadowAreaError.selfIntersection {
            return
        }
    }

    private static func automaticFitRecognizesLine() throws {
        let observations = (0...20).map { index in
            let x = Double(index) / 20
            return PlanarObservation(
                point: PlanarPoint(x: x, y: sin(x * 30) * 0.0001),
                uncertainty: 0.001,
                timestamp: Double(index)
            )
        }
        let fit = try ProfileFitter.fit(observations: observations, mode: .automatic)
        guard fit.geometry.kind == .line else { fatalError("straight trace fitted as arc") }
    }

    private static func automaticFitRecognizesArc() throws {
        let observations = (0...30).map { index in
            let angle = Double(index) / 30 * Double.pi / 2
            return PlanarObservation(
                point: PlanarPoint(x: cos(angle), y: sin(angle)),
                uncertainty: 0.001,
                timestamp: Double(index)
            )
        }
        let fit = try ProfileFitter.fit(observations: observations, mode: .automatic)
        guard case let .arc(_, radius, _, sweep) = fit.geometry else {
            fatalError("quarter circle fitted as line")
        }
        assertNear(radius, 1, tolerance: 1e-10, "fitted radius")
        assertNear(abs(sweep), .pi / 2, tolerance: 1e-10, "fitted sweep")
    }

    private static func robustArcFitRejectsOutlier() throws {
        let radius = 0.5
        let observations = (0...40).map { index in
            let angle = Double(index) / 40 * Double.pi / 2
            let jitter = (index == 0 || index == 40) ? 0 : sin(Double(index) * 1.7) * 0.0007
            var point = PlanarPoint(
                x: (radius + jitter) * cos(angle),
                y: (radius + jitter) * sin(angle)
            )
            if index == 19 {
                point.x += 0.06
                point.y -= 0.045
            }
            return PlanarObservation(
                point: point,
                uncertainty: 0.001,
                timestamp: Double(index)
            )
        }

        let fit = try ProfileFitter.fit(observations: observations, mode: .automatic)
        guard case let .arc(_, fittedRadius, _, sweep) = fit.geometry else {
            fatalError("noisy quarter circle fitted as line")
        }
        assertNear(fittedRadius, radius, tolerance: 0.005, "robust fitted radius")
        assertNear(abs(sweep), .pi / 2, tolerance: 0.02, "robust fitted sweep")
        assertNear(
            fit.geometry.start.distance(to: observations[0].point),
            0,
            tolerance: 1e-10,
            "arc start endpoint"
        )
        assertNear(
            fit.geometry.end.distance(to: observations[40].point),
            0,
            tolerance: 1e-10,
            "arc end endpoint"
        )
    }

    private static func straightTraceWithOutlierStaysLine() throws {
        let observations = (0...30).map { index in
            let x = Double(index) / 30
            let y = index == 14 ? 0.08 : sin(Double(index) * 2.3) * 0.0002
            return PlanarObservation(
                point: PlanarPoint(x: x, y: y),
                uncertainty: 0.001,
                timestamp: Double(index)
            )
        }
        let fit = try ProfileFitter.fit(observations: observations, mode: .automatic)
        guard fit.geometry.kind == .line else {
            fatalError("single depth spike turned a straight trace into an arc")
        }
    }

    private static func temporalEndpointFilterRejectsDepthSpike() {
        let plane = MeasurementPlane(
            origin: SIMD3<Float>(repeating: 0),
            normal: SIMD3<Float>(0, 0, 1),
            axisU: SIMD3<Float>(1, 0, 0),
            axisV: SIMD3<Float>(0, 1, 0)
        )
        let target = SIMD3<Float>(0.42, -0.18, 1.15)
        var filter = TemporalPointFilter()
        var reference: CursorSample?

        for index in 0..<9 {
            let jitter = Float(index % 3 - 1) * 0.0008
            var point = target + SIMD3<Float>(jitter, -jitter * 0.5, jitter * 0.25)
            if index == 5 {
                point += SIMD3<Float>(0.055, -0.04, 0.07)
            }
            let sample = cursor(point: point, timestamp: Double(index) / 30)
            filter.append(sample)
            if index == 8 { reference = sample }
        }

        guard let reference,
              let estimate = filter.stableEstimate(near: reference, plane: plane)
        else { fatalError("stable endpoint was rejected") }
        guard simd_distance(estimate.rawWorldPoint, target) < 0.002 else {
            fatalError("depth spike biased endpoint: \(estimate.rawWorldPoint)")
        }
        guard let planar = estimate.planarPoint else {
            fatalError("stable endpoint was not projected")
        }
        assertNear(planar.x, Double(target.x), tolerance: 0.002, "filtered endpoint x")
        assertNear(planar.y, Double(target.y), tolerance: 0.002, "filtered endpoint y")
    }

    private static func temporalEndpointFilterRejectsMotion() {
        var filter = TemporalPointFilter()
        var reference: CursorSample?
        for index in 0..<9 {
            let point = SIMD3<Float>(Float(index) * 0.012, 0, 1)
            let sample = cursor(point: point, timestamp: Double(index) / 30)
            filter.append(sample)
            reference = sample
        }
        guard let reference else { fatalError("missing moving reference") }
        if filter.stableEstimate(near: reference, plane: nil) != nil {
            fatalError("moving endpoint was accepted")
        }
    }

    private static func cursor(
        point: SIMD3<Float>,
        timestamp: TimeInterval
    ) -> CursorSample {
        CursorSample(
            rawWorldPoint: point,
            planarPoint: nil,
            planeResidualMeters: nil,
            uncertaintyMeters: 0.0035,
            timestamp: timestamp
        )
    }

    private static func polygon(_ points: [PlanarPoint]) -> [ProfileSegment] {
        points.indices.map { index in
            let next = (index + 1) % points.count
            return segment(.line(start: points[index], end: points[next]))
        }
    }

    private static func segment(_ geometry: SegmentGeometry) -> ProfileSegment {
        ProfileSegment(
            geometry: geometry,
            fitRMS: 0,
            meanObservationUncertainty: 0.001,
            observationCount: 10
        )
    }

    private static func assertNear(
        _ actual: Double,
        _ expected: Double,
        tolerance: Double,
        _ label: String
    ) {
        guard abs(actual - expected) <= tolerance else {
            fatalError("\(label): expected \(expected), got \(actual)")
        }
    }
}
