import ARKit
import RealityKit
import SwiftUI
import Combine
import os

private let log = Logger(subsystem: "com.ksaotome.dokodemo-backroom", category: "portal")

/// AR セッションの設定・タップ処理・ポータル配置・角度フェードを統括する。
///
/// 設計方針（DESIGN.md §2）:
/// - 判定は毎フレームやらない。タップ1回で開口部を確定し、アンカーに固定して以降は追従のみ。
/// - 検出は 深度→矩形→既定クアッド の3段フォールバック。どこかで必ず配置できる。
final class PortalARController: NSObject, ObservableObject, ARSessionDelegate {

    @Published var sensitivity: Float = 0.5
    @Published var hasPortal: Bool = false
    @Published var statusText: String = ""
    /// 実機デバッグ用のオンスクリーン診断行（原因切り分け用。安定したら消す）。
    @Published var debugText: String = ""
    private var lastTrackingState: String = "?"

    let isLiDAR = DeviceCapability.hasLiDAR
    var detectionMode: DetectionMode { DeviceCapability.preferredMode }

    private(set) weak var arView: ARView?
    private var currentAnchor: AnchorEntity?
    private var portalCenter: SIMD3<Float> = .zero
    private var portalNormal: SIMD3<Float> = SIMD3(0, 0, 1)

    private let rectDetector = RectangleOpeningDetector()
    private let depthDetector = DepthOpeningDetector()

    // MARK: - Session

    func configureSession(on view: ARView) {
        arView = view
        view.session.delegate = self

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical, .horizontal]
        config.environmentTexturing = .automatic

        if DeviceCapability.hasLiDAR {
            config.frameSemantics.insert(.sceneDepth)
            if DeviceCapability.supportsSceneMesh {
                config.sceneReconstruction = .mesh
            }
        }
        if DeviceCapability.supportsPersonOcclusion {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }

        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        statusText = defaultHint
        log.info("configureSession: LiDAR=\(DeviceCapability.hasLiDAR) mode=\(String(describing: DeviceCapability.preferredMode)) frameSemantics=\(config.frameSemantics.rawValue)")
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        lastTrackingState = String(describing: camera.trackingState)
        log.info("trackingState=\(self.lastTrackingState)")
    }

    private var defaultHint: String {
        isLiDAR ? "窓・ドアの開口部をタップ" : "枠をタップ（矩形を検出します）"
    }

    // MARK: - Tap → Portal

    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let view = arView else {
            log.error("handleTap: arView is nil")
            return
        }
        guard let frame = view.session.currentFrame else {
            log.error("handleTap: currentFrame is nil (session not running / camera not authorized?)")
            statusText = "カメラを起動中です。数秒待ってからもう一度タップしてください"
            debugText = "frame=nil track=\(lastTrackingState) — カメラ許可/起動待ち?"
            return
        }

        let viewPoint = recognizer.location(in: view)
        let viewport = view.bounds.size
        let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
        let tapVision = CoordinateBridge.visionPoint(fromViewPoint: viewPoint,
                                                     frame: frame,
                                                     viewport: viewport,
                                                     orientation: orientation)
        log.info("handleTap: viewPoint=(\(viewPoint.x, format: .fixed(precision: 1)),\(viewPoint.y, format: .fixed(precision: 1))) viewport=(\(viewport.width, format: .fixed(precision: 0))x\(viewport.height, format: .fixed(precision: 0))) orient=\(orientation.rawValue) tapVision=(\(tapVision.x, format: .fixed(precision: 3)),\(tapVision.y, format: .fixed(precision: 3)))")

        // 一次検出（端末に応じて）。深度が空振りしたら矩形へ。
        let primary: OpeningDetector = (detectionMode == .depth) ? depthDetector : rectDetector
        var observation = primary.detectOpening(in: frame, tapNormalized: tapVision, sensitivity: sensitivity)
        if observation == nil, detectionMode == .depth {
            observation = rectDetector.detectOpening(in: frame, tapNormalized: tapVision, sensitivity: sensitivity)
        }
        if let observation {
            log.info("detect: points=\(observation.points.count) conf=\(observation.confidence, format: .fixed(precision: 2)) src=\(String(describing: observation.source))")
        } else {
            log.info("detect: nil")
        }

        let detSummary = observation == nil ? "det=nil" : "det=\(observation!.points.count)pt/\(String(describing: observation!.source))"

        // タップ中心で壁面を1回だけ確定。取れなければカメラ前方 1.5m の仮想面。
        guard let plane = wallPlane(atViewPoint: viewPoint, view: view) else {
            log.error("placement failed: no camera ray")
            statusText = "カメラを少し動かしてからもう一度お試しください"
            debugText = "\(detSummary) plane=none track=\(lastTrackingState)"
            return
        }

        var corners3D: [SIMD3<Float>] = []
        var placement = ""

        // 検出した枠の4隅を、確定した平面へ投影する（1平面に射影＝非LiDARでも堅い）。
        if let observation {
            let viewCorners = observation.points.map {
                CoordinateBridge.viewPoint(fromVision: $0, frame: frame,
                                           viewport: viewport, orientation: orientation)
            }
            let projected = viewCorners.compactMap { unproject($0, onto: plane, view: view) }
            if projected.count == 4 {
                corners3D = projected
                placement = plane.isReal ? "fit-frame(plane)" : "fit-frame(forward)"
            }
        }

        // 枠が取れない/投影に失敗したら、タップ位置に既定サイズの穴。
        if corners3D.count < 4 {
            corners3D = defaultQuad(onto: plane, atViewPoint: viewPoint, view: view)
            placement = plane.isReal ? "default(plane)" : "default(forward)"
        }

        guard corners3D.count >= 4 else {
            statusText = "壁を検出できませんでした。少し動いてからもう一度お試しください"
            debugText = "\(detSummary) place=failed track=\(lastTrackingState)"
            return
        }

        log.info("placing portal via \(placement)")
        debugText = "\(detSummary) place=\(placement) track=\(lastTrackingState)"
        placePortal(corners: corners3D, view: view)
    }

    /// タップ点の壁面。実平面が取れればそれを、無ければカメラ前方 1.5m の仮想面を返す。
    private func wallPlane(atViewPoint p: CGPoint, view: ARView) -> WallPlane? {
        let camera = view.session.currentFrame?.camera.transform.translation ?? .zero
        if let hit = view.raycast(from: p, allowing: .estimatedPlane, alignment: .vertical).first
            ?? view.raycast(from: p, allowing: .estimatedPlane, alignment: .any).first {
            var n = simd_normalize(hit.worldTransform.yAxis)   // 平面 raycast の法線は y 軸
            let point = hit.worldTransform.translation
            if simd_dot(n, camera - point) < 0 { n = -n }       // カメラ側へ
            return WallPlane(point: point, normal: n, isReal: true)
        }
        if let ray = view.ray(through: p) {
            let n = -simd_normalize(ray.direction)
            return WallPlane(point: ray.origin + ray.direction * 1.5, normal: n, isReal: false)
        }
        return nil
    }

    /// スクリーン点から出したレイと平面の交点（ray-plane intersection）。
    private func unproject(_ viewPoint: CGPoint, onto plane: WallPlane, view: ARView) -> SIMD3<Float>? {
        guard let ray = view.ray(through: viewPoint) else { return nil }
        let denom = simd_dot(plane.normal, ray.direction)
        if abs(denom) < 1e-6 { return nil }
        let t = simd_dot(plane.normal, plane.point - ray.origin) / denom
        if t <= 0 { return nil }
        return ray.origin + ray.direction * t
    }

    private func defaultQuad(onto plane: WallPlane, atViewPoint p: CGPoint, view: ARView) -> [SIMD3<Float>] {
        let center = unproject(p, onto: plane, view: view) ?? plane.point
        let hw: Float = 0.45, hh: Float = 0.6   // 既定 0.9m x 1.2m
        let r = plane.right, u = plane.up
        return [
            center - r * hw - u * hh, // bottomLeft
            center + r * hw - u * hh, // bottomRight
            center + r * hw + u * hh, // topRight
            center - r * hw + u * hh  // topLeft
        ]
    }

    private func placePortal(corners: [SIMD3<Float>], view: ARView) {
        currentAnchor?.removeFromParent()

        let inset = insetPolygon3D(corners, meters: 0.025)
        let camera = view.session.currentFrame?.camera.transform.translation ?? .zero
        let light = view.session.currentFrame?.lightEstimate

        let result = PortalBuilder.build(cornersWorld: inset, cameraWorld: camera, lightEstimate: light)
        view.scene.addAnchor(result.anchor)

        currentAnchor = result.anchor
        portalCenter = result.centerWorld
        portalNormal = result.normalWorld
        hasPortal = true
        statusText = ""

        let dist = simd_length(result.centerWorld - camera)
        let facing = abs(simd_dot(simd_normalize(camera - result.centerWorld), result.normalWorld))
        log.info("portal placed: dist=\(dist, format: .fixed(precision: 2))m normal=(\(result.normalWorld.x, format: .fixed(precision: 2)),\(result.normalWorld.y, format: .fixed(precision: 2)),\(result.normalWorld.z, format: .fixed(precision: 2))) facing=\(facing, format: .fixed(precision: 2)) anchorsInScene=\(view.scene.anchors.count)")
        debugText += String(format: " → dist=%.2fm facing=%.2f anchors=%d", dist, facing, view.scene.anchors.count)
    }

    func clearPortal() {
        currentAnchor?.removeFromParent()
        currentAnchor = nil
        hasPortal = false
        statusText = defaultHint
    }

    // MARK: - Angle fade (per frame)

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // フレームを保持しない。必要な値だけ取り出してメインで反映。
        let cameraPos = frame.camera.transform.translation
        DispatchQueue.main.async { [weak self] in
            self?.updateFade(cameraPos: cameraPos)
        }
    }

    private func updateFade(cameraPos: SIMD3<Float>) {
        guard let anchor = currentAnchor else { return }
        let toCamera = simd_normalize(cameraPos - portalCenter)
        let facing = abs(simd_dot(toCamera, portalNormal))    // 1.0 = 正対
        let opacity = smoothstep(0.2, 0.5, facing)            // 浅い角度で消す
        anchor.components.set(OpacityComponent(opacity: opacity))
    }

    // MARK: - Session errors

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.statusText = "AR セッションエラー: \(error.localizedDescription)"
        }
    }
}
