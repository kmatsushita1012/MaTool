# Districtアカウント再発行機能 設計書

## 目的

- Districtデータを保持したまま、Cognitoアカウントのみ安全に再発行できるようにする。
- 再発行対象を `name` ではなく `districtId` で特定し、誤操作リスクを下げる。

## 仕様方針（変更後）

- 再発行は District作成APIとは分離する。
- 新API: `POST /districts/:districtId/reissue`
- UI導線:
  - `HeadquarterDistrictDetailView` に「アカウント再発行」ボタンを追加
  - タップで再発行専用画面へ遷移
  - 専用画面はメールアドレス入力欄のみ持つ
- 再発行専用画面は TCA Feature/View で実装する。

## スコープ

- iOS
  - `iOSApp/Sources/Presentation/View/Admin/Region/District/HeadquarterDistrictDetailFeature.swift`
  - `iOSApp/Sources/Presentation/View/Admin/Region/District/HeadquarterDistrictDetailView.swift`
  - `iOSApp/Sources/Presentation/View/Admin/Region/District/DistrictReissueFeature.swift`（新規）
  - `iOSApp/Sources/Presentation/View/Admin/Region/District/DistrictReissueView.swift`（新規）
  - `iOSApp/Sources/Data/DataFetcher/DistrictDataFetcher.swift`
- Backend
  - `Backend/Sources/Router/DistrictRouter.swift`
  - `Backend/Sources/Controller/DistrictController.swift`
  - `Backend/Sources/Usecase/DistrictUsecase.swift`
  - `Backend/Sources/Data/Auth/AuthManager.swift`
  - `Backend/Sources/Data/Auth/CognitoAuthManager.swift`
- Shared
  - `Shared/Sources/Pack/Pack.swift` (`DistrictReissueForm` 追加)

## API設計

### 既存（維持）

- `POST /festivals/:festivalId/districts`
  - 用途: 新規District作成
  - Body: `DistrictCreateForm { name, email }`

### 新規

- `POST /districts/:districtId/reissue`
  - 用途: 既存Districtのアカウント再発行
  - Body: `DistrictReissueForm { email }`
  - Auth: `headquarter(district.festivalId)` のみ許可
  - Response: `DistrictPack`

## Backend詳細

### Controller

- `DistrictController.postReissue` を追加。
- Path `districtId` と body `email` を受け取り、Usecaseへ委譲。

### Usecase

- `DistrictUsecase.postReissue(user:districtId:email:)` を追加。
- 処理手順:
  1. `districtId` で District 取得（なければ `404`）
  2. user が `headquarter` かつ `district.festivalId` 一致を確認（不一致は `401`）
  3. Cognitoユーザー削除（`username = districtId`）
  4. Cognitoユーザー新規作成（`username = districtId`, `email = body.email`）
  5. Districtデータは更新/新規作成しない
  6. 既存 `District + performances` を `DistrictPack` で返却

### AuthManager

- `delete(username:)` を追加済み。
- `CognitoAuthManager` で `AdminDeleteUser` を利用。

## iOS詳細

### HeadquarterDistrictDetail

- `Destination` に `reissue(DistrictReissueFeature)` を追加。
- 「アカウント再発行」ボタンで専用画面に遷移。

### DistrictReissueFeature / View（新規）

- State
  - `district`
  - `email`
  - `isLoading`
  - `alert`
- View
  - メールアドレス入力欄のみ
  - 右上に「再発行」
  - キャンセルボタン
  - フッターに「再登録が必要」注意文
- 実行
  - `DistrictDataFetcher.reissue(districtId:email:)` を呼ぶ
  - 成功で画面を閉じる

## エラーケース

- `401 unauthorized`
  - HQ権限不一致
- `404 notFound`
  - 指定 `districtId` が存在しない
- `500`
  - Cognito操作失敗など

## 受け入れ条件

1. `HeadquarterDistrictDetailView` から再発行専用画面へ遷移できる。
2. 専用画面には新しいメールアドレス入力欄のみ表示される。
3. 再発行実行で Districtデータ件数は増えない。
4. Cognitoユーザーは `districtId` をキーに削除→再作成される。
5. 既存の District新規作成API は従来どおり動作する。

## テスト計画

- Backend
  - `DistrictControllerTest`: `postReissue` 追加
  - `DistrictUsecaseTest`: `postReissue` 正常/異常（notFound/unauthorized）
  - `DistrictRouterTest`: `/districts/:districtId/reissue` のルーティング
- iOS
  - `HeadquarterDistrictDetailFeature`: `reissueTapped` で destination 遷移
  - `DistrictReissueFeature`: 入力検証、再発行成功/失敗

## 非スコープ

- District名ベースの再発行
- District作成画面での再発行実行
- Districtデータ本体の更新
