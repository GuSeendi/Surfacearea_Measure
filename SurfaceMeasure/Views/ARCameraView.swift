import RealityKit
import SwiftUI

struct ARCameraView: UIViewRepresentable {
    let controller: ARSessionController

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.backgroundColor = .black
        controller.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) { }
}
