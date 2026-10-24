# iOSApp レイヤー仕様

本ドキュメントは iOSApp レイヤーの正本参照先を集約する。

## 1. 責務

- Presentation: SwiftUI + TCA による画面状態管理
- Application: 起動/認証/同期オーケストレーション
- Data: API 通信クライアント
- 永続化撤去フェーズの DataFetcher は no-op で、ローカル永続化とデータ取得を行わない

## 2. 依存方向

`Presentation -> Application -> Data (HTTP)` を原則とする。
バケツリレー型アクセスでは `Presentation -> DataFetcher -> Data` の直接経路を許容する。

参照データは現在提供されず、画面の該当状態は空配列または `nil` となる。

## 3. 正本ドキュメント

- レイヤー詳細
  - `docs/spec/layers/iosapp/presentation.md`
  - `docs/spec/layers/iosapp/application.md`
  - `docs/spec/layers/iosapp/domain.md`
  - `docs/spec/layers/iosapp/data.md`
- 全体アーキテクチャ: `docs/spec/architecture-overview.md`
- データ同期とSSOT: `docs/spec/data-sync-and-ssot.md`
- ユースケース: `docs/spec/usecase-catalog.md`（iOS節）
- テスト方針: `docs/spec/test-strategy.md`（iOS節）
