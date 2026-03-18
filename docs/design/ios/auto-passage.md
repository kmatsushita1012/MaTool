# iOS 通過エリア自動判定 設計書（ドラフト修正版）

## 1. 目的

- ルート（`Point[]`）と地区ポリゴン（`District.area`）から、通過地区を自動判定する。
- 判定結果は `RoutePassage` で統一して扱う。
- 現行実装（2026-03-18）と矛盾しない導入計画を定義する。

## 2. 現在の実装状況（2026-03-18 時点）

### 2.1 既存仕様

- 通過情報は `RoutePassage` として保持される。
  - `districtId: District.ID?`
  - `memo: String?`
  - `order: Int`
- ルート編集画面では通過情報は手動追加のみ（地区選択または自由入力）。
- 保存時、Backend は `passages.reindexed()` で順序再採番して保存する。
- 通過判定（幾何計算）は未実装。

### 2.2 根拠コード

- iOS 手動入力: `iOSApp/Sources/Presentation/View/Admin/District/Route/RouteEditFeature.swift`
- 通過選択 UI: `iOSApp/Sources/Presentation/View/Admin/District/Route/Passage/PassageOptionsView.swift`
- Shared エンティティ: `Shared/Sources/Entity/Route.swift`
- Backend 保存時再採番: `Backend/Sources/Usecase/RouteUsecase.swift`

## 3. 反映済み方針（今回確定）

- 自動判定ロジックは **iOSApp ではなく Shared に実装**する。
- 通過データは **`RoutePassage` で統一**する。
- 自動判定実行時は **既存の通過入力をクリア**し、
  - 今回の判定ロジックで通過した町を
  - 通過順で
  - `RoutePassage` として再作成する。
- 導入箇所は **`RouteEditFeature` / `RouteEditView`** とする。

## 4. 自動判定仕様

### 4.1 入力

- `routePoints: [Point]`（`index` 順で処理）
- `districts: [District]`（`area.count >= 3` のみ対象）
- `mode: BoundaryMode`（`includeTouch` / `excludeTouch`）
- `routeId: Route.ID`（`RoutePassage` 生成に使用）

### 4.2 出力

- `RoutePassage[]`
- `districtId` は判定された地区ID
- `memo` は `nil`
- `order` は通過順（0始まり）
- 同一地区の重複は除外

### 4.3 判定定義

- ルート各線分について、地区ポリゴンに対して以下のいずれかで通過とみなす。
1. 線分とポリゴン辺が交差
2. 線分中点がポリゴン内部

- `includeTouch`: 境界接触を交差として含める
- `excludeTouch`: 境界接触のみは除外寄り

### 4.4 除外ルール

- `routePoints.count < 2` は空結果
- 同一点連続による退化線分はスキップ
- `area.count < 3` の地区は対象外
- 不正入力は throw せず安全に無視

## 5. アルゴリズム

- 粗判定: 線分 BBox と地区 BBox の交差判定
- 精密判定:
1. 線分とポリゴン辺の交差判定（orientation ベース）
2. 非交差時に中点の point-in-polygon（ray casting）

- 一度通過確定した地区は再判定しない
- 返却順は初回通過順

## 6. 配置・責務

### 6.1 Shared への実装

- 配置先: `Shared/Sources/...`（既存構成に合わせて決定）
- 役割:
  - 幾何判定
  - 通過順の地区ID決定
  - `RoutePassage` 配列生成

### 6.2 iOS 側導入

- `RouteEditFeature`
  - 自動判定実行アクション追加
  - 実行時に `state.passages` を一旦全削除
  - Shared の判定結果で `state.passages` を再構築
- `RouteEditView`
  - 自動判定実行ボタン（または同等導線）を追加

## 7. 既存手動入力の扱い

- 自動判定実行前の `state.passages` は全クリアする。
- `memo` 手入力も含めてクリア対象。
- 判定後は町IDベースの `RoutePassage` のみを通過順で再作成する。

## 8. テスト計画

### 8.1 Shared 単体テスト

- 幾何判定ケース:
1. 単純矩形を横切る
2. 線分が完全に内部
3. 境界接触（mode 差分）
4. BBox 重なりのみで非交差
5. 複数地区通過時の通過順
6. 退化線分スキップ
7. 不正ポリゴンスキップ

### 8.2 iOS Feature テスト

- `RouteEditFeature` で以下を確認:
1. 自動判定実行時に既存 passages がクリアされる
2. 判定結果の順で `RoutePassage` が再生成される
3. 判定結果が空のとき `state.passages == []`

## 9. 実装計画

### Phase 1: Shared 実装

- 通過判定ロジックを Shared に実装
- `RoutePassage` 生成までを Shared の責務として実装
- 単体テスト追加

### Phase 2: RouteEditFeature 導入

- 自動判定アクション追加
- 実行時クリア→再生成フロー実装

### Phase 3: RouteEditView 導入

- 自動判定実行導線を追加
- 操作後の通過一覧表示更新を確認

### Phase 4: 検証

- iOS テスト実行
- 手動確認:
1. 既存 passages ありで自動判定実行
2. passages が置き換わること
3. 保存後も順序が維持されること

## 10. 受け入れ条件

- 自動判定が `RoutePassage` を通過順で生成する
- 自動判定実行時に既存 passages がクリアされる
- `RouteEditFeature` / `RouteEditView` から利用できる
- 保存 API / DB スキーマ変更なしで動作する
- 不正入力や空入力でクラッシュしない

## 11. 非スコープ

- 穴あきポリゴン
- 自己交差ポリゴンの厳密対応
- 球面幾何の高精度計算
- 空間インデックス最適化（R-tree 等）
