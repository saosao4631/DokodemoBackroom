import ARKit
import UIKit

/// UIKit のビュー座標と Vision の正規化画像座標を相互変換する。
///
/// 注意: 端末の向きに強く依存する部分。ここは実機で必ず検証・調整すること
/// （フォールバックのタップ点 raycast はこの変換に依存しないので、多少ズレても
/// アプリは動く安全設計になっている）。
enum CoordinateBridge {

    /// ビュー座標(pt, 原点左上) → Vision 正規化座標(原点左下)。
    static func visionPoint(fromViewPoint p: CGPoint,
                            frame: ARFrame,
                            viewport: CGSize,
                            orientation: UIInterfaceOrientation) -> CGPoint {
        guard viewport.width > 0, viewport.height > 0 else { return .zero }
        let normView = CGPoint(x: p.x / viewport.width, y: p.y / viewport.height)
        let display = frame.displayTransform(for: orientation, viewportSize: viewport)
        let imageTopLeft = normView.applying(display.inverted())
        return CGPoint(x: imageTopLeft.x, y: 1 - imageTopLeft.y)
    }

    /// Vision 正規化座標(原点左下) → ビュー座標(pt, 原点左上)。
    static func viewPoint(fromVision v: CGPoint,
                          frame: ARFrame,
                          viewport: CGSize,
                          orientation: UIInterfaceOrientation) -> CGPoint {
        let imageTopLeft = CGPoint(x: v.x, y: 1 - v.y)
        let display = frame.displayTransform(for: orientation, viewportSize: viewport)
        let normView = imageTopLeft.applying(display)
        return CGPoint(x: normView.x * viewport.width, y: normView.y * viewport.height)
    }
}
