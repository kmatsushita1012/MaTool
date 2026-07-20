# iOSApp Presentation Layer Spec

## 1. 対象

- `iOSApp/Sources/Presentation`
- SwiftUI View / TCA Reducer(Feature)

## 2. 責務

- 画面状態の管理（State/Action/Reducer）
- ユーザー入力の受付と Application への委譲
- バケツリレー型の同期/取得処理では DataFetcher 呼び出しの起点になる
- 参照系は `SQLiteData` マクロ（`FetchOne`/`FetchAll`）でローカルSQLキャッシュを直接参照する
- ローディング/エラー/遷移状態の表現

## 3. 非責務

- API/永続化の低レベル実装

## 4. 依存ルール

- 原則: Presentation は Application 層のユースケースへ依存する。
- 例外: バケツリレー型アクセス（画面起点で段階取得する処理）では DataFetcher への直接依存を許容する。
- 直接依存時も、通信・永続化の実装詳細は Data 層に閉じ込める。
- 参照データは Presentation のStateへ過剰に複製せず、SQLキャッシュを正本として都度取得する。

## 5. 参照

- `docs/spec/usecase-catalog.md`
- `docs/spec/test-strategy.md`
