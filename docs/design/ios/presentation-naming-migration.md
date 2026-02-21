# Presentation層 命名リファクタ案（候補一覧）

目的: iOS Presentation 層の命名を揃えて、TCA(Feature) と SwiftUI(View) の責務が名前から分かるようにする。

このドキュメントは **「変換候補の列挙」まで**。実際のリネームは別PR/別作業で段階的に行う想定。

ステータス: **2026-02-19 に本ドキュメントの方針でリネーム実施済み**（以降、表の「現在」は“実施前”の名称・パスとして参照）。

---

## ルール案（提案）

### 1) TCA: `@Reducer` は `XXXFeature`
- `@Reducer struct XXX { ... }` の `XXX` は `XXXFeature` に統一する。
- 既に `XXXFeature` のものはそのまま。

### 2) View: `XXXStoreView` は `XXXView`
- `struct XXXStoreView: View` は `struct XXXView: View` に統一する（`StoreView` サフィックスを廃止）。
- ファイル名も原則型名に合わせる（`XXXStoreView.swift` → `XXXView.swift`）。

### 3) 管理者画面: `Admin` プレフィックスを外す
- 管理者画面の型名先頭に付く `Admin` を外す（例: `AdminDistrictEdit` → `DistrictEdit...`）。
- **スコープ/衝突回避はディレクトリで担保**する（例: `Presentation/StoreView/Admin/...` 配下で `Admin` を外す）。

### 4) 編集画面: `<Entity>Edit` に揃える
- 編集系は `<Entity>Edit`（+ Feature/View ルール）に寄せる。
  - Reducer: `<Entity>EditFeature`
  - View: `<Entity>EditView`

### 5) 管理者トップ: `XXXDashboard`
- 管理者のトップページは `XXXDashboard`（+ Feature/View ルール）に揃える。

---

## 変換候補（自動抽出 + 手整理）

以下は現状コードから拾えた「Presentation層の候補」。

### A) `@Reducer` なのに `Feature` が付いていないもの

| 現在 | 候補 |
|---|---|
| `Home` (`iOSApp/Sources/Presentation/StoreView/App/Home/Home.swift`) | `HomeFeature`（同ファイルを `HomeFeature.swift` に） |
| `Settings` (`iOSApp/Sources/Presentation/StoreView/App/Settings/Settings.swift`) | `SettingsFeature`（`SettingsFeature.swift`） |
| `Login` (`iOSApp/Sources/Presentation/StoreView/Auth/Login/LogIn.swift`) | `LoginFeature`（ファイル名も `LoginFeature.swift` に寄せる） |
| `ConfirmSignIn` (`iOSApp/Sources/Presentation/StoreView/Auth/CorfirmSignIn/ConfirmSignIn.swift`) | `ConfirmSignInFeature` |
| `ResetPassword` (`iOSApp/Sources/Presentation/StoreView/Auth/ResetPassword/ResetPassword.swift`) | `ResetPasswordFeature` |
| `ChangePassword` (`iOSApp/Sources/Presentation/StoreView/Auth/ChangePassword/ChangePassword.swift`) | `ChangePasswordFeature` |
| `UpdateEmail` (`iOSApp/Sources/Presentation/StoreView/Auth/UpdateEmail/UpdateEmail.swift`) | `UpdateEmailFeature` |
| `PublicMap` (`iOSApp/Sources/Presentation/StoreView/Public/Map/Root/PublicMap.swift`) | `PublicMapFeature` |
| `PublicLocations` (`iOSApp/Sources/Presentation/StoreView/Public/Map/Locations/PublicLocations.swift`) | `PublicLocationsFeature` |
| `PublicRoute` (`iOSApp/Sources/Presentation/StoreView/Public/Map/Route/PublicRoute.swift`) | `PublicRouteFeature` |
| `DistrictInfo` (`iOSApp/Sources/Presentation/StoreView/Public/Info/District/DistrictInfo.swift`) | `DistrictInfoFeature` |
| `FestivalInfo` (`iOSApp/Sources/Presentation/StoreView/Public/Info/Region/RegionInfo.swift`) | `FestivalInfoFeature`（ファイル名も合わせる） |
| `Alert` (`iOSApp/Sources/Presentation/StoreView/Shared/Alert.swift`) | `AlertFeature`（`Alert` 衝突/可読性の観点で要検討） |

### B) `StoreView` サフィックスの View

| 現在 | 候補 |
|---|---|
| `HomeStoreView` (`iOSApp/Sources/Presentation/StoreView/App/Home/HomeStoreView.swift`) | `HomeView`（`HomeView.swift`） |
| `OnboardingStoreView` (`iOSApp/Sources/Presentation/StoreView/App/Onboarding/OnboardingStoreView.swift`) | `OnboardingView`（`OnboardingView.swift`） |
| `SettingsStoreView` (`iOSApp/Sources/Presentation/StoreView/App/Settings/SettingsStoreView.swift`) | `SettingsView` |
| `LoginStoreView` (`iOSApp/Sources/Presentation/StoreView/Auth/Login/LogInStoreView.swift`) | `LoginView`（ファイル名も `LoginView.swift` に寄せる） |
| `ConfirmSignInStoreView` (`iOSApp/Sources/Presentation/StoreView/Auth/CorfirmSignIn/ConfirmSignInStoreView.swift`) | `ConfirmSignInView` |
| `ResetPasswordStoreView` (`iOSApp/Sources/Presentation/StoreView/Auth/ResetPassword/ResetPasswordStoreView.swift`) | `ResetPasswordView` |
| `ChangePasswordStoreView` (`iOSApp/Sources/Presentation/StoreView/Auth/ChangePassword/ChangePasswordStoreView.swift`) | `ChangePasswordView` |
| `UpdateEmailStoreView` (`iOSApp/Sources/Presentation/StoreView/Auth/UpdateEmail/UpdateEmailStoreView.swift`) | `UpdateEmailView` |
| `PublicMapStoreView` (`iOSApp/Sources/Presentation/StoreView/Public/Map/Root/PublicMapStoreView.swift`) | `PublicMapView` |
| `PublicLocationsMapStoreView` (`iOSApp/Sources/Presentation/StoreView/Public/Map/Locations/PublicLocationsMapStoreView.swift`) | `PublicLocationsMapView` |
| `DistrictInfoStoreView` (`iOSApp/Sources/Presentation/StoreView/Public/Info/District/DistrictInfoStoreView.swift`) | `DistrictInfoView` |
| `FestivalInfoStoreView` (`iOSApp/Sources/Presentation/StoreView/Public/Info/Region/RegionInfoStoreView.swift`) | `FestivalInfoView`（ファイル名も合わせる） |

### C) 管理者画面（`Admin` プレフィックス外し + Dashboard/Edit）

#### District 管理（現: `AdminDistrictTop` 系）
| 現在 | 候補 |
|---|---|
| `AdminDistrictTop` (`iOSApp/Sources/Presentation/StoreView/Admin/District/Top/AdminDistrictTop.swift`) | `DistrictDashboardFeature`（`.../DistrictDashboardFeature.swift`） |
| `AdminDistrictView` (`iOSApp/Sources/Presentation/StoreView/Admin/District/Top/AdminDistrictTopStoreView.swift`) | `DistrictDashboardView`（`.../DistrictDashboardView.swift`） |
| `AdminDistrictEdit` (`iOSApp/Sources/Presentation/StoreView/Admin/District/Edit/AdminDistrictEdit.swift`) | `DistrictEditFeature` |
| `AdminDistrictEditView` (`iOSApp/Sources/Presentation/StoreView/Admin/District/Edit/AdminDistrictEditStoreView.swift`) | `DistrictEditView` |

#### District Edit のサブ画面（現: `AdminBase/Area/Performance`）
| 現在 | 候補 |
|---|---|
| `AdminBaseEdit` (`iOSApp/Sources/Presentation/StoreView/Admin/District/Edit/Base/AdminBaseEdit.swift`) | `DistrictBaseEditFeature`|
| `AdminBaseView` (`iOSApp/Sources/Presentation/StoreView/Admin/District/Edit/Base/AdminBaseEditStoreView.swift`) | `DistrictBaseEditView` |
| `AdminAreaEdit` (`iOSApp/Sources/Presentation/StoreView/Admin/District/Edit/Area/AdminAreaEdit.swift`) | `DistrictAreaEditFeature` |
| `AdminAreaView` (`iOSApp/Sources/Presentation/StoreView/Admin/District/Edit/Area/AdminAreaEditStoreView.swift`) | `DistrictAreaEditView` |
| `AdminPerformanceEdit` (`iOSApp/Sources/Presentation/StoreView/Admin/District/Edit/Performance/AdminPerformanceEdit.swift`) |  `PerformanceEditFeature` |
| `AdminPerformanceView` (`iOSApp/Sources/Presentation/StoreView/Admin/District/Edit/Performance/AdminPerformanceEditStoreView.swift`) | `PerformanceEditView` |

#### 管理者専用の地図/部品（`Presentation/View` 配下）
| 現在 | 候補 |
|---|---|
| `AdminDistrictMap` (`iOSApp/Sources/Presentation/View/Map/AdminDistrictMapView.swift`) | 対象外 |
| `AdminLocationMap` (`iOSApp/Sources/Presentation/View/Map/AdminLocationMapView.swift`) | 対象外 |
| `AdminRouteItem` (`iOSApp/Sources/Presentation/View/Item/AdminRouteItemView.swift`) | 対象外 |

---

## 追加で見つかった命名の揺れ（今回のルール外だが併せて直すと良さそう）

- `Auth/CorfirmSignIn` ディレクトリ名が `Confirm` の誤字っぽい（`Corfirm`）。　やる
- `Auth/Login/LogIn.swift` は型が `Login` なので、ファイル名が揺れている。　`Login`に統一
- `Public/Info/Region/RegionInfo*.swift` は中身が `FestivalInfo*`。 RegionはFestivalに改名済み　MapKitのRegionと混同するため
- `AdminLocationMapView.swift` のヘッダコメントが `LocationAdminMapView.swift` になっている。　ヘッダはファイル名に合わせる

---

## 要確認（決めたいこと）

1. `Dashboard` の綴りは `Dashboard` で良い？（指示の `Dashbord` は誤字想定）`Dashboard`
2. Admin を外した後、衝突しそうな型（例: `DistrictEdit...`）は「フォルダで区別」でOK？ 実際に衝突した場合にはドキュメントに追記
3. `AdminBaseEdit` / `AdminAreaEdit` / `AdminPerformanceEdit` の `Entity` は `District` を付ける方針で良い？　変換候補に正しい案を上書き済み
4. `Alert` は `AlertFeature` に改名する？（Appleの `Alert` と混ざりやすい）　はい
