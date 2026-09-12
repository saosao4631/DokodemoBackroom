import RealityKit
import UIKit

/// 別空間（バックルーム風の無限廊下）をプロシージャルに生成する。
///
/// あの空間は基本「箱」。壁・床・天井は全部直方体なのでメッシュ資産は要らない。
/// 開口部から覗ける範囲しか見えないので生成範囲は狭くてよい（DESIGN.md §6）。
/// フォグは「奥のセグメントほど暗くする」ことで近似する（半透明を使わず安全＆軽い）。
enum BackroomsWorldBuilder {

    /// 開口サイズに合わせた廊下を返す。原点=開口面, 廊下は -Z 方向へ伸びる。
    static func build(openingWidth: Float, openingHeight: Float, tint: Float) -> Entity {
        let root = Entity()

        let corridorWidth = max(openingWidth * 1.6, 2.4)
        let corridorHeight = max(openingHeight * 1.25, 2.6)
        let length: Float = 9.0
        let segments = 6
        let segLen = length / Float(segments)
        let wallT: Float = 0.04

        // バックルームズの基準色
        let wallBase = UIColor(red: 0.80, green: 0.72, blue: 0.42, alpha: 1)   // 黄ばんだ壁紙
        let floorBase = UIColor(red: 0.46, green: 0.40, blue: 0.24, alpha: 1)  // 湿ったカーペット
        let ceilBase = UIColor(red: 0.86, green: 0.83, blue: 0.70, alpha: 1)   // 天井パネル
        let fogColor = UIColor(red: 0.05, green: 0.05, blue: 0.03, alpha: 1)

        for i in 0..<segments {
            let t = Float(i) / Float(max(1, segments - 1))
            let fog = lerpF(1.0, 0.12, t) * tint          // 奥ほど暗く = フォグ近似
            let zCenter = -segLen * (Float(i) + 0.5)
            let halfW = corridorWidth / 2
            let halfH = corridorHeight / 2

            root.addChild(box(SIMD3(corridorWidth, wallT, segLen),
                              color: scale(floorBase, fog),
                              at: SIMD3(0, -halfH, zCenter)))          // 床
            root.addChild(box(SIMD3(corridorWidth, wallT, segLen),
                              color: scale(ceilBase, fog),
                              at: SIMD3(0, halfH, zCenter)))           // 天井
            root.addChild(box(SIMD3(wallT, corridorHeight, segLen),
                              color: scale(wallBase, fog),
                              at: SIMD3(-halfW, 0, zCenter)))          // 左壁
            root.addChild(box(SIMD3(wallT, corridorHeight, segLen),
                              color: scale(wallBase, fog),
                              at: SIMD3(halfW, 0, zCenter)))           // 右壁
        }

        // 奥のフォグキャップ（これ以上は見えない）
        root.addChild(box(SIMD3(corridorWidth, corridorHeight, wallT),
                          color: fogColor,
                          at: SIMD3(0, 0, -length)))

        return root
    }

    private static func box(_ size: SIMD3<Float>, color: UIColor, at position: SIMD3<Float>) -> ModelEntity {
        let entity = ModelEntity(mesh: .generateBox(size: size), materials: [UnlitMaterial(color: color)])
        entity.position = position
        return entity
    }

    private static func scale(_ color: UIColor, _ factor: Float) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let f = CGFloat(max(0, min(1, factor)))
        return UIColor(red: r * f, green: g * f, blue: b * f, alpha: a)
    }
}
