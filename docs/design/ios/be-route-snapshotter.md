# Route Rendering MVP 設計書

## 0. 課題
iOSのRouteSnapShotterをAndroidでも利用したい。Shared層に統合された描画ロジックを作成し, iOSAppは直接、AndroidはBE経由で描画ロジックを呼び出したい。

以降はChatGPTが作成したドキュメントである。本サービスの構成等はあまり考慮してないので適宜書き換えを行うこと。

## 1. 目的

`RouteSnapshotter` の業務ロジックを Shared 層へ移し、以下を同時に成立させる。

* iOSApp: Shared の描画ロジックを直接呼び出してオフライン出力できる
* Backend: Shared の描画ロジックを呼び出し、API 経由で PNG/PDF を返せる
* Android: ルート編集中・一括作成の両方で Backend API を利用できる

MVP の主目的は「PNG を安定生成できる共通基盤の確立」であり、PDF は同じレンダリング基盤の拡張として実装する。

---

## 2. 到達目標（MVP）

* Shared に `RouteRenderCore` を新設し、MapKit/UIKit 依存を排除する
* Backend にスナップショット API を追加する（ID指定 + RoutePack POST）
* `routeId` 指定で PNG を返却できる
* `RoutePack` 指定で編集中データの PNG を返却できる
* iOS 既存 `RouteSnapshotter` を Shared ラッパー化し、見た目差分を許容範囲で維持する
* 将来の district 一括 PDF 出力に必要な API 形状を先に固定する

---

## 3. 非目標（MVP 範囲外）

* 出力結果の完全ピクセル一致（旧 iOS 実装との 1px 単位一致）
* 非同期ジョブ基盤（SQS/Step Functions）
* 長期キャッシュ最適化
* 高度なレイアウト自動調整（禁則・高精度文字組版）
* Bootstrap 系テスト/マイグレーションへの組み込み

---

## 4. 全体アーキテクチャ

```text
                +----------------------+
                | Shared.RouteRenderCore|
                |  - region calc         |
                |  - path segmentation   |
                |  - label layout        |
                |  - draw command build  |
                +-----------+-----------+
                            |
           +----------------+----------------+
           |                                 |
+----------v-----------+          +----------v----------------+
| iOSApp               |          | Backend (AWS Lambda)      |
| RouteSnapshotter     |          | RouteSnapshotController    |
| (wrapper)            |          | + MapFetcher + Renderer    |
| CoreGraphics/MapKit  |          | (Linux)                    |
+----------------------+          +----------------------------+
                                              |
                                   +----------v-----------+
                                   | Android / iOS Batch  |
                                   | via HTTP             |
                                   +----------------------+
```

### 採用方針

* Shared は「描画計算 + 描画命令生成」までを担当
* 実レンダラはプラットフォームごとに分離（iOS / Backend）
* Backend API は既存 `APIGatewayV2Request/Response` 基盤へ統合

---

## 5. API 仕様

### 5.1 ID 指定（保存済みルート）

`GET /routes/{routeId}/snapshot`

Query:

* `format` optional: `png` (default), `pdf`
* `width` optional: default `594`
* `height` optional: default `420`
* `scale` optional: default `1`
* `debug` optional: default `false`

### 5.2 RoutePack 指定（編集中ルート）

`POST /routes/snapshot`

Body:

* `RoutePack`（Shared 定義を利用）
* 補助情報: `district`, `period`, `hazardSections` を同梱する `RouteRenderPack` を新設

Query:

* `format`, `width`, `height`, `scale`, `debug` は GET と同じ

### 5.3 地区一括 PDF

`POST /districts/{districtId}/route-snapshots`

Query:

* `year` required: `latest` or `YYYY`
* `format` optional: `pdf` のみ許可（省略時 `pdf`）

挙動:

* 指定 `districtId` の `year` 対象 route 一覧を取得して 1 つの PDF を返す
* PDF は `1 route = 1 page` で構成する
* ページ順は route の `period.start` 昇順、同一時刻は route.id 昇順で安定化する
* 該当 route が 0 件の場合は `404` を返す

### レスポンス

成功時:

* HTTP 200
* `Content-Type`: `image/png` または `application/pdf`
* API Gateway v2 の `isBase64Encoded = true` で返却

失敗時:

* HTTP 400: リクエスト不正
* HTTP 404: route/district/period 不存在
* HTTP 422: 描画必須データ不足
* HTTP 502: 背景地図取得失敗
* HTTP 500: 描画失敗

---

## 6. API Gateway / Lambda 設計

### 現行前提との整合

* 本 Backend は `APIGatewayV2Request/Response` を使用している
* REST API 向け `binaryMediaTypes` 前提ではなく、v2 応答の `isBase64Encoded` を利用する

### 必要改修

* `Application.Response` に `isBase64Encoded: Bool` を追加
* `APIGateway.handler` で `APIGatewayV2Response(isBase64Encoded:)` へ伝搬
* 既存 JSON API は `isBase64Encoded = false` のまま維持

---

## 7. Backend の責務

`RouteSnapshotController`（新設）:

* パラメータ検証（routeId / format / size）
* 認可確認（既存 `AuthMiddleware` と同等方針）
* Usecase 呼び出し
* バイナリレスポンス生成

`RouteSnapshotUsecase`（新設）:

* 入力種別（ID指定 / RouteRenderPack 指定）を吸収
* データ取得（ID 指定時）
* Shared `RouteRenderCore` 実行
* 背景地図取得 + レンダラ実行

---

## 8. データ取得設計

### 8.1 ID 指定経路

* Route: `RouteRepository.get(id:)`
* Points: `PointRepository.query(by:)`
* District: `DistrictRepository.get(id:)`
* Period: `PeriodRepository.get(id:)`
* HazardSections: `HazardSectionRepository.query(by: festivalId)`

### 8.2 RoutePack 指定経路

* DB 読み取りは最小化する（基本は payload 完結）
* 認可や補助情報のみ必要なら追加参照

### 8.3 Shared 入力モデル

`RouteRenderInput`（新設）:

* route
* points
* district
* period
* hazardSections
* options（size/scale/debug/format）

---

## 9. Shared モジュール分割

`Shared/Sources/RouteRendering` を新設し、以下を配置する。

* `RouteRenderCore`
  * 全体 orchestration
* `RegionCalculator`
  * 描画対象 bbox と padding 計算
* `BoundarySegmenter`
  * 境界点分割（既存 `splitCoordinatesByBoundary` 移植）
* `CaptionLayoutEngine`
  * `drawnRects` 相当の衝突回避ロジック
* `RouteRenderCommandBuilder`
  * 線・点・テキストの描画命令へ変換
* `RouteRenderModels`
  * `RouteRenderInput/Output`, `DrawCommand`, `RenderTheme`

Shared は画像 API を直接持たず、描画命令列を返す。

---

## 10. 描画仕様

### 描画順（共通）

1. 背景地図
2. 危険区間 polyline（オレンジ）
3. ルート本線（白）
4. 境界 polyline（青/緑）
5. ピン
6. ポイント caption
7. 危険区間 caption
8. タイトルブロック

### 既存仕様の維持対象

* 境界点での分割色付け
* caption 衝突回避
* 開始/終了時刻のタイトル表示
* checkpoint 名 / anchor 名表示

### MVP 許容差分

* フォントは固定
* 角丸は簡易化可
* 改行の微調整は後続

---

## 11. レンダラ実装方針（実現可能性）

### 結論

* Shared にはレンダリング依存を入れない
* iOS は CoreGraphics / MapKit の現行資産を薄い Adapter として維持
* Backend は Linux 対応レンダラを採用する

### Backend 候補比較

* A: Cairo + Pango（推奨）
  * 長所: 線/文字/PDF を同一系で実装しやすい
  * 短所: Lambda コンテナでのネイティブ依存配布が必要
* B: pure Swift 画像ライブラリ
  * 長所: 導入が軽い
  * 短所: 日本語描画と PDF 対応が弱いことが多い

MVP は A を採用し、Backend を ZIP ではなくコンテナデプロイ前提で進める。

---

## 12. 画像確認方法

### 開発確認

* `GET /routes/{routeId}/snapshot?format=png`
* `POST /routes/snapshot?format=png`

ブラウザ/HTTP クライアントでレスポンス画像を確認する。

### debug 表示

`debug=true` 時は以下を画像右上へ描画:

* routeId
* pointCount
* center/span
* renderedAt
* renderVersion

---

## 13. セキュリティ・認可

* 既存 `AuthMiddleware` を適用
* ID 指定時は既存 Route API と同等の可視性ルールを流用
* RoutePack 指定時は送信主体（district/headquarter）に応じた入力制約を適用
* Map provider の鍵情報は Lambda 環境変数で管理（デプロイ時に注入）

---

## 14. 環境変数

```text
APPLE_MAPS_TEAM_ID
APPLE_MAPS_KEY_ID
APPLE_MAPS_PRIVATE_KEY
```

上記3つのみを本機能専用の機密環境変数とする。非機密設定（format default, timeout, font path, log level, provider種別）はコード定数または既存設定系で管理し、本機能専用の環境変数は追加しない。

---

## 15. エラーハンドリング

* `404`: route/district/period が存在しない
* `422`: points 不足、region 算出不能、描画命令生成不可
* `502`: 背景地図取得失敗（タイムアウト/上流異常）
* `500`: レンダラ内部失敗

エラー本文は既存 Backend 形式の JSON で返却する。

---

## 16. 実装フェーズ

### Phase 0: API 疎通

* 新規 endpoint 追加
* 固定 PNG を base64 で返却
* `isBase64Encoded` 伝搬確認

### Phase 1: Shared Core 抽出

* `splitCoordinatesByBoundary`、caption 配置、タイトル構築を Shared へ移設
* iOS `RouteSnapshotter` を Shared 利用に置換

### Phase 2: Backend PNG

* ID 指定 API 実装
* 地図背景 + draw command レンダリング

### Phase 3: RoutePack API

* `POST /routes/snapshot` 実装
* 編集中ルートの即時プレビュー対応

### Phase 4: PDF / 一括出力

* `POST /districts/{districtId}/route-snapshots`
* `districtId + year` 指定で複数 route を 1 PDF に連結
* `1 route = 1 page` を保証

---

## 17. テスト観点

### Shared 単体

* 境界分割
* bbox/padding
* caption 衝突回避
* タイトル文字列生成
* draw command 生成順序

### Backend 単体

* controller の status/content-type
* usecase の分岐（ID/RoutePack）
* map fetcher の異常系（timeout, non-200）

### 結合

* API から PNG/PDF が返る
* `isBase64Encoded=true` が付与される
* 代表 routeId で見切れが発生しない
* `districtId + year` の PDF が複数ページで返る
* PDF のページ数が対象 route 数と一致する

---

## 18. 既存コード移植方針

### Shared へ移す

* `splitCoordinatesByBoundary()`
* caption レイアウトロジック（矩形衝突判定）
* タイトル文言生成
* hazard section の重ね順

### iOS に残す

* `MKMapSnapshotter` 呼び出し
* CoreGraphics 描画実体

### Backend へ新設

* Map 取得クライアント
* Linux レンダラ Adapter
* Binary response encoder

---

## 19. 実装タスク定義

1. Shared に `RouteRendering` モジュールを追加
2. iOS `RouteSnapshotter` を Shared Core 呼び出しへ差し替え
3. Backend `RouteSnapshotController/Usecase/Router` を追加
4. `Application.Response` と `APIGateway` をバイナリ対応
5. `GET /routes/{routeId}/snapshot` を実装
6. `POST /routes/snapshot` を実装
7. 代表ケースの golden 画像比較テストを追加
8. `POST /districts/{districtId}/route-snapshots?year=...` の PDF 結合を実装
9. 運用手順（環境変数/デプロイ）を README へ追記

---

## 20. 未決事項（期限付き）

* レンダラ最終採用（Cairo/Pango）: Phase 0 完了時点で確定
* 日本語フォント配布: Phase 1 中に運用方式確定
* 地図プロバイダ利用規約確認: 実装着手前に確認

---

## 21. 最初の PR 範囲

最初の PR は失敗切り分けを優先し、以下に限定する。

1. `GET /routes/{routeId}/snapshot` 追加（固定 PNG 応答）
2. `Application.Response` の `isBase64Encoded` 対応
3. ルーティング配線と認可適用
4. 最低限の結合テスト追加

`RoutePack` 経路と Shared 抽出は次 PR へ分離する。

---

## 22. 完了条件

MVP 完了は以下を満たすこと。

* iOS: Shared 経由で既存同等の経路図出力ができる
* Backend: ID 指定と RoutePack 指定の両方で PNG を返せる
* Backend: `districtId + year` 指定で `1 route = 1 page` の PDF を返せる
* Android: 編集中/一括作成の導線で Backend API を利用可能
* 主要 route で線・危険区間・caption・タイトルが欠落しない
* 既存 Backend 運用（Auth/Router/CI）に統合されている

以降はユーザーの要求に基づく

## 23. 最終形態
* Shared層に描画ロジックを置く
* iOSAppからは既存のRouteSnapShotterを描画ロジックのラッパーに移行して、オフラインで呼び出し可能にする
* BEには IDの指定 および `RoutePack` の送付(POST通信)によってPDF/PNGを返却するパスを作成
    * 後者はルート編集中に任意のタイミングで行えるようにするため
* iOSAppの経路図一括作成ではBEに`districtId`を渡してPDFを返却
* Androidはルート編集中/一括作成共にBEを叩く
