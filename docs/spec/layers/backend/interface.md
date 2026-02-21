# Backend Interface Layer Spec

## 1. 対象

- `Backend/Sources/Router`
- `Backend/Sources/Controller`
- `Backend/Sources/Core` の Request/Response 入口部

## 2. 責務

- HTTP path/method と Controller の結線
- Request の decode、Response の encode
- 認証コンテキスト（`UserRole`）の受け渡し

## 3. 非責務

- 業務ルール判断
- 永続化処理

## 4. 入出力契約

- 入力: API Gateway/Lambda event
- 出力: HTTP status + JSON body
- 例外: `ErrorResponse` へ正規化して返却

## 5. 依存ルール

- Interface からは Application (`Usecase`) へ依存する。
- DataStore/Repository へ直接依存しない。

## 6. 参照

- `docs/spec/backend-api-contract.md`
- `docs/spec/usecase-catalog.md`
