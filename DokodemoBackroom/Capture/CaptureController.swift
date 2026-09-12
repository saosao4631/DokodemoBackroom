import ReplayKit
import RealityKit
import UIKit

/// 撮影・共有（DESIGN.md §7）。このジャンルは SNS の動画が全てなので撮影は主機能。
/// - 写真: ARView.snapshot
/// - 動画: v1 は ReplayKit（画面録画）。UI が写り込むので録画中はボタンを隠す。
final class CaptureController: NSObject, ObservableObject, RPPreviewViewControllerDelegate {

    @Published var isRecording = false
    @Published var micEnabled = true
    @Published var toast: String?

    func takePhoto(_ arView: ARView?) {
        guard let arView else { return }
        arView.snapshot(saveToHDR: false) { [weak self] image in
            guard let image else {
                self?.showToast("写真の取得に失敗しました")
                return
            }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            self?.showToast("写真を保存しました")
        }
    }

    func toggleRecording() {
        let recorder = RPScreenRecorder.shared()
        if recorder.isRecording {
            recorder.stopRecording { [weak self] preview, error in
                DispatchQueue.main.async {
                    self?.isRecording = false
                    if let error {
                        self?.showToast("録画停止エラー: \(error.localizedDescription)")
                        return
                    }
                    if let preview {
                        preview.previewControllerDelegate = self
                        UIApplication.shared.topViewController?.present(preview, animated: true)
                    }
                }
            }
        } else {
            recorder.isMicrophoneEnabled = micEnabled
            recorder.startRecording { [weak self] error in
                DispatchQueue.main.async {
                    if let error {
                        self?.showToast("録画開始エラー: \(error.localizedDescription)")
                        return
                    }
                    self?.isRecording = true
                }
            }
        }
    }

    private func showToast(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.toast = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                if self?.toast == message { self?.toast = nil }
            }
        }
    }

    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true)
    }
}
