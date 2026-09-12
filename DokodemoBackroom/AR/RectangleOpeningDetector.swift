import Vision
import ARKit

/// Vision の矩形検出でタップ位置の開口部を推定する（非Pro機の一次手段）。
/// 明るい窓 × 暗い壁のようにコントラストが強いほどよく当たる。ドア（暗×暗）は苦手。
struct RectangleOpeningDetector: OpeningDetector {

    func detectOpening(in frame: ARFrame,
                       tapNormalized tap: CGPoint,
                       sensitivity: Float) -> OpeningObservation? {
        let request = VNDetectRectanglesRequest()
        // デフォルトは最大1個しか返さないので必ず増やす。
        request.maximumObservations = 20
        request.minimumConfidence = 0.15
        request.minimumAspectRatio = 0.1      // 縦長・横長の枠も許容
        request.maximumAspectRatio = 1.0
        // sensitivity が低いほど小さな枠まで拾う。
        request.minimumSize = Float(0.02 + sensitivity * 0.06)
        request.quadratureTolerance = 40      // 斜めから見た台形も許容

        let handler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage,
                                            orientation: .up,
                                            options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let results = request.results, !results.isEmpty else { return nil }

        func corners(_ o: VNRectangleObservation) -> [CGPoint] {
            [o.bottomLeft, o.bottomRight, o.topRight, o.topLeft]
        }

        // タップを内包する矩形を優先。無ければ中心がタップに最も近いもの。
        let containing = results.first { pointInPolygon(tap, corners($0)) }
        let chosen = containing ?? results.min {
            hypot($0.boundingBox.midX - tap.x, $0.boundingBox.midY - tap.y) <
            hypot($1.boundingBox.midX - tap.x, $1.boundingBox.midY - tap.y)
        }
        guard let rect = chosen else { return nil }

        return OpeningObservation(points: corners(rect),
                                  confidence: rect.confidence,
                                  source: .rectangle)
    }
}
