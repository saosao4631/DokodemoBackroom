import ARKit

/// 現実の環境光に別空間の明るさを合わせる（DESIGN.md §4-4）。
/// 部屋の明かりを消したのに向こう側だけ明るいまま、という破綻を防ぐ。
enum LightMatcher {
    /// 環境光の強さを 0.35..1.3 のスケールに正規化（約 1000 lux ≒ 中立）。
    static func intensityScale(_ estimate: ARLightEstimate?) -> Float {
        guard let estimate else { return 1.0 }
        return Float(max(0.35, min(1.3, estimate.ambientIntensity / 1000.0)))
    }

    // TODO: ambientColorTemperature を使った色温度追従。毎フレーム tint 更新も未実装。
}
