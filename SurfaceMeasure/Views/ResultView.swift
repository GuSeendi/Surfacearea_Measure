import SwiftUI

struct ResultView: View {
  let result: ShadowMeasurementResult
  let segments: [ProfileSegment]
  let lengthMeasurement: StraightLengthMeasurement?
  let onMeasureLength: () -> Void
  let onRetryLength: () -> Void
  let onNewMeasurement: () -> Void

  var body: some View {
    ScrollView {
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

        if let lengthMeasurement {
          VStack(spacing: 3) {
            Text("ขั้นที่ 2 · ความยาวเส้นตรงจริง 3D")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Text(MeasurementReport.length(lengthMeasurement.lengthMeters))
              .font(.system(size: 34, weight: .bold, design: .rounded))
              .monospacedDigit()
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

          let cubicMeters = MeasurementReport.cubicMeters(
            areaSquareMeters: result.areaSquareMeters,
            straightLengthMeters: lengthMeasurement.lengthMeters
          )
          VStack(spacing: 4) {
            Text("ปริมาตรโดยประมาณ")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Text(MeasurementReport.volume(cubicMeters))
              .font(.system(size: 38, weight: .bold, design: .rounded))
              .monospacedDigit()
              .minimumScaleFactor(0.7)
            Text("คิว = ลูกบาศก์เมตร · พื้นที่เงา × ความยาวตรง")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text("ใช้แทนปริมาตรจริงเมื่อหน้าตัดคงที่ และแนวความยาวตั้งฉากกับระนาบพื้นที่เงา")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        }

        if result.relativeUncertainty > 0.05 {
          Label(
            "ความไม่แน่นอนสูง แนะนำให้วัดซ้ำโดยเคลื่อนกล้องช้าลง", systemImage: "exclamationmark.triangle.fill"
          )
          .font(.caption)
          .foregroundStyle(.yellow)
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        Text(
          "พื้นที่เป็นภาพฉาย 2D; ความยาวขั้นที่ 2 เป็นระยะตรงจริง 3D ระหว่างสองจุด LiDAR ผลยังไม่ผ่านการสอบเทียบแบบ traceable"
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

        HStack(spacing: 12) {
          ShareLink(
            item: MeasurementReport.plainText(
              result: result,
              segments: segments,
              lengthMeasurement: lengthMeasurement
            )
          ) {
            Label("แชร์", systemImage: "square.and.arrow.up")
              .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(.bordered)

          Button(action: lengthMeasurement == nil ? onMeasureLength : onRetryLength) {
            Label(
              lengthMeasurement == nil ? "ขั้นที่ 2 วัดความยาว" : "วัดความยาวใหม่",
              systemImage: "ruler"
            )
            .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(.borderedProminent)
          .tint(.cyan)
        }

        Button(action: onNewMeasurement) {
          Label("เริ่มวัดพื้นที่ใหม่", systemImage: "arrow.counterclockwise")
        }
        .font(.caption)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
      }
      .padding(16)
    }
    .frame(maxHeight: 430)
    .scrollIndicators(.hidden)
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
