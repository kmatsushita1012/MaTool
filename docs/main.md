# MaTool ドキュメントガイド

ドキュメントを「全体仕様」と「個別開発設計（開発ブランチ相当）」に分離して管理する。

## 1. 全体仕様（Spec）

全体仕様は実装の正本として扱う。特にレイヤー仕様は以下の3ファイルを起点に参照する。

- レイヤー別仕様
  - `docs/spec/layers/backend.md`
  - `docs/spec/layers/shared.md`
  - `docs/spec/layers/iosapp.md`
- 共通仕様
  - `docs/spec/architecture-overview.md`
  - `docs/spec/usecase-catalog.md`
  - `docs/spec/data-sync-and-ssot.md`
  - `docs/spec/test-strategy.md`
  - `docs/spec/layers/shared/extensions.md`

## 2. 個別開発設計（Design）

個別開発設計は、機能改修・移行・リファクタのための作業設計を置く。

- iOS開発設計
  - `docs/design/ios/presentation-naming-migration.md`
  - `docs/design/ios/result-to-taskresult-migration.md`
- 調査・分析メモ
  - `docs/design/research/repository-architecture-analysis.md`
  - `docs/design/research/datafetcher-protocols.md`

## 3. 運用ルール

- 実装の現行仕様を更新する場合は `docs/spec/` を更新する。
- 特定タスク向けの計画・候補・移行手順は `docs/design/` に作成する。
- 設計完了後に恒久化すべき内容は `docs/design/` から `docs/spec/` に反映する。
