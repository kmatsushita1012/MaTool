---
name: matool-ios-release
description: "MaToolでiOSリリース作業を定型化する。`main`から`release-ios`へのPRを`iOS: vX.X.X`形式で作成し、ラベルは`arc:iOS`のみ、対応milestoneを付与する。同時に`main`から次バージョン更新ブランチを作成し、未指定時はpatch bumpを採用して次milestoneも作成・設定する。release tagは`release-ios`が`main`へマージされたタイミングでGitHub Actionsで付与したいときに使う。"
---

# MaTool iOS Release Workflow

## 実行ディレクトリ（必須）

- Gitコマンドは必ず `/Users/matsushitakazuya/private/MaTool` で実行する。
- `git -C ...` は使わない。

## 事前条件

- 作業開始前に `git status` を確認し、working treeをcleanにする。
- ベースブランチは `main` を使う。
- `Package.resolved` は原則コミットしない（新規依存追加時のみ例外）。

## 入力パラメータ

- `release_version`（必須）: `vX.X.X`
- `next_version`（任意）: `vX.X.X`。未指定時は `release_version` からpatch bumpする。
- `next_bump`（任意）: `patch` / `minor` / `major`（既定: `patch`）
- `release_milestone`（任意）: 未指定時は `release_version` と同名を使う。
- `next_milestone`（任意）: 未指定時は `next_version` と同名を使う。

## 手順1: `main -> release-ios` PRを作成する

1. `main` を最新化する。

```bash
git switch main
git pull
```

2. `release-ios` ブランチを `main` から作成（既存なら `main` をfast-forwardできる状態にそろえる）。

```bash
git switch -c release-ios
```

3. iOSのリリース版バージョンへ更新し、コミットする。

```bash
git add -p
git commit -m "ios: ${release_version} リリース準備"
git push -u origin release-ios
```

4. milestoneを決定する。
- `release_milestone` 指定あり: それを使う。
- 未指定: `release_version` と同名を使う。
- milestoneが無ければ作成する。

```bash
gh api "repos/<owner>/<repo>/milestones?state=open" --paginate
gh api "repos/<owner>/<repo>/milestones" -f title="${release_milestone}"
```

5. PRを作成する（ラベルは `arc:iOS` のみ）。

```bash
gh pr create \
  --base main \
  --head release-ios \
  --title "iOS: ${release_version}" \
  --assignee @me \
  --label "arc:iOS" \
  --milestone "${release_milestone}"
```

## 手順2: `main` から次バージョン更新ブランチを作成する

1. `next_version` を決める。
- 指定あり: 指定値を使う。
- 未指定: `release_version` から `next_bump` で計算（既定はpatch）。

2. `main` からブランチを作る（名前は一意で短くする）。

```bash
git switch main
git pull
git switch -c ios/bump-version-${next_version}
```

3. 次バージョンに更新してコミット・pushする。

```bash
git add -p
git commit -m "ios: ${next_version} へバージョン更新"
git push -u origin HEAD
```

4. `next_milestone` を決定する。
- 指定あり: 指定値を使う。
- 未指定: `next_version` と同名を使う。
- milestoneが無ければ作成する。

5. 必要なら次バージョン更新PRを作成する（ラベルは `arc:iOS` のみ）。

```bash
gh pr create \
  --base main \
  --head "$(git branch --show-current)" \
  --title "iOS: ${next_version} バージョン更新" \
  --assignee @me \
  --label "arc:iOS" \
  --milestone "${next_milestone}"
```

## 手順3: release tagはマージ時に自動付与する

- 手動でローカルtagを切らない。
- `release-ios` から `main` へのPRがmergeされたときだけtagを付けるGitHub Actionsを使う。
- PRタイトル `iOS: vX.X.X` からversionを抽出し、`vX.X.X` tagを作成する。

最小構成の例:

```yaml
name: Create iOS Release Tag
on:
  pull_request:
    types: [closed]

jobs:
  tag-on-merge:
    if: >
      github.event.pull_request.merged == true &&
      github.event.pull_request.base.ref == 'main' &&
      github.event.pull_request.head.ref == 'release-ios' &&
      startsWith(github.event.pull_request.title, 'iOS: v')
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Extract version
        id: version
        run: |
          title="${{ github.event.pull_request.title }}"
          ver="${title#iOS: }"
          echo "ver=$ver" >> "$GITHUB_OUTPUT"
      - name: Create tag
        uses: actions/github-script@v7
        with:
          script: |
            const tag = '${{ steps.version.outputs.ver }}';
            const sha = context.payload.pull_request.merge_commit_sha;
            await github.rest.git.createRef({
              owner: context.repo.owner,
              repo: context.repo.repo,
              ref: `refs/tags/${tag}`,
              sha
            });
```

## 出力フォーマット（実行時）

- 最終報告は次の順で出す。
1. 作成したrelease PR URL
2. 作成した次バージョン更新ブランチ名（とPR URLがあれば併記）
3. 作成/使用したmilestone名（release/next）
4. tag運用（workflow化）の設定有無
