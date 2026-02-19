---
name: matool-git
description: "MaToolリポジトリのGit運用（パッケージ別のブランチ作成: ios/backend/shared、適切な粒度の日本語コミット、git push -u、PR作成）を統一する。MaToolでブランチ命名・コミット・push・PR作成の手順を求められたときに使う。"
---

# パッケージ別の進め方（必須）

- まず変更対象を **1つ** に決める: `ios` / `backend` / `shared`
  - `ios`: `iOSApp/` 配下中心
  - `backend`: `Backend/` 配下中心
  - `shared`: `Shared/` 配下中心
- 可能なら **パッケージごとにブランチとPRを分ける**（レビューしやすさ優先）。
  - 例外: `shared` の変更が `ios`/`backend` の最小限の追従を必ず要求する場合は、主となるパッケージを1つ決めて同一PRに含める（本文に理由を書く）。

# ブランチ運用

## 作業前チェック

- `git status` が clean か確認する（未コミットがある場合はコミット or stash）。
- ベースは `main` とする（別ブランチ運用が明示されている場合のみ従う）。

## ブランチを切る（パッケージ別）

- ブランチ名は原則 `codex/<package>/<topic>` とする（Codexが作業するブランチ識別のため）。
  - 既存運用として `ios/<topic>` のような形式が求められる場合はそれに従う
- `<package>` は `ios` / `backend` / `shared`
  - `ios`: `iOSApp/` 配下中心
  - `backend`: `Backend/` 配下中心
  - `shared`: `Shared/` 配下中心
- `<topic>` は短い英数字kebab-case（必要ならチケット番号を含める）

例（推奨）:
- `codex/ios/rename-loading-view`
- `codex/backend/add-district-filter`
- `codex/shared/fix-normalization-route`

例（既存運用に合わせる場合）:
- `ios/rename-loading-view`
- `backend/add-district-filter`
- `shared/fix-normalization-route`

コマンド例:

```bash
git switch main
git switch -c codex/ios/<topic>
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

- 形式は原則 `"<package>: <要約>"` とする（要約は日本語、簡潔に、命令形寄り）。

例:
- `ios: ルート編集画面に保存ボタンを追加`
- `backend: District取得APIにフィルタを追加`
- `shared: Routeモデルの正規化を修正`
- `ios: 不要なデバッグログを削除`

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

## 作成前チェック

- 差分が想定どおりか: `git diff main...HEAD`
- 変更対象パッケージが意図どおりか（混在していたら分割を検討）
- テスト/ビルド（可能な範囲で）を実施し、結果をPR本文に書く
- 秘密情報（トークン等）が入っていないことを確認する

## PRの基本ルール

- タイトル: コミットメッセージの要約に合わせて日本語で簡潔に
- ラベル:
  - **パッケージ系**（どれか1つ以上）: `ios` / `backend` / `shared`
  - **種別系**（どれか1つ以上）: `feature` / `refactor` / `fix`
  - 例: iOSのバグ修正なら `ios` + `fix`、sharedの整理なら `shared` + `refactor`
- Assignee: **自分**（作業責任者を明確にする）
- Milestone: **一番直近のもの**（運用上の「直近」に合わせる。迷ったら「Openの中で期日が最も近い」/ 期日が無ければ「最新のもの」）
- 本文に最低限含める:
  - 目的（なぜ）
  - 変更点（なに）
  - 動作確認（どう確認したか）
  - 影響範囲・リスク（あれば）
  - スクリーンショット/ログ（UI変更や挙動変更がある場合）

## PR作成コマンド（環境に応じて）

- GitHub CLI (`gh`) が使える場合:

```bash
# 例: ios + fix の場合（@me は自分）
gh pr create --fill --assignee @me --label "ios,fix" --milestone "<milestone>"
```

- `gh` が使えない/ネットワーク制約がある場合:
  - `git push` 後にGitHubのWeb UIからPRを作成し、上の本文テンプレを埋める
  - ラベル（`ios/backend/shared` + `feature/refactor/fix`）、Assignee（自分）、Milestone（直近）を必ず設定する
