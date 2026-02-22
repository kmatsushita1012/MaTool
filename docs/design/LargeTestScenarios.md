# iOSApp Large Test Scenarios

iOSApp の主要ユーザー導線に対して、回帰時の影響が大きいシナリオを優先度付きで定義する。

## 前提

- テスト対象: `iOSApp`
- テスト環境: iOS Simulator (最新安定OS)
- データ前提:
  - 祭典データが 1 件以上存在する
  - district ユーザー / headquarter ユーザー / guest 動線を実行できる
  - district には有効 route があるケースと、配信停止中のケースを用意する

## 重要シナリオ一覧

| ID | 優先度 | シナリオ | 手順（要約） | 期待結果 |
|---|---|---|---|---|
| LT-01 | P0 | 初回起動での Onboarding 遷移 | デフォルト祭典未設定で起動する | Onboarding が表示され、祭典一覧が選択可能 |
| LT-02 | P0 | Onboarding で祭典選択後に guest で進む | 祭典を選択し「見に行く」を選ぶ | Home に遷移し、guest で map/info を開ける |
| LT-03 | P0 | Onboarding で district 選択後に district map へ遷移 | 祭典選択後に district を選ぶ | district コンテキストで Home が開き route が表示される |
| LT-04 | P0 | guest から admin ログイン（headquarter） | Home で admin を開き headquarter でログイン | FestivalDashboard に遷移し、管理機能が表示される |
| LT-05 | P0 | guest から admin ログイン（district） | Home で admin を開き district でログイン | DistrictDashboard に遷移し、担当 district の機能のみ表示される |
| LT-06 | P0 | 設定画面で祭典切り替え | Settings で festival を変更し閉じる | Home 復帰後に map/info が新祭典データで開く |
| LT-07 | P1 | 設定画面で signOut | headquarter または district で signOut 実行 | Home の userRole が guest になり admin はログイン導線へ戻る |
| LT-08 | P1 | PublicMap: route 配信停止中アラート | route 未配信 district を選択する | 「配信停止中です。」通知が表示される |
| LT-09 | P1 | PublicMap: district 切り替え時のロード完了 | route あり district を連続で切り替える | ローディング解除後に選択 district の route が表示される |
| LT-10 | P1 | Info 画面の祭典未設定エラー | defaultFestival 未設定状態で info を開く | 祭典選択を促すエラーが表示される |
| LT-11 | P2 | 起動時の認証失敗フォールバック | 認証取得でエラーを発生させて起動 | クラッシュせず guest 扱いで festival/district 遷移が継続 |
| LT-12 | P2 | 設定画面の district 取得失敗 | festival 切り替え時に district fetch を失敗させる | エラー表示され、画面操作が継続できる |

## 重点確認ポイント

- 状態整合性:
  - `defaultFestivalId` / `defaultDistrictId` が画面遷移と一致して更新されること
  - signIn / confirmSignIn / signOut 後に `HomeFeature.State.userRole` が期待どおりであること
- UX品質:
  - ローディング中に二重操作で不整合が起きないこと
  - エラー時に画面遷移不能にならないこと
- データ同期:
  - festival 切替や role 変更時に stale データが残らないこと

## 実装順（推奨）

1. P0 を UI テスト自動化対象にする（LT-01 〜 LT-06）
2. P1 は回帰頻度が高いものから段階的に自動化する（LT-07 〜 LT-10）
3. P2 は依存差し替えベースの統合テストと組み合わせて実施する（LT-11, LT-12）

## 参照

- `iOSApp/Sources/Application/SceneUsecase.swift`
- `iOSApp/Sources/Presentation/View/App/Home/HomeFeature.swift`
- `iOSApp/Sources/Presentation/View/App/Onboarding/Onboarding.swift`
- `iOSApp/Sources/Presentation/View/App/Settings/SettingsFeature.swift`
- `iOSApp/Sources/Presentation/View/Public/Map/Root/PublicMapFeature.swift`
