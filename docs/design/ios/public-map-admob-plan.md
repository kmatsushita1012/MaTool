# PublicMap AdMob導入計画

## Summary

- PublicMap の町タブ切替と period 切替を契機に、条件付きでインタースティシャル広告を表示する。
- `PointView` / `LocationView` のシート下部にバナー広告を表示する。
- 広告SDK直接呼び出しを Presentation に置かず、Infrastructure の広告マネージャと Application のユースケースを挟んで判定・ロード・表示を制御する。

## 目的

- 広告表示条件を画面実装から分離し、権限・お気に入り・遷移回数に応じた制御を一箇所に集約する。
- PublicMap の既存データ取得フローを壊さず、タブ切替時の API アクセスと広告制御を同じユースケースで扱えるようにする。
- バナー広告を詳細シートのレイアウトに自然に組み込み、今後の差し替えや非表示条件追加に備える。

## 要件整理

### 1. インタースティシャル表示対象

- 対象画面: `iOSApp/Sources/Presentation/View/Public/Map/Root/PublicMapView.swift`
- 対象操作:
  - 町タブに切り替えた時
  - 町タブ内で period を切り替えた時
- 非対象:
  - `現在地一覧` タブ

### 2. インタースティシャル表示条件

- 本部権限 (`UserRole.headquarter`) の場合は表示しない。
- お気に入りの町 (`UserDefaults` の `defaultDistrictId`) が登録されている場合:
  - お気に入り対象の町では表示しない。
  - お気に入り以外の町を見た時のみ 3回に1回 表示する。
  - 「お気に入りの町が登録されている場合(各町権限を含む)」という要件から、ログイン中の自町も除外対象に含める前提で設計する。
- お気に入り登録も各町権限もない場合:
  - すべての町で 3回に1回 表示する。
  - ただし画面を開いた直後は最初の5回まで表示を許容しない。

### 3. バナー表示対象

- 対象画面:
  - `iOSApp/Sources/Presentation/View/Public/Map/Details/PointView.swift`
  - `iOSApp/Sources/Presentation/View/Public/Map/Details/LocationView.swift`
- 表示位置:
  - シートコンテンツのすぐ下
  - スクロールではなくシート下部固定が基本候補

## 現状整理

- `PublicMapFeature` は町タブ切替時に `sceneDataFetcher.launchDistrict` を直接呼んでいる。
- `PublicRouteFeature` から `selected(RouteEntry)` を受け、`PublicMapFeature.currentPeriodId` を更新している。
- period 切替そのものを広告イベントとして扱う処理は未実装。
- `PointView` / `LocationView` は単純な `VStack` で、広告を差し込む専用コンテナを持たない。
- iOSApp 内に AdMob / `GoogleMobileAds` 依存や広告抽象化レイヤは見当たらない。
- お気に入りの町は `UserDefaults` の `defaultDistrictId` を参照すれば取得できる。

## 設計方針

### 1. 層構成

- Domain:
  - 広告判定に必要な最小限の値オブジェクトまたはポリシー入力モデルを追加する。
  - 例: `PublicMapAdContext`, `PublicMapAdDecision`
- Application:
  - PublicMap 向け広告制御ユースケースを追加する。
  - 町切替・period切替時の API 呼び出しと広告判定をまとめる。
- Data / Infrastructure:
  - AdMob SDK をラップする広告マネージャを追加する。
  - 表示回数カウントやプリロード状態の永続化が必要なら `UserDefaultsClient` を利用する。
- Presentation:
  - `PublicMapFeature` はユースケース呼び出しと表示トリガ受信に専念する。
  - `PointView` / `LocationView` は広告コンテナ View を組み込むだけに留める。

### 2. 追加コンポーネント案

#### Application

- `PublicMapAdUsecaseProtocol`
  - `prepareInterstitialIfNeeded()`
  - `handleDistrictSelection(...)`
  - `handlePeriodSelection(...)`
- 役割:
  - APIアクセスが必要なタブ切替では `SceneDataFetcher` 呼び出しと広告判定を直列制御
  - カウント更新
  - 表示対象かどうかの判定
  - 表示する場合は広告マネージャへ表示要求

#### Infrastructure

- `AdManagerProtocol`
  - `loadInterstitial(placement:)`
  - `presentInterstitial(placement:)`
  - `bannerView(placement:)`
- `AdManager`
  - AdMob SDK への依存を閉じ込める実装
  - インタースティシャルのロード済み管理
  - バナー用 `UIViewRepresentable` またはラッパー View の供給

#### Persistence / Local State

- `PublicMapAdCounterStore`
  - `UserDefaultsClient` ベースを候補とする
  - 保存候補:
    - 町切替 / period切替の累積カウント
    - 初回5回スキップ用カウント
    - 最後に表示したタイミング（必要なら）
- お気に入り町判定:
  - 既存の `UserDefaults` 値 `defaultDistrictId` を読み取り、お気に入り町IDとして扱う

## 詳細仕様

### 1. インタースティシャルのカウント対象イベント

- カウントする:
  - `PublicMapFeature.Action.contentSelected(.route(_))`
  - `PublicRouteFeature` 内で period を切り替えた操作
- カウントしない:
  - `現在地一覧` への切替
  - 同じタブを再タップしただけの操作
  - 本部権限ユーザーの操作

### 2. 判定フロー

#### ケースA: 本部権限

- 常に非表示
- カウントも行わない方針を第一候補とする

#### ケースB: お気に入りまたは各町権限あり

- 除外対象町一覧を作る:
  - `UserDefaults.defaultDistrictId`
  - ログイン中の各町権限ユーザーなら自町ID
- 遷移先町が除外対象:
  - 非表示
  - カウント対象外にする方針で統一する
- 遷移先町が除外対象外:
  - 対象イベントごとにカウント
  - 3回に1回表示

#### ケースC: お気に入りなし、各町権限なし

- すべての町タブを対象とする
- 最初の5回は表示しない
- 6回目以降は 3回に1回表示

### 3. APIアクセスとの関係

- 町切替時:
  - 既存どおり `launchDistrict` を実行
  - データ取得成功後に広告判定・表示を行う
  - 失敗時は広告を表示しない
- period切替時:
  - 既存実装のままローカル状態更新のみで済むのか、再フェッチを伴うのか確認が必要
  - 計画上は「広告判定とカウントは API有無に依存しない」構成で切り出す

### 4. バナー広告表示

- `PointView` / `LocationView` に共通の `PublicMapBannerAdSection` を追加する。
- レイアウト案:
  - `VStack { content; banner }`
  - 必要に応じて `.safeAreaInset(edge: .bottom)` を使用
- バナーのロード失敗時:
  - 高さゼロで広告領域を潰す
  - 画面本体のコンテンツは維持する

## 実装ステップ

### 1. Foundation / Dependency

1. AdMob SDK 導入有無を確認し、未導入なら依存追加方法を確定する。
2. 広告 placement 命名を決める。
   - `publicMapInterstitial`
   - `publicMapDetailBanner`
3. 広告 unit ID の注入方法を決める。
   - build config
   - plist
   - dependency key

### 2. Infrastructure

1. `AdManagerProtocol` と live 実装を追加する。
2. インタースティシャルの preload / present / reload サイクルを定義する。
3. バナー表示用ラッパー View を追加する。
4. カウンタ保存用ストアを追加する。

### 3. Application / Usecase

1. PublicMap 用広告ユースケースを追加する。
2. 判定入力として以下を集約する。
   - 現在の `UserRole`
   - 自町ID
   - お気に入り町ID (`defaultDistrictId`)
   - 遷移先町ID
   - イベント種別（町切替 / period切替）
3. 町切替時ユースケースで `launchDistrict` と広告表示可否判定を直列化する。
4. period切替時ユースケースでカウント更新と広告表示可否判定を行う。

### 4. Presentation

1. `PublicMapFeature` から `sceneDataFetcher.launchDistrict` 直接呼び出しを外し、ユースケース経由にする。
2. `PublicRouteFeature` の period 選択イベントを `PublicMapFeature` まで伝搬し、広告ユースケースを呼べるようにする。
3. `PointView` / `LocationView` にバナーセクションを追加する。
4. 広告表示中にタブ切替UIや loading overlay と競合しないよう画面遷移を調整する。

## 影響ファイル候補

- `iOSApp/Sources/Presentation/View/Public/Map/Root/PublicMapView.swift`
- `iOSApp/Sources/Presentation/View/Public/Map/Root/PublicMapFeature.swift`
- `iOSApp/Sources/Presentation/View/Public/Map/Route/PublicRouteFeature.swift`
- `iOSApp/Sources/Presentation/View/Public/Map/Details/PointView.swift`
- `iOSApp/Sources/Presentation/View/Public/Map/Details/LocationView.swift`
- `iOSApp/Sources/Application/SceneUsecase.swift`
- `iOSApp/Sources/Data/Client/UserDefaultsClient.swift`
- `iOSApp/Sources/Data/...` 配下の新規広告関連ファイル

## テスト観点

### ユースケース

1. 本部権限では常に広告が抑止される。
2. お気に入り登録済み町では広告が出ない。
3. お気に入り外の町では 3回に1回表示される。
4. 各町権限ユーザーは自町で広告が出ない。
5. お気に入りも権限もない guest は最初の5回をスキップし、その後 3回に1回表示される。
6. `現在地一覧` はカウントにも表示にも含まれない。
7. API失敗時は広告が表示されない。

### Presentation

1. 町タブ切替時に既存のルート読込が維持される。
2. period切替時に広告判定が呼ばれる。
3. `PointView` / `LocationView` のシート本文直下にバナー領域が出る。
4. バナー未ロード時もシートレイアウトが崩れない。

## 受け入れ条件

- PublicMap で `現在地一覧` 以外の町タブ切替時に、指定ルールどおりインタースティシャルが制御される。
- period切替でも同じカウントルールが適用される。
- 本部権限では一切表示されない。
- `PointView` / `LocationView` のシート下部にバナー広告が表示される。
- 広告SDK依存は Infrastructure に閉じ込められ、Presentation から直接参照しない。

## 未確定事項 / 確認事項

1. period切替イベントの現在の発火点
   - `PublicRouteFeature` のどの Action が最終的な切替確定イベントか確認が必要。
2. AdMob SDK と広告 unit ID
   - 依存追加済みか未導入か不明。
   - 開発用 / 本番用 unit ID の切替方法を決める必要がある。
3. カウント対象外イベントの扱い
   - 除外対象町・本部権限・現在地一覧でカウントを進めない前提でよいか確認が必要。
