import Foundation

enum TrackingGrade: String, Sendable {
    case normal
    case limited
    case unavailable
}

enum DepthGrade: Int, Comparable, Sendable {
    case unavailable = -1
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum QualityIssue: String, Sendable {
    case tracking
    case depth
    case tooClose
    case tooFar
    case movingTooFast
    case obliqueView
    case thermal
}

struct CaptureQuality: Sendable, Equatable {
    var tracking: TrackingGrade = .unavailable
    var depth: DepthGrade = .unavailable
    var distanceMeters: Double?
    var speedMetersPerSecond: Double = 0
    var frontalScore: Double?
    var uncertaintyMeters: Double = 0.02
    var issues: [QualityIssue] = [.tracking, .depth]

    var isAcceptable: Bool { issues.isEmpty }

    var headline: String {
        guard let issue = issues.first else { return "พร้อมวางจุด" }
        switch issue {
        case .tracking: return "ขยับช้า ๆ เพื่อให้กล้องจับตำแหน่ง"
        case .depth: return "เล็งที่ขอบซึ่ง LiDAR มองเห็นชัด"
        case .tooClose: return "ถอยออกเล็กน้อย"
        case .tooFar: return "ขยับเข้าใกล้อีกหน่อย"
        case .movingTooFast: return "เคลื่อนกล้องช้าลง"
        case .obliqueView: return "หันกล้องให้ตรงกับระนาบมากขึ้น"
        case .thermal: return "เครื่องร้อน พักสักครู่"
        }
    }
}

struct FrameTelemetry: Sendable {
    var tracking: TrackingGrade
    var depth: DepthGrade
    var distanceMeters: Double?
    var speedMetersPerSecond: Double
    var frontalScore: Double?
    var depthUncertaintyMeters: Double
    var thermalState: ProcessInfo.ThermalState
}
