import Foundation

enum ProfileValidator {
    static func maximumConnectionGap(_ segments: [ProfileSegment]) -> Double {
        guard !segments.isEmpty else { return .infinity }
        var maximum = 0.0
        for index in segments.indices {
            let next = segments.index(after: index)
            let nextIndex = next == segments.endIndex ? segments.startIndex : next
            maximum = max(
                maximum,
                segments[index].geometry.end.distance(to: segments[nextIndex].geometry.start)
            )
        }
        return maximum
    }

    static func hasSelfIntersection(_ segments: [ProfileSegment]) -> Bool {
        let polyline = tessellatedPolyline(segments, close: true, maximumChordError: 0.0002)
        guard polyline.count >= 4 else { return false }
        let edgeCount = polyline.count - 1

        for first in 0..<edgeCount {
            for second in (first + 1)..<edgeCount {
                let adjacent = abs(first - second) <= 1
                    || (first == 0 && second == edgeCount - 1)
                if adjacent {
                    if collinearOverlap(
                        polyline[first], polyline[first + 1],
                        polyline[second], polyline[second + 1]
                    ) > 1e-10 {
                        return true
                    }
                    continue
                }
                if intersects(
                    polyline[first], polyline[first + 1],
                    polyline[second], polyline[second + 1]
                ) {
                    return true
                }
            }
        }
        return false
    }

    static func tessellatedPolyline(
        _ segments: [ProfileSegment],
        close: Bool,
        maximumChordError: Double = 0.0005
    ) -> [PlanarPoint] {
        var points: [PlanarPoint] = []
        for segment in segments {
            let tessellated = segment.geometry.tessellated(
                maximumChordError: maximumChordError
            )
            if points.isEmpty {
                points.append(contentsOf: tessellated)
            } else {
                points.append(contentsOf: tessellated.dropFirst())
            }
        }
        if close, let first = points.first, let last = points.last, first != last {
            if first.distance(to: last) <= 1e-8 {
                points[points.count - 1] = first
            } else {
                points.append(first)
            }
        }
        return points
    }

    private static func intersects(
        _ a: PlanarPoint,
        _ b: PlanarPoint,
        _ c: PlanarPoint,
        _ d: PlanarPoint
    ) -> Bool {
        let epsilon = 1e-10
        let ab = b - a
        let cd = d - c
        let ac = c - a
        let denominator = ab.cross(cd)

        if abs(denominator) < epsilon {
            guard abs(ac.cross(ab)) < epsilon else { return false }
            return collinearOverlap(a, b, c, d) > epsilon
        }
        let t = ac.cross(cd) / denominator
        let u = ac.cross(ab) / denominator
        return t >= -epsilon && t <= 1 + epsilon && u >= -epsilon && u <= 1 + epsilon
    }

    private static func collinearOverlap(
        _ a: PlanarPoint,
        _ b: PlanarPoint,
        _ c: PlanarPoint,
        _ d: PlanarPoint
    ) -> Double {
        let ab = b - a
        guard abs(ab.cross(c - a)) < 1e-10,
              abs(ab.cross(d - a)) < 1e-10
        else { return 0 }
        let useX = abs(ab.x) >= abs(ab.y)
        let a0 = useX ? a.x : a.y
        let a1 = useX ? b.x : b.y
        let c0 = useX ? c.x : c.y
        let c1 = useX ? d.x : d.y
        return max(
            0,
            min(max(a0, a1), max(c0, c1))
                - max(min(a0, a1), min(c0, c1))
        )
    }
}
