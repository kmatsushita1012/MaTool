# MaTool リポジトリ構造・アーキテクチャ分析

このドキュメントは `./.codex/main.md` と実際のソース構成（`Backend`, `Shared`, `iOSApp`）をもとに、ディレクトリ構造とレイヤー構成を整理したものです。

## 1. 全体構成（トップレベル）

```text
MaTool/
├── Backend/      # AWS Lambda + API Gateway 向けバックエンド
├── Shared/       # Backend / iOSApp で共有するモデル・共通処理
├── iOSApp/       # SwiftUI + TCA ベースの iOS クライアント
├── docs/         # 設計メモ（テーブル、scene など）
├── .codex/       # Codex 作業メモ
└── MaTool.xcworkspace
```

## 2. モジュール別構造

### 2.1 Backend

```text
Backend/Sources/
├── Core/         # HTTP/Lambda 実行基盤、Request/Response、Middleware
├── Router/       # エンドポイント定義（パスとコントローラ結線）
├── Controller/   # HTTP 入出力変換、Usecase 呼び出し
├── Usecase/      # 業務ルール、権限判定、ユースケース実装
├── Data/
│   ├── Repository/   # 永続化アクセス
│   ├── Database/     # DynamoDB 向けデータストア実装
│   └── Auth/         # Cognito 連携
└── Utils/
```

### 2.2 Shared

```text
Shared/Sources/
├── Entity/       # Festival, District, Route, Point など共有エンティティ
├── Validation/   # 値検証
├── Extensions/   # 共通拡張
├── Utils/        # 共通ユーティリティ
└── Pack/         # API/ユースケース間の集約 DTO
```

### 2.3 iOSApp

```text
iOSApp/Sources/
├── Presentation/ # SwiftUI View / TCA Feature(StoreView)
├── Application/  # 画面起動・認証・シーン遷移のユースケース層
├── Domain/       # クライアント側ドメインモデル/契約
├── Data/
│   ├── DataFetcher/ # API呼び出し + ローカル同期
│   ├── Client/      # HTTP / UserDefaults / 認証プロバイダ
│   └── SQLite/      # ローカルDBアクセス
├── Utils/
├── SupportingFiles/
└── MaToolApp.swift
```

## 3. レイヤー分類（Application / Domain / Infrastructure / UI）

## 3.1 Backend の分類

- UI / Interface 層:
  - `Backend/Sources/Router`
  - `Backend/Sources/Controller`
  - 役割: 外部IF（HTTPパス、Request/Response）とユースケースの接続
- Application 層:
  - `Backend/Sources/Usecase`
  - 役割: 業務フロー・権限制御・集約ロジック
- Domain 層:
  - 主体は `Shared/Sources/Entity` を利用
  - `Usecase` 内の業務規則（可視性判定など）
- Infrastructure 層:
  - `Backend/Sources/Data/Repository`
  - `Backend/Sources/Data/Database`
  - `Backend/Sources/Data/Auth`
  - `Backend/Sources/Core`（Lambda 実行基盤）

実装上の流れは概ね `Router -> Controller -> Usecase -> Repository/DataStore`。

## 3.2 iOSApp の分類

- UI 層:
  - `iOSApp/Sources/Presentation`
  - `iOSApp/Sources/MaToolApp.swift`, `iOSApp/Sources/iOSApp.swift`
  - 役割: SwiftUI 画面、TCA Store/Feature、ユーザー操作処理
- Application 層:
  - `iOSApp/Sources/Application`
  - 役割: 起動処理、認証フロー、画面遷移/初期化シナリオ
- Domain 層:
  - `iOSApp/Sources/Domain`
  - `Shared/Sources/Entity`（共通ドメイン）
  - 役割: エンティティ、契約、業務的な型定義
- Infrastructure 層:
  - `iOSApp/Sources/Data/Client`
  - `iOSApp/Sources/Data/DataFetcher`
  - `iOSApp/Sources/Data/SQLite`
  - 役割: API通信、認証トークン、ローカル永続化、同期

実装上の流れは概ね `Presentation -> Application -> DataFetcher/Client -> API/SQLite`。

## 3.3 Shared の位置づけ

- 基本は Domain 中心（共有エンティティ・値オブジェクト）
- 一部は Infrastructure 寄り（SQLite 連携拡張など）
- 実務上は「クロスモジュール共通レイヤー」として機能

## 4. アーキテクチャ所見

- 明確に層が分かれており、命名も整っている。
- `Usecase` と `Data/Repository` の境界が明瞭で、依存逆転（DI）を利用している。
- iOS 側は TCA + Application + Data の分離がされ、画面とデータアクセスの責務が分離されている。
- `Shared` がドメイン共通言語として機能しており、Backend/iOS 間で型整合を取りやすい構成。

## 5. 補足（現状の分類で迷いやすい点）

- `Backend/Sources/Core` はフレームワーク基盤なので、純粋な Domain ではなく Infrastructure とみなすのが妥当。
- `iOSApp/Sources/Application` の `*Usecase.swift` は名称どおり Application 層だが、実装次第で Domain ロジックが混ざりやすい。
- `Shared/Sources/Extensions` は内容により Domain 拡張と Infrastructure 拡張が混在し得るため、今後は用途別に分割するとより明確になる。
