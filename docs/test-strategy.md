# MaTool テスト戦略

このドキュメントは、現状実装（特に `Backend/Tests/Controller`）をベースにしたプロジェクトのテスト方針を定義する。

## 1. 基本方針

- テストの中心は単体テスト（Unit Test）。
- `swift-dependencies` により依存を差し替え、外部要因を排除して再現性を確保する。
- カバレッジは 100% を目標にする（最低ラインではなく、設計時の目標値）。
- 既存の完成度が高い `Backend/Controller` テストをテンプレートとして横展開する。

## 2. 参照すべき良い実装

- `Backend/Tests/Controller/FestivalControllerTest.swift`
- `Backend/Tests/Controller/DistrictControllerTest.swift`
- `Backend/Tests/Controller/RouteControllerTest.swift`
- `Backend/Tests/Controller/ProgramControllerTest.swift`
- `Backend/Tests/Controller/LocationControllerTest.swift`
- `Backend/Tests/Usecase/Mock/UsecaseMock.swift`
- `Backend/Tests/Data/Repository/Mocks/RepositoryMocks.swift`

上記には次の共通パターンがある。

- 正常系/異常系を対で用意する。
- 入力（Request/body/parameter/user）を明示する。
- 出力（statusCode/body/header）を明示する。
- 依存モックの call count と引数伝搬を検証する。
- `withDependencies { ... } operation: { ... }` で対象を構築する。
  - util関数をextensionに用意して対象を構築する
- struct本体はテストケースのみにしてutil関数を含めない

## 3. レイヤー別テスト方針

## 3.1 Backend

- Controller:
  - 最重要レイヤー。現状方針を継続。
  - 必須観点: パラメータ解釈、body decode、`user == nil` 時の既定値、response encode、例外伝播。
- Usecase:
  - 権限判定・分岐・境界条件を中心に検証。
  - Repository/Auth 依存は全てモック化。
- Repository:
  - クエリ組み立てと入出力の整合に集中。
  - 実DB統合は最小限にし、通常は `DataStoreMock` を利用。
- Router/Core:
  - ルーティング解決とミドルウェア接続を重点検証。

## 3.2 Shared

- Entity / Validation:
  - `Point+Validation` のようなドメインルールを最優先で網羅。
  - 比較ロジック（`Comparable`）や日時判定（`contains`, `before`）の境界値を検証。
- DTO/Pack:
  - Encode/Decode の対称性、欠損/optional の扱いを検証。

## 3.3 iOSApp

- Application:
  - 起動シナリオ（launch/signIn/select）を分岐網羅。
  - Auth/DataFetcher/UserDefaults は依存差し替えで固定化。
- DataFetcher/Client:
  - 通信結果と SQLite 同期の副作用を分離検証。
  - 成功・失敗・空配列・権限エラーの分岐を網羅。
- Presentation:
  - ロジックは Feature 単位でテストし、View スナップショットは必要最小限。

## 4. モック・差し替えルール（swift-dependencies）

- 対象レイヤーは「直近の依存のみ」モック化する（過剰モックを避ける）。
- モックは次を持つ。
  - 呼び出し回数カウンタ
  - 引数キャプチャ
  - 成功/失敗を切り替える handler
- 原則としてテスト本体で注入する。
  - `withDependencies { $0[SomeKey.self] = mock } operation: { ... }`
- `fatalError("Unimplemented")` や `TestError.unimplemented` によって未設定依存の見逃しを防ぐ。

## 5. ケース設計ルール

- 1ユースケースにつき最低 3 パターン:
  - 正常系
  - 異常系（依存がエラー）
  - 境界/権限系（nil, empty, unauthorized, not found）
- 複雑分岐はテーブル駆動にする。
- アサーション順は統一する。
  - 1. 実行結果
  - 2. 出力値（body/header/status）
  - 3. 依存呼び出し（call count / 引数）

## 6. カバレッジ運用

- 目標: 行カバレッジ 100%（Backend / Shared / iOSApp それぞれ）。
- ただし「数値を埋めるだけ」のテストは禁止し、分岐の意味を説明できることを条件とする。
- CI は既存 workflow を利用して `-enableCodeCoverage YES` で継続測定する。
  - `.github/workflows/job_test_backend.yml`
  - `.github/workflows/job_test_shared.yml`
  - `.github/workflows/job_test_iosapp.yml`

## 7. 実装テンプレート（Controller向け）

`Backend/Controller` 流儀を基本テンプレートとする。

1. Arrange:
   - モック作成（handler に期待値/例外を設定）
   - `withDependencies` で subject 作成
   - `makeRequest` で入力構築
2. Act:
   - 対象メソッドを `await` 実行
3. Assert:
   - `statusCode`, `headers`, body decode 結果
   - 呼び出し回数
   - 引数伝搬

## 8. 優先度付き拡張計画

1. Shared の実テスト追加
   - `Point+Validation`, `Period`, `DateTime` から開始
2. iOSApp Application/Data の単体テスト拡充
   - `SceneUsecase`, `RouteDataFetcher` を優先
3. 既存 Backend テストの命名とヘルパーを統一
4. カバレッジレポートの閾値チェックを CI に追加

## 9. Auth系テストケース一覧

単なるログイン可否だけでなく、認証ライフサイクル全体を対象にする。

## 9.1 iOS AuthService / AuthProvider

- 初期化:
  - `initialize` 成功
  - `initialize` 失敗（設定不備）
- サインイン:
  - 正常ログイン（role取得まで成功）
  - `newPasswordRequired` 分岐
  - 認証失敗（ID/PW不正）
  - タイムアウト
- サインイン確定:
  - `confirmSignIn` 成功
  - `confirmSignIn` 失敗時に signOut されること
- ロール/トークン:
  - `getUserRole` 成功（headquarter/district/guest）
  - `getUserRole` 失敗時に guest へフォールバック
  - `getAccessToken`（ログイン済/guest）
  - トークン取得失敗時の `nil` 返却
- サインアウト:
  - 正常
  - 失敗
  - 実行後に内部 role が `guest` へ戻ること
- パスワード変更:
  - `changePassword` 成功
  - 現在PW不一致/ポリシー違反/タイムアウト
- パスワードリセット:
  - `resetPassword` 成功
  - 対象ユーザー不在
  - タイムアウト
  - `confirmResetPassword` 成功
  - 確認コード不正/期限切れ
- メール更新:
  - `updateEmail` 完了（done）
  - `updateEmail` 確認コード要求（verificationRequired）
  - `confirmUpdateEmail` 成功
  - `confirmUpdateEmail` コード不正

## 9.2 iOS SceneUsecase（認証連動）

- `launch`:
  - defaultFestival なし -> onboarding
  - defaultFestival あり + district なし -> festival
  - defaultFestival あり + district あり -> district
  - auth取得失敗時 -> guest分岐
- `signIn`:
  - headquarter成功時の同期とUserDefaults更新
  - district成功時の同期とUserDefaults更新
  - 失敗時に状態を壊さないこと
- `confirmSignIn`:
  - signIn後と同じ整合状態になること

## 9.3 Backend Auth（Middleware / Usecase権限）

- `AuthMiddleware`:
  - Authorizationなし -> `guest`
  - Bearerあり有効 -> `headquarter/district`
  - Bearerあり無効 -> エラー応答
- 権限制御:
  - festival更新は `headquarter(festivalId)` のみ許可
  - district更新は `district(districtId)` のみ許可
  - route更新/削除は所有districtのみ許可
  - period更新/削除は対象festival headquarterのみ許可
  - location更新/削除は対象district本人のみ許可

## 9.4 AuthManager / Cognito連携（Backend）

- `create(username,email)`:
  - 正常
  - 既存ユーザー衝突
  - 属性不足
- `get(accessToken)`:
  - 正常（role解釈）
  - token不正/期限切れ
  - role属性不正（unknown role）
- `get(username)`:
  - 正常
  - user not found
