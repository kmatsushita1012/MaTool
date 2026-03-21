# iOS LocationProvider 分離設計書（Map 用 / Broadcast 用）

## 1. 目的

- `LocationProvider` を用途別に分離し、地図表示（使用時のみ許可）と配信（常に許可）を安全に共存させる。
- Map 側の停止・権限変更が Broadcast 側の配信を中断させない構造にする。
- Admin 側は Apple 公式仕様に沿って、中断リスクを最小化する設定を明文化する。

## 2. 現状の問題（2026-03-21 時点）

- 単一の `locationProvider` を Map / Broadcast の両方で共有している。
  - Map: `PublicMapFeature`, `PublicLocationsFeature`, `PublicRouteFeature`
  - Broadcast: `LocationService`（`LocationTrackingFeature` 経由）
- `stopTracking()` が共通 `CLLocationManager` に対して実行されるため、用途間で副作用が発生する。
- `requestPermission()` が `requestWhenInUseAuthorization()` と `requestAlwaysAuthorization()` を同時実行しており、Map 用途でも常時許可フローに触れてしまう。

## 3. ゴール

- Map は「アプリ使用中のみ許可（When In Use）」で現在地表示に限定する。
- Broadcast は「常に許可（Always）」前提で、背景実行中も配信継続を最優先にする。
- 2用途が別インスタンスの `CLLocationManager` を持ち、互いに停止・設定変更の影響を与えない。

## 4. 提案アーキテクチャ

### 4.1 依存を分離

- 既存 `locationProvider` を以下に分割する。
  - `mapLocationProvider`（地図表示向け）
  - `broadcastLocationProvider`（配信向け）

### 4.2 プロトコル分離

- `MapLocationProviderProtocol`
  - `requestWhenInUsePermission()`
  - `startUserLocationSession()` / `stopUserLocationSession()`
  - `getLocation()`
- `BroadcastLocationProviderProtocol`
  - `requestAlwaysPermission()`（内部で WhenInUse -> Always の順）
  - `startBroadcastTracking(onUpdate:)`
  - `stopBroadcastTracking()`
  - `getLocation()`
  - `isAlwaysAuthorized()`

### 4.3 `CLLocationManager` インスタンス

- `MapLocationProvider` 内
  - `private let manager = CLLocationManager()`
- `BroadcastLocationProvider` 内
  - `private let manager = CLLocationManager()`
  - （任意拡張）再起動耐性強化のため `significantChangeManager` を別途持つ

## 5. Admin 配信の「中断最小化」設定（Apple 公式ベース）

中断ゼロは iOS の制御上保証できないが、以下は「配信中断を減らす」ために設定必須。

### 5.1 `CLLocationManager` 必須プロパティ/呼び出し

1. `allowsBackgroundLocationUpdates = true`
2. `pausesLocationUpdatesAutomatically = false`
3. `activityType = .fitness` または `.automotiveNavigation`（用途に合わせ固定）
4. `desiredAccuracy = kCLLocationAccuracyBest`（配信精度優先）
5. `distanceFilter = kCLDistanceFilterNone`（停止させない方針時）
6. `showsBackgroundLocationIndicator = true`（運用透明性のため推奨）
7. `startUpdatingLocation()`（配信開始時）
8. `stopUpdatingLocation()`（配信終了時のみ）
9. `authorizationStatus` と `accuracyAuthorization` の監視
10. 必要時 `requestTemporaryFullAccuracyAuthorization(withPurposeKey:)`

### 5.2 App 設定（Info.plist / Capability）

1. `UIBackgroundModes` に `location`
2. `NSLocationWhenInUseUsageDescription`
3. `NSLocationAlwaysAndWhenInUseUsageDescription`
4. （iOS 11 未満サポート時のみ）`NSLocationAlwaysUsageDescription`
5. （一時的高精度要求を使う場合）`NSLocationTemporaryUsageDescriptionDictionary`

### 5.3 再起動・復帰耐性

1. `locationManagerDidChangeAuthorization(_:)` で権限劣化を即検知し UI へ反映。
2. `didFailWithError` で復旧リトライを行う（即時ループは避け、バックオフ）。
3. 必要に応じて `startMonitoringSignificantLocationChanges()` を併用し、アプリ停止後の復帰導線を持つ。
4. 起動時 `UIApplicationLaunchOptionsLocationKey` を見て、配信セッション再構築を実施。
5. Background App Refresh が OFF の場合、復帰イベント制限がある前提で運用設計する。

## 6. Map 側ポリシー（使用時のみ）

1. 許可要求は `requestWhenInUseAuthorization()` のみ。
2. `allowsBackgroundLocationUpdates` は常に `false`。
3. 地図表示中のみセッション開始し、画面離脱で停止。
4. 可能なら `requestLocation()` ベースへ寄せ、常時 `startUpdatingLocation()` を避ける。

## 7. 具体的なコード変更方針

### 7.1 新規追加

- `iOSApp/Sources/Data/Client/MapLocationProvider.swift`
- `iOSApp/Sources/Data/Client/BroadcastLocationProvider.swift`
- DependencyKey:
  - `MapLocationProviderKey`
  - `BroadcastLocationProviderKey`

### 7.2 既存更新

1. `LocationService` の依存を `locationProvider` -> `broadcastLocationProvider` へ変更。
2. `PublicMapFeature` / `PublicLocationsFeature` / `PublicRouteFeature` の依存を `mapLocationProvider` へ変更。
3. 既存 `LocationProvider` は互換期間後に削除。
4. 権限文言（`INFOPLIST_KEY_NSLocation*UsageDescription`）を Map と Broadcast の用途が明確になる文面へ更新。

### 7.3 競合防止ルール

1. Map 側から Broadcast 側の `stop` を絶対に呼ばない。
2. Broadcast 配信中は Map 側のセッション開始/停止が独立して完結することをテストで保証。

### 7.4 `LocationService` を含む再構成（最適化案）

`LocationService` が「位置取得制御」と「配信ワークフロー（送信間引き・API送信・履歴管理）」を同時に持っているため、以下に分離する。

1. `BroadcastLocationProvider`
  - 位置取得と権限制御だけを担当。
  - `CLLocationManager` の設定/監視、`AsyncStream<CLLocation>` 提供。
2. `BroadcastCoordinator`（新規）
  - 配信セッションのライフサイクル管理（start/stop/recover）。
  - 送信インターバル制御、バックオフ再試行、バックグラウンド復帰時の再接続。
3. `LocationService`（薄いFacade化）
  - Feature からの窓口のみ。
  - 実処理は `BroadcastCoordinator` に委譲。
4. `BroadcastHistoryStore`（新規・actor）
  - `Status` 履歴と `AsyncStream<[Status]>` の責務を専有。

この分離で、`LocationService` の肥大化と停止リスク（Task/continuation/送信の密結合）を下げる。

## 8. 受け入れ条件

1. Map の画面遷移・終了が Broadcast 配信継続に影響しない。
2. Broadcast 配信中、アプリが Background に遷移しても位置更新が継続する。
3. Always 権限未付与時、Broadcast UI が配信不可理由を明示する。
4. Map は When In Use のみで機能し、Always 未許可でも利用可能。
5. 既存履歴配信（`LocationService.historyStream()`）の挙動が維持される。

## 9. テスト計画

1. Unit: Map/Broadcast Provider の設定値検証（プロパティ初期化テスト）。
2. Unit: Map 側 `stop` 実行時に Broadcast 側 `isTracking` が不変であること。
3. Feature: `LocationTrackingFeature` 開始/停止で Broadcast Provider のみ呼ばれること。
4. Feature: Public の `userFocusTapped` が Map Provider のみを参照すること。
5. 手動: バックグラウンド遷移、画面ロック、低電力モードでの配信継続確認。

## 10. Apple 公式ドキュメント根拠

- `CLLocationManager`（複数 manager 作成可、`distanceFilter`/`desiredAccuracy`、delegate/RunLoop 注意）
  - https://developer.apple.com/documentation/corelocation/cllocationmanager
- `requestAlwaysAuthorization()`（WhenInUse との段階的要求、Info.plist キー要件）
  - https://developer.apple.com/documentation/corelocation/cllocationmanager/requestalwaysauthorization%28%29
- `NSLocationAlwaysAndWhenInUseUsageDescription`（背景利用時に必要）
  - https://developer.apple.com/documentation/bundleresources/information-property-list/nslocationalwaysandwheninuseusagedescription
- Energy Efficiency Guide（`allowsBackgroundLocationUpdates`、`pausesLocationUpdatesAutomatically`、`activityType`、`desiredAccuracy` の設計指針）
  - https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/LocationBestPractices.html
- Location and Maps Programming Guide（Background 配信、significant-change、再起動条件、`UIApplicationLaunchOptionsLocationKey`）
  - https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/LocationAwarenessPG/CoreLocation/CoreLocation.html
