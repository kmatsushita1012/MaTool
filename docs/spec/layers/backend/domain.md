# Backend Domain Layer Spec

## 1. 対象

- `Shared/Sources/Entity`
- `Shared/Sources/Validation`
- Backend Usecase 内のドメイン制約適用ロジック

## 2. 責務

- エンティティ不変条件の維持
- `Visibility` や期間判定などのドメイン制約適用
- Pack と Entity の整合担保

## 3. 非責務

- HTTP仕様
- DynamoDBアクセス実装

## 4. 依存ルール

- Domain は特定の通信/DB実装に依存しない。
- Backend 側の実装では Shared モデルを正本として扱う。

## 5. 参照

- `docs/spec/domain-model.md`
- `docs/spec/data-sync-and-ssot.md`
