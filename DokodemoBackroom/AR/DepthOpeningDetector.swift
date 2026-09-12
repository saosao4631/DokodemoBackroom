import ARKit
import CoreVideo

/// LiDAR の深度マップから開口部を推定する（Pro機の一次手段）。
/// タップ点の深度から連続する領域を region-grow し、そのバウンディング矩形を返す。
/// 壁と奥の部屋が同じ白でも、深度が飛ぶので境界で切れるのが強み。
///
/// v1 はバウンディング矩形止まり。輪郭トレース＆RGB エッジ吸着は DESIGN.md §4-7 の TODO。
struct DepthOpeningDetector: OpeningDetector {

    func detectOpening(in frame: ARFrame,
                       tapNormalized tap: CGPoint,
                       sensitivity: Float) -> OpeningObservation? {
        guard let depthMap = frame.sceneDepth?.depthMap else { return nil }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard width > 0, height > 0 else { return nil }

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)

        func depth(_ x: Int, _ y: Int) -> Float {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float32.self)
            return row[x]
        }

        // tap(Vision, 原点左下) → 深度ピクセル(原点左上)。
        let sx = min(width - 1, max(0, Int(tap.x * CGFloat(width))))
        let sy = min(height - 1, max(0, Int((1 - tap.y) * CGFloat(height))))

        let seed = depth(sx, sy)
        guard seed > 0, seed.isFinite else { return nil }

        // 連続とみなす閾値: sensitivity 0..1 → 20cm..2cm。低いほど緩く広がる。
        let tolerance = 0.02 + (1 - sensitivity) * 0.18

        var visited = [Bool](repeating: false, count: width * height)
        var stack: [(Int, Int)] = [(sx, sy)]
        var minX = sx, maxX = sx, minY = sy, maxY = sy
        var count = 0

        while let (x, y) = stack.popLast() {
            if x < 0 || y < 0 || x >= width || y >= height { continue }
            let idx = y * width + x
            if visited[idx] { continue }
            visited[idx] = true

            let d = depth(x, y)
            if d <= 0 || !d.isFinite { continue }
            if abs(d - seed) > tolerance { continue }

            count += 1
            if x < minX { minX = x }; if x > maxX { maxX = x }
            if y < minY { minY = y }; if y > maxY { maxY = y }

            stack.append((x + 1, y))
            stack.append((x - 1, y))
            stack.append((x, y + 1))
            stack.append((x, y - 1))
        }

        guard count > 50 else { return nil }

        // 深度ピクセルの bbox(原点左上) → Vision 正規化座標(原点左下)。
        let x0 = CGFloat(minX) / CGFloat(width)
        let x1 = CGFloat(maxX) / CGFloat(width)
        let vYTop = 1 - CGFloat(minY) / CGFloat(height)
        let vYBot = 1 - CGFloat(maxY) / CGFloat(height)

        let points = [
            CGPoint(x: x0, y: vYBot), // bottomLeft
            CGPoint(x: x1, y: vYBot), // bottomRight
            CGPoint(x: x1, y: vYTop), // topRight
            CGPoint(x: x0, y: vYTop)  // topLeft
        ]

        let confidence = Float(min(1.0, Double(count) / 2000.0))
        return OpeningObservation(points: points, confidence: confidence, source: .depth)
    }
}
