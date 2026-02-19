# データ同期・SSOT仕様（構造/フローレベル）

本仕様は、実装言語やライブラリに依存しない形で、データ同期とSSOT（Single Source of Truth）の設計方針を定義する。

## 1. 目的

- 画面表示・編集・同期の整合を保つ。
- オフライン/通信遅延があっても、アプリ内の状態を一貫して扱う。
- オフライン/キャッシュ戦略を別プラットフォームへ移植可能にする。

## 1.1 現状ステータス（As-Is）

- 完全オフライン対応は未完了。
- ただし、データ取得タイミングは概ね整備済み。
- 既知の未完了点:
  - Settingsでの町（District）切り替え時の取得フローは改善余地がある。

## 2. SSOTの定義

- クライアント内SSOT:
  - ローカル永続ストアを表示用の正本とする。
  - UIは原則としてローカル正本を参照する。
- サーバ側正本:
  - 業務的な最終正本はサーバデータ。
  - クライアントは同期を通じてサーバ正本へ収束する。

## 3. 同期対象の単位

- Festival単位同期:
  - Festival本体
  - District一覧
  - Period一覧
  - Location一覧
  - Checkpoint/HazardSection（権限に応じて）
- District単位同期:
  - Performance一覧
  - Route一覧
  - Point一覧
  - currentRoute情報
- 個別編集同期:
  - FestivalPack / DistrictPack / RouteDetailPack など編集単位Pack

## 4. 同期トリガ

- 起動時同期:
  - 既定Festival/Districtに応じて初期データを取得
- コンテキスト切替時同期:
  - Festival選択変更
  - District選択変更（Settings経由の切替は未完了領域あり）
- 編集確定時同期:
  - 作成/更新/削除の成功後にローカル正本を更新
- 定期/イベント同期（必要時）:
  - 位置情報など時間変化が大きいデータ

## 5. 基本フロー

## 5.1 参照系（Read）

1. 同期対象をサーバから取得する  
2. 取得結果をローカル正本へ反映する  
3. UIはローカル正本を再読込する  

## 5.2 更新系（Write）

1. 編集単位（Pack）でサーバへ更新要求  
2. サーバ成功レスポンスを受ける  
3. ローカル正本へ差分反映（必要に応じて置換）  
4. UIをローカル正本から再構築  

## 5.3 削除系（Delete）

1. サーバ削除成功を確認  
2. ローカル正本の対象データを削除  
3. 子要素がある場合は整合ルールに従い連動削除  

## 6. 整合ルール

- 「サーバ成功後にローカル反映」を原則とする。
- 更新反映は編集単位の一貫性を優先する。
  - 例: Route更新時はPointを含む単位で整合を取る。
- 可視性/権限で取得結果が変わる場合、ローカル表示も同じ制約に従う。
- 同期対象外データを不意に破壊しないよう、スコープ単位で反映範囲を限定する。

## 7. 競合・再試行の方針（高レベル）

- 競合時の原則:
  - サーバ応答を最終判断とする。
- 再試行:
  - 一時失敗は再実行可能な設計とする。
  - 冪等性を意識し、同一操作の重複反映を防ぐ。
- ユーザー操作との整合:
  - 反映待ち状態と確定状態を区別できる設計にする。

## 7.1 競合時ルール（現行方針）

- 基本はサーバ優先（Server Wins）。
- クライアントのローカル編集結果は、サーバ成功レスポンスで確定する。
- 取得と更新が競合した場合:
  - 最後に受け取ったサーバ正規レスポンスへ収束する。
- 将来的にオフライン編集を導入する場合:
  - 競合解決ポリシー（Server Wins / Field Merge / Manual Resolve）を明文化して追加する。

## 8. 可観測性

- 同期イベントは以下を追跡可能にする。
  - 開始/成功/失敗
  - 対象スコープ（Festival/District/Route等）
  - 反映件数の概要
- ログ/メトリクスは「どの同期で不整合が起きたか」を辿れる粒度にする。

## 9. 境界と責務

- Domain:
  - エンティティ制約、不変条件
- Application:
  - 同期のオーケストレーション（いつ何を同期するか）
- Data:
  - サーバI/O
  - ローカル反映
  - 差分適用
- UI:
  - ローカル正本の状態表示
  - 編集要求の発行

## 10. 整合性保証（保証レベル）

- 現行で保証すること:
  - サーバ成功後にローカル正本へ反映し、表示を再構築すること
  - 編集単位（Pack単位）の一貫性を保って反映すること
  - 権限/可視性に応じた取得結果を表示に反映すること
- 現行で保証しきれていないこと:
  - 完全オフライン時の編集継続と後同期
  - Settingsでの町切替を含む全経路での同一同期保証

## 11. 非目標（本仕様で扱わない範囲）

- 言語/フレームワーク固有のAPI仕様
- 特定ライブラリの実装手順
- 低レベルのDBスキーマ詳細
- 画面ごとの詳細エラーメッセージ設計

## 12. 関連ドキュメント

- `/Users/matsushitakazuya/private/MaTool/.codex/as-is-architecture.md`
- `/Users/matsushitakazuya/private/MaTool/.codex/domain-model-spec.md`
- `/Users/matsushitakazuya/private/MaTool/.codex/usecase-catalog.md`
- `/Users/matsushitakazuya/private/MaTool/.codex/api-contract-spec.md`

## 13. Android移植時のキャッシュ方針（Room）

- Androidではキャッシュ読み取りの基盤として Room を使用する。
- 役割分担:
  - API: 真実の更新元（Server Source）
  - Room: 画面表示用のローカル正本（Client SSOT）
- 基本ルール:
  - API成功後にRoomへ反映
  - 画面はRoomを購読して表示
  - 同期単位は Festival/District/Route Pack を維持

## 14. ORM使用箇所一覧（As-Is）

実装依存の詳細は省くが、現行でORM相当を利用している箇所は以下。

- スキーマ定義:
  - `iOSApp/Sources/Data/SQLite/SQLiteStore+Setup.swift`
- 共通CRUDラッパ:
  - `iOSApp/Sources/Data/SQLite/SQLiteStore.swift`
- 同期書き込み（DataFetcher）:
  - `iOSApp/Sources/Data/DataFetcher/FestivalDataFetcher.swift`
  - `iOSApp/Sources/Data/DataFetcher/DistrictDataFetcher.swift`
  - `iOSApp/Sources/Data/DataFetcher/RouteDataFetcher.swift`
  - `iOSApp/Sources/Data/DataFetcher/PeriodDataFetcher.swift`
  - `iOSApp/Sources/Data/DataFetcher/LocationDataFetcher.swift`
  - `iOSApp/Sources/Data/DataFetcher/SceneDataFetcher.swift`
- 読み取りクエリ（Entry/Join中心）:
  - `iOSApp/Sources/Domain/Entry/RouteEntry.swift`
  - `iOSApp/Sources/Domain/Entry/PointEntry.swift`
  - `iOSApp/Sources/Domain/Entry/LocationEntry.swift`
  - `iOSApp/Sources/Domain/Extensions/Entity+SQLiteData.swift`
- 画面側の直接参照（主にFetchOne/FetchAll）:
  - `iOSApp/Sources/Application/SceneUsecase.swift`
  - `iOSApp/Sources/Presentation/StoreView/App/Home/Home.swift`
  - `iOSApp/Sources/Presentation/StoreView/App/Settings/Settings.swift`
  - `iOSApp/Sources/Presentation/StoreView/Admin/District/Route/Point/PointEditFeature.swift`
  - ほか `FetchOne/FETCHAll` 使用箇所（Route/Map/Info関連）

## 15. 必要SQL一覧（Room DAO化のための列挙）

以下は As-Is のクエリパターンを SQL へ展開した一覧。  
`Entry` の join 系を含む。

## 15.1 スキーマ（テーブル）

```sql
CREATE TABLE festivals (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  subname TEXT NOT NULL,
  description TEXT,
  prefecture TEXT NOT NULL,
  city TEXT NOT NULL,
  base TEXT NOT NULL,
  image TEXT NOT NULL
);

CREATE TABLE checkpoints (
  id TEXT PRIMARY KEY NOT NULL,
  festivalId TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT
);

CREATE TABLE hazardsections (
  id TEXT PRIMARY KEY NOT NULL,
  title TEXT NOT NULL,
  festivalId TEXT NOT NULL,
  coordinates TEXT NOT NULL
);

CREATE TABLE districts (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  festivalId TEXT NOT NULL,
  "order" INTEGER NOT NULL DEFAULT 0,
  "group" TEXT,
  description TEXT,
  base TEXT,
  area TEXT NOT NULL,
  image TEXT NOT NULL,
  visibility INTEGER NOT NULL DEFAULT 0,
  isEditable INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE performances (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  districtId TEXT NOT NULL,
  performer TEXT NOT NULL,
  description TEXT
);

CREATE TABLE periods (
  id TEXT PRIMARY KEY NOT NULL,
  festivalId TEXT NOT NULL,
  date TEXT NOT NULL,
  title TEXT NOT NULL,
  start TEXT NOT NULL,
  "end" TEXT NOT NULL
);

CREATE TABLE routes (
  id TEXT PRIMARY KEY NOT NULL,
  districtId TEXT NOT NULL,
  periodId TEXT NOT NULL,
  visibility INTEGER NOT NULL DEFAULT 0,
  description TEXT
);

CREATE TABLE points (
  id TEXT PRIMARY KEY NOT NULL,
  routeId TEXT NOT NULL,
  coordinate TEXT NOT NULL,
  time TEXT,
  checkpointId TEXT,
  performanceId TEXT,
  anchor TEXT,
  "index" INTEGER NOT NULL DEFAULT 0,
  isBoundary INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE floatlocations (
  id TEXT PRIMARY KEY NOT NULL,
  districtId TEXT NOT NULL,
  coordinate TEXT NOT NULL,
  timestamp TEXT NOT NULL
);
```

## 15.2 基本参照（FetchOne/FetchAll）

```sql
SELECT * FROM festivals WHERE id = :festivalId LIMIT 1;
SELECT * FROM districts WHERE id = :districtId LIMIT 1;
SELECT * FROM periods WHERE id = :periodId LIMIT 1;
SELECT * FROM routes WHERE id = :routeId LIMIT 1;
SELECT * FROM checkpoints WHERE id = :checkpointId LIMIT 1;
SELECT * FROM performances WHERE id = :performanceId LIMIT 1;

SELECT * FROM districts WHERE festivalId = :festivalId;
SELECT * FROM points WHERE routeId = :routeId ORDER BY "index" ASC;
SELECT * FROM periods WHERE festivalId = :festivalId;
SELECT * FROM periods
WHERE festivalId = :festivalId
  AND date BETWEEN :yearStart AND :yearEnd;
```

## 15.3 Entry系 JOIN クエリ

### RouteSlot（Period LEFT JOIN Route）
```sql
SELECT p.*, r.*
FROM periods p
LEFT JOIN routes r
  ON p.id = r.periodId
 AND r.districtId = :districtId
WHERE p.festivalId = :festivalId
  AND p.date BETWEEN :yearStart AND :yearEnd;
```

### RouteEntry（Period INNER JOIN Route）
```sql
SELECT p.*, r.*
FROM periods p
JOIN routes r
  ON p.id = r.periodId
 AND r.districtId = :districtId
WHERE p.festivalId = :festivalId
  AND p.date BETWEEN :yearStart AND :yearEnd;
```

### PointEntry（Point + Checkpoint + Performance）
```sql
SELECT pt.*, c.*, pf.*
FROM points pt
LEFT JOIN checkpoints c ON pt.checkpointId = c.id
LEFT JOIN performances pf ON pt.performanceId = pf.id
WHERE pt.routeId = :routeId
ORDER BY pt."index" ASC;
```

### FloatEntry（District + FloatLocation）
```sql
SELECT fl.*, d.*
FROM districts d
JOIN floatlocations fl ON d.id = fl.districtId
WHERE d.festivalId = :festivalId;
```

### FloatEntry単体（districtId指定）
```sql
SELECT fl.*, d.*
FROM floatlocations fl
JOIN districts d ON fl.districtId = d.id
WHERE fl.districtId = :districtId
LIMIT 1;
```

### Point編集補助（Point -> Route -> District）
```sql
SELECT d.*
FROM points pt
JOIN routes r ON pt.routeId = r.id
JOIN districts d ON r.districtId = d.id
WHERE pt.id = :pointId
LIMIT 1;
```

## 15.4 同期時の更新系SQL（代表）

```sql
-- Festival単位の全置換（launch）
DELETE FROM festivals;
DELETE FROM checkpoints;
DELETE FROM hazardsections;
DELETE FROM periods;
DELETE FROM districts;
DELETE FROM floatlocations;
-- その後に各INSERT（UPSERT）を実行

-- District単位の全置換（launch）
DELETE FROM performances;
DELETE FROM routes;
DELETE FROM points;
-- その後に各INSERT（UPSERT）を実行

-- FestivalPack差分反映
DELETE FROM festivals WHERE id = :festivalId;
DELETE FROM checkpoints WHERE id IN (:deletedCheckpointIds);
DELETE FROM hazardsections WHERE id IN (:deletedHazardSectionIds);
-- その後にINSERT/UPSERT

-- DistrictPack差分反映
DELETE FROM districts WHERE id = :districtId;
DELETE FROM performances WHERE id IN (:deletedPerformanceIds);
-- その後にINSERT/UPSERT

-- RouteDetailPack差分反映
DELETE FROM routes WHERE id = :routeId;
DELETE FROM points WHERE id IN (:deletedPointIds);
-- その後にINSERT/UPSERT

-- Period差分反映
DELETE FROM periods WHERE id IN (:deletedPeriodIds);
DELETE FROM routes WHERE periodId IN (:deletedPeriodIds);
-- その後にINSERT/UPSERT

-- Location更新
DELETE FROM floatlocations WHERE districtId = :districtId;
-- その後にINSERT/UPSERT
```

## 15.5 推奨インデックス（Room移植時）

```sql
CREATE INDEX idx_checkpoints_festivalId ON checkpoints(festivalId);
CREATE INDEX idx_hazardsections_festivalId ON hazardsections(festivalId);
CREATE INDEX idx_districts_festivalId ON districts(festivalId);
CREATE INDEX idx_performances_districtId ON performances(districtId);
CREATE INDEX idx_periods_festivalId_date ON periods(festivalId, date);
CREATE INDEX idx_routes_districtId_periodId ON routes(districtId, periodId);
CREATE INDEX idx_points_routeId_index ON points(routeId, "index");
CREATE INDEX idx_floatlocations_districtId ON floatlocations(districtId);
```
