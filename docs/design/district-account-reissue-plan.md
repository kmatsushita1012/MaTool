# Districtアカウント再発行機能 設計書

## 目的

- `DistrictCreateFeature/View` と `POST /festivals/:festivalId/districts` に「アカウント再発行」機能を追加する。
- 事故・引き継ぎ時に、Districtデータ本体は維持したまま Cognito ユーザーのみ再作成できるようにする。

## 背景

- 現在の District 作成 API は「Districtデータ新規作成 + Cognito招待作成」のみを想定している。
- 既存 District に対してログイン不能等の復旧をしたい場合、データを作り直さず Cognito 側だけ再発行したい。

## スコープ

- iOS:
  - `iOSApp/Sources/Presentation/View/Admin/Region/District/DistrictCreateFeature.swift`
  - `iOSApp/Sources/Presentation/View/Admin/Region/District/DistrictCreateView.swift`
  - `iOSApp/Sources/Data/DataFetcher/DistrictDataFetcher.swift`
- Shared:
  - `Shared/Sources/Pack/Pack.swift` (`DistrictCreateForm`)
- Backend:
  - `Backend/Sources/Controller/DistrictController.swift`
  - `Backend/Sources/Usecase/DistrictUsecase.swift`
  - `Backend/Sources/Data/Auth/AuthManager.swift`
  - `Backend/Sources/Data/Auth/CognitoAuthManager.swift`

## 要件

1. Viewに再発行用トグルを追加する。
2. トグルのフッター（caption）で「Districtデータは残るが、アカウント再登録が必要」旨を表示する。
3. トグルON時に「本当に再発行しますか？アカウントの再登録が必要です」の確認アラートを表示する。
4. トグルONで作成実行時は、Districtデータを新規作成せず、既存Districtを維持したまま Cognito ユーザーを削除→新規作成する。
5. トグルOFF時は既存挙動（新規District作成）を維持する。

## 仕様詳細

## UI仕様（DistrictCreateView）

- 追加状態:
  - `isReissue: Bool = false`
  - `@Presents var confirmAlert: AlertFeature.State?`（既存 `alert` と用途分離する場合）
- 入力項目:
  - 既存の `name`, `email` は継続利用。
- 追加セクション:
  - Toggleラベル例: `アカウントを再発行する`
  - Footer文言例: `ONにすると地区データはそのまま保持され、アカウントのみ再登録が必要になります。`
- 保存時挙動:
  - `isReissue == false`: 既存どおり即 `createTapped` 実行。
  - `isReissue == true`: 確認アラートを出し、OK時のみAPI実行。
- 確認アラート文言案:
  - タイトル: `アカウントを再発行しますか？`
  - 本文: `実行すると既存アカウントは無効になり、再登録が必要です。`
  - ボタン: `再発行する` / `キャンセル`

## API契約変更

### エンドポイント

- `POST /festivals/:festivalId/districts`

### Request (`DistrictCreateForm`)

- 追加フィールド:
  - `reissue: Bool`（default `false`）

```json
{
  "name": "第一町",
  "email": "district@example.com",
  "reissue": true
}
```

### Response

- 既存どおり `DistrictPack` を返却。

## Backend仕様（Usecase分岐）

`DistrictUsecase.post(user:headquarterId:newDistrictName:email:reissue:)` に拡張し、以下で分岐する。

1. 共通
- 認可: `headquarter(festivalId)` のみ許可。
- District ID: 既存仕様同様 `makeDistrictId(name, festival)` を使用。

2. `reissue == false`（新規作成）
- 現行ロジック維持。
- District存在時は `409 conflict`。
- Cognito作成後、Districtを新規保存。

3. `reissue == true`（再発行）
- 対象Districtが存在しない場合: `404 notFound`。
- 対象Districtが存在する場合:
  - Cognitoユーザー削除（username = districtId）
  - Cognitoユーザー新規作成（username = districtId, email = request.email）
  - District repository への `post` は行わない（既存データ維持）
  - 既存District + 既存Performance を返す（`DistrictPack`）

## AuthManager拡張

- `AuthManager` に削除APIを追加:
  - `func delete(username: String) async throws`
- `CognitoAuthManager` 実装:
  - AWS Cognito `AdminDeleteUser` を利用。
- エラー方針:
  - ユーザー不存在時を許容するかは要件選択。
  - 本設計では運用復旧優先のため「不存在は無視して再作成継続」を推奨。

## データ整合性方針

- 再発行では District/Performance/Route などのドメインデータを一切変更しない。
- 変更対象は Cognito ユーザーのみ。
- 監査性のため、将来的に `reissue` 実行ログ（festivalId, districtId, operator）を記録する余地を残す。

## エラーケース

- `401 unauthorized`: HQ権限不一致。
- `404 notFound`: `reissue=true` で対象Districtなし。
- `409 conflict`: `reissue=false` で同名District既存。
- `500`: Cognito操作失敗、Repository取得失敗など。

## テスト計画

## Backend

- `Backend/Tests/Usecase/DistrictUsecaseTest.swift`
  - `post reissue=false`: 既存回帰（現行テスト維持）。
  - `post reissue=true && district exists`: delete/create が呼ばれ、repository.post が呼ばれない。
  - `post reissue=true && district not found`: notFound。
  - `post reissue=true && unauthorized`: unauthorized。
- `Backend/Tests/Controller/DistrictControllerTest.swift`
  - `DistrictCreateForm.reissue` のデコードと usecase 引き渡し確認。

## iOS

- `DistrictCreateFeature` reducer test 追加:
  - `isReissue=false` では即API呼び出し。
  - `isReissue=true` では確認アラート表示。
  - 確認OKでAPI呼び出し、キャンセルで未実行。
- `DistrictDataFetcher`:
  - POST body に `reissue` が含まれることを検証。

## 受け入れ条件

1. 再発行トグルとcaptionがDistrict作成画面に表示される。
2. 再発行トグルONで作成時、確認アラートが表示される。
3. 再発行実行時、Districtデータは増えず、既存Districtが維持される。
4. Cognitoユーザーは削除後に同一 username で再作成される。
5. トグルOFFでは従来の新規作成挙動に回帰がない。

## 実装順（推奨）

1. Shared `DistrictCreateForm` に `reissue` 追加。
2. Backend `Controller/Usecase/AuthManager` を拡張。
3. iOS DataFetcher と Feature/View を更新。
4. Backend/iOS テスト追加。
5. API契約書 `docs/spec/backend-api-contract.md` の POST `/festivals/:festivalId/districts` を更新。

## 非スコープ

- District ID 生成ルール変更。
- 既存Districtの名称変更・統合。
- Bootstrap やマイグレーション処理。
