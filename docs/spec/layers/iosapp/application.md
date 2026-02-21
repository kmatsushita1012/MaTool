# iOSApp Application Layer Spec

## 1. 対象

- `iOSApp/Sources/Application`

## 2. 責務

- 起動・認証・同期シナリオのオーケストレーション
- 画面ユースケースの単位で処理を構成
- Presentation へ返す状態の整形

## 3. 非責務

- View 表示制御
- 通信/DB の低レベル実装

## 4. 依存ルール

- Data 層 protocol に依存して I/O を実行する。
- UI固有型へ過度に依存しない。

## 5. 参照

- `docs/spec/usecase-catalog.md`
- `docs/spec/data-sync-and-ssot.md`
