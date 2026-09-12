import XCTest
import simd
@testable import DokodemoBackroom

final class GeometryTests: XCTestCase {

    func testPointInPolygon() {
        let square = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1)
        ]
        XCTAssertTrue(pointInPolygon(CGPoint(x: 0.5, y: 0.5), square))
        XCTAssertFalse(pointInPolygon(CGPoint(x: 1.5, y: 0.5), square))
        XCTAssertFalse(pointInPolygon(CGPoint(x: -0.1, y: 0.5), square))
    }

    func testInsetPolygonShrinksTowardCenter() {
        let quad = [
            SIMD3<Float>(-1, -1, 0),
            SIMD3<Float>(1, -1, 0),
            SIMD3<Float>(1, 1, 0),
            SIMD3<Float>(-1, 1, 0)
        ]
        let inset = insetPolygon3D(quad, meters: 0.1)
        // 各点は中心(0,0,0)へ近づくので原点からの距離が縮む。
        for (a, b) in zip(quad, inset) {
            XCTAssertLessThan(simd_length(b), simd_length(a))
        }
    }

    func testInsetPolygonClampsToNotCrossCenter() {
        let quad = [
            SIMD3<Float>(-0.05, -0.05, 0),
            SIMD3<Float>(0.05, -0.05, 0),
            SIMD3<Float>(0.05, 0.05, 0),
            SIMD3<Float>(-0.05, 0.05, 0)
        ]
        // 開口より大きなオフセットでも中心を越えて反転しない（最大45%まで）。
        let inset = insetPolygon3D(quad, meters: 10)
        for p in inset {
            XCTAssertGreaterThan(simd_length(p), 0)
        }
    }

    func testSmoothstep() {
        XCTAssertEqual(smoothstep(0, 1, -1), 0, accuracy: 1e-6)
        XCTAssertEqual(smoothstep(0, 1, 2), 1, accuracy: 1e-6)
        XCTAssertEqual(smoothstep(0, 1, 0.5), 0.5, accuracy: 1e-6)
    }

    func testLerp() {
        XCTAssertEqual(lerpF(0, 10, 0.25), 2.5, accuracy: 1e-6)
    }
}
