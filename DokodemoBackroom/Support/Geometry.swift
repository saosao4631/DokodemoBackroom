import CoreGraphics
import simd

/// 点が多角形の内側にあるか（レイキャスティング法, 2D）。
func pointInPolygon(_ p: CGPoint, _ poly: [CGPoint]) -> Bool {
    guard poly.count >= 3 else { return false }
    var inside = false
    var j = poly.count - 1
    for i in 0..<poly.count {
        let a = poly[i]
        let b = poly[j]
        if (a.y > p.y) != (b.y > p.y),
           p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x {
            inside.toggle()
        }
        j = i
    }
    return inside
}

/// 壁面（点＋法線）。isReal=false はカメラ前方に置いた仮想面。
struct WallPlane {
    let point: SIMD3<Float>
    let normal: SIMD3<Float>
    let isReal: Bool

    /// 面内の右方向（ワールド上方向と法線から導出）。
    var right: SIMD3<Float> {
        let worldUp = SIMD3<Float>(0, 1, 0)
        var r = simd_cross(worldUp, normal)
        if simd_length(r) < 1e-3 { r = SIMD3<Float>(1, 0, 0) }
        return simd_normalize(r)
    }

    /// 面内の上方向。
    var up: SIMD3<Float> {
        simd_normalize(simd_cross(normal, right))
    }
}

/// 3D 多角形を重心方向へ meters だけ縮める（内側オフセット）。
/// 誤差を「空間が壁にはみ出す」側でなく「枠が少し見える」側へ倒すための安全策。
func insetPolygon3D(_ pts: [SIMD3<Float>], meters: Float) -> [SIMD3<Float>] {
    guard pts.count >= 3, meters > 0 else { return pts }
    let center = pts.reduce(SIMD3<Float>(repeating: 0), +) / Float(pts.count)
    return pts.map { p in
        let dir = center - p
        let len = simd_length(dir)
        guard len > 1e-4 else { return p }
        let step = min(meters, len * 0.45)
        return p + dir / len * step
    }
}
