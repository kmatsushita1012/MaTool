# iOSApp Presentation Layer Spec

## 1. 対象

- `iOSApp/Sources/Presentation`
- SwiftUI View / TCA Reducer(Feature)

## 2. 責務

- 画面状態の管理（State/Action/Reducer）
- ユーザー入力の受付と Application への委譲
- AppState を読み取り、画面に必要な参照データを公開する
- 非同期の取得・更新は Application の UseCase に委譲する
- ローディング/エラー/遷移状態の表現

## 3. 非責務

- API/永続化の低レベル実装

## 4. 依存ルール

- Presentation は Application 層の UseCase に依存し、DataFetcher を直接呼び出さない。
- UseCase は DataFetcher のレスポンスを AppState に反映する。
- View は AppState を直接参照せず、Feature の State が公開する値を使用する。

## 5. 参照

- `docs/spec/usecase-catalog.md`
- `docs/spec/test-strategy.md`
