# MaTool 単一 Swift Package / モジュール移行ガイド

> 状態: 設計・移行計画（実装は別PR）。対象: `main` の tree `438cc5f660b0fb5e9042e41d64eee3dcdd75bb04` を確認した時点（2026-11-22）。関連: #455、#307。
>
> この文書は実際のソース配置・import・DependencyKeyを調査して定めた移設方針。まだソース移動・ビルド確認を実施したという意味ではない。実装着手時はHEADとの差分を再確認する。

## 1. 目標・現状

目標はリポジトリルートに単一の `Package.swift` を置き、iOS AppとLinux Lambda Backendで `Domain` を共用し、**既存8つのLibrary Targetを基本とし、BackendInfrastructureを追加した9 Library Targetを推奨案**として薄い実行／アプリ起動Targetに整理すること。

現行は `Shared/Package.swift`（`Shared` library）と `Backend/Package.swift`（すべてのBackendソースを一つの `Backend` executableに収容）の2パッケージ。iOSコードは `iOSApp/MaTool.xcodeproj` 内にあり、`MaTool.xcworkspace` も利用している。従ってXcodeプロジェクト名を機械的に `iOSApp.xcodeproj` と仮定しない。

想定するLibrary Target（9つ目の`BackendInfrastructure`は提案段階。8つを維持する代替案はB3参照）:

| Target | 内容 | 主な依存先 |
| --- | --- | --- |
| `Domain` | 旧`Shared`のEntity / DTO / Pack / 検証 / 純粋な共通ロジック | Foundation、必要最小限のLinux対応外部依存 |
| `BackendCore` | UseCase・Repository契約・認証/外部Client契約・業務ルール | Domain, Dependencies |
| `BackendDatabase` | DynamoDB DataStore / Record / Repository具象 | BackendCore, Domain, AWS DynamoDB SDK |
| `BackendAPI` | Application/Router/HTTP Controller・Lambdaアダプター | BackendCore, Domain |
| `BackendInfrastructure`（追加推奨） | Cognito / S3 / SNS / App Store Server APIなど外部サービスのLive実装 | BackendCore, Domain, 外部SDK |
| `AppCore` | UseCase、DataFetcher、アプリ固有状態・Entry・外部Client契約・共通画面用の純粋な状態型 | Domain, Dependencies（共有状態には追加Packageなしを優先） |
| `AppInfrastructure` | HTTP / Amplify / S3 / StoreKit / UserDefaults / 位置情報 / 画像・広告等のLive Client実装 | AppCore, Domain, 外部SDK |
| `AppPresentation` | TCA Feature/Reducer・Storeを利用するScreen/View・Navigation | AppCore, AppUI, Domain, TCA |
| `AppUI` | TCA非依存のSwiftUI / UIKit / MapKit View・Style・汎用コンポーネント | Domain, AppCore（純粋なView入力モデルだけ） |

別途 `Backend` executable（現行`Backend/Sources/Backend.swift`の`@main`相当）を薄く設ける。Xcode Appエントリ `iOSApp/Sources/MaToolApp.swift`、リソース、署名・CapabilitiesはXcode側に残す。

依存方向の原則:

~~~text
Domain ← BackendCore ← BackendDatabase
              ↑
              ├──────── BackendInfrastructure
              ↑
              └──────── BackendAPI
                           ↑
Backend executable ───────┘ (Core / Database / Infrastructureも組み立てる)

Domain ← AppCore ← AppInfrastructure
            ↑
            └── AppPresentation → AppUI（純粋UI、AppCoreの値型を利用可）
                      ↑
                 iOSApp (Composition Root; AppInfrastructureも組み立て)
~~~

`BackendCore` → `BackendDatabase` / `BackendInfrastructure`、`AppCore` → `AppInfrastructure`、`AppUI` → `AppPresentation` は禁止。外側の具体型を内側の `DependencyKey.liveValue` から直接生成することも禁止。モジュール間の`internal`を越える型には必要最小限の`public`を付ける（単なる機械的な一括`public`化は禁止）。

## 2. Backend: 依存性逆転・移設対象

### B1. Repository: 契約と実装の同居（必須）

`Backend/Sources/Data/Repository/**`には`*RepositoryProtocol`、`*RepositoryKey`、`*Repository`具象、`Record`変換が同じファイルにある。対象:

- `CreditRepository.swift`、`DistrictRepository.swift`、`Festival/CheckpointRepository.swift`、`Festival/FestivalRepository.swift`、`Festival/HazardSectionRepository.swift`
- `ImpressionRepository.swift`、`LocationRepository.swift`、`PassageRepository.swift`、`PerformanceRepository.swift`、`PeriodRepository.swift`
- `PointRepository.swift`、`PurchaseRepository.swift`、`RouteRepository.swift`、`StoreRepository.swift`、`Repository.swift`

**分割**: Repositoryの`protocol`・業務上の戻り値／結果型（例: `ImpressionChargeResult`）・DependencyValuesのアクセサ/Keyの**宣言**を`BackendCore/Repository`へ。`DataStore`・`Record`・DynamoDBのキー生成・具象Repositoryを`BackendDatabase`へ。`RouteUsecase`等はBackendCoreの契約だけに依存させる。

現行`FestivalRepositoryKey.liveValue = FestivalRepository()`、`RouteRepositoryKey.liveValue = RouteRepository()`等はCoreからDatabaseを参照する逆依存になる。**CoreでLive具象を作らず**、Backend起動のComposition Rootで実装を注入する。テスト用の差し替えを維持する。`PeriodRepositoryKey`にも`DataStoreFactoryKey`へのLive依存があり同様。

`Backend/Sources/Data/Database/DataStore.swift`の`DataStoreFactory`、`DynamoDBTransactionalDataStore`、`RecordProtocol`、Query/FilterConditionは原則BackendDatabase内部に閉じ、UseCaseへ漏らさない。`Record`をRepository契約の戻り値にしない。

**SDK依存の実態:** RepositoryはAWS SDKを直接`import`していないが、少なくとも`CreditRepository.swift`、`PurchaseRepository.swift`、`ImpressionRepository.swift`、`StoreRepository.swift`は`DynamoDBTransactionOperation`/`DynamoDBEncoder`/`DynamoDBAttribute`等を参照している。`DynamoDBAttribute`は`DynamoDBClientTypes.AttributeValue`へのtypealiasであり、DynamoDB SDK型への間接依存も存在する。既存の原子性・条件付き更新を無理に汎用Repository APIへ隠蔽しない。これらはBackendDatabaseの具体実装として扱う。

### B2. HTTP Controllerは実際にはBackendAPIへ（必須・Issue #455の原案を修正）

`Backend/Sources/Controller/`の次の**11ファイルすべて**が`Request`/`Response`を直接使用している:

`AdvertisementController`、`AdvertiserAuthController`、`DistrictController`、`FestivalController`、`ImageUploadController`、`LocationController`、`PeriodController`、`PurchaseController`、`RouteController`、`SceneController`、`StoreController`。

`Request`、`Response`、`Handler`、`Error`は`Backend/Sources/Infrastructure/Application.swift`のHTTP境界であり、ControllerをそのままBackendCoreへ入れるとCore → API依存になる。今回はControllerのHTTP処理・ControllerProtocol/Keyを**BackendAPI**へ移す。Controllerから業務ロジックを移動したい場合のみHTTP非依存の新しいUseCase/ServiceをBackendCoreへ抽出し、Controller自体はAPIに残す。

`Backend/Sources/Router/**`、`Infrastructure/APIGateway.swift`、`Infrastructure/Application.swift`、`Infrastructure/Midleware/AuthMiddleware.swift`、HTTP関連`Utils/Request+Decode.swift`、`Response+Encode.swift`もBackendAPIへ。`Backend/Sources/Usecase/**`は原則BackendCoreへ（次項の例外に注意）。

**別の必須依存境界: エラー型。** `Backend/Sources/Utils/Error+Application.swift`には`typealias Error = Application.Error`があり、`Usecase/**`、Repository、Cognito/S3/SNS等のLive実装まで`Error.notFound/badRequest/forbidden/internalServerError`を参照している。現在`Application.Error`は`Backend/Sources/Infrastructure/Application.swift`にネストされているため、このまま分割すると**BackendCore → BackendAPI、BackendInfrastructure → BackendAPI**の逆依存が発生する。

- HTTPに依存しない`BackendError: Swift.Error, Sendable, Equatable`（または同等の名前）を**BackendCore**へ抽出し、UseCase・Repository・Live Clientの共通エラー契約にする。
- `BackendAPI`は`BackendError`からHTTP status code / ErrorResponse / Responseへの**変換のみ**を持つ。
- 呼び出し元の`Error.*`を`BackendError.*`へ更新するか、互換typealiasを適切な境界に置き、APIの`Application`に型依存しないことをビルドで検証する。

### B3. 外部サービス契約とAWS実装の同居（必須）

| 現行 | BackendCoreに置くもの | 具象アダプターの置き場 |
| --- | --- | --- |
| `Data/Auth/AuthManager.swift` | `AuthManager`、`AuthManagerFactory`契約/Key | `CognitoAuthManager.swift`、AWS SDK実装 |
| `Data/Client/AppStoreClient.swift` | `AppStoreClientProtocol`、`VerifiedPurchase`など業務で使う独自型/Key | App Store Server Library実装 |
| `Data/Client/S3ImageClient.swift` | `ImageStorageClientProtocol`/Key | `S3ImageClient` (AWSS3) |
| `Data/Client/ReportNotificationClient.swift` | `ReportNotificationClientProtocol`/Key | `ReportNotificationClient` (AWSSNS) |
| `Usecase/AppStoreNotificationHistoryRecovery.swift` | `AppStoreNotificationHistoryClientProtocol`/Key、復旧処理のオーケストレーション | `AppStoreNotificationHistoryClient` (AppStoreServerLibrary) |

**推奨案:** `BackendInfrastructure`を**9つ目のLibrary Target**として追加し、Cognito/S3/SNS/App Store Server APIのLiveアダプターを収容する。`BackendAPI`はHTTP境界に専念し、薄い`Backend` executableが`BackendCore`/`BackendDatabase`/`BackendInfrastructure`/`BackendAPI`を組み立てる。

**8 Library Targetが必須の場合の代案:** `BackendDatabase`を`BackendInfrastructure`へ改名・統合し、`Database/`（DataStore/Repository実装）と`Clients/`（外部API）を内部ディレクトリで区分する。HTTP専用の`BackendAPI`へ外部Client実装を混ぜる案は優先しない。**この追加ターゲット案は設計上の推奨であり、最終採用は未決定。**

`Usecase/Utils/ImpressionToken.swift`は`Crypto`をimportしている。AWS依存ではないが、純粋な署名・検証か外部Clientとするか確認する。`S3ImageClient.swift`中の`UploadedJPEGValidator`はAWS呼び出しと切り離せる純粋な検証ロジックであり、適切にCoreへ分離できる。

### B4. BackendのDI組み立て

`Backend/Sources/Backend.swift`の`@main`、Routerの`@Dependency(*ControllerKey.self)`、UseCaseの`@Dependency(*RepositoryKey.self)`の生成順を維持する。CoreのKeyにDatabase/APIの具象を直接参照させず、起動側のLive登録/明示注入で依存グラフを組み立てる。`DependencyKey`の宣言をCoreへ移しただけで`static liveValue`が具象参照したままだと**即座に循環依存**する。起動時初期化・テストごとのoverrideスコープ・Lambdaでの共有インスタンス再利用を検証する。

## 3. iOS: 依存性逆転・移設対象

### A1. DataFetcherの契約と具象は同じソース内（必須）

`iOSApp/Sources/Data/Fetcher/`の`AdvertiserAuthDataFetcher`、`CreditDataFetcher`、`DistrictDataFetcher`、`FestivalDataFetcher`、`ImageUploadDataFetcher`、`LocationDataFetcher`、`PeriodDataFetcher`、`RouteDataFetcher`、`SceneDataFetcher`、`StoreAdDataFetcher`、`StoreDataFetcher`には`*Protocol`/`*Key`と通信実装が同居している。

今回はDataFetcher**の抽象・業務上の操作APIと純粋な組み立て処理をAppCore**へ配置する。例: `FestivalDataFetcher`の`@Dependency(HTTPClientKey.self)`を残す場合、`HTTPClientProtocol`/`HTTPClientKey`は必ずAppCoreへ抽出する。通信プロトコルの詳細（URL、method、query、token）の組み立てまで外側へ隠したい場合は、DataFetcherのネットワーク具象をAppInfrastructureへ置き、AppCoreにはDataFetcherProtocolだけを残す。**AppCoreからInfrastructureの実装をimportしない**ことを優先し、どちらの方式にするかファイルごとに明記する。

`Data/Fetcher/DataFetcher.swift`は`getToken()`で`authProvider`へ依存している。移行時は`AuthProvider`契約をAppCoreへ移し、通信認証と分離する。`Query.queryItems`はHTTPクエリ文字列への変換のため、純粋なQuery enumとHTTPへのエンコードを分離することも検討する。

### A2. Clientの契約とLive実装を分離（必須）

| 現行`iOSApp/Sources/Data/Client/` | AppCore側 | AppInfrastructure側 |
| --- | --- | --- |
| `HTTPClient.swift` | `HTTPClientProtocol`、Key | `HTTPClient` actor |
| `AuthProvider.swift` | `AuthProvider`の関数契約、認証結果型 | `Amplify` / `AWSCognitoAuthPlugin`のLive定義 |
| `StoreKitClient.swift` | `StoreKitClientProtocol`、`StoreCreditProduct`、`StoreKitPurchaseOutcome`、`StoreKitTransactionInfo` | `StoreKitClient` actor |
| `S3ImageUploadClient.swift` | `S3ImageUploadClientProtocol`、Key | URLSessionのPUT実装 |
| `MapLocationProvider.swift`、`BroadcastLocationProvider.swift` | 位置配信/取得の契約（可能ならSDK非依存の`Coordinate`型） | CoreLocationを使用する実装 |
| `ImageCacheClient.swift`、`ImageJPEGProcessingClient.swift`、`PhotoLibraryClient.swift` | 入出力契約/Key | キャッシュ・写真ライブラリ・JPEG処理の実装 |
| `StoreAdImpressionQueueClient.swift` | Queue契約/Key | 再送・保持処理 |
| `UserDefaultsClient.swift` | UserDefaults操作の契約/キー | `UserDefaults`実装（`UserDefaltsManager`含む） |
| `AppStatusClient.swift`、`AdManager.swift` | 画面/UseCaseから必要な最小契約と値型 | URLSession / GoogleMobileAdsの具象 |

`StoreCreditUsecase`、`AdvertiserDashboardUsecase`、`StoreAdBannerUsecase`、`LaunchSceneUseCase`等は現在これらのKeyを呼んでいる。AppCoreで宣言したDependencyKeyのLive具象生成をAppInfrastructureから設定する。`AppCore`の`static liveValue`で`HTTPClient`、`Amplify`、`StoreKitClient`などを直接組み立てない。

### A3. AppCoreの共有状態: **新規依存なしを最優先**（方式は実装前にPoC）

`iOSApp/Sources/Application/**`の多数のUseCase（例: `CreateRouteUseCase.swift`、`SaveLocationUseCase.swift`、`LaunchSceneUseCase.swift`、`RouteStateUpdates.swift`）は現在`import ComposableArchitecture`を用い、`Shared<AppState?>`/`withLock`でアプリ全体の状態を読み書きする。**AppCoreからTCA本体を排除することが目標であり、swift-sharingの直接依存は最終手段**。現状を維持するためだけに新たなライブラリを追加しない。

優先的に検証する選択肢は次の通り。いずれも`sessionId`/`requestId`を用いた古いレスポンスの無視、並行リクエスト間の整合性、共有状態の観測、単体テスト容易性を実測で確認する。

| 優先度 | 案 | 依存 / 長所 | 注意点 |
| --- | --- | --- | --- |
| **1** | **非同期UseCaseは結果を返し、同期`inout AppState`更新を別関数にする** | Swift標準のみ、CoreがUI/状態管理ライブラリ非依存。副作用とState更新を分離 | Reducerに結果アクションを受け取る変更が必要。現在の複数UseCase更新箇所に広く波及 |
| **2** | **`AppStateAccess`（読み取り＋同期`inout`更新クロージャ）をCoreで定義** | Swift標準のみ。呼び出し元が必要な状態管理実装を適合させ、既存`withLock`更新に近い使い勝手 | クロージャが原子的に更新することを所有者側で保証。非同期呼び出し中に排他を保持しない |
| **3** | **Observationの`@Observable`と`@MainActor`な参照保持モデル** | Apple/Swift標準のObservationを利用し、3rd-party依存なし | TCAでの観測・Reducer状態との同期を含めSSOT所有方法を再設計。`@Observable`自体は排他・トランザクションを保証しない |
| **4** | **SwiftUIの`Binding<AppState?>`** | 追加外部Package不要。読み書きAPIが単純 | AppCoreがSwiftUIに依存（UI層の逆依存）。`Binding`のget/setだけでは複合更新の原子性・並行安全性を保証しない。MainActor制約とTCA `@Shared`とのブリッジを確認 |
| **最終手段** | **`swift-sharing`の`Sharing` Productへ直接依存** | 既存`Shared<AppState?>`/`withLock`を活用可能、TCA本体は不要 | Coreに第三者パッケージが追加される。上記方式で要求を満たせない場合のみ採用を検討 |

#### 第一候補: 非同期処理と同期的な状態変更を明確に分ける

~~~swift
// AppCore（概念例）
struct CreateRouteUseCase {
    // DataFetcherの抽象を注入
    func callAsFunction(/* 入力 */) async throws -> RoutePack {
        // API通信のみ。AppStateへの直接参照は持たない
    }
}

func applyRouteResponse(
    _ response: RoutePack,
    context: RouteStateUpdateContext,
    to state: inout AppState
) {
    guard state.sessionId == context.sessionId,
          state.districtState?.requestId == context.districtRequestId
    else { return }
    // 既存の更新ロジック
}

// AppPresentation: reducerがEffectの結果を受け、同期処理中にstateを更新する。
// 古い応答の無視に必要なcontextはリクエスト開始時に捕捉する。
~~~

`func save(appState: inout AppState) async`のように**actor隔離された共有状態を非同期`inout`で直接渡さない**。Reducerの`Effect.run`はescapingなので、`inout State`をそのままキャプチャして更新できない。非同期結果はAction経由で戻してから同期`inout`で反映する。

#### 第二候補: 薄いAppStateAccess（必要なら）

~~~swift
// AppCore側の契約イメージ。外部Packageは不要。
struct AppStateAccess: Sendable {
    var snapshot: @Sendable () -> AppState?
    var update: @Sendable (@Sendable (inout AppState?) -> Void) -> Void
}
~~~

`AppPresentation`のアダプターは既存の`Shared.withLock`を用いて`update`の処理を同期・原子的に行う。`AppCore`には`Shared`型を公開しない。置き換えのテストでは`Mutex`/actor等を用いて同等の安全性を確かめる（具体的な`@Sendable`署名、Swift 6.2の隔離ルール、TCA状態への適用はPoCでコンパイル確認して確定する）。クロージャをまたいでlockを保持して`await`しない。

#### Observation / Bindingの検証

- Observationの場合、`@Observable final class AppStateHolder`のような所有者を`@MainActor`で持ち、更新を同期的なメソッドにする案を評価。Reducerと画面が同一インスタンスを参照できること、表示更新が適切に伝播すること、現在の`AppState`が保持するSession世代のガードが失われないことをPoCで確認する。
- SwiftUIの`Binding`をAppCoreのUseCase引数に直接渡す案も比較するが、`Binding`のSwiftUI依存を許可する必要がある。特に並行更新をget/setに分割すると別Taskによる更新の上書きが発生しうるので、状態変更の排他やMainActor化を明示する。`@Observable`と`Binding`は同じ概念ではなく、Observationは値の観測、Bindingは値への読み書き口。
- **採用判断**: 既存のUseCase/Featureへの変更量が許容できるなら1、既存の共有更新を多く残したいなら2を優先する。3/4は具体的な利点が示せる場合のみ。**swift-sharingは1〜4で実現できない要件が確認できた場合だけ採用**する。

`@ObservableState`、`@Presents`、`Effect`等のTCA専用型はAppPresentationに留める。AppUIへのTCA依存が生じないことも確認する。

### A4. `iOSApp/Sources/Domain`は無条件で新Domainへ入れない

- `Shared/Sources/{Entity,DTO,Pack,Validation,Extensions,Utils}`はLinux対応を確認して`Domain`へ移設。
- `iOSApp/Sources/Domain/Entry/{LocationEntry,PointEntry,RouteEntry,RouteDraft}.swift`、`Entities/Auth/AuthState.swift`、`Entities/Location/Status.swift`、`Entities/Share/AdvertiserStore.swift`、`Entities/Share/AppStatus.swift`、`Entities/Share/Others.swift`、`Error/APIError.swift`等の**アプリ専用型**は原則AppCore。Shared/Domainへ安易に混ぜない。
- `Entities/Share/Coordinate+MapKit.swift`と`iOSApp/Sources/Utils/MKCoordinateRegion+Equatable.swift`はApple向け拡張なので**Linux共通Domainには入れず**AppUIまたはAppInfrastructure。
- `Domain/Error/AuthError.swift`、`CognitoAuthErrorLocalization.swift`の`Amplify`/`AWSCognitoAuthPlugin`依存部分はAppInfrastructureでエラー変換。SDK非依存の`AppError`定義はAppCore。
- `iOSApp/Sources/Application/AppState*.swift`、`SceneSelection.swift`、`SceneSessionCoordinator.swift`、UseCase群はAppCore。`MaToolApp.swift`はXcode側に残す。

## 4. TCA Feature内部の共有型の抽出（実コードで確認）

ルール: `AppPresentation`のReducer/State/Action/Navigation自体は動かさない。**TCAに依存しないContent Viewが入力として受け取る独立モデル、業務編集状態、純粋な変換ロジック**をFeatureのネストから外し、AppCoreの独立型にする。AppUIへの移動対象となるContent Viewは`Feature.XXX`を引数型にしない。名前変更時は既存テスト・全参照元を更新する。

| 優先 | 現行の定義/参照 | 抽出先・理由 |
| --- | --- | --- |
| **必須** | `PublicMapFeature.Content`、`PublicMapFeature.DistrictContentGroup` (`Public/Map/Root/PublicMapFeature.swift`) → `PublicMapContentView` (`PublicMapView.swift`) が直接参照 | `AppCore/PublicMapContent`、`DistrictContentGroup`。選択状態と地区グループ。View側`private extension PublicMapFeature.Content`も新しい独立型を拡張する |
| **必須** | `PeriodListFeature.State.YearlyPeriods` (`Admin/Region/Period/PeriodListFeature.swift`) → `PeriodListContentView` (`PeriodListView.swift`) が引数に使用 | `AppCore/YearlyPeriods`。年度によるグルーピング`makePeriodsStates`も純粋関数として抽出可能 |
| **必須** | `PointEditFeature.PointType` (`Admin/District/Route/Point/PointEditFeature.swift`) と`Point.apply(pointType:)`/`init(point:)` → `PointEditView.swift`にもextensionあり | `AppCore/PointType`。編集状態・Entity変換・検証の責務であり、ViewやTCAだけに閉じない |
| **必須** | ファイルスコープ`ImageEditMode`が`View/Shared/ImageEditFeature.swift`で定義され、`ImageEditContentView`で利用 | `AppCore/ImageEditMode`と`uploadVariant(for:)`。表示文言を返す`title(for:)`はAppUI（表示ローカライズ）へ分割する |
| **必須** | `MapToast` が`Presentation/Parts/Others/MapToastView.swift`に`MapToastView`と同居し、`PublicMapFeature`ほかReducerが保持 | `AppCore/MapToast`（純粋な値型）と`AppUI/MapToastView`に分離。文字列生成をUIローカライズと分離するか検討 |
| **候補** | `PublicRouteFeature.Replay` → `PublicRouteMapView`が`store.replay`を解釈し、`ReplayController`を操作 | 再生状態の独立enumを`AppCore`へ。`ReplayController`本体は`MapKit`/`ObservableObject`を含むためAppUI側（View主導のコントローラ）で可。`Detail`は画面遷移なのでPresentationに残す |
| **候補** | `RouteEditFeature.EditMode`、`Operation`、`Tab` → `RouteEditView`が`Tab`をtypealias | 編集に関わる`EditMode`/`Operation`の独立値型をAppCoreへ。`Tab`をTCA非依存Content Viewへ渡すなら`AppCore/RouteEditTab`へ（UIタイトル等はAppUI）、画面専用ならPresentation残置でも可 |
| **候補** | `FestivalInfoFeature.DisplayMode` → `FestivalInfoContentView` (`FestivalInfoView.swift`) が`Binding`で参照 | Content ViewをAppUIへ切り出す際は`AppCore/FestivalInfoDisplayMode`に独立定義し、`"紹介"/"町一覧"`等の表示文言はAppUIに置く |
| **要確認** | `SettingsFeature.PendingParticipationChange`、`ParticipationChangeCompletion`、`PublicMapFeature.DistrictLaunchResult`、`RootFeature.State.Scene` | UseCase/他画面でも使う純粋な状態ならAppCoreへ。単一Reducer内部で完結するなら移動不要 |

**AppCoreへ移さないもの**: `Feature.Action`、`Feature.State`（@ObservableState・@Shared・@Presentsあり）、`Feature.Destination`/`AlertDestination`、TCAのNavigation Case、`CancelID`、`TaskID`、Reducer専用の`Delegate`等。`ExportKind`、`LoadingAction`等も画面専用ならPresentationに留める。すべてのネストenumを機械的にCoreへ動かすことはしない。

## 5. AppUI切り出しと混在ファイル

- `Presentation/Parts/Input/**`、`Parts/Item/**`、`Parts/Map/{MapView,MapFragments,...}`、`Parts/Modifier/**`、`Parts/Others/**`、`Presentation/Style/**`、`Presentation/Utils`の**純粋なView/Modifier/MapKit機能**をAppUIへ。`MapCoordinatePickerFeature.swift`、`StoreAdBannerFeature.swift`、`StoreAdBannerView.swift`はTCA依存なのでAppPresentationに留める。
- `PublicMapView.swift`は`PublicMapView`（Store依存、Presentation）と`PublicMapContentView`（TCA非依存、AppUI候補）が**同一ファイル**。ファイルを分割し、上記の独立したContent型を参照させる。
- `PeriodListView.swift`も`PeriodListScreen`（Presentation）と`PeriodListContentView`（AppUI候補）を分割。`YearlyPeriods`の切り出しが前提。
- `ImageEditScreen.swift`は`ImageEditScreen`（Presentation）と`ImageEditContentView`（AppUI候補）に分割。`ImageEditMode`を独立化。
- `FestivalInfoView.swift`は`FestivalInfoView`（Presentation）と`FestivalInfoContentView`などTCA非依存の子View（AppUI候補）が同居。DisplayModeの型とBindingを整理してから分割。
- `Utils/Async.swift`では値型`AsyncValue`等とSwiftUIの`@ViewBuilder viewWhen`が同居。AppCoreへ純粋処理、AppUIへSwiftUI extensionを**ファイル分割**する。
- `Utils/ComposableArchitecture+TaskResult.swift`では`AppResult`/`VoidAppResult`と`Effect.task`/`Effect.dismiss`が同居。結果型をAppCore、Effect拡張をAppPresentationへ分ける。
- `Presentation/Utils/RouteSnapshotter.swift`、`PDFRenderer.swift`はMapKit/UIKit/PDFKitを使うため**AppUIの描画ユーティリティに配置してよい**。`AppPresentation → AppUI`は許可した依存方向なので、`RouteEditFeature.wholeTapped/partialTapped`が`RouteSnapshotter`を直接使うこと自体はモジュール境界違反ではない。`RouteExportClient`による依存性逆転は**必須ではなく**、Reducer単体テストで描画副作用の置き換えが必要になった場合に検討する。
- `Parts/Advertisement/PublicMapBannerAdSection.swift`はView内で`AdManager`と`GoogleMobileAds`へ直接依存。AppUIをTCA非依存にすることとは別に、広告SDKの境界を`AdBannerView`の入力/アダプターに整理。SDK依存の実装をAppInfrastructureへ移す際のUIViewRepresentableの置き場所をレビューする。

## 6. 単一Package.swiftとLinux

1. SwiftPMはビルドProductの依存Targetのみコンパイルできる。Linuxの`swift build --product Backend`でAppUIのSwiftUI/UIKitソースをビルドしない依存グラフにする。
2. ただし**Package全体の外部依存解決**は残る。Apple専用Packageやresolver問題があればmanifest評価時の`#if !os(Linux)`でApp側の`products`・`targets`・`dependencies`をまとめて除く。`#if os(Linux)`はビルド先ではなくPackage.swiftの**実行ホスト**の条件である。
3. テストもLinux用にBackend/Domainのtest targetsだけをmanifestへ登録する。単なる`swift test --filter`だけではiOSテストの依存コンパイル回避を保証しない。
4. 旧`Backend/Package.resolved`、`Shared/Package.resolved`、workspaceの`Package.resolved`の扱い、依存バージョン固定方針を統一する（`AGENTS.md`のresolved運用ルールとの整合をレビュー）。
5. `Backend/Dockerfile`の`COPY Shared/Package.swift ...` / `COPY Backend/Package.swift ...`、`WORKDIR /workspace/Backend`、依存先行ビルド用`__DependencyPrebuild.swift`は単一Package化で必ず調整する。`swift build --product Backend`を用い、Docker layer cacheの再利用効果を維持・計測する。
6. `.github/workflows/job_test_backend.yml`、`job_test_shared.yml`、`job_test_iosapp.yml`、`job_deploy_backend.yml`と`ci_scripts/**`の`--package-path Backend/Shared`、パスフィルタ、coverage出力パス、キャッシュキー、`xcodebuild -project iOSApp/MaTool.xcodeproj`、XcodeのローカルPackage参照を更新する。
7. 現行の`BackendBootstrap`はTest Targetとしてデータ注入/マイグレーション用途を持つ。通常のCIテストに無条件追加しない（既存`AGENTS.md`の禁止事項を維持）。

## 7. 実施順序（PR分割案）

1. **事前準備**: 現行HEADのiOS/Backend/Sharedビルド・テスト・依存グラフ、カバレッジとデプロイを記録。移設先のpublic APIを必要最小限で設計。
2. **純粋な型の切り出し**: `PublicMapContent`、`YearlyPeriods`、`PointType`、`ImageEditMode`、`MapToast`、`AsyncValue`などを既存Xcode Target内でまず別ファイル化。振る舞いとUIを変更せずテストを追加/更新。
3. **Backendの契約分割**: まず`Application.Error`をHTTP非依存のBackendCoreエラーへ分離し、HTTPエラー変換をAPIへ移動。そのうえでRepositoryProtocol/外部ClientProtocolとLiveを分け、HTTP ControllerをAPI境界として固定。DIのComposition Rootを作成。既存テストを維持。
4. **Appの契約分割**: DataFetcher/Clientの契約とLiveを分ける。まず非同期UseCaseの結果返却＋同期`inout`、次にクロージャ型`AppStateAccess`をPoC比較し、必要ならObservation/Bindingを検証する。swift-sharing追加は最終手段。AppCoreが外側の型をimportしない状態を先に作る。
5. **モジュールの切り出し**: Domain→BackendCore/BackendDatabase/BackendInfrastructure（採用する場合）/BackendAPI→AppCore/AppInfrastructure→AppUI/AppPresentationの順にTargetを作り、移動。各段階でコンパイルとテスト。
6. **単一manifest化とCI対応**: root Packageに収束、Xcode/Backend Docker/Actions/Xcode Cloud関連パスを更新。Linux依存解決不具合が出た場合のみmanifestの`#if`を追加。
7. **検証/仕上げ**: 循環参照なし、正しいモジュール公開境界、テスト・カバレッジ・既存動作、Lambdaデプロイ、iOS署名/配布構成を確認後に完了。

無理に単一PRに詰めない。移動専用PRと機能修正PRを分け、変更は必要な順序で後方互換を考慮する。Edition移行など進行中のEntity変更はこのIssueのスコープへ混入させない。

## 8. 完了条件・拒否条件

- [ ] ルート`Package.swift`と8 Library Target（推奨するBackendInfrastructureを採用する場合は9）、薄いBackend executable、現行iOSエントリからビルドできる。
- [ ] `BackendCore`にHTTP Request/Response、DynamoDB、AWS SDK具象、Cognito/S3/SNS/AppStoreのLive実装が存在しない。`Application.Error`への依存も解消し、HTTP statusのマッピングがBackendAPIだけにある。`BackendAPI`にも外部ClientのLive実装を混在させない構成を優先。
- [ ] `BackendDatabase`/`BackendAPI`からCoreへ向かう一方向依存で、Coreの`liveValue`が外側を生成しない。
- [ ] `AppCore`が`AppInfrastructure`をimportせず、DataFetcher/Clientの契約が内側にある。`inout` / `AppStateAccess` / Observation / Bindingを比較し**追加依存なしを優先**した共有状態方式を確定。`AppCore`から`import ComposableArchitecture`をなくし、原子的更新と古いレスポンス破棄を維持。
- [ ] `AppUI`のソースに`ComposableArchitecture`、`StoreOf`、`Feature.State/Action`、`Reducer`の参照がない。`AppCore`へ不必要な外部Package依存を増やしていない。
- [ ] 前述の`PublicMapContentView`、`PeriodListContentView`、`ImageEditContentView`などが独立型を使用し、TCA Featureのネスト型へ依存しない。
- [ ] LinuxでBackend/Domainのビルドとテストが成功、iOSでAppのビルドと該当テストが成功（**実測**）。
- [ ] Docker/CIの依存キャッシュ・coverage・Lambda起動・既存APIレスポンス・Appの動作に回帰がない。
- [ ] 既存`BackendBootstrap`を予期せず実行していない。

### 参照元（main、実装開始時に再照合）

- Backend: `Backend/Package.swift`、`Backend/Sources/{Data/Repository,Data/Database,Data/Auth,Data/Client,Controller,Usecase,Infrastructure,Router}`、`Backend/Dockerfile`。
- App: `iOSApp/Sources/{Application,Data/Fetcher,Data/Client,Domain,Presentation,Utils}`、`iOSApp/MaTool.xcodeproj/project.pbxproj`。
- CI: `.github/workflows/job_test_{backend,shared,iosapp}.yml`、`job_deploy_backend.yml`、`ci_scripts/**`、`AGENTS.md`。
