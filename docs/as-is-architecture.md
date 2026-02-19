# MaTool As-Isアーキテクチャ仕様

本ドキュメントは、現行実装（Backend / Shared / iOSApp）の責務境界と依存関係を固定化する

## 1. 対象範囲

- Backend: `Backend/Sources`
- Shared: `Shared/Sources`
- iOSApp: `iOSApp/Sources`
- テスト方針参照: `Backend/Tests`, `Shared/Tests`, `iOSApp/Tests`

## 2. システム構成（As-Is）

```text
iOSApp (SwiftUI + TCA)
  -> HTTP (APIGateway endpoint)
Backend (AWS Lambda + API Gateway)
  -> DynamoDB / Cognito
Shared
  -> Backend / iOSApp 共通のEntity, Pack, Validation
```

## 3. モジュール責務

## 3.1 Shared（共通ドメイン）

- 主責務:
  - 共通Entity（Festival, District, Route, Point, Period等）
  - Pack（集約DTO）
  - Validation（`Point+Validation`）
  - 値オブジェクト（Coordinate, SimpleDate, SimpleTime）
- 補足:
  - Domain中心だがSQLite連携を意識した表現（`@Table`, `SQLiteData`）を含む

## 3.2 Backend（サーバサイド）

- エントリ:
  - `Backend/Sources/Backend.swift`
  - `APIGateway` 実装で Lambda Runtime を起動
- レイヤー:
  - Interface: `Router`, `Controller`
  - Application: `Usecase`
  - Infrastructure: `Data/Repository`, `Data/Database`, `Data/Auth`, `Core`
- リクエスト処理:
  - `AuthMiddleware` が Bearer Token を解釈して `UserRole` を付与
  - `Router` が path/method を `Controller` に接続
  - `Controller` が request/response変換と `Usecase` 呼び出し
  - `Usecase` が業務ロジックと権限判定を実行
  - `Repository` が `DataStore` 経由で DynamoDB を操作

## 3.3 iOSApp（クライアント）

- エントリ:
  - `iOSApp/Sources/MaToolApp.swift`
  - `RootSceneView` で launch state に応じて画面分岐
- レイヤー:
  - UI: `Presentation`（SwiftUI + TCA Feature）
  - Application: `Application`（SceneUsecase, AuthService）
  - Data: `DataFetcher`, `Client`, `SQLite`
  - Domain: `Domain` + `Shared Entity`
- 起動時:
  - DB初期化（SQLite）
  - 認証状態取得
  - Festival/District単位でAPI取得
  - 取得結果をSQLiteへ同期
- 注記:
  - フロントのエラーハンドリングは現在整備途中のため、本書では詳細設計には踏み込まず、構造と責務の記述に留める。

## 4. 依存方向（現行ルール）

## 4.1 Backend

```text
Router -> Controller -> Usecase -> Repository -> DataStore(DynamoDB)
                            \-> AuthManager(Cognito)
```

- `swift-dependencies` により依存を注入
- 上位層は下位層のProtocolへ依存（実体は `DependencyKey.liveValue`）

## 4.2 iOSApp

```text
Presentation -> Application(Usecase/Service) -> DataFetcher -> HTTPClient/AuthProvider
                                         \-> SQLiteStore
```

- `SceneUsecase` が起動シナリオのオーケストレーションを担当
- DataFetcher が API取得 + SQLite同期を担当

## 4.3 Shared

```text
Shared Entity <- Backend
Shared Entity <- iOSApp
```

- バックエンドとクライアントで同一ドメイン型を共有
- API境界の型差分を縮小し、整合を高める構成

## 5. データ設計の要点（As-Is）

- Routeはドメイン上 `districtId × periodId` で決まる運行単位
- PointはRoute配下の最小要素（`index`, `coordinate`, `time`, `anchor`等）
- Visibilityで公開範囲を制御（`admin`, `route`, `all`）
- iOSローカルはSQLiteをSSOTとして扱う設計（取得後に差分同期/再構成）

## 6. 認証・認可（As-Is）

- Backend:
  - `AuthMiddleware` がAuthorizationヘッダを解釈
  - Cognitoから `UserRole` を解決（`headquarter`, `district`, `guest`）
  - Usecaseで権限判定を実施
- iOS:
  - `AuthService` が `AuthProvider`（Amplify）をラップ
  - トークン取得とロール取得をアプリ内利用用に抽象化

## 7. テスト設計（As-Is）

- 基本は単体テスト中心
- `swift-dependencies` でMock差し替え
- Backendは `Controller` テストが特に整備されている
- 正常系/異常系/権限系を分け、call count と引数伝搬を確認

## 8. 技術要素（現行）

- Backend:
  - Swift + AWS Lambda Runtime
  - AWS SDK for Swift（DynamoDB, Cognito）
  - swift-dependencies
- iOS:
  - SwiftUI
  - The Composable Architecture
  - SQLiteData / GRDB
  - Amplify Auth
- Shared:
  - Swift Package
  - `SQLiteData` を用いた共通Entity定義

## 9. As-Isの強み

- ドメインモデル共有によりBackend/iOSの整合性が高い
- Usecase境界とRepository境界が比較的明確
- `swift-dependencies` を軸にテスト容易性が高い
- iOS側でAPIとローカル永続化の責務が分離されている

## 10. As-Isの課題

- SharedがSwift実装に閉じているため、言語実装に対して独立したモデル定義が別途必要
- 一部に旧モデル由来の命名・構成（legacy文脈）が残る
- iOS側は「Applicationが同期オーケストレーションを多く持つ」ため責務肥大化の余地
- ローカルDBスキーマとドメイン制約の対応がコード上に分散

## 11. 活用方針（この文書の使い方）

- まず本書の「依存方向」と「責務境界」を参照し、設計制約として扱う
- 次にShared Entity仕様を言語非依存モデルへ抽象化する
- 最後に以下を1対1で対応づける
  - `Usecase` -> Domain UseCase
  - `DataFetcher/Repository` -> Data Layer
  - `Presentation StoreView` -> Presentation Layer (State + Action + Reducer相当)

## 12. 参照ドキュメント

- `./.codex/repository-architecture-analysis.md`
- `./.codex/shared-entity-documentation.md`
- `./.codex/test-strategy.md`
