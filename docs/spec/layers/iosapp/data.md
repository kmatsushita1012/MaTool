# iOSApp Data Layer Spec

## 1. 対象

- `iOSApp/Sources/Data/Temporary/RemovalPhaseDataFetchers.swift`
- `iOSApp/Sources/Data/Client`

## 2. 責務

- API 通信（HTTP/Auth）
- 現在の DataFetcher は no-op で、API取得結果の保存・参照は行わない

## 3. 非責務

- 画面状態の保持
- ビジネス判断（認可や業務ポリシー決定）

## 4. 依存ルール

- API 通信クライアントは Data 層に置く。
- DataFetcher の一時実装は `RemovalPhaseDataFetchers.swift` に集約する。

## 5. 参照

- `docs/spec/data-sync-and-ssot.md`
- `docs/design/research/datafetcher-protocols.md`
