# MaTool 開発ガイド

MaTool は祭典・町・屋台の現在位置と行動経路を扱う iOS アプリと、その API を管理するリポジトリです。
開発時のルールは [AGENTS.md](../AGENTS.md) を参照してください。

## 構成

| 場所 | 役割 |
| --- | --- |
| `iOSApp/` | SwiftUI・TCA による iOS アプリ |
| `Backend/` | AWS Lambda / API Gateway 用の Swift API |
| `Shared/` | 両者で共有するモデル・通信データ型・検証ロジック |
| `MaTool.xcworkspace` | アプリと Swift パッケージをまとめたワークスペース |
| `.github/workflows/` | テスト・デプロイの定義 |
| `ci_scripts/` | Xcode Cloud 用の設定生成処理 |

`Shared/Package.swift` と `Backend/Package.swift` の Swift tools version は 6.2 です。
iOS アプリの deployment target は iOS 17.0、Backend パッケージの対象は macOS 15 以降です。
依存関係と対応 OS の正確な設定は、各 `Package.swift` と `iOSApp/MaTool.xcodeproj/project.pbxproj` を参照してください。

## アーキテクチャとデータの流れ

### iOS

- `Presentation/`: SwiftUI の View と TCA の Feature。表示状態・操作・画面遷移を扱います。
- `Application/`: 起動、認証、祭典・参加町の選択、位置配信、広告判定などのユースケースを扱います。
- `Domain/`: アプリ固有の型、入力データ、エラーを定義します。
- `Data/`: HTTP、認証、位置情報、広告、UserDefaults、SQLite へのアクセスを扱います。
- 依存注入には `swift-dependencies` を使います。

永続化する祭典・町・ルートなどは SQLiteData のテーブルで管理し、Feature / View が必要なデータを参照します。
通信とローカルデータの更新は `DataFetcher` と `SQLiteStore` が担います。
SQLite のテーブル作成は `Data/SQLite/SQLiteStore+Setup.swift` のマイグレーションに集約しています。

設計方針はクリーンアーキテクチャ、TCA、可能な限り AppState を SSOT にすることです。
現状の起動状態は `RootSceneView` の共有 `LaunchState`、各画面の状態は `HomeFeature.State` などに分かれており、
アプリ全体が単一の AppState に統合済みという構成ではありません。

### Backend

`Infrastructure/APIGateway` → `Application`・認証ミドルウェア → `Router` → `Controller` → `Usecase` → `Repository` → `DataStore` の順に処理します。

- `Infrastructure/`: Lambda イベントと API 応答の変換、ルーティング基盤、認証ミドルウェア。
- `Router/`: HTTP メソッド・パスと Controller の対応。
- `Controller/`: パラメータ・本文の読み取りと応答生成。
- `Usecase/`: 権限、公開範囲、更新可否、データ整合性の判断。
- `Data/Repository/`: モデルと保存レコードの変換、データ単位の取得・更新。
- `Data/Database/`: DynamoDB 接続、エンコード・デコード、クエリ処理。
- `Data/Auth/`: Cognito による認証・アカウント操作。

Backend はレイヤードアーキテクチャを採用します。共有モデルは `Shared` にあり、Backend 固有のレイヤーと分離しています。

## モデルと重要な仕様

- `Festival` に `District`・`Period`・`Checkpoint`・`HazardSection` が属します。
- `District` に `Performance` と屋台の位置 `FloatLocation` が属します。
- `Route` は町と期間を参照し、`Point` と `RoutePassage` を持ちます。
- `FestivalPack`・`DistrictPack`・`RoutePack` は関連データをまとめて送受信する型です。
- `LaunchFestivalPack` と `LaunchDistrictPack` は初期表示に必要なデータをまとめて返します。

### 起動・選択・同期

1. `RootSceneView` で SQLite を用意し、`SceneUsecase.launch()` を呼びます。
2. 起動時はローカルキャッシュを消し、保存済みの祭典・参加町と認証状態に応じてデータを取得します。
3. 祭典が未設定なら祭典一覧を取得してオンボーディングを表示します。
4. 保存済みの対象が見つからない場合は選択を解除します。一時的な通信エラーでは保存済み選択を維持します。
5. 祭典を切り替えるときはサインアウトの完了を待ってからデータを取得し、参加町の選択を解除します。

選択した祭典・参加町は UserDefaults、取得したモデルは SQLite、画面固有の状態は TCA が保持します。
`SceneDataFetcher` は起動用 Pack を取得して SQLite を更新し、`currentRouteId` を画面側へ返します。

### 公開範囲・整合性

- ユーザー権限は `guest`、`headquarter(festivalId)`、`district(districtId)` です。
- Bearer トークンがある場合は認証ミドルウェアで確認します。不正なトークンは 401 になります。
- ルートの公開範囲は `admin`・`route`・`all`。`admin` は対象の町・祭典の管理者に限定し、
  `route` は権限のない閲覧者への応答から時刻を除きます。
- `District.isEditable == false` の町では、ルートの追加・更新・削除を拒否します。
- Pack 更新時は子要素の祭典 ID・町 ID・ルート ID と、親の ID の整合性を検証します。
- ルート保存時は地点の不要な時刻を除去し、地点・通過エリアを再採番して検証します。
- 位置情報の一般公開時間は、同日の期間の最早開始時刻の30分前から最遅終了時刻までです。
  時間外の位置情報閲覧は、その町自身の管理者に限ります。

実際の判定は Backend の各 Usecase と `Usecase/LocationPublicAccess.swift`、地点の検証は
`Shared/Sources/Validation/Point+Validation.swift` を参照してください。

## API

パス定義は `Backend/Sources/Router/`、本文の型は `Shared/Sources/Pack/Pack.swift`、
クエリの解釈は各 Controller が正本です。

| 対象 | 主なエンドポイント |
| --- | --- |
| ヘルスチェック | `GET /health` |
| 祭典 | `GET /festivals`、`GET・PUT /festivals/:festivalId` |
| 祭典の起動データ | `GET /festivals/:festivalId/launch` |
| 町 | `GET・POST /festivals/:festivalId/districts`、`GET・PUT /districts/:districtId` |
| 町の管理 | `PUT /districts/:districtId/core`、`POST /districts/:districtId/reissue` |
| 町の起動データ | `GET /districts/:districtId/launch`、`GET /districts/:districtId/launch-festival` |
| 期間 | `GET・POST /festivals/:festivalId/periods`、`GET・PUT・DELETE /periods/:periodId` |
| ルート | `GET・POST /districts/:districtId/routes`、`GET・PUT・DELETE /routes/:routeId` |
| 位置情報 | `GET /festivals/:festivalId/locations`、`GET・PUT・DELETE /districts/:districtId/locations` |

応答は JSON です。成功時は 200、本文が不要な場合は `{}` を返します。
エラー本文には `message` と `localizedDescription` が入ります。
`Date` は iOS と Backend の双方で Unix 秒として送受信します。

HTTPClient は公開 GET で HTTP キャッシュの指示に従い、認証付き GET とキャッシュ無効指定では
再取得・保存禁止を要求します。更新成功後は既存の URL キャッシュを無効化します。

## ローカル設定

### iOS

以下の環境変数を用意し、リポジトリルートで `./.github/scripts/generate_ios_xcconfig.sh` を実行します。

- `MATOOL_API_BASE_URL`
- `MATOOL_USER_GUIDE_URL`
- `MATOOL_CONTACT_URL`

`iOSApp/Config/Debug.xcconfig` と `Release.xcconfig` が生成され、アプリにもリソースとして組み込まれます。
Debug の広告にはテスト ID を使います。Release の広告 ID を指定する場合は
`MATOOL_ADMOB_APP_ID`、`MATOOL_PUBLIC_MAP_INTERSTITIAL_AD_UNIT_ID`、
`MATOOL_PUBLIC_MAP_BANNER_AD_UNIT_ID` をすべて設定します。

認証用の `iOSApp/amplifyconfiguration.json` は利用する環境のものを配置してください。
`amplifyconfiguration.example.json` は形式の参照用です。設定値や秘密情報はコミットしません。

### Backend

`COGNITO_USER_POOL_ID` と `COGNITO_TEST_EMAIL` はプロセスの環境変数、または `Backend/.env` から読み取ります。
`Backend/.env` は Package.swift のコピーリソースでもあるため、ビルド時に必要です。
実環境へアクセスする検証では、その環境に対する AWS 認証・権限も必要です。

## テストと動作確認

通常のテストターゲットは `SharedTests`、`BackendTests`、`iOSAppTests` です。
Swift Testing（`import Testing`）を使い、ソースとテストを1ファイル対1ファイルで対応させます。
対象ソースの `Sources/` からの相対ディレクトリを、同じモジュールの `Tests/` 配下に再現します。

例: `iOSApp/Sources/Data/Client/HTTPClient.swift` → `iOSApp/Tests/Data/Client/HTTPClientTests.swift`。
同じソースのテストを機能名ごとに別ファイルへ増やさず、対応するテストファイルにまとめます。
モック・共通ヘルパーは検証ケースとは分けて管理します。

- build・test・起動は XcodeBuildMCP を使います。
- iOS は iPhone シミュレータを指定し、`iOSAppTests` スキームでテストします。
- Shared / Backend は My Mac で `SharedTests` / `BackendTests` スキームと対応するテストプランを選びます。
- `BackendBootstrap` は初期データ投入・マイグレーション用の別ターゲットです。通常の検証では実行しません。
- iOS の実装後は `iOSApp` スキームで iPhone シミュレータに起動し、sim-use で対象画面へ移動します。
  対象の操作を実行し、スクリーンショットと UI 情報で最終状態を確認します。起動だけでは検証完了にしません。
- Backend の実装変更では実際の入口を呼び、応答と副作用を確認します。
- iOS と Backend の同時変更時の開発環境・一時 URL の扱いは AGENTS.md に従います。

## CI と配布

`.github/workflows/` の定義が実際の実行条件です。

- main 向け PR は変更パスに応じてテストします。Shared の変更時は3モジュールを検証します。
- 現行のテスト workflow は Xcode 26.6 を指定しています。
- `backend/**`・`main`・`release-backend` への push は Backend のデプロイ workflow を起動します。
- `release-ios` への push は iOS の配布 workflow を起動し、配布成功後にアプリのバージョンに対応するタグを設定します。
