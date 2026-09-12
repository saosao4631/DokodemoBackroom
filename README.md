# どこでもBackroom / DokodemoBackroom

窓・ドア・テレビなどの**四角い開口部をタップすると、その向こうが別空間（バックルーム風）に変わって見える** AR カメラアプリ（iOS）。

「どこでもドア」のもじり。撮った写真・動画の共有を主機能として設計している。

## 仕組み（概要）

1. タップした瞬間に**1回だけ**開口部を判定（毎フレームやらない）。
2. 検出は **深度フラッドフィル（LiDAR機）→ Vision矩形検出 → タップ点の既定サイズ** の3段フォールバック。
3. タップ中心で壁面を1回だけ確定し、検出した枠の4隅をその平面へ**投影**して穴の形を決める（非LiDAR機でも安定）。
4. 開口部に**壁の厚み（暗い筒＝三方枠）**を立て、視差で「本当に穴が空いている」ように見せる。
5. 手前の人は `personSegmentationWithDepth` でオクルージョン。

設計の詳細・TODO は [DESIGN.md](DESIGN.md)、開発メモは [CLAUDE.md](CLAUDE.md)。

## 必要環境

- Xcode 26 / Swift 5.9+
- iOS 18.0 以上（RealityKit の PortalComponent/WorldComponent/PortalMaterial が iOS 18+）
- 実機（AR）。LiDAR機だと深度検出・オクルージョンの品質が上がる
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## ビルド

`*.xcodeproj` は生成物なのでコミットしない。クローン後に生成する。

```sh
xcodegen generate
open DokodemoBackroom.xcodeproj   # 実機を選んで Run
```

## ステータス

開発中（縦切りプロトタイプ）。四角い枠へのフィット＋人オクルージョンを安全な完成形として作り込み中。
