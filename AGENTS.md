# MaTool エージェントルール

## iOS

- 原則として [$swift-app-architecture](/Users/matsushitakazuya/.homesick/repos/dotfiles/home/.agents/skills/swift-app-architecture/SKILL.md) に従い、クリーンアーキテクチャを目指す。
- ViewModel の代わりに TCA（The Composable Architecture）を使用する。スキルの ViewModel に関する方針より、このルールを優先する。
- AppState を可能な限り状態の唯一の情報源（SSOT）にする。
- iOS の実装後は必ず XcodeBuildMCP を用いて iPhone シミュレータで iOSApp を起動し、動作確認を行う。
- [$sim-use](/Users/matsushitakazuya/.codex/skills/sim-use/SKILL.md) に従って実際に画面操作を行い、実装・変更した画面に到達したことを確認する。起動確認だけで完了としない。
- 対象画面で必要なタップ・入力・スクロールなどを行い、動作と UI を必ず目視で確認する。最終状態のスクリーンショットと UI 情報を取得し、要件と照合する。

## Backend

- レイヤードアーキテクチャを使用する。
- Backend 単独の作業では、原則としてローカルで実行・確認する。
- Backend 単独の作業では、明示的な指示がある場合のみ push する。

## 共通

### テスト

- Swift のテストには必ず Swift Testing（`import Testing`）を使用し、XCTest は使用しない。
- テスト対象のソースファイルとテストファイルを1対1で対応させる。テストファイルはテストターゲット配下に置き、対象ソースのディレクトリ構造をそのまま再現する。

- テスト用モックは `Sources` に置かず `Tests/Utility/` に Spy として実装し、各テストで明示的に依存を差し替える。

### iOSApp と Backend を同時に変更する場合

- 最初に `backend/<topic>` ブランチを push する。
- iOSApp の起動確認では API ベース URL を `dev-XXX` にする。`XXX` は `<topic>` と一致させる。
- この一時的な API URL の変更はコミットしない。
- 誤って push した場合は、PR 作成前にその変更だけを取り消す。

### Package.resolved

- `Package.resolved` の変更は原則としてコミットしない。
- 新しいパッケージ依存を追加し、ロックファイルの更新が必要な場合のみコミットする。
- すべてのパッケージルートに適用する（例: `Shared/Package.resolved`、`Backend/Package.resolved`）。

### Bootstrap

- サンドボックス内では `Backend/Bootstrap` のテストやマイグレーション・データ投入処理を実行しない。
- 通常の開発や CI 修正では、ユーザーから明示的な指示がない限り Bootstrap を対象外とする。

## GitHub とブランチ運用

### ブランチ戦略

- 原則として `main` から作業ブランチを作成する。
- ブランチ名は `ios/<topic>`・`backend/<topic>`・`shared/<topic>` とし、コード変更を伴わない文書・設定の変更は `meta/<topic>` とする。`<topic>` は短い英数字の kebab-case にする。
- `codex/*` は使用しない。
- 原則としてパッケージごとにブランチと PR を分ける。Shared の変更に最小限の追従が必要な場合は同じ PR に含め、本文に理由を書く。

### push・PR

- 初回の push のみ `git push -u origin HEAD` で upstream を設定し、以降は `git push` を使う。
- PR 作成前に `main` との差分とコミット全体を確認し、目的外の変更や秘密情報が含まれていないことを確認する。
- 実装者側として参加している場合、レビュースレッドを決して resolve しない。resolve はレビュワーとして参加している場合に限り許容する。
- PR のタイトルは日本語で簡潔に書く。本文には目的・変更点・実行した検証を記載し、懸念があれば併記する。
- ラベルは対象（`arc:iOS`・`arc:BE`・`arc:Shared`）と種別（`type:Feature`・`type:Refactor`・`type:Fix`）から各1つを付ける。実際に存在するラベル名を優先し、`meta` の変更も最も近い対象を選ぶ。
- Assignee は自分（`@me`）にする。
- Milestone は未完了のうち、期限が最も近い将来のものを選ぶ。将来の期限がなければ、期限が最も近いもの、期限の設定もなければ作成が最も新しいものを選ぶ。
