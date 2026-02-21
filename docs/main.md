## アプリ概要　

アプリ名「MaTool」

祭の管理運営や情報発信を行うアプリ

## 主な機能
- 祭屋台の現在地共有と表示
- 祭屋台のルート
    - 管理者による作成・提出
    - 本部による確認・PDF共有
    - 一般公開
- その他各町の情報発信

## アーキテクチャ構成

- Shared Swift 共通ドメイン層
- Backend Swift+AWS Lambda, DynamoDB, APIGateway
- iOSApp Swift

### Backend
- swift-dependencies
- aws-sdk

### iOSApp
- Composable Architecture
- SQLiteDate(キャッシュ兼フロントのSSOT)
- swift-dependencies

## 仕様書

- CI仕様書: `docs/spec/ci-spec.md`
