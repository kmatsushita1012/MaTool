# iOSApp Data Layer Spec

## 1. 対象

- `iOSApp/Sources/Data/DataFetcher`
- `iOSApp/Sources/Data/Client`
- `iOSApp/Sources/Data/SQLite`

## 2. 責務

- API 通信（HTTP/Auth）
- ローカルSSOT（SQLite）への反映
- 同期単位（Festival/District/Route Pack）の整合管理
- `SQLiteData` マクロ経由の参照クエリ基盤（`FetchOne`/`FetchAll`）を提供する

## 3. 非責務

- 画面状態の保持
- ビジネス判断（認可や業務ポリシー決定）

## 4. 依存ルール

- Data は外部I/O実装を担当し、上位へ protocol で提供する。
- 同期の最終整合はサーバ成功レスポンス基準で反映する。
- Presentation/Domain が参照する SQL キャッシュの正本は Data 層が管理する SQLite とする。

## 5. 参照

- `docs/spec/data-sync-and-ssot.md`
- `docs/design/research/datafetcher-protocols.md`
