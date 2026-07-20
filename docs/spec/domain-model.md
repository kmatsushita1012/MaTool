# ドメインモデル仕様（正本）

`Shared/Sources/Entity` と `Shared/Sources/Pack` と `Shared/Sources/Validation` を基準に、ドメイン全体を整理した正本ドキュメントです。

## 1. 全体像

- Festival 系: `Festival`, `Period`, `Checkpoint`, `HazardSection`
- District 系: `District`, `Performance`, `FloatLocation`
- Route 系: `Route`, `Point`, `Anchor`
- 共通属性/補助: `Visibility`, `Coordinate`, `SimpleDate`, `SimpleTime`, `ImagePath`, `UserRole`

主な関係は以下です。

```text
Festival
 ├─ Checkpoint
 ├─ HazardSection
 ├─ District
 │   ├─ Performance
 │   ├─ FloatLocation
 │   └─ Route
 │       └─ Point (checkpointId/performanceId/anchor を任意参照)
 └─ Period
     └─ Route
```

## 2. Festival 系

## 2.1 Festival

- ファイル: `Shared/Sources/Entity/Festival.swift`
- 役割: 祭り全体のルート集約
- 主なプロパティ:
  - `id: String`
  - `name: String`
  - `subname: String`
  - `description: String?`
  - `prefecture: String`
  - `city: String`
  - `base: Coordinate`（基準座標）
  - `image: ImagePath`
- 関係:
  - 子: `Checkpoint`, `HazardSection`, `District`, `Period`

## 2.2 Period

- ファイル: `Shared/Sources/Entity/Period.swift`
- 役割: 祭り内の開催日・時間枠
- 主なプロパティ:
  - `id: String`
  - `festivalId: Festival.ID`
  - `date: SimpleDate`
  - `title: String`
  - `start: SimpleTime`
  - `end: SimpleTime`
- 関係:
  - 親: `Festival`
  - 子: `Route`
- 実装上の仕様:
  - `Comparable` 実装: `date + start` の日時で比較
  - `contains(_:)`: 指定日時が期間内か判定
  - `before(_:)`: 指定日時が開始以前か判定

## 2.3 Checkpoint

- ファイル: `Shared/Sources/Entity/Festival.swift`
- 役割: 祭り共通の固定地点マスタ
- 主なプロパティ:
  - `id: String`
  - `festivalId: Festival.ID`
  - `name: String`
  - `description: String?`
- 関係:
  - 親: `Festival`
  - `Point.checkpointId` から参照される

## 2.4 HazardSection

- ファイル: `Shared/Sources/Entity/Festival.swift`
- 役割: 祭り共通の危険区域マスタ
- 主なプロパティ:
  - `id: String`
  - `title: String`
  - `festivalId: Festival.ID`
  - `coordinates: [Coordinate]`
- 関係:
  - 親: `Festival`

## 3. District 系

## 3.1 District

- ファイル: `Shared/Sources/Entity/District.swift`
- 役割: 祭り内の町（運行主体）
- 主なプロパティ:
  - `id: String`
  - `name: String`
  - `festivalId: Festival.ID`
  - `order: Int`
  - `group: String?`
  - `description: String?`
  - `base: Coordinate?`
  - `area: [Coordinate]`（エリアポリゴン）
  - `image: ImagePath`
  - `visibility: Visibility`
  - `isEditable: Bool`
- 関係:
  - 親: `Festival`
  - 子: `Performance`, `FloatLocation`, `Route`

## 3.2 Performance

- ファイル: `Shared/Sources/Entity/District.swift`
- 役割: 町ごとの演目
- 主なプロパティ:
  - `id: String`
  - `name: String`
  - `districtId: District.ID`
  - `performer: String`
  - `description: String?`
- 関係:
  - 親: `District`
  - `Point.performanceId` から参照される

## 3.3 FloatLocation

- ファイル: `Shared/Sources/Entity/FloatLocation.swift`
- 役割: 町の現在位置/履歴ログ
- 主なプロパティ:
  - `id: String`
  - `districtId: District.ID`
  - `coordinate: Coordinate`
  - `timestamp: Date`
- 関係:
  - 親: `District`

## 4. Route 系

## 4.1 Route

- ファイル: `Shared/Sources/Entity/Route.swift`
- 役割: 特定の町 × 特定期間の運行ルート
- ドメイン上の識別: `districtId` と `periodId` の組で決まるルート
- 主なプロパティ:
  - `id: String`
  - `districtId: District.ID`
  - `periodId: Period.ID`
  - `visibility: Visibility`
  - `description: String?`
- 関係:
  - 親: `District`, `Period`
  - 子: `Point`

## 4.2 Point

- ファイル: `Shared/Sources/Entity/Route.swift`
- 役割: ルートを構成する最小単位の座標点
- 主なプロパティ:
  - `id: String`
  - `routeId: Route.ID`
  - `coordinate: Coordinate`
  - `time: SimpleTime?`
  - `checkpointId: Checkpoint.ID?`
  - `performanceId: Performance.ID?`
  - `anchor: Anchor?`
  - `index: Int`
  - `isBoundary: Bool`
- 関係:
  - 親: `Route`
  - 任意参照: `Checkpoint`, `Performance`, `Anchor`

### Point の実装ルール（Validation）

- ファイル: `Shared/Sources/Validation/Point+Validation.swift`
- 単体検証:
  - `checkpointId`, `performanceId`, `anchor` は同時に複数設定不可
  - `checkpointId` がある場合 `time` 必須
  - `anchor` がある場合 `time` 必須
- 配列検証:
  - `Anchor.start` は 1 個のみ、かつ先頭必須
  - `Anchor.end` は 1 個のみ、かつ末尾必須
  - `time` は昇順（単調増加）必須
- `Point` は `index` で `Comparable`

## 4.3 Anchor

- ファイル: `Shared/Sources/Entity/Route.swift`
- 役割: Point の意味属性
- 値:
  - `start`
  - `end`
  - `rest`

## 4.4 Visibility

- ファイル: `Shared/Sources/Entity/Route.swift`
- 役割: 公開制御
- 値:
  - `admin`
  - `route`
  - `all`

## 5. 共通値オブジェクト・補助型

## 5.1 Coordinate

- ファイル: `Shared/Sources/Entity/Coordinate.swift`
- `latitude`, `longitude` を保持

## 5.2 SimpleDate / SimpleTime

- ファイル: `Shared/Sources/Entity/DateTime.swift`
- `SimpleDate`: `year/month/day`
- `SimpleTime`: `hour/minute`
- どちらも `Comparable`
- 日本時間（`Asia/Tokyo`）基準の変換実装を持つ

## 5.3 ImagePath

- ファイル: `Shared/Sources/Entity/Others.swift`
- `light` / `dark` の画像パスを保持

## 5.4 UserRole

- ファイル: `Shared/Sources/Entity/Auth.swift`
- 値:
  - `.headquarter(String)`
  - `.district(String)`
  - `.guest`
- `id` プロパティで関連IDを取得可能（`guest` は `nil`）

## 5.5 DomainError

- ファイル: `Shared/Sources/Entity/Error.swift`
- Point 検証に対応するドメインエラーを定義

## 6. Pack との対応（集約単位）

`Shared/Sources/Pack/Pack.swift` では Entity を以下の単位で束ねる。

- 位置づけ:
  - Pack は DTO 的な役割を持つ。
  - 複数 Entity を「編集・同期の単位」で束ねてやり取りするためのモデル。

- `FestivalPack`
  - `festival + checkpoints + hazardSections`
- `DistrictPack`
  - `district + performances`
- `RouteDetailPack`
  - `route + points`
- `LaunchFestivalPack`
  - `festival + districts + periods + locations + checkpoints + hazardSections`
- `LaunchDistrictPack`
  - `performances + routes + points + currentRouteId`

## 7. 補足

- `Legacy.Span`（`Shared/Sources/Entity/Legacy.swift`）は旧表現で、`toPeriod` により `Period` へ変換可能。
- `Entity` は `Codable & Sendable & Hashable & Equatable` の typealias（`Shared/Sources/Utils/Contracts.swift`）。

## 8. 集約・境界づけられた責務

- `Festival` 集約:
  - ルート: `Festival`
  - 配下: `Checkpoint`, `HazardSection`, `Period`, `District`
  - 責務: 祭典単位の基準情報と公開用マスタの保持
- `District` 集約:
  - ルート: `District`
  - 配下: `Performance`, `FloatLocation`, `Route`
  - 責務: 町単位の運行主体情報と現在位置/演目の保持
- `Route` 集約:
  - ルート: `Route`
  - 配下: `Point`
  - 責務: 期間内運行経路と時系列ポイントの保持
- 補助境界:
  - `UserRole`, `Visibility`, `Anchor` は横断ルールを担う列挙モデル

## 9. ドメイン不変条件（Invariant）

- `Route` はドメイン上 `districtId × periodId` で決まる。
- `Point` は次の制約を満たす。
  - `checkpointId`, `performanceId`, `anchor` の同時複数設定は禁止。
  - `checkpointId` がある場合 `time` 必須。
  - `anchor` がある場合 `time` 必須。
  - 配列として扱う場合、`start` は先頭1件、`end` は末尾1件。
  - `time` は単調増加。
- `Visibility` は公開範囲を限定する。
  - `admin`: 管理者向け
  - `route`: ルート情報制限
  - `all`: 全公開

## 10. ID と参照整合ルール

- 全エンティティの識別子は `String` を採用。
- 親子関係はID参照で保持（外部キー制約はアプリケーションで担保）。
- 主要参照:
  - `Period.festivalId -> Festival.id`
  - `District.festivalId -> Festival.id`
  - `Route.districtId -> District.id`
  - `Route.periodId -> Period.id`
  - `Point.routeId -> Route.id`
  - `Point.checkpointId -> Checkpoint.id`（任意）
  - `Point.performanceId -> Performance.id`（任意）

## 11. 状態遷移とライフサイクル

- Festival起点:
  - `FestivalPack` で festival/checkpoint/hazard を一括更新
  - `LaunchFestivalPack` で起動同期用の祭典単位スナップショットを提供
- District起点:
  - `DistrictPack` で district/performances を扱う
  - `LaunchDistrictPack` で district配下の運行情報を一括同期
- Route起点:
  - `RouteDetailPack` で route/points を同時更新
  - Point配列は保存前に検証ルールを適用

## 12. 時刻・座標モデルの仕様

- 時刻:
  - `SimpleDate`, `SimpleTime` を業務時刻表現として使用
  - 比較・変換は `Asia/Tokyo` を基準に実装
- 座標:
  - `Coordinate(latitude, longitude)` を共通採用
  - 面表現は `area: [Coordinate]` / `coordinates: [Coordinate]`
  - 点表現は `base`, `coordinate` を利用

## 13. 権限モデル仕様

- `UserRole`:
  - `.headquarter(id)`
  - `.district(id)`
  - `.guest`
- 権限判断は主に Usecase 層で実施し、Entity自体は最小限の権限情報のみ持つ。
- `id` 取得規約:
  - `headquarter` / `district` は対応するIDを返却
  - `guest` は `nil`

## 14. エラーモデル仕様

- ドメイン検証エラーは `DomainError` で表現。
- `Point` 検証に関する失敗理由を型安全に区別する。
- UI向け文言は `Point.Error` の `LocalizedError` で提供。

## 15. 非機能要件に関わる設計メモ

- `Entity` / `Pack` / `DTO` は `Codable & Sendable & Hashable & Equatable` を満たす。
- API層とローカル永続化層の両方で同一モデルを再利用し、整合を優先。
- 永続化形式（SQLite列, JSON表現）は実装依存だが、意味的な正本は本ドキュメントのモデル定義とする。
