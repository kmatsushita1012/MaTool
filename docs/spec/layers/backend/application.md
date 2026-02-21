# Backend Application Layer Spec

## 1. 対象

- `Backend/Sources/Usecase`

## 2. 責務

- ユースケース単位の業務フロー実行
- 認可判定（`UserRole`）
- 集約単位（Pack）の整合保証

## 3. 非責務

- HTTP入出力変換
- DynamoDB/Cognito の実装詳細

## 4. 入出力契約

- 入力: Entity/Pack + `UserRole`
- 出力: Entity/Pack（または削除系は空）
- 失敗: 認可/存在/競合/内部エラーを上位へ伝播

## 5. 依存ルール

- Repository/Auth の protocol に依存する。
- Router/Controller には依存しない。

## 6. 参照

- `docs/spec/usecase-catalog.md`
- `docs/spec/domain-model.md`
