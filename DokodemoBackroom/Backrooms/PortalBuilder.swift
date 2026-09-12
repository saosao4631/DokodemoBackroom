import ARKit
import RealityKit
import UIKit

struct PortalBuildResult {
    let anchor: AnchorEntity
    let centerWorld: SIMD3<Float>
    let normalWorld: SIMD3<Float>
}

/// 開口部の4隅（ワールド座標）から、壁の厚み付きポータル＋別空間を組み立てる。
enum PortalBuilder {

    /// 壁の厚み（三方枠の奥行き）。視差の見え隠れが「本当に穴」の証拠になる（DESIGN.md §4-1）。
    static let wallDepth: Float = 0.12

    /// corners は [bottomLeft, bottomRight, topRight, topLeft]（ワールド座標）。
    static func build(cornersWorld corners: [SIMD3<Float>],
                      cameraWorld: SIMD3<Float>,
                      lightEstimate: ARLightEstimate?) -> PortalBuildResult {
        let bl = corners[0], br = corners[1], tr = corners[2], tl = corners[3]
        let center = (bl + br + tr + tl) / 4

        // 開口面の基底を4隅から推定。
        var right = simd_normalize((br - bl) + (tr - tl))
        var up = simd_normalize((tl - bl) + (tr - br))
        up = simd_normalize(up - right * simd_dot(up, right))    // right へ直交化
        var normal = simd_normalize(simd_cross(right, up))

        // 法線がカメラ側を向くよう補正（右手系を保つため right を反転して作り直す）。
        if simd_dot(normal, cameraWorld - center) < 0 {
            right = -right
            normal = simd_normalize(simd_cross(right, up))
        }

        let width = max(0.2, (simd_length(br - bl) + simd_length(tr - tl)) / 2)
        let height = max(0.2, (simd_length(tl - bl) + simd_length(tr - br)) / 2)

        let transform = simd_float4x4(
            SIMD4(right.x, right.y, right.z, 0),
            SIMD4(up.x, up.y, up.z, 0),
            SIMD4(normal.x, normal.y, normal.z, 0),
            SIMD4(center.x, center.y, center.z, 1)
        )
        let anchor = AnchorEntity(.world(transform: transform))

        // ポータル越しにだけ見える「隠された世界」。
        let world = Entity()
        world.components.set(WorldComponent())

        let tintScale = LightMatcher.intensityScale(lightEstimate)

        // 1) 壁の厚み（暗い筒）
        world.addChild(makeTube(width: width, height: height, depth: wallDepth, tint: tintScale))

        // 2) 別空間本体（筒の奥へ）
        let backrooms = BackroomsWorldBuilder.build(openingWidth: width,
                                                    openingHeight: height,
                                                    tint: tintScale)
        backrooms.position = SIMD3(0, 0, -wallDepth)
        world.addChild(backrooms)

        // 3) ポータル面（generatePlane は XY 平面 / +Z 法線）
        let portal = ModelEntity(mesh: .generatePlane(width: width, height: height),
                                 materials: [PortalMaterial()])
        portal.components.set(PortalComponent(target: world))

        anchor.addChild(world)
        anchor.addChild(portal)

        return PortalBuildResult(anchor: anchor, centerWorld: center, normalWorld: normal)
    }

    /// 開口部の内側に暗い筒（三方枠の内面）を立てる。z=0(開口面) から z=-depth(奥) へ。
    private static func makeTube(width: Float, height: Float, depth: Float, tint: Float) -> Entity {
        let tube = Entity()
        let t: Float = 0.03
        let v = CGFloat(max(0.05, min(1, 0.18 * tint)))   // 光の届かない暗い内面
        let color = UIColor(red: v, green: v, blue: v, alpha: 1)

        func wall(_ size: SIMD3<Float>, _ position: SIMD3<Float>) -> ModelEntity {
            let e = ModelEntity(mesh: .generateBox(size: size), materials: [UnlitMaterial(color: color)])
            e.position = position
            return e
        }

        let hw = width / 2, hh = height / 2, hd = depth / 2
        tube.addChild(wall(SIMD3(t, height, depth), SIMD3(-hw, 0, -hd)))         // 左
        tube.addChild(wall(SIMD3(t, height, depth), SIMD3(hw, 0, -hd)))          // 右
        tube.addChild(wall(SIMD3(width + 2 * t, t, depth), SIMD3(0, hh, -hd)))   // 上
        tube.addChild(wall(SIMD3(width + 2 * t, t, depth), SIMD3(0, -hh, -hd)))  // 下
        return tube
    }
}
