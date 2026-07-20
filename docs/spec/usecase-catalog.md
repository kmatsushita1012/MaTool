# ユースケースカタログ

現行実装に存在するユースケースを、機能単位で整理したカタログ。  
対象は `Backend/Sources/Usecase` と `iOSApp/Sources/Application`。

## 1. 記法

- ID: `BE-xxx` は Backend、`IOS-xxx` は iOS Application
- 入力: 主な引数、前提データ
- 出力: 返却値
- 権限: 主な認可条件
- 副作用: 永続化・外部I/O・状態更新

## 2. Backend Usecase

## 2.1 Festival

### BE-001 Festival一覧取得
- メソッド: `FestivalUsecase.scan()`
- 入力: なし
- 出力: `[Festival]`
- 権限: なし（公開）
- 副作用: なし（読み取り）

### BE-002 Festival詳細取得
- メソッド: `FestivalUsecase.get(_ id: String)`
- 入力: `festivalId`
- 出力: `FestivalPack`
- 権限: なし（公開）
- 副作用: `festival/checkpoints/hazardSections` を並列取得

### BE-003 Festival更新
- メソッド: `FestivalUsecase.put(_ pack: FestivalPack, user: UserRole)`
- 入力: `FestivalPack`, `UserRole`
- 出力: `FestivalPack`
- 権限: `headquarter(id)` かつ `id == pack.festival.id`
- 副作用: Festival本体更新 + Checkpoint/HazardSection差分更新

## 2.2 District

### BE-010 District一覧取得
- メソッド: `DistrictUsecase.query(by regionId: String)`
- 入力: `festivalId`
- 出力: `[District]`
- 権限: なし（公開）
- 副作用: なし（読み取り）

### BE-011 District詳細取得
- メソッド: `DistrictUsecase.get(_ id: String)`
- 入力: `districtId`
- 出力: `DistrictPack`
- 権限: なし（公開）
- 副作用: District + Performance群取得

### BE-012 District作成（招待）
- メソッド: `DistrictUsecase.post(user:headquarterId:newDistrictName:email:)`
- 入力: `UserRole`, `festivalId`, 新規町名, メール
- 出力: `DistrictPack`
- 権限: `headquarter(id)` かつ `id == headquarterId`
- 副作用: ID生成・重複確認・Cognito招待・District作成

### BE-013 District更新
- メソッド: `DistrictUsecase.put(id:item:user:)`
- 入力: `districtId`, `DistrictPack`, `UserRole`
- 出力: `DistrictPack`
- 権限: `district(id)` かつ `id == districtId`
- 副作用: District更新 + Performance差分更新

## 2.3 Route

### BE-020 Route詳細取得
- メソッド: `RouteUsecase.get(id:user:)`
- 入力: `routeId`, `UserRole`
- 出力: `RouteDetailPack`
- 権限: `Visibility` に応じて制御（admin非公開あり）
- 副作用: Route取得 + District参照 + Point群取得

### BE-021 Route一覧取得
- メソッド: `RouteUsecase.query(by:type:now:user:)`
- 入力: `districtId`, `RouteQueryType(all/year/latest)`, `now`, `UserRole`
- 出力: `[Route]`
- 権限: `Visibility` フィルタ適用
- 副作用: 年度条件に応じてRoute取得

### BE-022 Route作成
- メソッド: `RouteUsecase.post(districtId:pack:user:)`
- 入力: `districtId`, `RouteDetailPack`, `UserRole`
- 出力: `RouteDetailPack`
- 権限: `user.id == districtId` かつ `pack.route.districtId == user.id`
- 副作用: Route保存 + Point差分更新

### BE-023 Route更新
- メソッド: `RouteUsecase.put(id:pack:user:)`
- 入力: `routeId`, `RouteDetailPack`, `UserRole`
- 出力: `RouteDetailPack`
- 権限: 既存Routeの `districtId == user.id`
- 副作用: Route保存 + Point差分更新

### BE-024 Route削除
- メソッド: `RouteUsecase.delete(id:user:)`
- 入力: `routeId`, `UserRole`
- 出力: なし
- 権限: 既存Routeの `districtId == user.id`
- 副作用: Route削除

## 2.4 Location

### BE-030 祭典内Location一覧取得
- メソッド: `LocationUsecase.query(by:user:now:)`
- 入力: `festivalId`, `UserRole`, `now`
- 出力: `[FloatLocation]`
- 権限: 管理者は常時可、一般は期間内のみ
- 副作用: Period判定（公開時間制御）

### BE-031 DistrictのLocation取得
- メソッド: `LocationUsecase.get(districtId:user:now:)`
- 入力: `districtId`, `UserRole`, `now`
- 出力: `FloatLocation?`
- 権限: 管理者/当該districtは可、一般は期間内のみ
- 副作用: District解決 + Period判定

### BE-032 Location更新
- メソッド: `LocationUsecase.put(_ location:user:)`
- 入力: `FloatLocation`, `UserRole`
- 出力: `FloatLocation`
- 権限: `user.id == location.districtId`
- 副作用: Location保存

### BE-033 Location削除
- メソッド: `LocationUsecase.delete(districtId:user:)`
- 入力: `districtId`, `UserRole`
- 出力: なし
- 権限: `user.id == districtId`
- 副作用: Location削除

## 2.5 Period

### BE-040 Period取得
- メソッド: `PeriodUsecase.get(id:)`
- 入力: `periodId`
- 出力: `Period`
- 権限: なし（公開）
- 副作用: なし（読み取り）

### BE-041 Period一覧取得（年指定）
- メソッド: `PeriodUsecase.query(by:year:)`
- 入力: `festivalId`, `year`
- 出力: `[Period]`
- 権限: なし（公開）
- 副作用: なし（読み取り）

### BE-042 Period一覧取得（全件）
- メソッド: `PeriodUsecase.query(by:)`
- 入力: `festivalId`
- 出力: `[Period]`
- 権限: なし（公開）
- 副作用: なし（読み取り）

### BE-043 Period作成
- メソッド: `PeriodUsecase.post(festivalId:period:user:)`
- 入力: `festivalId`, `Period`, `UserRole`
- 出力: `Period`
- 権限: `headquarter(id)` かつ `id == festivalId == period.festivalId`
- 副作用: Period保存

### BE-044 Period更新
- メソッド: `PeriodUsecase.put(festivalId:period:user:)`
- 入力: `festivalId`, `Period`, `UserRole`
- 出力: `Period`
- 権限: 作成と同様
- 副作用: Period保存

### BE-045 Period削除
- メソッド: `PeriodUsecase.delete(id:user:)`
- 入力: `periodId`, `UserRole`
- 出力: なし
- 権限: 対象Periodの `festivalId` と `headquarter(id)` 一致
- 副作用: Period削除

## 2.6 Scene（起動用集約取得）

### BE-050 Festival起点の起動データ取得
- メソッド: `SceneUsecase.fetchLaunchFestivalPack(festivalId:user:now:)`
- 入力: `festivalId`, `UserRole`, `now`
- 出力: `LaunchFestivalPack`
- 権限: roleに応じて返却内容を制御（admin/public）
- 副作用: adminはマスタを広く返却、publicは公開向け絞り込み

### BE-051 District起点のFestival起動データ取得
- メソッド: `SceneUsecase.fetchLaunchFestivalPack(districtId:user:now:)`
- 入力: `districtId`, `UserRole`, `now`
- 出力: `LaunchFestivalPack`
- 権限: BE-050に準拠
- 副作用: districtからfestivalを解決してBE-050へ委譲

### BE-052 District起点の詳細起動データ取得
- メソッド: `SceneUsecase.fetchLaunchDistrictPack(districtId:user:now:)`
- 入力: `districtId`, `UserRole`, `now`
- 出力: `LaunchDistrictPack`
- 権限: Route visibilityに応じてルートを絞り込み
- 副作用: currentRoute算出 + Point読込

## 3. iOS Application Usecase / Service

注記: フロントのエラーハンドリングは整備途中のため、ここでは詳細ポリシーを深掘りしない。

## 3.1 SceneUsecase（起動・選択）

### IOS-001 アプリ起動
- メソッド: `SceneUsecase.launch()`
- 入力: なし（UserDefaults, Auth状態を内部参照）
- 出力: `LaunchState`
- 権限: 認証状態に応じて `guest/district/headquarter` を判定
- 副作用: DB初期同期、既定festival/districtの読込、状態分岐

### IOS-002 サインイン
- メソッド: `SceneUsecase.signIn(username:password:)`
- 入力: ユーザ名, パスワード
- 出力: `SignInResult`
- 権限: AuthProvider結果に準拠
- 副作用: roleに応じた初期データ取得 + UserDefaults更新

### IOS-003 初回サインイン確定
- メソッド: `SceneUsecase.confirmSignIn(password:)`
- 入力: 新パスワード
- 出力: `Result<UserRole, AuthError>`
- 権限: AuthProvider結果に準拠
- 副作用: IOS-002と同様

### IOS-004 Festival選択
- メソッド: `SceneUsecase.select(festivalId:)`
- 入力: `festivalId`
- 出力: なし
- 権限: なし
- 副作用: Festival同期 + UserDefaults更新（district解除）

### IOS-005 District選択
- メソッド: `SceneUsecase.select(districtId:)`
- 入力: `districtId`
- 出力: `Route.ID?`（current）
- 権限: なし
- 副作用: District同期 + UserDefaults更新

## 3.2 AuthService（認証操作）

### IOS-010 認証初期化
- メソッド: `AuthService.initialize()`
- 入力: なし
- 出力: なし
- 副作用: Amplify Auth初期化

### IOS-011 ログイン/ログアウト/トークン取得
- メソッド: `signIn`, `signOut`, `getAccessToken`, `getUserRole`
- 入力: 認証情報
- 出力: `SignInResult` / `Result<UserRole, AuthError>` / `String?`
- 副作用: 内部 `userRole` 状態更新、AuthProvider連携

### IOS-012 アカウント操作
- メソッド: `changePassword`, `resetPassword`, `confirmResetPassword`, `updateEmail`, `confirmUpdateEmail`
- 入力: 各操作パラメータ
- 出力: `Result<Empty, AuthError>` または `UpdateEmailResult`
- 副作用: AuthProviderへの委譲

## 3.3 LocationService（位置情報配信）

### IOS-020 位置追跡開始
- メソッド: `LocationService.start(id:interval:)`
- 入力: `districtId`, `Interval`
- 出力: なし
- 権限: 呼び出し元フローで制御
- 副作用: 追跡タスク開始、位置取得、閾値間隔送信、履歴更新

### IOS-021 位置追跡停止
- メソッド: `LocationService.stop(id:)`
- 入力: `districtId`
- 出力: なし
- 副作用: 追跡停止、位置削除API呼び出し、履歴更新

### IOS-022 位置履歴・状態参照
- メソッド: `getLocationHistory`, `historyStream`, `getIsTracking`, `getInterval`, `getLocation`
- 入力: なし
- 出力: 履歴/状態/現在位置
- 副作用: なし（参照中心）

## 4. 関連仕様

- ドメイン正本: `docs/spec/domain-model.md`
- As-Is構造: `docs/spec/architecture-overview.md`
- テスト戦略: `docs/spec/test-strategy.md`
