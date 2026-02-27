# CI キャッシュ戦略計画（GitHub Actions）

## 目的
- CI のキャッシュヒット率を改善する。
- キャッシュ総容量を抑え、GitHub Actions のキャッシュ上限到達を回避する。
- テスト速度を維持しつつ、無駄なキャッシュ保存を減らす。

## 対象ワークフロー
- `.github/workflows/job_test_backend.yml`
- `.github/workflows/job_test_shared.yml`
- `.github/workflows/job_test_iosapp.yml`
- `.github/workflows/job_deploy_iosapp.yml`

## 現状整理（課題）
1. `DerivedData` の key がテスト3ジョブで同一（`${{ runner.os }}-derived-26.0`）
- `Backend/.derivedData` / `Shared/.derivedData` / `iOSApp/.derivedData` で実体が別なのに key が同じ。
- 同一 key に対して保存競合が起き、復元対象の整合性が低い。
- ジョブごとに必要ファイルが異なるため、ヒットしても有効利用されにくい。

2. `DerivedData` はサイズが大きく、変更耐性が低い
- Swift/Xcode のビルド成果物はコード変更で差分が大きく、再利用率が低い。
- 大容量キャッシュを頻繁に作ると、上限枯渇の主因になる。

3. SPM キャッシュ key がロックファイル非連動（テストジョブ）
- `spm-Backend-26.0` など固定 key で依存差分を吸収できない。
- 依存更新時のミスマッチや不整合を招きやすい。

4. 保存条件の最適化がない
- PR 実行でも毎回 save 対象になりやすく、容量を消費する。
- 「restore は全ジョブ、save は限定ジョブ」の分離がない。

## 目標（KPI）
- 2週間以内に、対象ジョブの実効キャッシュヒット率を 60%以上。
- 4週間以内に、キャッシュ総使用量を現状比 40%以上削減。
- `DerivedData` 起因のキャッシュ保存失敗（容量超過/競合）を 0 件化。

## 戦略
### 1. キャッシュ階層を分離する
- 優先して残す: 依存解決系キャッシュ（SPM ダウンロードキャッシュ）。
- 原則削減: フル `DerivedData` キャッシュ。
- 必要時のみ限定: `SourcePackages` など依存寄りディレクトリ（サイズ上限を監視）。

### 2. key 設計を「再利用性」と「正確性」で分ける
- 共通ルール:
  - key は `OS + Xcode + 対象モジュール + lockfile hash` を基本にする。
  - restore-keys は 1 段階だけにし、過剰フォールバックを避ける。
- 例（SPM）:
  - `macos-26-spm-backend-${{ hashFiles('Backend/Package.resolved', 'Shared/Package.resolved') }}`
  - `macos-26-spm-iosapp-${{ hashFiles('iOSApp/Package.resolved', 'Shared/Package.resolved') }}`

### 3. save 条件を絞る
- PR では restore のみ。
- save は以下に限定:
  - `push` to `main`
  - リリース系ブランチ（`release-*`）
- これによりキャッシュ増殖を抑え、寿命の長いキャッシュのみ残す。

### 4. `DerivedData` は段階的に停止
- Phase 1: テストジョブの `DerivedData` キャッシュを無効化。
- Phase 2: 速度影響を計測し、必要なら `SourcePackages` のみ再導入。
- `job_deploy_iosapp.yml` はビルド再現性優先のため、`DerivedData` キャッシュは原則無効化。

### 5. 可観測性を追加する
- 各 cache step の `cache-hit` を job summary に出力。
- 週次でキャッシュ件数/総容量/上位 key を確認する運用を追加。
- 上限近傍（例: 80%）で古い key を削除するメンテナンス手順を定義。

## 実装計画
### Phase 0: 計測導入（半日）
- `actions/cache` step の `id` を統一して付与。
- `cache-hit` を `GITHUB_STEP_SUMMARY` に出力。
- 直近1週間の baseline（ヒット率・総容量）を取得。

### Phase 1: 低リスク最適化（1日）
- テスト3ジョブの `DerivedData` キャッシュを停止。
- SPM key を lockfile hash 連動へ変更。
- save 条件を `main/release` のみに制限。

### Phase 2: 追補最適化（1日）
- 必要時のみ `SourcePackages` キャッシュを導入（フル `DerivedData` は使わない）。
- restore-keys を最小化（prefix 1本）。

### Phase 3: 運用定着（継続）
- 週次レビュー（ヒット率・容量・所要時間）。
- しきい値を超えたら不要 key を削除。
- 3週連続で KPI 達成できれば現行戦略を固定。

## 変更案（ワークフロー別）
1. `job_test_backend.yml`
- `Cache DerivedData` を削除。
- SPM key を `Backend/Package.resolved + Shared/Package.resolved` hash 連動に変更。
- save を `push(main/release)` に限定。

2. `job_test_shared.yml`
- `Cache DerivedData` を削除。
- SPM key を `Shared/Package.resolved` hash 連動に変更。
- save 条件を限定。

3. `job_test_iosapp.yml`
- `Cache DerivedData` を削除。
- SPM key を `iOSApp/Package.resolved + Shared/Package.resolved` hash 連動に変更。
- save 条件を限定。

4. `job_deploy_iosapp.yml`
- `Cache DerivedData` は無効化（または `SourcePackages` 限定へ置換）。
- SPM key は lockfile hash を維持し、不要 restore-prefix を縮小。

## リスクと対策
1. 初期数回のビルド時間増
- 対策: baseline 比較を行い、増加が大きい場合のみ `SourcePackages` を再導入。

2. lockfile 未更新による再利用不整合
- 対策: 依存更新PRで `Package.resolved` 変更を必須確認。

3. キャッシュ削減でネットワーク依存が増える
- 対策: `main` での定期 save を維持し、PR は restore 優先で吸収。

## 受け入れ基準
- テスト3ジョブで `DerivedData` キャッシュが使われていない。
- SPM key が各モジュールの `Package.resolved` hash 連動になっている。
- PR 実行で新規キャッシュが過剰作成されない。
- KPI（ヒット率/容量削減）を 4 週間以内に満たす。

## 運用ルール
- 新規依存追加時のみ `Package.resolved` 更新をコミットする。
- key 命名規約（`{os}-xcode{x.y}-{domain}-{hash}`）を統一する。
- キャッシュ対象を増やす変更は、容量見積もり（概算MB）をPR本文に記載する。
