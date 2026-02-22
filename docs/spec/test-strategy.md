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

### 5.1 命名規則（Backend）

- テスト名は次のいずれかを使用する。
  - `<メソッド名>_正常_条件`
  - `<メソッド名>_異常_条件`
- `条件` は `条件1` のような連番ではなく、`権限不一致` `未登録` `年指定あり` など分岐/エラー内容を具体的に記述する。
- 条件分岐がない場合のみ、`<メソッド名>_正常` を許可する。
- `<メソッド名>` 以外は日本語で記述する。
- 正常系テストでは「結果の整合性」と「モック呼び出し確認（`callCount` / `lastCalled...`）」を同一テスト内で検証する。
- 依存先（Repository/Usecase/Controller）が `throw` した場合に、対象がそのエラーを透過して再送出する異常系を必ず含める。
- `Usecase` / `Controller` / `Router` の各テストファイルに、少なくとも1件の異常系テストを含める。

### 5.2 make() ヘルパー規約

- `withDependencies` を行う `make()` は、モック引数にデフォルト値（原則 `.init()`）を設定する。
- これにより、各テストで必要な依存のみ差し替える。
- テスト本体で「何も設定していない `Mock()`」を生成しない。未設定依存は `make()` のデフォルト引数に委譲する。
- 引数キャプチャは `lastCalledId`, `lastCalledUser` などの命名で統一する。

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

## 10. 移行中ルール（2026-02）

- 目的: まず `Backend` テストターゲットのコンパイルエラーを解消し、実行可能な最小セットへ戻す。
- 旧API（`Program` 系、旧 `Route`/`Location` DTO）を参照するテストは、無理に互換実装を足さず、現行APIに合わせて更新する。
- 更新コストが高くコンパイルを恒常的に阻害する旧テストは、一時的に削除してよい（再作成は別PRで管理）。
- Repository モックは原則 `Backend/Tests/Data/Repository/Mocks/RepositoryMocks.swift` に集約し、テストファイル内への個別実装を増やさない。
- 変更を進める順番:
  1. コンパイルエラーを出している旧テストの整理（削除または現行化）
  2. 共通モックの現行プロトコル追従
  3. Usecase/Controller/Router の順で再テスト実装

### 10.1 進捗メモ（2026-02-22）

- `backend/reduce-test-compile-errors` ブランチで、旧 `Program` 系テストと旧 Router/Controller/Repository テストを整理。
- `Backend/Tests/Data/Repository/Mocks/RepositoryMocks.swift` を現行プロトコルに合わせて再編成。
- `Usecase` テストは `LocationUsecaseTest` / `RouteUsecaseTest` を現行APIで再構築。
- 実行確認: `swift test --filter Usecase` は pass（`Backend/.env` の unhandled resource 表示は継続）。
- 復元開始順:
  1. `RepositoryMock`（集約ファイル）整備
  2. `UsecaseMock` 整備
  3. `ControllerMock` 復元
  4. `DataStoreMock` はジェネリクス影響が大きいため後続で対応
- Usecase復元:
  - `FestivalUsecaseTest` / `DistrictUsecaseTest` / `PeriodUsecaseTest` を最小構成で再追加
  - 既存 `LocationUsecaseTest` / `RouteUsecaseTest` と合わせて `swift test --filter Usecase` がpass
- Entityモック整備:
  - `Backend/Tests/Utility/Entity+Mock.swift` に `static func mock(...)` を追加し、ID/リレーションキーを上書き可能に統一
- Controller復元:
  - `FestivalControllerTest` / `DistrictControllerTest` / `RouteControllerTest` / `LocationControllerTest` / `PeriodControllerTest` / `SceneControllerTest` を再追加
  - `SceneController` テストのため `SceneUsecaseMock` を `Backend/Tests/Usecase/Mock/UsecaseMock.swift` に追加
  - 実行確認: `swift test --filter Controller` がpass
- Router復元:
  - `FestivalRouterTest` / `DistrictRouterTest` / `OtherRouterTest` を再追加
  - `Application.handle` 経由で path 解決と controller 連携（`festivalId` / `districtId` / `periodId` 伝搬）を検証
  - 実行確認: `swift test --filter Router` がpass
- 全体確認:
  - `swift test` が pass（37 tests / 20 suites）

### 10.2 追加進捗（2026-02-22）

- テストケースを増量（95 tests / 21 suites まで拡張）
  - `Usecase`: `Festival/District/Location/Period/Route/Scene` の正常系・権限系・NotFound系を追加
  - `Controller`: 各Controllerの主要メソッド（`get/query/post/put/delete/launch`）の引数伝搬・分岐を追加
  - `Router`: 各Routerで複数エンドポイントの経路検証を追加
- カバレッジ実測（`swift test --enable-code-coverage` + `llvm-cov`）:
  - 集計対象: `Sources/Controller`, `Sources/Usecase`, `Sources/Router`
  - `TOTAL`: Regions 84.26% / Lines 89.68%
  - `Usecase/SceneUsecase.swift`: Regions 71.29%（未網羅分岐が残存）
- 方針:
  - 「100%目標」は維持し、次は `SceneUsecase` と `RouteUsecase` の残分岐を優先して埋める

## 11. Bootstrap 実行ポリシー

- `Backend/Bootstrap` の injector/migrator テストは、sandbox 上では実行しない。
- Bootstrap 実行はデータ書き込みを伴うため、明示的なユーザー指示がある場合のみ対象とする。
