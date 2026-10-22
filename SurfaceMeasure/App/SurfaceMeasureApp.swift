import SwiftUI

@main
struct SurfaceMeasureApp: App {
    var body: some Scene {
        WindowGroup {
            MeasurementFlowView()
                .preferredColorScheme(.dark)
        }
    }
}
