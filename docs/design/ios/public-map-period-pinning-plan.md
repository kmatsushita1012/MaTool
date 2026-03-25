# PublicMap period固定 + Location復帰時リセット 設計

## 目的

- PublicMap の Route 表示で、町（District）を切り替えても `periodId` を固定し、同一日程のルートを優先表示する。
- `Location -> Route` に遷移した場合は固定をリセットし、現在時刻に最も近い日程（従来挙動）を表示する。

## 要件（今回）

1. `PublicMapFeature` に `currentPeriodId` を保持する。
2. `launchDistrict` API に任意クエリ `periodId=XXX` を追加する。
3. Routeタブ間移動時は `currentPeriodId` を `launchDistrict` に渡す。
4. `Location -> Route` 遷移時は `currentPeriodId` をリセットしてから `launchDistrict` を呼ぶ。

## 現状整理

- `PublicMapFeature` は District 選択時に `sceneDataFetcher.launchDistrict(districtId:)` を呼び、`currentRouteId` のみ受け取る。
- `SceneUsecase.fetchLaunchDistrictPack` は常に「現在に最も近い Period」を選び、`LaunchDistrictPack.currentRouteId` を返す。
- `PublicRouteFeature.State` は `routeId` を初期選択に使うが、`periodId` 自体の永続状態は持っていない。

## 仕様

### 1) PublicMapFeature 状態

- `PublicMapFeature.State` に `var currentPeriodId: Period.ID?` を追加。
- 初期値:
  - `init(festival:district:routeId:)`: `routeId` からローカル `Route` を引いて `periodId` をセット（見つからなければ `nil`）。
  - `init(festival:)`: `nil`。

### 2) タブ遷移時の状態遷移

- Route -> Route（別District）:
  - `currentPeriodId` を維持。
  - `launchDistrict(districtId:, periodId: currentPeriodId)` を呼ぶ。
- Location -> Route:
  - `currentPeriodId = nil` にリセット。
  - `launchDistrict(districtId:, periodId: nil)` を呼ぶ（BEが「現在に最も近い日程」を選定）。
- Route -> Location:
  - 以降の Route 遷移でリセット判定できるよう、明示的に `currentPeriodId = nil` にする。

### 3) launchDistrict API 契約

- Endpoint: `GET /districts/:districtId/launch`
- Query（追加）:
  - `periodId: String`（optional）
- 挙動:
  - `periodId` 指定あり:
    - 対象 District の公開可能 Route のうち `route.periodId == periodId` を優先。
    - 見つからない場合は従来ロジック（現在に最も近い日程）にフォールバック。
  - `periodId` 指定なし:
    - 従来どおり現在に最も近い日程を選定。
- Response:
  - 既存 `LaunchDistrictPack` を維持（`currentRouteId` を返す）。

## 実装設計

### iOSApp

1. `SceneDataFetcherProtocol`
- `launchDistrict(districtId:clearsExistingData:)` を
  `launchDistrict(districtId:periodId:clearsExistingData:)` に拡張。
- 互換のため default extension で `periodId: nil` オーバーロードを残す。

2. `SceneDataFetcher.launchDistrict`
- `client.get(path:..., query: ...)` を使い、`periodId` がある場合のみ `["periodId": periodId]` を付与。
- 受信後は従来どおり DB upsert し `currentRouteId` を返す。

3. `PublicMapFeature`
- `State` に `currentPeriodId` 追加。
- `.contentSelected` で「直前が locations か」を判定して `currentPeriodId` リセットを制御。
- `routeEffect` に `periodId` 引数を追加して `sceneDataFetcher.launchDistrict(districtId:periodId:)` を呼ぶ。
- `.routePrepared` 時に `routeId` から `Route.periodId` を引き、`currentPeriodId` を更新。

### Backend

1. `SceneController.launchDistrict`
- `request.parameter("periodId", as: String.self)` を `try?` で取得（未指定許容）。
- `sceneUsecase.fetchLaunchDistrictPack(..., periodId: periodId)` を呼ぶ。

2. `SceneUsecaseProtocol` / `SceneUsecase`
- `fetchLaunchDistrictPack(districtId:user:now:periodId:)` を追加（`periodId` optional）。
- 既存シグネチャは default extension で `periodId: nil` に委譲して互換維持。
- `periodId` 指定時の current route 決定:
  - 可視性フィルタ後の routes から `periodId` 一致を抽出。
  - 候補があればそれを current に採用。
  - なければ既存の priority(now) 最小を採用。

3. Router
- ルートパスは変更不要（同一 endpoint で query 受け取り）。

## 影響範囲

- iOS
  - `iOSApp/Sources/Presentation/View/Public/Map/Root/PublicMapFeature.swift`
  - `iOSApp/Sources/Data/DataFetcher/SceneDataFetcher.swift`
- Backend
  - `Backend/Sources/Controller/SceneController.swift`
  - `Backend/Sources/Usecase/SceneUsecase.swift`
  - `Backend/Tests/Controller/SceneControllerTest.swift`
  - `Backend/Tests/Usecase/SceneUsecaseTest.swift`

## テスト観点

### iOS

1. Route -> Route で `currentPeriodId` を保持したまま API 呼び出しされる。
2. Location -> Route で `currentPeriodId` が `nil` リセットされる。
3. `routePrepared` 後、`currentRouteId` に対応する `Route.periodId` が `currentPeriodId` に反映される。

### Backend

1. `periodId` 指定ありで該当 Route がある場合、`currentRouteId` がその period の route になる。
2. `periodId` 指定ありで該当 Route がない場合、従来どおり nearest 選定にフォールバックする。
3. `periodId` 未指定時は既存挙動と同一。
4. Controller で query `periodId` が正しく usecase へ伝搬される。

## 受け入れ条件

- PublicMap で A町の Route 表示中に B町へ切替すると、A町で選ばれていた period と同一 period の Route が選ばれる。
- Location タブへ移動後に任意の町 Route へ移ると、period 固定は解除され、現在に最も近い日程が選ばれる。
- 既存の guest/admin の可視性制御と時刻マスク仕様は変わらない。
