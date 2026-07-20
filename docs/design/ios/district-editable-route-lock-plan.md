# District.isEditable と Route更新禁止 対応計画

## 目的

- 本部画面 `HeadquarterDistrictDetailView` の編集モードで `District.isEditable` を変更できるようにする。
- `District.isEditable == true` の間は、Route の更新系操作（作成・更新・削除）を一切できない状態にする。
- Route 更新禁止時のエラーメッセージに、祭ごとの本部名（`Festival.subname`）を含める。

## 背景と現状

- `District` エンティティには `isEditable` が既に存在する。
  - `Shared/Sources/Entity/District.swift`
- HQ 権限の District 更新（`PUT /districts/:id/core`）では `isEditable` が保存対象になっている。
  - `Backend/Sources/Usecase/DistrictUsecase.swift`
- ただし `HeadquarterDistrictDetailView` では `order` / `group` のみ編集でき、`isEditable` の操作 UI がない。
  - `iOSApp/Sources/Presentation/View/Admin/Region/District/HeadquarterDistrictDetailView.swift`
- Route 更新系 API（post/put/delete）には `isEditable` による禁止ロジックが未実装。
  - `Backend/Sources/Usecase/RouteUsecase.swift`

## 方針

- 仕様の正本は Backend とし、Route 更新禁止は必ず Backend で拒否する。
- iOS 側は UX 向上のため事前ガード（ボタン無効化/アラート）を追加するが、最終的な防御は Backend に置く。

## 実装計画

### 1. HQ詳細画面で `isEditable` を編集可能にする

- 対象: `HeadquarterDistrictDetailView`
- 変更内容:
  - 編集セクションに `Toggle`（例: 「地区編集を許可」または「Route更新ロック」）を追加し、`$store.district.isEditable` にバインドする。
  - 既存の `.disabled(!store.isEditable)` 制御配下で toggle も編集可能にする（編集モード中のみ変更可）。
- 補足:
  - 既存の保存導線 `editTapped -> dataFetcher.update(district:)` はそのまま利用し、追加 API は作らない。

### 2. Route更新禁止を Backend に実装する

- 対象: `Backend/Sources/Usecase/RouteUsecase.swift`
- 変更内容:
  - `post(districtId:pack:user:)` の認可後に対象 District を取得し、`district.isEditable == true` なら更新拒否。
  - `put(id:pack:user:)` では既存 Route から districtId を特定し、対象 District の `isEditable` を見て更新拒否。
  - `delete(id:user:)` でも同様に `isEditable` を見て削除拒否。
- 返却エラー:
  - 既存のエラー種別体系に合わせて `Error.forbidden`（または `Error.conflict`）を統一利用。
  - メッセージは `Festival.subname` を含める（例: `\(festival.subname)編集中のためRoute更新はできません`）。

### 3. iOS側で Route 更新操作を事前抑止する

- 対象: `DistrictDashboardFeature` / `DistrictDashboardView`
- 変更内容:
  - `state.district.isEditable == true` の場合、`onRouteEdit` を開始しない。
  - 代わりに `AlertFeature.error(...)` で「現在はRoute更新不可」を表示する。
  - 必要に応じて `RouteSlotView` の見た目（無効状態）を追加。
- 目的:
  - API で弾かれる前にユーザーへ理由を明示して操作の無駄を減らす。

### 4. テスト追加・更新

- Backend:
  - `Backend/Tests/Usecase/RouteUsecaseTest.swift`
  - 追加ケース:
    - `post`: district.isEditable = true で失敗する
    - `put`: district.isEditable = true で失敗する
    - `delete`: district.isEditable = true で失敗する
- iOS:
  - `DistrictDashboardFeature` の reducer テスト（未整備なら新規）で、`isEditable == true` 時に `.onRouteEdit` が alert 遷移することを確認。

## 影響範囲

- iOS UI:
  - `iOSApp/Sources/Presentation/View/Admin/Region/District/HeadquarterDistrictDetailView.swift`
  - `iOSApp/Sources/Presentation/View/Admin/District/Top/DistrictDashboardFeature.swift`
  - （必要なら）`iOSApp/Sources/Presentation/View/Admin/District/Top/DistrictDashboardView.swift`
- Backend:
  - `Backend/Sources/Usecase/RouteUsecase.swift`
  - `Backend/Tests/Usecase/RouteUsecaseTest.swift`

## 受け入れ条件

- HQ で地区詳細を編集モードにし、`isEditable` を切り替えて保存できる。
- `isEditable == true` の地区では、Route 作成/更新/削除 API がすべて失敗する。
- District 管理画面では Route 編集開始時に禁止メッセージが出る。
- `isEditable == false` に戻すと、従来どおり Route 更新が可能。

## リスクと対策

- リスク: `isEditable` の意味解釈がチーム内で逆転する可能性。
- 対策: 本計画では「`true` のとき Route更新禁止」を仕様として明文化し、エラーメッセージも同じ意味で統一する。

## 実施順

1. Backend の更新禁止ロジックとテストを先に実装
2. HQ 詳細画面に `isEditable` 編集 UI を追加
3. District 側の事前ガード（alert/無効化）を追加
4. iOS テストと手動確認で最終検証
