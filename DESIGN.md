# DESIGN — どこでもBackroom

壁打ちで固めた設計をコードに落とすための覚書。優先度は「労力あたりの没入感」で決める。

## 1. コンセプト

カメラに映った窓・ドアの開口部をタップ → その向こうを別空間（バックルーム風の無限廊下）に置き換える AR。SNS に上がる動画が全てになるジャンルなので、**撮影・共有を主機能**として設計する。

- 対応端末: **LiDAR優先＋非Pro機フォールバック**
- 「30秒で飽きる」が最大の敵。→ 撮影の気持ちよさ＋「奥で何かが動く」程度の仕掛けで撮影動機を作る。

## 2. パイプライン（1タップ確定方式）

```
タップ
 └→ その瞬間の ARFrame（+ depthMap）を1枚コピー
     └→ 開口部を判定（深度 or 矩形）→ 画像空間ポリゴン
         └→ 各点を垂直平面へ raycast → 3D座標
             └→ ポリゴンでメッシュ生成、PortalMaterial を貼る
                 └→ AnchorEntity にぶら下げて固定。以降は判定しない
```

**毎フレーム判定しない理由:** 縁がチラつき、負荷でフレームが落ちる。「リアルタイムに自然」は判定の連打ではなく、1回固定 → ARKit に追わせることで達成する。

## 3. 開口部検出（`AR/OpeningDetector.swift`）

差し替え可能なプロトコル。3段フォールバック。

| 端末 | 一次 | 仕組み | 弱点 |
|---|---|---|---|
| LiDAR機 | `DepthOpeningDetector` | タップ点の深度から連続領域を region-grow。壁と奥が同色でも深度で切れる | 深度は 256×192 で粗い |
| 非Pro機 | `RectangleOpeningDetector` | `VNDetectRectanglesRequest` でタップを内包する矩形 | 白壁×白部屋で漏れる |
| 共通 | 既定クアッド | タップ点 raycast + 既定サイズ | 形は合わない |

**チューニング**: 矩形は `minimumAspectRatio` / `minimumSize` / `quadratureTolerance`。深度は連続とみなす閾値（sensitivity スライダーで露出）。

### 現状の実装レベル
- `RectangleOpeningDetector`: 実装済み（Vision）。
- `DepthOpeningDetector`: region-grow → マスクのバウンディング矩形を返す簡易版。輪郭トレース＆RGBエッジ吸着は TODO（§7）。
- どちらも nil のときは Coordinator が既定クアッドにフォールバック。

## 4. 境界を自然に見せる（最重要・費用対効果順）

「マスク判定を頑張る」より「境界を誤魔化す」ほうが圧倒的に効く。

1. **壁の厚み（筒）** — `PortalBuilder` が開口部の内側に深さ ~0.12m の暗い筒（三方枠の内面）を立てる。カメラを動かすと筒の内面が視差で見え隠れし、「本当に穴が空いている」最強の証拠になる。縁が暗くなるのでマスクのズレも隠れる。**実装済み。**
2. **内側オフセット** — マスクを 2〜3cm 内側に縮める。誤差は「小さすぎ（枠が少し見える）」側に倒すと気づかれにくく、「大きすぎ（空間が壁にはみ出す）」側は一発でバレる。**実装済み（`insetMeters`）。**
3. **グレイン** — カメラ映像のセンサーノイズに合わせ画面全体に薄くグレイン。暗所ほど強く。→ TODO（`Rendering/GrainPostProcess`）。
4. **露出・色温度追従** — `ARFrame.lightEstimate` の `ambientIntensity`/`ambientColorTemperature` でマテリアルの tint をスケール。部屋の明かりを消した瞬間に向こう側だけ明るく残る破綻を防ぐ。→ 生成時に一次適用済み、毎フレーム追従は TODO。
5. **エッジのフェザリング** — 境界を数px なめらかに。ハードな切り抜きは CG に見える。→ TODO。
6. **人オクルージョン** — `.personSegmentationWithDepth` を frameSemantics に追加。**実装済み（対応端末のみ）。**
7. **輪郭のRGBエッジ吸着** — 深度マスクの輪郭を RGB の Sobel 最大位置へ数px 動かす。一番大変で一番効果が薄い。1ヶ月なら捨ててよい。→ TODO。

**1〜4 + 6 で体感の8割。**

## 5. 角度・距離フェード

浅い角度だと平面性がバレるので消す。毎フレーム、カメラ方向とポータル法線の内積で不透明度を決める。

```
facing  = dot(normalize(camPos - portalPos), portalNormal)   // 1.0 = 正対
opacity = smoothstep(0.25, 0.55, facing)
```

`PortalARCoordinator` が `session(_:didUpdate:)` で計算し、アンカーの `OpacityComponent` に反映。距離でも同様にフェード可。

## 6. 別空間の生成（`Backrooms/BackroomsWorldBuilder.swift`）

バックルーム系は基本「箱」。壁・床・天井・柱は全部直方体なのでプロシージャル生成でいける。

- 開口部から覗ける範囲しか見えない → **生成範囲は狭くてよい**。濃いフォグ＋廊下の使い回しで成立。
- フォグは雰囲気作りと描画負荷削減を兼ねる。奥はフォグ色の板＋暗いマテリアルで潰す（RealityKit iOS に本格フォグが無いための近似）。
- 質感: まずは単色 `UnlitMaterial`（蛍光灯の平坦で明るい質感）。テクスチャ（黄ばんだ壁紙・湿ったカーペット・天井パネル）は ambientCG / Poly Haven の CC0 を後入れ。画像生成AIはシームレス・ノーマルマップ問題があるので非推奨。
- 音（蛍光灯のブーン＝60/120Hz サイン波＋フィルタノイズ）は費用対効果が高い。→ TODO。

## 7. 撮影・共有（`Capture/CaptureController.swift`）

- 写真: `ARView.snapshot`。
- 動画: v1 は ReplayKit `RPScreenRecorder.startRecording` + `RPPreviewViewController`（実装が堅い）。UI が写り込むので**録画中はボタンを隠す**。将来は `startCapture` + `AVAssetWriter` で UI 除外・マイク音声トグル。

## 8. 権利・審査メモ

- Backrooms Wiki の Level 記述は CC BY-SA（表示＋シェアアライク義務）。特定 Level をそのまま使わない。
- Kane Pixels 版の固有デザインは避ける。
- App Store 4.3（類似/スパム）に注意。表示名「どこでもBackroom」は採用。独自体験（録画・共有、切り口）で差別化する。
- ホラー表現でレーティングが上がる。ジャンプスケアを入れるなら年齢区分に注意。
- `NSCameraUsageDescription` に「なぜ室内を撮るのか」を明記済み。

## 9. マイルストーン

- [x] 週1: ARKit + タップ + ポータル配置（中身グレー箱でOK）
- [ ] 週2: 空間生成・フォグ・ライティング
- [ ] 週3: テクスチャ・音・詰め
- [ ] 週4: 録画・共有・審査提出バッファ（審査で数日取られる前提）
