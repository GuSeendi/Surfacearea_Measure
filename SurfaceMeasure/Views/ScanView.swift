import SwiftUI

struct ScanView: View {
    @ObservedObject var controller: ARSessionController

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topPanel
                Spacer()
                bottomPanel
            }
            .safeAreaPadding(.horizontal, 16)
            .safeAreaPadding(.vertical, 10)
        }
        .animation(.easeInOut(duration: 0.18), value: controller.phase)
        .animation(.easeInOut(duration: 0.18), value: controller.quality.isAcceptable)
    }

    private var topPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Label("พื้นที่เงา 2D", systemImage: "square.dashed")
                    .font(.headline)
                Spacer()
                if let distance = controller.quality.distanceMeters {
                    Label(MeasurementReport.length(distance), systemImage: "arrow.left.and.right")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                qualityDot
            }

            if controller.phase == .tracing {
                Picker("ชนิดเส้น", selection: $controller.traceMode) {
                    ForEach(TraceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: controller.quality.isAcceptable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(controller.quality.isAcceptable ? .green : .yellow)
                Text(controller.statusText)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !controller.segments.isEmpty {
                    Text("\(controller.segments.count) ด้าน")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let action = controller.lastActionText {
                Text(action)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var bottomPanel: some View {
        switch controller.phase {
        case .preparing:
            ProgressView("กำลังเตรียม LiDAR…")
                .controlSize(.large)
                .panelStyle()
        case .findingPlane:
            VStack(spacing: 10) {
                Text("ระนาบนี้คือฉากรับเงา จุดขอบทุกจุดจะถูกฉายตั้งฉากลงบนระนาบนี้")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(action: controller.lockPlane) {
                    Label("ล็อกระนาบเงา", systemImage: "viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryMeasureButtonStyle(color: .cyan))
                .disabled(!controller.quality.isAcceptable || controller.currentCursor == nil)
            }
            .panelStyle()
        case .tracing:
            traceControls
        case .result:
            if let result = controller.result {
                ResultView(
                    result: result,
                    segments: controller.segments,
                    onNewMeasurement: controller.resetMeasurement
                )
            }
        case .unavailable:
            EmptyView()
        }
    }

    private var traceControls: some View {
        VStack(spacing: 12) {
            if controller.isNearStart {
                Label(
                    controller.canClose
                        ? "พร้อมปิดพื้นที่ — แตะปุ่มสีเขียว"
                        : "ถึงจุดเริ่มแล้ว — ถือกล้องนิ่งสักครู่",
                    systemImage: controller.canClose ? "checkmark.circle.fill" : "scope"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(controller.canClose ? .green : .yellow)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let closureDistance = controller.closureDistance,
               controller.hasStartPoint {
                HStack {
                    Text("ระยะถึงจุดเริ่ม")
                    Spacer()
                    Text(MeasurementReport.length(closureDistance))
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(controller.canClose ? .green : .secondary)
            }

            HStack(spacing: 12) {
                Button(action: controller.undo) {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.bordered)
                .disabled(!controller.canUndo)

                Button {
                    if controller.canClose {
                        controller.closeProfile()
                    } else {
                        controller.placePoint()
                    }
                } label: {
                    Label(
                        controller.canClose
                            ? "ปิดและคำนวณพื้นที่"
                            : (controller.isNearStart
                                ? "ถือให้นิ่งเพื่อปิด"
                                : (controller.hasStartPoint ? "เพิ่มจุด" : "วางจุดเริ่ม")),
                        systemImage: controller.isNearStart ? "checkmark" : "plus"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(PrimaryMeasureButtonStyle(color: controller.isNearStart ? .green : .cyan))
                .disabled(controller.canClose ? false : !controller.canPlacePoint)

                Button(action: controller.resetMeasurement) {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("เริ่มใหม่")
            }
        }
        .panelStyle()
    }

    private var qualityDot: some View {
        Circle()
            .fill(controller.quality.isAcceptable ? Color.green : Color.yellow)
            .frame(width: 10, height: 10)
            .shadow(color: controller.quality.isAcceptable ? .green : .yellow, radius: 5)
            .accessibilityLabel(controller.quality.isAcceptable ? "คุณภาพพร้อม" : "คุณภาพยังไม่พร้อม")
    }
}

private struct PrimaryMeasureButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 18)
            .foregroundStyle(.black)
            .background(
                color.opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private extension View {
    func panelStyle() -> some View {
        padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
