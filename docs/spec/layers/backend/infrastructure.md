# Backend Infrastructure Layer Spec

## 1. 対象

- `Backend/Sources/Data/Repository`
- `Backend/Sources/Data/Database`
- `Backend/Sources/Data/Auth`
- `Backend/Sources/Core` の実行基盤部

## 2. 責務

- DynamoDB/Cognito 連携
- 永続化/取得の実装
- 外部依存のエラーハンドリング

## 3. 非責務

- 業務フローの意思決定
- API contract の仕様定義

## 4. 依存ルール

- Infrastructure は Application から呼ばれる実装層。
- 上位層へは protocol 契約を通じて機能を提供する。

## 5. データ整合

- Repository は集約単位で読み書き整合を保つ。
- 削除時は関連データの連動を保証する。

## 6. 参照

- `docs/spec/layers/backend/table.md`
- `docs/spec/test-strategy.md`
