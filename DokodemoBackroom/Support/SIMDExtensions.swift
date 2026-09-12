import simd

extension simd_float4x4 {
    /// 平行移動成分（ワールド座標）。
    var translation: SIMD3<Float> {
        SIMD3(columns.3.x, columns.3.y, columns.3.z)
    }
    /// ローカル +X 軸のワールド方向。
    var xAxis: SIMD3<Float> { SIMD3(columns.0.x, columns.0.y, columns.0.z) }
    /// ローカル +Y 軸のワールド方向。
    var yAxis: SIMD3<Float> { SIMD3(columns.1.x, columns.1.y, columns.1.z) }
    /// ローカル +Z 軸のワールド方向。
    var zAxis: SIMD3<Float> { SIMD3(columns.2.x, columns.2.y, columns.2.z) }
}

/// GLSL 相当の smoothstep。
func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    guard edge1 != edge0 else { return x < edge0 ? 0 : 1 }
    let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)
}

/// 線形補間（simd の mix と衝突しないよう独自名）。
func lerpF(_ a: Float, _ b: Float, _ t: Float) -> Float {
    a + (b - a) * t
}
