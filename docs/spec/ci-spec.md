# CI仕様書

## 1. 目的

本仕様は、MaTool の GitHub Actions ベース CI/CD の構成と、`gh-fix-ci` スキルによる監視・障害一次切り分け手順を定義する。

## 2. 対象範囲

- 対象リポジトリ: `MaTool`
- 対象CI基盤: GitHub Actions
- 対象ワークフロー:
  - `dispatch_pull_request.yml`
  - `dispatch_main.yml`
  - `dispatch_dev_backend.yml`
  - `dispatch_prod_backend.yml`
  - `dispatch_prod_iosapp.yml`
  - `job_test_backend.yml`
  - `job_test_shared.yml`
  - `job_test_iosapp.yml`
  - `job_deploy_backend.yml`
  - `job_deploy_iosapp.yml`
  - `job_clean_backend.yml`

## 3. トリガー仕様

### 3.1 Pull Request CI

- ワークフロー: `.github/workflows/dispatch_pull_request.yml`
- トリガー:
  - `pull_request` (target: `main`)
  - `workflow_dispatch`
- 挙動:
  - `dorny/paths-filter` で変更領域を判定し、以下のテストを条件実行する。
    - Backend変更 or Shared変更: Backendテスト
    - iOSApp変更 or Shared変更: iOSAppテスト
    - Shared変更: Sharedテスト

### 3.2 main ブランチ

- ワークフロー: `.github/workflows/dispatch_main.yml`
- トリガー: `push` to `main`
- 実行:
  - Sharedテスト
  - Backendテスト
  - iOSAppテスト
  - Backendデプロイ
- 備考:
  - `deploy` は現状 `needs` 依存がコメントアウトされており、テスト完了待ちなしで起動しうる。

### 3.3 Backend開発/本番デプロイ

- ワークフロー:
  - `.github/workflows/dispatch_dev_backend.yml` (`push` to `backend/**`)
  - `.github/workflows/dispatch_prod_backend.yml` (`push` to `release-backend`)
- 実行: reusable workflow `job_deploy_backend.yml`

### 3.4 iOS本番デプロイ

- ワークフロー: `.github/workflows/dispatch_prod_iosapp.yml`
- トリガー: `push` to `release-ios`
- 実行: reusable workflow `job_deploy_iosapp.yml`

### 3.5 クリーンアップ

- ワークフロー: `.github/workflows/job_clean_backend.yml`
- トリガー: `pull_request` closed
- 条件: `merged == true` のときのみ実行
- 実行: API Gateway/Lambda alias 連携リソースの削除

## 4. テストワークフロー仕様

### 4.1 共通

- 実行ランナー: `macos-26`
- Xcode: `26.0`
- SPM/DerivedData キャッシュを利用
- テスト結果サマリを `xcresulttool` + `jq` で出力
- 失敗テスト数が 1 以上の場合に `exit 1`

### 4.2 Backend

- ワークフロー: `.github/workflows/job_test_backend.yml`
- 実行対象:
  - Workspace: `MaTool.xcworkspace`
  - Scheme: `BackendTests`
  - TestPlan: `BackendTests`
  - Destination: `platform=macOS`

### 4.3 Shared

- ワークフロー: `.github/workflows/job_test_shared.yml`
- 実行対象:
  - Workspace: `MaTool.xcworkspace`
  - Scheme: `SharedTests`
  - TestPlan: `SharedTests`
  - Destination: `platform=macOS`

### 4.4 iOSApp

- ワークフロー: `.github/workflows/job_test_iosapp.yml`
- 実行対象:
  - Project: `iOSApp/MaTool.xcodeproj`
  - Scheme: `iOSApp`
  - Destination: `platform=iOS Simulator,name=iPhone 17,OS=26.0.1`

## 5. デプロイ仕様

### 5.1 Backendデプロイ

- ワークフロー: `.github/workflows/job_deploy_backend.yml`
- 概要:
  - Docker build により Lambda bootstrap を作成
  - `aws lambda update-function-code` -> `publish-version` -> `update-alias/create-alias`
  - API Gateway v2 integration/route を更新または作成
- ステージ名ルール:
  - `backend/*` -> `dev-<branch-suffix>`
  - `release-backend` -> `prod`
  - `main` -> `dev`

### 5.2 iOSデプロイ

- ワークフロー: `.github/workflows/job_deploy_iosapp.yml`
- 概要:
  - `xcodebuild archive` 実行
  - `ExportOptions.plist` と App Store Connect 秘密鍵を生成
  - IPA Export と App Store Connect へのアップロードを実施

## 6. `gh-fix-ci` 監視運用仕様

### 6.1 目的

- PR 上の失敗チェックを迅速に把握し、GitHub Actions 由来の原因を一次切り分けする。

### 6.2 前提条件

- `gh` 認証済みであること (`gh auth status` が成功)
- 監視対象は GitHub Actions チェックのみ
- 外部CI (例: Buildkite) は対象外とし、`detailsUrl` の共有までを行う

### 6.3 標準手順

1. PR を特定する。
   - 既定: 現在ブランチのPR (`gh pr view --json number,url`)
   - 明示指定: PR番号またはURL
2. 失敗チェックを抽出する。
   - 推奨:
     - `python "<path-to-gh-fix-ci>/scripts/inspect_pr_checks.py" --repo "." --pr "<PR番号またはURL>"`
   - JSON取得時:
     - `python "<path-to-gh-fix-ci>/scripts/inspect_pr_checks.py" --repo "." --pr "<PR番号またはURL>" --json`
3. 失敗ログのスニペットを確認し、以下を記録する。
   - failing check 名
   - run URL
   - 失敗箇所の抜粋
   - ログ欠落時は「ログ未取得」を明記
4. 原因分析と修正方針を提示する。
5. 承認後に修正を実施し、再度 `gh pr checks` で収束確認する。

### 6.4 手動フォールバック

- `gh pr checks <pr> --json name,state,bucket,link,startedAt,completedAt,workflow`
- `gh run view <run_id> --json name,workflowName,conclusion,status,url,event,headBranch,headSha`
- `gh run view <run_id> --log`
- 実行中でログ未確定の場合:
  - `gh api "/repos/<owner>/<repo>/actions/jobs/<job_id>/logs" > <path>`

### 6.5 監視結果フォーマット

- 監視報告は最低限、以下を含むこと。
  - 対象PR (`number`, `url`)
  - 失敗チェック一覧
  - 各チェックの run URL
  - 失敗要約（1-3行）
  - 次アクション（修正案または追加調査案）

## 7. 運用上の注意

- `dispatch_main.yml` の `deploy` はテスト依存が無効化されているため、意図しない先行デプロイのリスクがある。
- `job_clean_backend.yml` の `release-backend` 判定部分に `STAGE_NAME = "prod"` があり、シェル変数代入としては不正であるため修正対象候補。
- CIログ調査時は、まず GitHub Actions 失敗を優先し、外部CIはリンクのみ記録する。

## 8. 変更管理

- CI仕様変更時は、対象ワークフローファイル更新と同時に本仕様書も更新する。
- PR説明には、以下を明記する。
  - 変更したワークフローファイル
  - 影響ブランチ/トリガー
  - 監視手順 (`gh-fix-ci`) への影響
