import SwiftUI
import RealityKit
import ARKit

/// ARView を SwiftUI に橋渡しする。セッション設定とタップ登録だけ行い、
/// ロジックは PortalARController に委譲する。
struct ARPortalView: UIViewRepresentable {
    let controller: PortalARController

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        controller.configureSession(on: view)

        let tap = UITapGestureRecognizer(target: controller,
                                         action: #selector(PortalARController.handleTap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
