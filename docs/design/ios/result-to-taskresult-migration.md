# iOSApp Result -> TaskResult 移行設計

## 1. 背景
- 現状の iOSApp は `Result<Success, APIError/AuthError>` が広範囲に存在し、`async throws` と `Result` が混在している。
- 特に Presentation 層では Action が `Result` を直接持つため、Effect 内の `do/catch` と Reducer 側の `switch result` でエラーハンドリングが二重化しやすい。
- 目標は「非 Presentation 層は `try/catch` を標準化」「Presentation 層は TCA の `TaskResult` で Effect 結果を受ける」に統一すること。

## 2. 目的
- `Result<Success, Error>` の濫用を解消し、`async throws` ベースの API に寄せる。
- Presentation 層の Action を `TaskResult<Success>` に統一する。
- `VoidResult<APIError>` を `VoidTaskResult` に置き換える。
- エラー変換の責務を明確化し、Reducer の実装パターンを統一する。

## 3. 適用範囲
- 対象: `iOSApp/Sources`（Presentation / Application / Data / Utils）
- 非対象: `Backend`, `Shared`（本移行では変更しない）

## 4. レイヤ別設計方針

| レイヤ | 新ルール | 補足 |
|---|---|---|
| Data / Application | `async throws` を基本にする | `Result` を返さず `throw` で失敗を表現 |
| Presentation (TCA Reducer) | `Effect.task` で `TaskResult` 化して Action 送信 | Action は `TaskResult<T>` / `VoidTaskResult` |
| Presentation (Reducer本体) | `TaskResult` を `success/failure` で分岐 | `failure` で必要に応じて `APIError/AuthError` へ変換 |

## 5. 変更仕様

## 5.1 Action 型
- 変更前: `case received(Result<Hoge, APIError>)`
- 変更後: `case received(TaskResult<Hoge>)`

- 変更前: `case saved(VoidResult<APIError>)`
- 変更後: `case saved(VoidTaskResult)`

## 5.2 Effect 実装パターン
推奨は `.task(Action.xxx)` で `TaskResult` を直接 Action へマップする形。
- `.task { send in ... }` / `.task { _ in ... }` のような別シグネチャは追加しない。

```swift
return .task(Action.received) {
    try await usecase.execute(...)
}
```

Void の場合（`.task` 推奨）:
```swift
return .task(Action.saved) {
    try await usecase.save(...)
}
```

## 5.3 Reducer の失敗処理
`TaskResult` の `failure` は `Error` になるため、Reducer で必要なドメインエラーへ寄せる。

- `errorCaught(APIError)` のようなエラー専用 Action は作らない。
- `received(TaskResult<...>)` の `.failure(error)` で処理を完結させる。

```swift
case .received(.failure(let error)):
    if let apiError = error as? APIError {
        state.alert = .error(apiError.localizedDescription)
    } else {
        state.alert = .error(error.localizedDescription)
    }
    return .none
```

## 5.4 Utility 方針
- `iOSApp/Sources/Utils/ComposableArchitecture+TaskResult.swift` の `VoidTaskResult` は継続利用。
- `iOSApp/Sources/Utils/Async.swift` の `task(...) -> Result` は段階的に廃止対象。
- 将来的には `TaskResult` 変換ヘルパーに一本化する（`Result` を返すヘルパーは削除）。

## 5.5 Phase 2 互換方針
- Protocol 本体は `async throws` を正とする。
- Presentation で `Result` 呼び出しが必要な箇所は、Protocol extension に `Result` ラッパーを切り出す。
- `Result` ラッパーは `@available(*, deprecated, ...)` を付与する。
- `catch` で期待型へ cast できない場合は `.unknown(...)` を返す。

## 6. 現状調査結果（2026-02-15）

TaskResult 適用済み（確認済み）:
- `iOSApp/Sources/Presentation/StoreView/Admin/District/Route/RouteEditFeature.swift`
- `iOSApp/Sources/Presentation/StoreView/Public/Map/Route/PublicRoute.swift`
- `iOSApp/Sources/Presentation/StoreView/App/Onboarding/Onboarding.swift`
- `iOSApp/Sources/Presentation/StoreView/App/Home/Home.swift`
- `iOSApp/Sources/Presentation/StoreView/App/Settings/Settings.swift`
- `iOSApp/Sources/Presentation/StoreView/Auth/CorfirmSignIn/ConfirmSignIn.swift`
- `iOSApp/Sources/Presentation/StoreView/Auth/ChangePassword/ChangePassword.swift`
- `iOSApp/Sources/Presentation/StoreView/Auth/ResetPassword/ResetPassword.swift`
- `iOSApp/Sources/Presentation/StoreView/Auth/UpdateEmail/UpdateEmail.swift`
- `iOSApp/Sources/Presentation/StoreView/Admin/District/Top/AdminDistrictTop.swift`
- `iOSApp/Sources/Presentation/StoreView/Admin/District/Edit/AdminDistrictEdit.swift`
- `iOSApp/Sources/Presentation/StoreView/Admin/Region/Top/FestivalDashboardFeature.swift`
- `iOSApp/Sources/Presentation/StoreView/Admin/Region/Period/PeriodEditFeature.swift`
- `iOSApp/Sources/Presentation/StoreView/Admin/Region/Edit/FestivalEditFeature.swift`

Phase 1 実施結果（2026-02-15）:
- Presentation 層の Action から `Result<..., APIError/AuthError>` と `VoidResult<APIError>` は排除済み。
- 非同期 Effect は `.task(Action.xxx)` の形へ統一。

Data / Application 層の現状:
- Protocol 本体は `async throws` ベースへ移行済み。
- `Result` は deprecated extension ラッパーに限定（移行互換用途）。
- `iOSApp/Sources/Utils/Async.swift` の `task(...) -> Result` は次 Phase で削除対象。

Phase 2 実施結果（2026-02-15）:
- `HTTPClientProtocol` を `async throws` へ変更。
- `AuthServiceProtocol` の `Result` 戻り値 API を `async throws` へ変更。
- `SceneUsecaseProtocol.confirmSignIn` を `async throws -> UserRole` へ変更。
- 互換用途の `Result` ラッパーを extension に分離し、`@available(*, deprecated, ...)` を付与。

## 7. 段階的移行手順

## Phase 1: Presentation Action 置換（優先）
- 各 Feature の Action を `TaskResult` / `VoidTaskResult` に置換。
- `.task(Action.xxx)` に統一。
- Reducer 側は `TaskResult` の `success/failure` を処理。

完了条件:
- Presentation 層の Action から `Result<..., APIError/AuthError>` と `VoidResult<APIError>` が消える。

## Phase 2: Application/Data を `async throws` 化
- プロトコル戻り値の `Result` を `throws` へ変更。
- 実装内で `return .failure(...)` している箇所を `throw` に変更。
- 呼び出し元 Reducer では `TaskResult` 化して受ける。
- 旧 `Result` 呼び出しは deprecated extension ラッパーに隔離する。

完了条件:
- Application/Data の public API から `Result` 戻り値を撤廃（必要な enum 結果型を除く）。

## Phase 3: ユーティリティ/命名整理
- `VoidResult` 型エイリアスと `Result` 依存 extension の削除。
- `task(...) -> Result` の削除。
- エラー変換ヘルパー（`Error -> APIError/AuthError`）を最小セットに整理。

完了条件:
- `Result` は Swift 標準の局所利用（内部処理）以外で使用しない。

## 8. 移行時の互換ポリシー
- 1 PR で全面変更せず、Feature 単位で段階移行する。
- 一時的に `TaskResult` と旧 `Result` が共存してもよいが、Feature 内ではどちらかに統一する。
- 既存 UI 挙動（アラート文言、ローディング制御、遷移条件）は変更しない。

## 9. テスト観点
- 成功系:
  - Effect 実行後に `TaskResult.success` で state 更新されること。
- 失敗系:
  - `APIError/AuthError` が正しくアラート/状態に反映されること。
  - 非期待エラーが `unknown` 扱い等でフォールバックされること。
- 回帰:
  - ローディング開始/終了のタイミング
  - 画面遷移・モーダル表示条件
  - 既存 Snapshot / ユニットテストの通過

## 10. 既知リスク
- `TaskResult.failure` が `Error` のため、型情報を失いやすい。
- `AuthError` と `APIError` が混在する Feature では失敗処理を明示的に分岐する必要がある。
- `Result` 廃止を急ぐと、既存テストのスタブ戻り値定義を広範囲に修正する必要がある。

## 11. 決定事項
- Presentation 層の非同期結果 Action は `TaskResult` を標準とする。
- Void 成功は `VoidTaskResult` を標準とする。
- Data / Application は `try/catch` 前提の `async throws` を標準とする。
