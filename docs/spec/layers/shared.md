# Shared レイヤー仕様

本ドキュメントは Shared レイヤーの正本参照先を集約する。

## 1. 責務

- 共通ドメインモデル（Entity/Value Object）
- API/Usecase で共通利用する Pack
- ドメイン制約の Validation
- 共通利用可能な Extension の集約（Domain/Infrastructure）

## 2. 依存方向

- Backend と iOSApp が Shared を参照する。
- Shared は業務ルールの中心として両レイヤーの整合を担保する。
- Extension は「Sharedに置けるものを優先してSharedへ集約」する。

## 3. 正本ドキュメント

- Extension方針: `docs/spec/layers/shared/extensions.md`
- 全体アーキテクチャ: `docs/spec/architecture-overview.md`
- ドメインモデル: `docs/spec/domain-model.md`
- ユースケース: `docs/spec/usecase-catalog.md`
- テスト方針: `docs/spec/test-strategy.md`（Shared節）
