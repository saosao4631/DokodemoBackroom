import CoreGraphics
import ARKit

/// 開口部の観測結果。
/// points は正規化画像座標（原点=左下, Vision 準拠, x/y ∈ [0,1]）の輪郭。
struct OpeningObservation {
    var points: [CGPoint]
    var confidence: Float
    var source: DetectionMode
}

/// 開口部検出器。実装を差し替えられるようにプロトコルで抽象化する。
/// tap は正規化画像座標（原点=左下, Vision 準拠）。
protocol OpeningDetector {
    func detectOpening(in frame: ARFrame,
                       tapNormalized tap: CGPoint,
                       sensitivity: Float) -> OpeningObservation?
}
