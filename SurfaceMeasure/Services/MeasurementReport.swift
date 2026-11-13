import Foundation

enum MeasurementReport {
    static func area(_ squareMeters: Double) -> String {
        if squareMeters < 0.01 {
            return String(format: "%.1f cm²", squareMeters * 10_000)
        }
        return String(format: "%.4f m²", squareMeters)
    }

    static func length(_ meters: Double) -> String {
        if meters < 1 {
            return String(format: "%.1f cm", meters * 100)
        }
        return String(format: "%.3f m", meters)
    }

    static func cubicMeters(areaSquareMeters: Double, straightLengthMeters: Double) -> Double {
        areaSquareMeters * straightLengthMeters
    }

    static func volume(_ cubicMeters: Double) -> String {
        guard cubicMeters.isFinite, cubicMeters >= 0 else { return "—" }
        return String(format: "%.4g m³", cubicMeters)
    }

    static func percentage(_ ratio: Double) -> String {
        guard ratio.isFinite else { return "—" }
        return String(format: "%.1f%%", ratio * 100)
    }

    static func plainText(
        result: ShadowMeasurementResult,
        segments: [ProfileSegment],
        lengthMeasurement: StraightLengthMeasurement? = nil
    ) -> String {
        var lines = [
            "SurfaceMeasure — พื้นที่เงา 2D",
            "พื้นที่: \(area(result.areaSquareMeters))",
            "ความไม่แน่นอนโดยประมาณ (95%): ±\(area(result.uncertainty95SquareMeters))",
            "เส้นรอบรูป: \(length(result.perimeterMeters))",
            "จำนวนด้าน: \(result.segmentCount)",
            "สถานะการสอบเทียบ: ยังไม่ผ่านการรับรองแบบ traceable"
        ]
        for (index, segment) in segments.enumerated() {
            let kind = segment.geometry.kind == .arc ? "โค้ง" : "ตรง"
            lines.append("ด้าน \(index + 1) (\(kind)): \(length(segment.length))")
        }
        if let lengthMeasurement {
            lines.append("ความยาวเส้นตรงจริง 3D: \(length(lengthMeasurement.lengthMeters))")
            let cubicMeters = cubicMeters(
                areaSquareMeters: result.areaSquareMeters,
                straightLengthMeters: lengthMeasurement.lengthMeters
            )
            lines.append("ปริมาตรโดยประมาณ (พื้นที่เงา × ความยาวตรง): \(volume(cubicMeters)) — คิว/ลูกบาศก์เมตร")
            lines.append("ใช้แทนปริมาตรจริงเมื่อหน้าตัดคงที่ และแนวความยาวตั้งฉากกับระนาบพื้นที่เงา")
        }
        return lines.joined(separator: "\n")
    }
}
