# DokodemoBackroom / どこでもBackroom

窓・ドアの開口部をタップすると、その向こうが「別空間（バックルーム風）」に変わって見える AR カメラアプリ。撮った写真・動画の共有を主機能として設計する。

## ビルド

XcodeGen 管理。`*.xcodeproj` は生成物なのでコミットしない（.gitignore 済み）。

```sh
xcodegen generate
# シミュレータでビルド確認（AR は動かないがコンパイル検証になる）
xcodebuild -project DokodemoBackroom.xcodeproj -scheme DokodemoBackroom \
  -destination 'generic/platform=iOS Simulator' build
# 実機で実行するのが本番（ARKit/LiDAR が必要）
```

- Bundle: `com.ksaotome.dokodemo-backroom`  / Team: `PVLPVC2YL3`
- Deployment: iOS 18.0（RealityKit の PortalComponent/WorldComponent/PortalMaterial/OpacityComponent が iOS 18+。ここが要件で最低ラインが決まる）
- 表示名: 「どこでもBackroom」

## 設計の要点（詳細は DESIGN.md）

1. **判定は毎フレームやらない。** タップの瞬間に1回だけ開口部を判定し、3Dポリゴンに変換して ARKit のアンカーに固定。以降はトラッキングに追従させる。
2. **境界は「精度」より「誤魔化し」。** 開口部に壁の厚み（暗い筒＝三方枠）を立て、マスクを内側に数cmオフセットする。これで視差が出て「本当に穴が空いている」ように見え、マスクのズレも目立たなくなる。
3. **検出器は差し替え可能。** LiDAR機=深度フラッドフィル、非Pro機=Vision矩形検出、どちらも失敗時はタップ点レイキャストの既定サイズにフォールバック。
4. **飽きさせない対策 = 撮影/共有を本体に。** 写真は `ARView.snapshot`、動画は ReplayKit。

## ディレクトリ

- `AR/` — セッション、端末能力判定、開口部検出
- `Backrooms/` — ポータル生成、プロシージャル空間生成
- `Rendering/` — 露出/色温度追従、グレイン（TODO）
- `Capture/` — 写真・動画キャプチャ
- `Views/` — SwiftUI オーバーレイ UI
- `Support/` — simd 等の補助
