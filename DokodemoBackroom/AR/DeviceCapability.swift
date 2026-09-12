import ARKit

enum DetectionMode {
    case depth      // LiDAR: 深度フラッドフィル
    case rectangle  // 非Pro機: Vision 矩形検出
}

/// 端末能力の一元判定。ここを見れば「今の端末で何が使えるか」が分かる。
enum DeviceCapability {
    static var hasLiDAR: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    static var supportsPersonOcclusion: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth)
    }

    static var supportsSceneMesh: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    static var preferredMode: DetectionMode {
        hasLiDAR ? .depth : .rectangle
    }
}
