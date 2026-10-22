import SwiftUI

struct ResultView: View {
    let result: ShadowMeasurementResult
    let segments: [ProfileSegment]
    let onNewMeasurement: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("พื้นที่เงา")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(MeasurementReport.area(result.areaSquareMeters))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                Text("±\(MeasurementReport.area(result.uncertainty95SquareMeters)) โดยประมาณ")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.yellow)
            }

            HStack {
                metric("เส้นรอบรูป", MeasurementReport.length(result.perimeterMeters))
                Divider().frame(height: 34)
                metric("ด้าน", "\(result.segmentCount)")
                Divider().frame(height: 34)
                metric("ความไม่แน่นอน", MeasurementReport.percentage(result.relativeUncertainty))
            }

            if result.relativeUncertainty > 0.05 {
                Label("ความไม่แน่นอนสูง แนะนำให้วัดซ้ำโดยเคลื่อนกล้องช้าลง", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("ผลนี้เป็นพื้นที่ฉายบนระนาบ 2D ไม่ใช่พื้นที่ผิว 3D และยังไม่ผ่านการสอบเทียบแบบ traceable")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ShareLink(item: MeasurementReport.plainText(result: result, segments: segments)) {
                    Label("แชร์", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)

                Button(action: onNewMeasurement) {
                    Label("วัดใหม่", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold()).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
