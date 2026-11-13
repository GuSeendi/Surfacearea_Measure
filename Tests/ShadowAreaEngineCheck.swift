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
        print("check: irregular freeform curve")
        try irregularCurvePreservesProjectedAreaAndLength()
        print("check: automatic irregular curve")
        try automaticFitRetainsIrregularCurve()
        print("check: hand tremor does not inflate length")
        try handTremorDoesNotInflateLength()
        print("check: unstable trace rejection")
        try unstableTraceIsRejected()
        print("check: freeform gap rejection")
        try freeformGapIsRejected()
        print("check: freeform crossing rejection")
        try freeformSelfIntersectionIsRejected()
        print("check: temporal endpoint filter")
        temporalEndpointFilterRejectsDepthSpike()
        print("check: moving endpoint rejection")
        temporalEndpointFilterRejectsMotion()
        print("check: direct 3D straight length")
        straightLengthUsesSpatialDistance()
        print("check: final cubic-meter volume")
        finalVolumeUsesAreaTimesStraightLength()
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

    private static func irregularCurvePreservesProjectedAreaAndLength() throws {
        func boundary(_ x: Double) -> PlanarPoint {
            PlanarPoint(
                x: x,
                y: 0.2 * sin(.pi * x) + 0.07 * sin(3 * .pi * x)
            )
        }
        let observations = (0...100).map { index in
            let x = Double(index) / 100
            var point = boundary(x)
            if index != 0 && index != 100 {
                point.y += sin(Double(index) * 2.7) * 0.0015
            }
            if index == 48 { point.y += 0.06 }
            return PlanarObservation(
                point: point,
                uncertainty: 0.0035,
                timestamp: Double(index) / 30
            )
        }
        let fit = try ProfileFitter.fit(observations: observations, mode: .arc)
        guard case let .freeform(points) = fit.geometry, points.count >= 4 else {
            fatalError("irregular curve was reduced to a circular arc or line")
        }
        assertNear(fit.geometry.start.distance(to: boundary(0)), 0, tolerance: 1e-12, "curve start")
        assertNear(fit.geometry.end.distance(to: boundary(1)), 0, tolerance: 1e-12, "curve end")

        let reference = (0...10_000).map { boundary(Double($0) / 10_000) }
        let referenceLength = zip(reference, reference.dropFirst()).reduce(0.0) {
            $0 + $1.0.distance(to: $1.1)
        }
        assertNear(fit.geometry.length, referenceLength, tolerance: 0.025, "freeform length")

        let closing = segment(.line(start: boundary(1), end: boundary(0)))
        let result = try ShadowAreaCalculator.calculate(segments: [
            segment(fit.geometry), closing
        ])
        let referenceArea = 0.4 / .pi + 0.14 / (3 * .pi)
        assertNear(result.areaSquareMeters, referenceArea, tolerance: 0.005, "freeform area")
    }

    private static func freeformGapIsRejected() throws {
        let observations = (0...10).map { index in
            let x = index < 5 ? Double(index) * 0.01 : Double(index) * 0.01 + 0.1
            return PlanarObservation(
                point: PlanarPoint(x: x, y: 0.1 * sin(x * .pi)),
                uncertainty: 0.0035,
                timestamp: Double(index) / 30
            )
        }
        do {
            _ = try ProfileFitter.fit(observations: observations, mode: .arc)
            fatalError("skipped boundary was silently bridged")
        } catch ProfileFitError.discontinuousTrace {
            return
        }
    }

    private static func automaticFitRetainsIrregularCurve() throws {
        let observations = (0...100).map { index in
            let x = Double(index) / 100
            return PlanarObservation(
                point: PlanarPoint(
                    x: x,
                    y: 0.2 * sin(.pi * x) + 0.07 * sin(3 * .pi * x)
                ),
                uncertainty: 0.0035,
                timestamp: Double(index) / 30
            )
        }
        let fit = try ProfileFitter.fit(observations: observations, mode: .automatic)
        guard case .freeform = fit.geometry else {
            fatalError("automatic mode forced an irregular curve into one circle")
        }
    }

    private static func handTremorDoesNotInflateLength() throws {
        let observations = (0...100).map { index in
            let x = Double(index) / 100
            let y = index == 0 || index == 100
                ? 0 : 0.003 * sin(Double(index) * 1.3)
            return PlanarObservation(
                point: PlanarPoint(x: x, y: y),
                uncertainty: 0.0035,
                timestamp: Double(index) / 30
            )
        }
        let fit = try ProfileFitter.fit(observations: observations, mode: .arc)
        guard fit.geometry.length < 1.01 else {
            fatalError("hand tremor inflated curve length: \(fit.geometry.length)")
        }
    }

    private static func unstableTraceIsRejected() throws {
        let observations = (0...100).map { index in
            let x = Double(index) / 100
            let y = index == 0 || index == 100
                ? 0 : 0.015 * sin(Double(index) * 0.65)
            return PlanarObservation(
                point: PlanarPoint(x: x, y: y),
                uncertainty: 0.0035,
                timestamp: Double(index) / 30
            )
        }
        do {
            _ = try ProfileFitter.fit(observations: observations, mode: .arc)
            fatalError("unstable hand motion was accepted as precise curve")
        } catch ProfileFitError.unstableTrace {
            return
        }
    }

    private static func freeformSelfIntersectionIsRejected() throws {
        let crossed = segment(.freeform(points: [
            PlanarPoint(x: 0, y: 0),
            PlanarPoint(x: 1, y: 1),
            PlanarPoint(x: 0, y: 1),
            PlanarPoint(x: 1, y: 0)
        ]))
        let closing = segment(.line(
            start: PlanarPoint(x: 1, y: 0),
            end: PlanarPoint(x: 0, y: 0)
        ))
        guard ProfileValidator.hasSelfIntersection([crossed], close: false) else {
            fatalError("self-crossing curve was not detected before committing the side")
        }
        do {
            _ = try ShadowAreaCalculator.calculate(segments: [crossed, closing])
            fatalError("self-crossing freeform boundary was accepted")
        } catch ShadowAreaError.selfIntersection {
            return
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

    private static func straightLengthUsesSpatialDistance() {
        let start = SIMD3<Float>(0, 0, 0)
        let end = SIMD3<Float>(3, 4, 12)
        let measurement = StraightLengthMeasurement(
            startWorldPoint: start,
            endWorldPoint: end
        )
        assertNear(measurement.lengthMeters, 13, tolerance: 1e-10, "3D line length")

        let plane = MeasurementPlane(
            origin: .zero,
            normal: SIMD3<Float>(0, 0, 1),
            axisU: SIMD3<Float>(1, 0, 0),
            axisV: SIMD3<Float>(0, 1, 0)
        )
        let projectedLength = plane.project(start).point.distance(
            to: plane.project(end).point
        )
        assertNear(projectedLength, 5, tolerance: 1e-10, "2D projection contrast")
        guard measurement.lengthMeters > projectedLength else {
            fatalError("straight length was incorrectly projected onto the area plane")
        }

        let areaResult = ShadowMeasurementResult(
            areaSquareMeters: 1,
            perimeterMeters: 4,
            uncertainty95SquareMeters: 0.01,
            segmentCount: 4,
            maximumFitRMS: 0
        )
        let report = MeasurementReport.plainText(
            result: areaResult,
            segments: [],
            lengthMeasurement: measurement
        )
        guard report.contains("ความยาวเส้นตรงจริง 3D:") else {
            fatalError("combined report omitted the direct 3D length")
        }
    }

    private static func finalVolumeUsesAreaTimesStraightLength() {
        let areaResult = ShadowMeasurementResult(
            areaSquareMeters: 0.6,
            perimeterMeters: 123,
            uncertainty95SquareMeters: 0.01,
            segmentCount: 4,
            maximumFitRMS: 0
        )
        let line = StraightLengthMeasurement(
            startWorldPoint: .zero,
            endWorldPoint: SIMD3<Float>(0, 0, 2.5)
        )
        let cubicMeters = MeasurementReport.cubicMeters(
            areaSquareMeters: areaResult.areaSquareMeters,
            straightLengthMeters: line.lengthMeters
        )
        assertNear(cubicMeters, 1.5, tolerance: 1e-12, "area × direct length")
        guard MeasurementReport.volume(cubicMeters) == "1.5 m³" else {
            fatalError("volume is not formatted in cubic meters")
        }

        let areaOnly = MeasurementReport.plainText(result: areaResult, segments: [])
        guard !areaOnly.contains("ปริมาตร") else {
            fatalError("volume appeared before the straight length was measured")
        }
        let completed = MeasurementReport.plainText(
            result: areaResult,
            segments: [],
            lengthMeasurement: line
        )
        guard completed.contains("ปริมาตรโดยประมาณ"), completed.contains("1.5 m³") else {
            fatalError("final report omitted the measured volume")
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
