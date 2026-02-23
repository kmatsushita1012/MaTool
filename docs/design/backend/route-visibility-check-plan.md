# Route Visibility チェック 実装計画（Backend）

## 目的
- Route/District の `visibility` 挙動を統一し、配信データの公開範囲を要件どおりにする。

## 対象
- `Backend/Sources/Usecase/RouteUsecase.swift`
- `Backend/Sources/Usecase/SceneUsecase.swift`
- `Backend/Sources/Usecase/DistrictUsecase.swift`
- `Backend/Tests/Usecase/RouteUsecaseTest.swift`
- `Backend/Tests/Usecase/SceneUsecaseTest.swift`
- `Backend/Tests/Usecase/DistrictUsecaseTest.swift`

## 要件と現状整理
1. Route追加時にDistrictの`visibility`をデフォルト採用
- 要件: 新規Routeの`visibility`は、作成元Districtの`visibility`を初期値にする。
- 現状: ルート追加時のデフォルト設定は `iOSApp` 側（`RouteEditFeature`）で対応する項目。
- 方針: 本Backend計画の実装対象外（BE変更なし）。必要に応じてiOS側の実装・確認項目として別管理する。

2. `Visibility.admin` は自町(`.district`)と本部(`.headquarter`)のみ公開
- 要件: 既存どおり。
- 現状: `RouteUsecase.isVisible` / `SceneUsecase.isVisible` で実装済み。
- 方針: 既存テストを維持し、回帰防止テストを追加。

3. `Visibility.route` は自町/本部以外へ `time = nil` で配信
- 要件: Route自体は配信するが、時刻情報のみマスク。
- 現状:
- `RouteUsecase` に `removeTimeIfNeeded` はあるが、呼び出し経路に未適用。
- 条件判定が `district.visibility == .route` になっており、`route.visibility` ではない。
- `SceneUsecase.fetchLaunchDistrictPack` でも points は無加工で返却。
- 方針:
- `RouteUsecase.get` で `route.visibility` と閲覧者ロールを使って points の `time` をマスク。
- `SceneUsecase.fetchLaunchDistrictPack` でも `currentRoute.visibility` を基準に同様のマスクを適用。
- 共通ロジック化（ヘルパー関数）して条件の不一致を防ぐ。

4. District.visibility変更時に、その町の最新年度Routeをデフォルト値へ更新
- 要件: Districtの`visibility`更新をトリガーに、当該Districtの最新年度Routeの`visibility`を一括更新。
- 現状: `DistrictUsecase.put(id:item:user:)` / `put(id:district:user:)` とも Route 更新処理なし。
- 方針:
- District更新前後の `visibility` を比較し、変更時のみRoute更新を実行。
- 更新対象は最新年度のRouteのみ（`LatestPeriodRouteResolver` で対象年度を解決）。
- 各Routeの `visibility` を新しいDistrict値に置換して `routeRepository.put` で保存。
- 更新処理は並列実行（TaskGroup）で行う。
- HQ更新経路は現在 `visibility` を変更しない仕様のため、主対象は District権限の `put(id:item:user:)`。
- iOS連携事項: iOSApp の visibility 編集セクションフッターに、本フロー（District変更時にRouteへ反映される）説明を追加する。

## 実装タスク
1. Route追加デフォルト化
- Backend実装なし（iOSApp `RouteEditFeature` 側の対応項目）。

2. route可視性時刻マスク
- `RouteUsecase.get` に時刻マスク適用。
- `SceneUsecase.fetchLaunchDistrictPack` の points に時刻マスク適用。
- `removeTimeIfNeeded` 相当処理を「`route.visibility == .route`」判定へ修正。

3. District更新時のRoute一括更新
- `DistrictUsecase.put(id:item:user:)` に差分検出と一括更新処理を追加。
- 対象は最新年度のRouteのみとし、更新は並列実行する。
- 失敗時はエラーをそのまま返し、中途半端更新を避ける方針を明文化（必要なら将来的にトランザクション検討）。

4. テスト追加
- `RouteUsecaseTest`
- `get`: Route.visibility が `route` かつ閲覧者が対象外のとき、point.time が `nil` になる。
- `SceneUsecaseTest`
- `fetchLaunchDistrictPack`: currentRoute.visibility = `route` で対象外ユーザーに時刻マスクがかかる。
- `DistrictUsecaseTest`
- District.visibility変更時に同Districtの最新年度Routeが更新される。
- District.visibility不変時はRoute更新が走らない。

## 受け入れ基準
- `admin` 可視性: ゲストは非表示、対象districtと本部は表示。
- `route` 可視性: ルート自体は見えるが、対象外ユーザーは point.time が常に `nil`。
- District.visibility変更時: 当該districtの最新年度Routeの`visibility`が新値へ揃う。
- 既存公開(`all`)の挙動に回帰がない。

## 実装順（推奨）
1. 時刻マスク処理（要件3）
2. District更新時の一括反映（要件4）
3. 回帰テスト追加と全体確認

## 注意点
- 既存ワークツリーに未関連変更（`Package.resolved` 等）があるため、本件の差分には含めない。
- `Package.resolved` は新規依存追加がない限りコミット対象外。
