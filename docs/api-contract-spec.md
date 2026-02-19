# API契約仕様（Endpoint単位 / As-Is）

本仕様は `Backend/Sources/Router` と `Backend/Sources/Controller` の実装を正として整理した現行API契約。

## 1. 共通仕様

## 1.1 Base

- Base URL: 環境ごとの API Gateway エンドポイント
- Content-Type: `application/json`
- 文字コード: UTF-8

## 1.2 認証

- Authorizationヘッダ（任意）:
  - `Authorization: Bearer <access_token>`
- 認証解決:
  - 有効トークン: `headquarter(id)` または `district(id)`
  - ヘッダなし: `guest`
- 認可は各Usecase側で判定。

## 1.3 共通レスポンス

- 成功:
  - HTTP `200`
  - Body: JSON（空の場合 `{}`）
- 失敗:
  - HTTP: `400/401/403/404/409/500`
  - Body:
    - `message: String`（固定ラベル）
    - `localizedDescription: String`（詳細）

## 1.4 主要クエリパラメータ

- `year`:
  - `Int`（例: `2026`）
  - `"latest"`

## 2. Endpoint一覧

## 2.1 Festival

### GET `/festivals`
- 概要: Festival一覧取得
- 認証: 不要
- Query: なし
- Response `200`: `[Festival]`

### GET `/festivals/:festivalId`
- 概要: Festival詳細取得
- 認証: 不要
- Path: `festivalId: String`
- Response `200`: `FestivalPack`

### PUT `/festivals`
- 概要: Festival更新
- 認証: 必要（`headquarter(festivalId)`）
- Body: `FestivalPack`
- Response `200`: `FestivalPack`
- Errors: `401`, `500`

### GET `/festivals/:festivalId/launch`
- 概要: 起動用Festivalデータ取得
- 認証: 任意（roleで返却内容が変わる）
- Path: `festivalId: String`
- Response `200`: `LaunchFestivalPack`

## 2.2 District

### GET `/festivals/:festivalId/districts`
- 概要: Festival配下District一覧
- 認証: 不要
- Path: `festivalId: String`
- Response `200`: `[District]`

### POST `/festivals/:festivalId/districts`
- 概要: District作成（招待）
- 認証: 必要（`headquarter(festivalId)`）
- Path: `festivalId: String`
- Body: `DistrictCreateForm`
- Response `200`: `DistrictPack`
- Errors: `401`, `404`, `409`, `500`

### GET `/districts/:districtId`
- 概要: District詳細取得
- 認証: 不要
- Path: `districtId: String`
- Response `200`: `DistrictPack`

### PUT `/districts/:districtId`
- 概要: District更新
- 認証: 必要（`district(districtId)`）
- Path: `districtId: String`
- Body: `DistrictPack`
- Response `200`: `DistrictPack`
- Errors: `401`, `500`

### GET `/districts/:districtId/launch-festival`
- 概要: District基準でFestival起動データ取得
- 認証: 任意
- Path: `districtId: String`
- Response `200`: `LaunchFestivalPack`

### GET `/districts/:districtId/launch`
- 概要: District起動データ取得
- 認証: 任意（visibility適用）
- Path: `districtId: String`
- Response `200`: `LaunchDistrictPack`

## 2.3 Route

### GET `/districts/:districtId/routes`
- 概要: District配下Route一覧
- 認証: 任意（visibility適用）
- Path: `districtId: String`
- Query: `year`（省略時all / `latest` / `Int`）
- Response `200`: `[Route]`

### POST `/districts/:districtId/routes`
- 概要: Route作成
- 認証: 必要（`district(districtId)`）
- Path: `districtId: String`
- Body: `RouteDetailPack`
- Response `200`: `RouteDetailPack`
- Errors: `401`, `404`, `500`

### GET `/routes/:routeId`
- 概要: Route詳細取得
- 認証: 任意（visibility適用）
- Path: `routeId: String`
- Response `200`: `RouteDetailPack`

### PUT `/routes/:routeId`
- 概要: Route更新
- 認証: 必要（対象Routeのdistrict一致）
- Path: `routeId: String`
- Body: `RouteDetailPack`
- Response `200`: `RouteDetailPack`
- Errors: `401`, `404`, `500`

### DELETE `/routes/:routeId`
- 概要: Route削除
- 認証: 必要（対象Routeのdistrict一致）
- Path: `routeId: String`
- Response `200`: `{}`
- Errors: `401`, `404`, `500`

## 2.4 Location

### GET `/festivals/:festivalId/locations`
- 概要: Festival配下Location一覧
- 認証: 任意（管理者と一般で可視条件が異なる）
- Path: `festivalId: String`
- Response `200`: `[FloatLocation]`
- Errors: `401`, `404`, `500`

### GET `/districts/:districtId/locations`
- 概要: DistrictのLocation取得
- 認証: 任意（管理者/当該district/一般で判定）
- Path: `districtId: String`
- Response `200`: `FloatLocation`
- Errors: `401`, `404`, `500`

### PUT `/districts/:districtId/locations`
- 概要: DistrictのLocation更新
- 認証: 必要（`user.id == body.districtId`）
- Path: `districtId: String`（実装上は権限判定でbody側を利用）
- Body: `FloatLocation`
- Response `200`: `FloatLocation`
- Errors: `401`, `404`, `500`

### DELETE `/districts/:districtId/locations`
- 概要: DistrictのLocation削除
- 認証: 必要（`user.id == districtId`）
- Path: `districtId: String`
- Response `200`: `{}`
- Errors: `401`, `404`, `500`

## 2.5 Period

### GET `/festivals/:festivalId/periods`
- 概要: Period一覧取得
- 認証: 不要
- Path: `festivalId: String`
- Query: `year?: Int`
- Response `200`: `[Period]`

### GET `/festivals/:festivalId/periods/:periodId`
- 概要: Period取得
- 認証: 不要
- Path: `festivalId: String`, `periodId: String`
- Response `200`: `Period`

### POST `/festivals/:festivalId/periods`
- 概要: Period作成
- 認証: 必要（`headquarter(festivalId)`）
- Path: `festivalId: String`
- Body: `Period`
- Response `200`: `Period`
- Errors: `401`, `500`

### PUT `/festivals/:festivalId/periods`
- 概要: Period更新
- 認証: 必要（`headquarter(festivalId)`）
- Path: `festivalId: String`
- Query: `year: Int`（Controller実装上 required）
- Body: `Period`
- Response `200`: `Period`
- Errors: `400`, `401`, `500`

### DELETE `/festivals/:festivalId/periods/:periodId`
- 概要: Period削除
- 認証: 必要（対象Periodのfestival一致）
- Path: `festivalId: String`, `periodId: String`
- Response `200`: `{}`
- Errors: `401`, `404`, `500`

## 3. 現行実装の差分メモ（クライアント整合用）

以下は「Backend Router定義」と「iOS DataFetcher呼び出し」の不整合候補。

- Festival更新:
  - Backend: `PUT /festivals`
  - iOS: `PUT /festivals/{festivalId}`
- Period系:
  - Backend: `/festivals/:festivalId/periods...`
  - iOS: `/periods/{id}` を `GET/PUT/DELETE` に使用
- Location系:
  - Backend: `/districts/:districtId/locations`
  - iOS: `/district/:districtId/locations`（単数）
- District core更新:
  - iOS: `PUT /districts/:districtId/core`
  - Backend Router: 該当 endpoint なし

本仕様はAs-Is記録のため、上記差分は「既知ズレ」として扱う。

## 4. 参照実装

- Router:
  - `/Users/matsushitakazuya/private/MaTool/Backend/Sources/Router/FestivalRouter.swift`
  - `/Users/matsushitakazuya/private/MaTool/Backend/Sources/Router/DistrictRouter.swift`
  - `/Users/matsushitakazuya/private/MaTool/Backend/Sources/Router/RouteRouter.swift`
- Controller:
  - `/Users/matsushitakazuya/private/MaTool/Backend/Sources/Controller/FestivalController.swift`
  - `/Users/matsushitakazuya/private/MaTool/Backend/Sources/Controller/DistrictController.swift`
  - `/Users/matsushitakazuya/private/MaTool/Backend/Sources/Controller/RouteController.swift`
  - `/Users/matsushitakazuya/private/MaTool/Backend/Sources/Controller/LocationController.swift`
  - `/Users/matsushitakazuya/private/MaTool/Backend/Sources/Controller/PeriodController.swift`
  - `/Users/matsushitakazuya/private/MaTool/Backend/Sources/Controller/SceneController.swift`
- 共通I/O:
  - `/Users/matsushitakazuya/private/MaTool/Backend/Sources/Core/Request+.swift`
  - `/Users/matsushitakazuya/private/MaTool/Backend/Sources/Core/Response+.swift`
  - `/Users/matsushitakazuya/private/MaTool/Backend/Sources/Core/Error+.swift`

