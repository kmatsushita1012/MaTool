# RoutePassageのカスタマイズ機能追加

## 要求

### Shared層
通過する町を記録するRoutePassageを以下に示す
```swift
@Table public struct RoutePassage: Entity, Identifiable {
    public let id: String
    public let routeId: Route.ID
    public let districtId: District.ID
    public var order: Int
}
```
これに
- 自由記述欄を追加(例:"XXX神社で奉納")
- districtIdをnil許容にする

自由記述欄の候補を考えること(`title`など)

### Backend
適切なデコード/エンコードを行う
※Shared層の対応で実現可能

### iOS
- PassageOptionsViewの上部に自由入力欄を追加
    - 一文字以上入力されていれば完了ボタンを押下可能に
    - 既存のDistrictの列挙は自由入力欄の下
- PassageItemViewのタイトル表記を
    - districtIdがnonnil -> district.name
    - districtIdがnil -> 自由入力欄を表示

## 実装設計

### 1. データモデル設計(Shared)

`RoutePassage` を以下の方針で拡張する。

- `districtId` を `District.ID?` に変更
- 自由記述欄を `memo: String?` として追加
  - 空文字は保存せず `nil` に正規化する
  - 表示時は `memo` をそのまま使う

想定モデル:

```swift
@Table public struct RoutePassage: Entity, Identifiable {
    public let id: String
    public let routeId: Route.ID
    public let districtId: District.ID?
    public var order: Int
    public var memo: String?
}
```

#### 自由記述欄の命名候補

- `title`
  - 汎用すぎて意図が曖昧になりやすい
- `note`
  - 一般的だが、他Entityの備考と混同しやすい
- `memo` (採用)
  - 短く、UI上の「自由入力メモ」と対応づけしやすい
  - 「district未指定時の表示テキスト」という用途にも自然

### 2. バリデーション/整合ルール

入力確定時に以下を保証する。

- `districtId != nil` の場合
  - `memo` は任意(必要なら共存可)
- `districtId == nil` の場合
  - `memo` は1文字以上必須
- `memo` は `trim` 後に空なら `nil` へ正規化

### 3. Backend設計

Sharedモデル変更を反映し、`RoutePassage` の encode/decode を追従する。

- `districtId` の `null` を許容
- `memo` の `null` / 未指定を許容
- 既存データとの後方互換
  - `memo` 未存在データは `nil` として扱う
  - `districtId` 既存データはそのまま `non-nil` として読める

### 4. iOS設計

#### PassageOptionsView

- 画面上部に自由入力欄を追加
- その下に既存のDistrictリストを配置
- 完了ボタン活性条件
  - District選択済み、または
  - 自由入力欄に `trim` 後1文字以上

#### 入力確定時のデータ生成

- District選択時
  - `districtId = selectedDistrict.id`
  - `memo = normalized(inputText)` (空なら `nil`)
- 自由入力のみ時
  - `districtId = nil`
  - `memo = normalized(inputText)` (1文字以上必須)

#### PassageItemView

タイトル表示ルール:

- `districtId != nil` -> `district.name`
- `districtId == nil` -> `memo` を表示
- `districtId == nil && memo == nil` は不整合としてフォールバック文字列(例: `"(未設定)"`)を表示

## 実装計画

### Phase 1: Shared変更

1. `RoutePassage` に `districtId: District.ID?` と `memo: String?` を追加
2. 関連する初期化・変換処理を修正
3. 既存呼び出し側のコンパイルエラーを解消

### Phase 2: Backend対応

1. `RoutePassage` の decode/encode 追従
2. `districtId = null` と `memo` 未指定/`null` の受け入れ確認
3. 既存JSONとの互換性確認

### Phase 3: iOS UI/ロジック対応

1. `PassageOptionsView` に自由入力欄を追加し、配置を調整
2. 完了ボタン活性条件を要件どおり実装
3. 選択確定時に `districtId` と `memo` をルールに従って組み立て
4. `PassageItemView` のタイトル表示分岐を実装

### Phase 4: テスト

1. モデル変換テスト
   - `districtId` あり/なし
   - `memo` あり/空/未指定
2. UIロジックテスト
   - 完了ボタン活性条件
   - タイトル表示分岐
3. 回帰確認
   - 既存のDistrict選択フローが壊れていないこと

## 受け入れ基準

- `districtId` を `nil` で保存・通信できる
- 自由入力のみでPassageを作成できる
- District選択時は従来どおり district 名が表示される
- District未選択時は自由入力テキストが表示される
- 空入力のみでは完了できない
