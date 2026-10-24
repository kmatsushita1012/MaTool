# MaTool エージェントルール

## iOS

- 原則として [$swift-app-architecture](/Users/matsushitakazuya/.homesick/repos/dotfiles/home/.agents/skills/swift-app-architecture/SKILL.md) に従い、クリーンアーキテクチャを目指す。
- ViewModel の代わりに TCA（The Composable Architecture）を使用する。スキルの ViewModel に関する方針より、このルールを優先する。
- AppState を可能な限り状態の唯一の情報源（SSOT）にする。
- iOSApp の変更後は Simulator で起動して動作を確認する。

## Backend

- レイヤードアーキテクチャを使用する。
- Backend 単独の作業では、原則としてローカルで実行・確認する。
- Backend 単独の作業では、明示的な指示がある場合のみ push する。

## 共通

### テスト

- Swift のテストには必ず Swift Testing（`import Testing`）を使用し、XCTest は使用しない。
- テスト対象のソースファイルとテストファイルを1対1で対応させる。テストファイルはテストターゲット配下に置き、対象ソースのディレクトリ構造をそのまま再現する。

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
