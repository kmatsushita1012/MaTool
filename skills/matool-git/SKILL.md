---
name: matool-git
description: "MaToolリポジトリのGit運用（パッケージ別のブランチ作成: ios/backend/shared、適切な粒度の日本語コミット、push（-uは初回のみ）、PR作成・ラベル/assignee/milestone設定）を統一する。MaToolでブランチ命名・コミット・push・PR作成の手順を求められたときに使う。"
---

# パッケージ別の進め方（必須）

- まず変更対象を **1つ** に決める: `ios` / `backend` / `shared`
  - `ios`: `iOSApp/` 配下中心
  - `backend`: `Backend/` 配下中心
  - `shared`: `Shared/` 配下中心
- コード改変を伴わない変更（例: `docs/` の編集のみ）は `meta` 扱いにする（ブランチprefix/コミットprefixも `meta`）。
- 可能なら **パッケージごとにブランチとPRを分ける**（レビューしやすさ優先）。
  - 例外: `shared` の変更が `ios`/`backend` の最小限の追従を必ず要求する場合は、主となるパッケージを1つ決めて同一PRに含める（本文に理由を書く）。

# ブランチ運用

## 実行ディレクトリ（重要）

- Gitコマンドは **必ずプロジェクトルートで実行** する（このリポジトリでは `/Users/matsushitakazuya/private/MaTool`）。
- `git -C ...` は環境によって失敗するため **使用しない**。

## 作業前チェック

- `git status` が clean か確認する（未コミット・未追跡がある場合は整理してから進める）。
  - `gh pr create` は未コミットがあっても進むが、警告が出て事故りやすいので **基本は clean 推奨**
- ベースは `main` とする（別ブランチ運用が明示されている場合のみ従う）。
- `Package.resolved` は **原則コミットしない**（例: `Shared/Package.resolved`, `Backend/Package.resolved`）。
  - 例外: 新規パッケージ追加など、lock更新のコミットが必要な変更のみ含める。

## ブランチを切る（パッケージ別）

- ブランチprefixは原則 `ios` / `backend` / `shared`
- `codex/*` prefix は **CIが壊れるため禁止**（絶対に使わない）
- コード改変を伴わない変更（例: `docs/` の編集のみ）は `meta/<topic>`

`<topic>` は短い英数字kebab-case（必要ならチケット番号を含める）

例:
- `ios/rename-loading-view`
- `backend/add-district-filter`
- `shared/fix-normalization-route`
- `meta/update-ios-docs`

コマンド例:

```bash
git switch main
git switch -c ios/<topic>
```

# コミット（日本語・適切な粒度）

## 基本方針

- **1コミット = 1つの意味のある変更** にする（レビュー・リバート容易性を優先）。
- 迷ったら「あとで単独で戻したくなるか？」で分ける。

よくある分け方の例:
- `ios`: UI変更 / ロジック変更 / 依存更新 / リネーム・整形 を分ける
- `backend`: API仕様変更 / 実装 / マイグレーション・スキーマ / テスト を分ける
- `shared`: 型・モデル変更 / 正規化・変換ロジック / 依存更新 を分ける

## コミットメッセージ（日本語）

- 形式は原則 `"<package>: <要約>"`（要約は日本語、簡潔に、命令形寄り）

例:
- `ios: Presentation(View)をPartsへ移動`
- `backend: District取得APIにフィルタを追加`
- `shared: Routeモデルの正規化を修正`
- `meta: ドキュメントの記述を更新`

推奨コマンド:

```bash
git add -p
git commit -m "ios: <要約>"
```

# push（`-u` は初回のみ）

```bash
# 初回push（upstream設定）
git push -u origin HEAD

# 2回目以降
git push
```

# PR作成

## 前提（gh）

- GitHub CLI を使うなら、まず `gh auth status` でログイン状態を確認し、未ログインなら `gh auth login`

## 作成前チェック

- 差分が想定どおりか: `git diff main...HEAD`
- 変更対象パッケージが意図どおりか（混在していたら分割を検討）
- `git status` に未追跡ファイルが残っていないか（意図せず含めない）
  - 例: Xcode由来の `MaTool.xcworkspace/xcshareddata/` 等
  - 例: SwiftPM由来の `Shared/Package.resolved`, `Backend/Package.resolved` 等
- テスト/ビルド（可能な範囲で）を実施し、結果をPR本文に書く
- 秘密情報（トークン等）が入っていないことを確認する

## PRの基本ルール（ラベル/assignee/milestone）

- タイトル: コミットメッセージの要約に合わせて日本語で簡潔に
- ラベルは **2系統** を付ける（実際のラベル名を優先する）
  - **アーキテクチャ/対象**: `arc:iOS` / `arc:BE` / `arc:Shared`
  - **種別**: `type:Feature` / `type:Refactor` / `type:Fix`
  - 迷ったらラベル一覧を見る: `gh label list --limit 200`
- `meta` の場合も、変更対象に近い `arc:*` を付ける（例: `docs/iOS/` なら `arc:iOS`）
- Assignee: **自分**（`gh` では `--assignee @me`）
- Milestone: **一番直近のもの**
  - 候補確認: `gh api "repos/<owner>/<repo>/milestones?state=open" --paginate`
  - 直近の解釈: due date があるなら最も近い（未来優先）、無いなら作成が新しいもの

## 本文テンプレ（最低限）

- 目的（なぜ）
- 変更点（なに）
- 動作確認（どう確認したか）
- 影響範囲・リスク（あれば）
- スクリーンショット/ログ（UI変更や挙動変更がある場合）

## PR作成コマンド（例）

```bash
# 例: iOSのリネーム整理（自分にassign、milestone付与）
gh pr create --fill --base main --assignee @me --label "arc:iOS" --label "type:Refactor" --milestone "<milestone>"
```

補足:
- `--label` は複数回指定できる（コロン付きラベルは引用する）
- `--milestone` は **名前** 指定（例: `v3.0.0`）
