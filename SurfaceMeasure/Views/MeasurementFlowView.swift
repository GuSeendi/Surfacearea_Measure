import SwiftUI

struct MeasurementFlowView: View {
    @StateObject private var controller = ARSessionController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ARCameraView(controller: controller)
                .ignoresSafeArea()

            ScanView(controller: controller)

            if case let .unavailable(message) = controller.phase {
                unavailableCard(message: message)
            }
        }
        .task {
            await controller.prepare()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if controller.authorization == .authorized {
                    controller.startSession(resetTracking: false)
                } else {
                    Task { await controller.prepare() }
                }
            case .background:
                controller.pause()
            default:
                break
            }
        }
    }

    private func unavailableCard(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 38, weight: .semibold))
            Text("ไม่สามารถเริ่มการวัดได้")
                .font(.title3.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if controller.authorization == .denied {
                Button("เปิด Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(maxWidth: 340)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding()
    }
}
