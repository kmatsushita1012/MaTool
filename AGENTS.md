# MaTool エージェントルール

## iOS

- View と Presentation Feature は [matool-swiftui-view](.codex/skills/matool-swiftui-view/SKILL.md) に従う。View 以外のレイヤー設計は [$swift-app-architecture](/Users/matsushitakazuya/.homesick/repos/dotfiles/home/.agents/skills/swift-app-architecture/SKILL.md) に従い、クリーンアーキテクチャを目指す。
- Usecase から別の Usecase を呼び出さない。責務やライフサイクルが異なる処理は必要な重複を許容し、共通化は同じ責務を持つ処理に限る。
- `authProvider.initialize()` はアプリの初回起動時にのみ呼び出し、サインアウトや起動データ再取得では呼び出さない。

## Backend

- レイヤードアーキテクチャを使用する。
- 各レイヤーの責務、禁止事項、依存方向を次のとおりにする。

| レイヤー | 責務 | 禁止する処理・依存 | 依存先 |
| --- | --- | --- | --- |
| Router / Infrastructure | ルート登録、ミドルウェア構成、実行環境や API Gateway アダプターの初期化 | 業務判断、永続化、外部 API の呼び出し | Controller、実行基盤 |
| Controller | HTTP の入力 decode、Usecase 呼び出し、HTTP status とレスポンス encode | 業務ルール、Repository / Client の直接呼び出し、AWS SDK の利用 | Usecase、HTTP フレームワーク |
| Usecase | アプリケーション処理の組み立て、認可、入力検証、業務ルールの適用、Repository / Client の調整 | HTTP request / response の操作、DynamoDB の式・属性値・SDK 型の操作 | Shared の型、Repository / Client の protocol |
| Domain（Shared） | Entity / Value Object と、フレームワークに依存しない業務ルール | Backend の層、HTTP、AWS SDK、Database、Repository / Client への依存 | Shared 内の Domain 型 |
| Repository（Data/Repository） | DataStore を通じた検索・保存、Record と Shared の型の変換 | 業務判断や編集可能項目の選別、DynamoDB の式・属性値・SDK 型の組み立て | DataStore、Shared の型 |
| DataStore（Data/Database） | 汎用的な Record の永続化と、共通で必要な DB 処理の SDK への変換 | 業務ポリシー、HTTP の操作、個別 Usecase 専用の API | Database SDK |
| Client（Data/Client・Data/Auth） | 外部サービスとの通信・認証と、その結果のアプリ内型への変換 | アプリケーション全体の業務フロー、Controller / HTTP response の操作 | 外部 SDK / API、Client protocol |

- 依存方向は `Router / Infrastructure → Controller → Usecase → Repository / Client → DataStore / 外部 SDK` とし、Domain（Shared）は各層から利用する。内側の層から外側の層へ依存しない。
- Repository は保存・検索の具体的な SDK 表現を作らず、既存の汎用 DataStore 操作を使う。個別案件の都合だけで DataStore に専用メソッドや専用トランザクション API を追加しない。
- 強い原子性を全ユースケースの標準要件にしない。複数書き込みの all-or-nothing が仕様に明記されている場合だけ transaction を使い、DataStore に Usecase 固有の API や transaction API を増やさず既存の汎用操作を使う。
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
