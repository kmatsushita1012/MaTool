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

## テスト計画

### 1. 目的

- 広告表示条件が要件どおりに動作することを確認する。
- PublicMap の既存挙動を壊さずに広告導線が追加されていることを確認する。
- 「配信停止中」のような表示不能ケースで広告カウントが進まないことを確認する。
- バナー追加によって詳細シートのレイアウトや操作性が崩れないことを確認する。

### 2. テストレベル

- Unit Test
  - 広告ポリシー
  - PublicMap 向け広告ユースケース
  - 起動時 / 町切替時の例外系判定
- Integration Test
  - `PublicMapFeature` と `PublicRouteFeature` のイベント接続
  - `SceneDataFetcher` 成功 / 失敗時の広告制御
- Manual Test
  - Simulator / 実機でのインタースティシャル表示タイミング
  - シート内バナーの見え方
  - 広告表示後の画面復帰と状態維持

### 3. 実施順

1. Unit Test で広告表示条件とカウント条件を固定する。
2. Feature レベルで町切替 / period切替 / 配信停止中ケースの導線を確認する。
3. Manual Test で AdMob 実表示時の復帰、導線、レイアウトを確認する。
4. リリース前確認で development 用広告 ID と production 用広告 ID の設定差分を確認する。

### 4. 完了条件

- 主要な広告判定ロジックが Unit Test で再現できる。
- PublicMap の「町切替」「period切替」「現在地一覧」が想定どおり分岐する。
- 配信停止中ケースでアラート表示と広告カウント抑止の両方が確認できる。
- バナー表示有無で `PointView` / `LocationView` のコンテンツが崩れない。

## テストケース

### A. 広告ポリシー Unit Test

1. 本部権限では広告を表示しない
   - 条件: `UserRole.headquarter`
   - 期待: `shouldShowInterstitial == false`
   - 期待: カウントは増えない

2. お気に入り町では広告を表示しない
   - 条件: `targetDistrictId == defaultDistrictId`
   - 期待: `shouldShowInterstitial == false`
   - 期待: カウントは増えない

3. 各町権限ユーザーの自町では広告を表示しない
   - 条件: `UserRole.district(selfDistrictId)` かつ `targetDistrictId == selfDistrictId`
   - 期待: `shouldShowInterstitial == false`
   - 期待: カウントは増えない

4. お気に入り外の町では 3回に1回表示する
   - 条件: お気に入りあり、遷移先はお気に入り外
   - 期待: 1回目・2回目は非表示、3回目で表示

5. お気に入りも権限もない guest は最初の5回をスキップする
   - 条件: `favoriteDistrictId == nil` かつ `UserRole.guest`
   - 期待: 1回目から5回目まで非表示

6. お気に入りも権限もない guest は 6回目以降 3回に1回表示する
   - 条件: 上記継続
   - 期待: 6回目で表示、7回目・8回目は非表示、9回目で表示

### B. PublicMapAdUsecase Unit Test

1. 町切替 API 成功時は routeId を返す
   - 条件: `launchDistrict` 成功
   - 期待: `routeId` が呼び出し元へ返る

2. 町切替 API 失敗時は広告表示しない
   - 条件: `launchDistrict` 失敗
   - 期待: `presentInterstitial` が呼ばれない
   - 期待: カウントは増えない

3. 表示可能コンテンツがない町では広告カウントを進めない
   - 条件: `routes.isEmpty && float == nil`
   - 期待: `handleDistrictSelectionResult(..., hasDisplayableContent: false)` でカウント不変
   - 期待: `presentInterstitial` が呼ばれない

4. 表示可能コンテンツがある町では広告判定を進める
   - 条件: `routes` または `float` が存在
   - 期待: カウント更新と表示判定が走る

5. period切替では API 成功 / 失敗に依存せず広告判定を行う
   - 条件: `handlePeriodSelection(...)`
   - 期待: カウントと表示判定のみ実行される

### C. PublicMapFeature / Presentation Test

1. 初回表示でルートも現在地もない場合にアラートが出る
   - 条件: `destination.route.routes.isEmpty && destination.route.float == nil`
   - 期待: `AlertFeature.notice("配信停止中です。")`

2. 町タブ切替後にルートも現在地もない場合にアラートが出る
   - 条件: 町切替後の `routePrepared` 時点で表示可能コンテンツなし
   - 期待: アラートが表示される
   - 期待: 広告カウントは増えない

3. 町タブ切替後にルートまたは現在地がある場合は通常表示される
   - 条件: `routes` または `float` が存在
   - 期待: アラートなし
   - 期待: 広告判定のみ実行される

4. `現在地一覧` 切替では広告カウントを進めない
   - 条件: `contentSelected(.locations)`
   - 期待: 広告表示なし
   - 期待: カウント不変

5. 同じタブの再タップでは広告カウントを進めない
   - 条件: 既に選択中のタブを再タップ
   - 期待: イベント不発
   - 期待: カウント不変

6. period切替時に広告判定が呼ばれる
   - 条件: `destination(.presented(.route(.selected(...))))`
   - 期待: `handlePeriodSelection(...)` が呼ばれる

### D. 詳細シート / バナー Manual Test

1. `PointView` 表示時に本文直下へバナー領域が出る
   - 条件: バナー広告ロード成功
   - 期待: テキスト直下に広告が出る
   - 期待: CTA や本文が隠れない

2. `LocationView` 表示時に本文直下へバナー領域が出る
   - 条件: バナー広告ロード成功
   - 期待: レイアウト崩れなし

3. バナー未ロード時に高さゼロ相当で崩れない
   - 条件: 広告ロード失敗または unit ID 無効
   - 期待: シート本文だけが表示される
   - 期待: 不自然な余白が残らない

4. シートの detent 切替でバナーが重ならない
   - 条件: `.fraction(0.3)`, `.medium`, `.large`
   - 期待: いずれも本文スクロールやタップを阻害しない

### E. 運用確認 Manual Test

1. インタースティシャル表示後に Onboarding へ戻らない
   - 条件: 広告を閉じる
   - 期待: 直前の PublicMap / Home 導線へ復帰
   - 期待: `defaultFestivalId` / `defaultDistrictId` が維持される

2. アプリ再起動後も保存済み festival / district が維持される
   - 条件: 広告表示後にアプリ再起動
   - 期待: onboarding へ戻らない

3. 配信停止中の町を跨いでも広告の表示タイミングが前倒しされない
   - 条件: カウント対象町と配信停止中町を交互に切替
   - 期待: 配信停止中町の訪問でカウントは進まない

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
