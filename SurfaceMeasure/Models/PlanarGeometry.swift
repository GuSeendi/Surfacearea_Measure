import Foundation

struct PlanarPoint: Codable, Hashable, Sendable {
    var x: Double
    var y: Double

    static let zero = PlanarPoint(x: 0, y: 0)

    static func + (lhs: Self, rhs: Self) -> Self {
        .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: Self, rhs: Double) -> Self {
        .init(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    var length: Double { hypot(x, y) }

    func distance(to other: Self) -> Double {
        (self - other).length
    }

    func dot(_ other: Self) -> Double {
        x * other.x + y * other.y
    }

    func cross(_ other: Self) -> Double {
        x * other.y - y * other.x
    }
}

struct PlanarObservation: Sendable {
    var point: PlanarPoint
    var uncertainty: Double
    var timestamp: TimeInterval
}

enum TraceMode: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case line
    case arc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "อัตโนมัติ"
        case .line: "เส้นตรง"
        case .arc: "เส้นโค้ง"
        }
    }
}

enum SegmentGeometry: Codable, Hashable, Sendable {
    case line(start: PlanarPoint, end: PlanarPoint)
    case arc(center: PlanarPoint, radius: Double, startAngle: Double, sweep: Double)

    var start: PlanarPoint {
        switch self {
        case let .line(start, _): start
        case let .arc(center, radius, startAngle, _):
            PlanarPoint(
                x: center.x + radius * cos(startAngle),
                y: center.y + radius * sin(startAngle)
            )
        }
    }

    var end: PlanarPoint {
        switch self {
        case let .line(_, end):
            return end
        case let .arc(center, radius, startAngle, sweep):
            let angle = startAngle + sweep
            return PlanarPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
        }
    }

    var length: Double {
        switch self {
        case let .line(start, end): start.distance(to: end)
        case let .arc(_, radius, _, sweep): radius * abs(sweep)
        }
    }

    var kind: TraceMode {
        switch self {
        case .line: .line
        case .arc: .arc
        }
    }

    /// Exact signed contribution to 1/2 integral(x dy - y dx).
    var signedAreaContribution: Double {
        switch self {
        case let .line(start, end):
            return 0.5 * start.cross(end)
        case let .arc(center, radius, startAngle, sweep):
            let endAngle = startAngle + sweep
            let deltaX = radius * (cos(endAngle) - cos(startAngle))
            let deltaY = radius * (sin(endAngle) - sin(startAngle))
            return 0.5 * (
                center.x * deltaY
                    - center.y * deltaX
                    + radius * radius * sweep
            )
        }
    }

    func tessellated(maximumChordError: Double = 0.0005) -> [PlanarPoint] {
        switch self {
        case let .line(start, end):
            return [start, end]
        case let .arc(center, radius, startAngle, sweep):
            guard radius > 0, abs(sweep) > 0 else { return [start, end] }
            let safeError = min(max(maximumChordError, 0.000_01), radius)
            let step = max(0.01, 2 * acos(max(-1, 1 - safeError / radius)))
            let count = max(2, Int(ceil(abs(sweep) / step)))
            return (0...count).map { index in
                let t = Double(index) / Double(count)
                let angle = startAngle + sweep * t
                return PlanarPoint(
                    x: center.x + radius * cos(angle),
                    y: center.y + radius * sin(angle)
                )
            }
        }
    }
}

struct ProfileSegment: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var geometry: SegmentGeometry
    var fitRMS: Double
    var meanObservationUncertainty: Double
    var observationCount: Int

    var length: Double { geometry.length }
}

struct ShadowMeasurementResult: Sendable, Equatable {
    var areaSquareMeters: Double
    var perimeterMeters: Double
    var uncertainty95SquareMeters: Double
    var segmentCount: Int
    var maximumFitRMS: Double

    var relativeUncertainty: Double {
        guard areaSquareMeters > 0 else { return .infinity }
        return uncertainty95SquareMeters / areaSquareMeters
    }
}
