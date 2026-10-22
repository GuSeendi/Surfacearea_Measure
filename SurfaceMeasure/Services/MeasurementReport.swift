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

    static func percentage(_ ratio: Double) -> String {
        guard ratio.isFinite else { return "—" }
        return String(format: "%.1f%%", ratio * 100)
    }

    static func plainText(result: ShadowMeasurementResult, segments: [ProfileSegment]) -> String {
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
        return lines.joined(separator: "\n")
    }
}
