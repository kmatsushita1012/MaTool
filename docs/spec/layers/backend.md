# Backend レイヤー仕様

本ドキュメントは Backend レイヤーの正本参照先を集約する。

## 1. 責務

- 外部IF: HTTP/API Gateway 入口と認証解決
- アプリケーション: Usecase の業務ロジックと認可
- データアクセス: Repository 経由で DynamoDB/Cognito 連携

## 2. 依存方向

`Router -> Controller -> Usecase -> Repository -> DataStore`

## 3. 正本ドキュメント

- レイヤー詳細
  - `docs/spec/layers/backend/interface.md`
  - `docs/spec/layers/backend/application.md`
  - `docs/spec/layers/backend/domain.md`
  - `docs/spec/layers/backend/infrastructure.md`
- 全体アーキテクチャ: `docs/spec/architecture-overview.md`
- API契約: `docs/spec/backend-api-contract.md`
- ユースケース: `docs/spec/usecase-catalog.md`（Backend節）
- テーブル設計メモ: `docs/spec/layers/backend/table.md`
- 起動データ設計メモ: `docs/spec/layers/backend/scene.md`
- テスト方針: `docs/spec/test-strategy.md`（Backend節）
