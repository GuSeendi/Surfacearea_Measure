import Foundation

enum ProfileFitError: Error, Equatable {
    case insufficientObservations
    case coincidentEndpoints
    case invalidCurve
    case discontinuousTrace
    case unstableTrace
}

struct SegmentFit: Sendable {
    var geometry: SegmentGeometry
    var rmsError: Double
    var meanObservationUncertainty: Double
    var observationCount: Int
}

enum ProfileFitter {
    static func fit(
        observations: [PlanarObservation],
        mode: TraceMode
    ) throws -> SegmentFit {
        let reduced = spatiallyReduced(observations)
        guard reduced.count >= 2 else { throw ProfileFitError.insufficientObservations }

        let points = reduced.map(\.point)
        let start = points[0]
        let end = points[points.count - 1]
        guard start.distance(to: end) >= 0.001 else {
            throw ProfileFitError.coincidentEndpoints
        }

        let lineRMS = robustRMS(points.map { signedDistance($0, start, end) })
        let meanUncertainty = reduced.map(\.uncertainty).reduce(0, +) / Double(reduced.count)
        let line = SegmentFit(
            geometry: .line(start: start, end: end),
            rmsError: lineRMS,
            meanObservationUncertainty: meanUncertainty,
            observationCount: reduced.count
        )

        if mode == .line { return line }
        if mode == .arc {
            return try freeformFit(
                points: points,
                uncertainty: meanUncertainty,
                observationCount: reduced.count
            )
        }

        let chord = start.distance(to: end)
        let sagitta = robustSagitta(points: points, start: start, end: end)
        let minimumSagitta = max(0.008, meanUncertainty * 2.5)
        guard reduced.count >= 6, sagitta >= minimumSagitta else { return line }

        guard let arc = arcFit(points: points, uncertainty: meanUncertainty) else {
            return try freeformFit(
                points: points,
                uncertainty: meanUncertainty,
                observationCount: reduced.count
            )
        }
        let sweep = abs(arc.sweep)
        let automaticArcIsUsable = sweep >= .pi / 45
            && sweep <= .pi * 1.95
            && arc.rms < lineRMS * 0.82
            && arc.rms <= max(0.0025, meanUncertainty * 1.75)
            && arc.inlierRatio >= 0.70
            && arc.directionConsistency >= 0.72
            && arc.radius >= chord * 0.5

        guard automaticArcIsUsable else {
            return try freeformFit(
                points: points,
                uncertainty: meanUncertainty,
                observationCount: reduced.count
            )
        }

        return SegmentFit(
            geometry: .arc(
                center: arc.center,
                radius: arc.radius,
                startAngle: arc.startAngle,
                sweep: arc.sweep
            ),
            rmsError: arc.rms,
            meanObservationUncertainty: meanUncertainty,
            observationCount: reduced.count
        )
    }

    /// Retain the actual silhouette instead of forcing every curve onto one circle.
    /// A short spatial median removes isolated depth spikes; Douglas–Peucker then
    /// removes hand tremor below the sensor's lateral uncertainty. Endpoints stay exact.
    private static func freeformFit(
        points: [PlanarPoint],
        uncertainty: Double,
        observationCount: Int
    ) throws -> SegmentFit {
        guard points.count >= 5 else { throw ProfileFitError.insufficientObservations }
        var filtered = points
        for index in 1..<(points.count - 1) {
            let lower = max(0, index - 2)
            let upper = min(points.count - 1, index + 2)
            let neighborhood = Array(points[lower...upper])
            filtered[index] = PlanarPoint(
                x: median(neighborhood.map(\.x).sorted()),
                y: median(neighborhood.map(\.y).sorted())
            )
        }
        filtered[0] = points[0]
        filtered[filtered.count - 1] = points[points.count - 1]

        let maximumGap = max(0.05, uncertainty * 6)
        guard zip(filtered, filtered.dropFirst()).allSatisfy({
            $0.0.distance(to: $0.1) <= maximumGap
        }) else { throw ProfileFitError.discontinuousTrace }

        let tolerance = min(0.008, max(0.002, uncertainty * 1.25))
        let kept = simplify(filtered, tolerance: tolerance)
        guard kept.count >= 2 else { throw ProfileFitError.invalidCurve }
        let fitted = kept.map { filtered[$0] }
        let coarse = simplify(filtered, tolerance: tolerance * 2).map { filtered[$0] }
        let fineLength = pathLength(fitted)
        let coarseLength = pathLength(coarse)
        guard fineLength - coarseLength <= max(0.012, fineLength * 0.02) else {
            throw ProfileFitError.unstableTrace
        }
        let residuals = points.map { point in distance(point, to: fitted) }
        return SegmentFit(
            geometry: .freeform(points: fitted),
            rmsError: robustRMS(residuals),
            meanObservationUncertainty: uncertainty,
            observationCount: observationCount
        )
    }

    private static func simplify(_ points: [PlanarPoint], tolerance: Double) -> [Int] {
        guard points.count > 2 else { return Array(points.indices) }
        var selected = [0, points.count - 1]
        var pending = [(0, points.count - 1)]
        while let (start, end) = pending.popLast() {
            guard end > start + 1 else { continue }
            var maximum = 0.0
            var farthest = start
            for index in (start + 1)..<end {
                let error = distance(points[index], to: points[start], points[end])
                if error > maximum {
                    maximum = error
                    farthest = index
                }
            }
            if maximum > tolerance {
                selected.append(farthest)
                pending.append((start, farthest))
                pending.append((farthest, end))
            }
        }
        return selected.sorted()
    }

    private static func distance(_ point: PlanarPoint, to path: [PlanarPoint]) -> Double {
        zip(path, path.dropFirst()).map {
            distance(point, to: $0.0, $0.1)
        }.min() ?? .infinity
    }

    private static func pathLength(_ points: [PlanarPoint]) -> Double {
        zip(points, points.dropFirst()).reduce(0) {
            $0 + $1.0.distance(to: $1.1)
        }
    }

    private static func distance(
        _ point: PlanarPoint,
        to start: PlanarPoint,
        _ end: PlanarPoint
    ) -> Double {
        let edge = end - start
        let squaredLength = edge.dot(edge)
        guard squaredLength > 1e-12 else { return point.distance(to: start) }
        let fraction = min(1, max(0, (point - start).dot(edge) / squaredLength))
        return point.distance(to: start + edge * fraction)
    }

    private static func spatiallyReduced(_ observations: [PlanarObservation]) -> [PlanarObservation] {
        guard let first = observations.first else { return [] }
        var result = [first]
        result.reserveCapacity(min(observations.count, 512))

        for observation in observations.dropFirst().dropLast() {
            if result.last!.point.distance(to: observation.point) >= 0.0015 {
                result.append(observation)
            }
            if result.count == 511 { break }
        }

        if let last = observations.last, last.point != result.last?.point {
            result.append(last)
        }
        return result
    }

    private static func signedDistance(
        _ point: PlanarPoint,
        _ start: PlanarPoint,
        _ end: PlanarPoint
    ) -> Double {
        let chord = end - start
        let length = chord.length
        guard length > 0 else { return point.distance(to: start) }
        return chord.cross(point - start) / length
    }

    /// Uses the middle 85% of samples so one bad LiDAR return cannot decide
    /// whether an otherwise straight trace should become a curve.
    private static func robustRMS(_ residuals: [Double]) -> Double {
        guard !residuals.isEmpty else { return 0 }
        let ordered = residuals.sorted { abs($0) < abs($1) }
        let keepCount = max(2, Int(ceil(Double(ordered.count) * 0.85)))
        let kept = ordered.prefix(keepCount)
        return sqrt(kept.reduce(0.0) { $0 + $1 * $1 } / Double(kept.count))
    }

    private static func robustSagitta(
        points: [PlanarPoint],
        start: PlanarPoint,
        end: PlanarPoint
    ) -> Double {
        let values = points.dropFirst().dropLast()
            .map { abs(signedDistance($0, start, end)) }
            .sorted()
        guard !values.isEmpty else { return 0 }
        let index = min(values.count - 1, Int(Double(values.count - 1) * 0.70))
        return values[index]
    }

    private struct ArcFit {
        var center: PlanarPoint
        var radius: Double
        var startAngle: Double
        var sweep: Double
        var rms: Double
        var inlierRatio: Double
        var directionConsistency: Double
    }

    /// Fits a circle whose center is constrained to the perpendicular bisector
    /// of the endpoints. This keeps both tapped endpoints exact while all the
    /// intermediate samples vote on curvature. Median initialization, Huber
    /// weighting and an MAD inlier pass reject hand jitter and depth spikes.
    private static func arcFit(points: [PlanarPoint], uncertainty: Double) -> ArcFit? {
        guard points.count >= 3 else { return nil }
        let start = points[0]
        let end = points[points.count - 1]
        let chordVector = end - start
        let chord = chordVector.length
        guard chord >= 0.001 else { return nil }

        let tangent = PlanarPoint(x: chordVector.x / chord, y: chordVector.y / chord)
        let normal = PlanarPoint(x: -tangent.y, y: tangent.x)
        let midpoint = (start + end) * 0.5
        let halfChord = chord * 0.5
        let local = points.map { point -> (x: Double, y: Double) in
            let delta = point - midpoint
            return (delta.dot(tangent), delta.dot(normal))
        }

        let minimumOffset = max(0.000_25, chord * 0.001)
        var centerOffsets = local.dropFirst().dropLast().compactMap { sample -> Double? in
            guard abs(sample.y) >= minimumOffset else { return nil }
            let value = (
                sample.x * sample.x + sample.y * sample.y - halfChord * halfChord
            ) / (2 * sample.y)
            return value.isFinite && abs(value) <= 100 ? value : nil
        }
        guard !centerOffsets.isEmpty else { return nil }
        centerOffsets.sort()
        var offset = median(centerOffsets)

        offset = refineCenterOffset(
            offset,
            local: local,
            halfChord: halfChord,
            uncertainty: uncertainty,
            included: Array(local.indices)
        )

        var radialResiduals = radialErrors(local: local, halfChord: halfChord, offset: offset)
        let absoluteResiduals = radialResiduals.map(abs)
        let residualMedian = median(absoluteResiduals.sorted())
        let deviations = absoluteResiduals.map { abs($0 - residualMedian) }.sorted()
        let mad = median(deviations)
        let inlierLimit = max(0.0015, uncertainty * 2.5, residualMedian + 3.5 * 1.4826 * mad)
        var inliers = radialResiduals.indices.filter {
            $0 == 0 || $0 == radialResiduals.count - 1 || abs(radialResiduals[$0]) <= inlierLimit
        }
        guard inliers.count >= 3 else { return nil }

        offset = refineCenterOffset(
            offset,
            local: local,
            halfChord: halfChord,
            uncertainty: uncertainty,
            included: inliers
        )
        radialResiduals = radialErrors(local: local, halfChord: halfChord, offset: offset)
        inliers = radialResiduals.indices.filter {
            $0 == 0 || $0 == radialResiduals.count - 1 || abs(radialResiduals[$0]) <= inlierLimit
        }

        let radius = hypot(halfChord, offset)
        guard radius.isFinite, radius >= halfChord, radius >= 0.003, radius <= 100 else {
            return nil
        }
        let center = midpoint + normal * offset
        let startAngle = atan2(start.y - center.y, start.x - center.x)
        let angles = inliers.map { index in
            atan2(points[index].y - center.y, points[index].x - center.x)
        }
        guard let sweepAnalysis = orderedSweep(
            angles: angles,
            endAngle: atan2(end.y - center.y, end.x - center.x),
            startAngle: startAngle
        ), abs(sweepAnalysis.sweep) > 1e-5
        else { return nil }

        let inlierResiduals = inliers.map { radialResiduals[$0] }
        return ArcFit(
            center: center,
            radius: radius,
            startAngle: startAngle,
            sweep: sweepAnalysis.sweep,
            rms: robustRMS(inlierResiduals),
            inlierRatio: Double(inliers.count) / Double(points.count),
            directionConsistency: sweepAnalysis.consistency
        )
    }

    private static func refineCenterOffset(
        _ initial: Double,
        local: [(x: Double, y: Double)],
        halfChord: Double,
        uncertainty: Double,
        included: [Int]
    ) -> Double {
        var offset = initial
        for _ in 0..<12 {
            let radius = hypot(halfChord, offset)
            guard radius > 1e-9 else { break }
            let residuals = radialErrors(local: local, halfChord: halfChord, offset: offset)
            let scale = max(0.00075, uncertainty * 1.5)
            var numerator = 0.0
            var denominator = 0.0
            for index in included {
                let sample = local[index]
                let distance = hypot(sample.x, sample.y - offset)
                guard distance > 1e-9 else { continue }
                let residual = residuals[index]
                let derivative = (offset - sample.y) / distance - offset / radius
                let weight = abs(residual) <= scale ? 1 : scale / abs(residual)
                numerator += weight * residual * derivative
                denominator += weight * derivative * derivative
            }
            guard denominator > 1e-12 else { break }
            let rawStep = numerator / denominator
            let maximumStep = max(0.01, min(0.5, max(abs(offset), halfChord) * 0.35))
            let step = min(max(rawStep, -maximumStep), maximumStep)
            offset -= step
            offset = min(max(offset, -100), 100)
            if abs(step) < 1e-8 { break }
        }
        return offset
    }

    private static func radialErrors(
        local: [(x: Double, y: Double)],
        halfChord: Double,
        offset: Double
    ) -> [Double] {
        let radius = hypot(halfChord, offset)
        return local.map { hypot($0.x, $0.y - offset) - radius }
    }

    private static func orderedSweep(
        angles: [Double],
        endAngle: Double,
        startAngle: Double
    ) -> (sweep: Double, consistency: Double)? {
        guard angles.count >= 2 else { return nil }
        var previous = angles[0]
        var accumulated = 0.0
        var totalVariation = 0.0
        for angle in angles.dropFirst() {
            let delta = signedAngle(angle - previous)
            accumulated += delta
            totalVariation += abs(delta)
            previous = angle
        }

        let endpointDelta = endAngle - startAngle
        let revolutions = ((accumulated - endpointDelta) / (2 * .pi)).rounded()
        let sweep = endpointDelta + revolutions * 2 * .pi
        guard totalVariation > 1e-8 else { return nil }
        return (sweep, min(1, abs(sweep) / totalVariation))
    }

    private static func signedAngle(_ value: Double) -> Double {
        var angle = value.truncatingRemainder(dividingBy: 2 * .pi)
        if angle > .pi { angle -= 2 * .pi }
        if angle < -.pi { angle += 2 * .pi }
        return angle
    }

    private static func median(_ orderedValues: [Double]) -> Double {
        guard !orderedValues.isEmpty else { return 0 }
        let middle = orderedValues.count / 2
        if orderedValues.count.isMultiple(of: 2) {
            return (orderedValues[middle - 1] + orderedValues[middle]) * 0.5
        }
        return orderedValues[middle]
    }
}
