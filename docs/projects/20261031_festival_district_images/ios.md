# Festival / District 紹介画像 — iOS 詳細設計

- 対象: `iOSApp` の Festival / District 管理者向け編集画面
- 上位仕様: [spec.md](./spec.md)（PR #380 でマージ済み）
- 本書の目的: **画像選択時に S3 一時アップロードし、元の編集画面で「保存」を押したときだけ正式反映**する iOS の画面・状態・通信設計を確定する
- 本 PR は設計書のみ。コード・画像・AWS 設定は変更しない

## 1. UX / 画面構成

### 1.1 Festival / District の既存編集画面

- `FestivalEditContentView` と `DistrictEditContentView` に「紹介画像」の項目を追加し、**「画像を変更」**ボタンでシートを開く。
- 既存の祭典名／町名、紹介文、所在地、交差点、余興などの編集欄や画面遷移は維持する。管理者の権限境界も変更しない。
- 編集画面に既存の「保存」・「キャンセル」を残す。**正式反映は編集画面の「保存」時のみ**。
- Light / Dark の選択や S3 一時アップロードの有無にかかわらず、編集画面の保存操作は従来の `FestivalPack` / `DistrictPack` PUT を使用する。

### 1.2 画像編集シート

`ImageEditSheet`（仮称）を `NavigationStack` を持つ `.sheet` として表示する。Festival / District で同じ内容を共用する。

1. **上部:** `Picker` を `.segmented`、`.controlSize(.large)` として表示。選択肢は **「ライト」「ダーク」**。既存 `RouteEditView.tab` の `.routeSegmentPickerStyle()` と同じ見た目を基準にする（必要なら限定的にスタイルを共通化）。
2. **中央:** 選択中のモードの画像プレビュー。未変更なら既存 `ImagePath.light/dark` の公開 URL、アップロード済みなら選択したローカル JPEG プレビューを表示する。未設定または参照解除予定ならプレースホルダー。
3. **下部:** 画像がなければ **「画像を追加」**、画像があれば **「画像を変更」**を表示し、`PhotosPicker` を開く。既存画像がある場合は「画像を削除」も用意し、削除は最終 PUT での `nil` による**参照解除のみ**。
4. **右上:** `xmark` の閉じるボタン。**シートを閉じても画像の編集結果（S3 アップロード済みの一時キーを含む）は元の編集画面に保持**する。シートには独立した「確定」「保存」ボタンは設けない。
5. シートを開き直すと直前のライト／ダークの選択・プレビュー・保留状態を再表示する。モードを切り替えても他方の編集内容は失われない。
6. 画像アップロード中は選択操作の重複と閉じる操作を抑制し、進捗を表示する。失敗した場合はエラーと再試行手段を示し、同じ画像を選択し直さなくても再送できるようにする。

`PhotosPicker` のキャンセルは画像変更なし。既存の画像が片方しかない場合も、**各モードを独立して編集**する。公開画面の「片方がない場合は他方へフォールバック」と、編集画面の「各モードに実在する画像を表示」は区別する。

### 1.3 重要な2段階確定

| 操作 | S3 一時オブジェクト | Backend 本番 Entity / 公開画像 |
| --- | --- | --- |
| シートを開く・ライト／ダークを切替 | 変更なし | 変更なし |
| **PhotosPicker で画像を選択** | **その場で署名 URL を取得し、直接 PUT** | **変更なし** |
| 選択した画像の一時 PUT が成功 | 一時キーを編集 State に保留 | 変更なし |
| シート右上 `xmark` | **一時キー・プレビューを保持** | 変更なし |
| 元の編集画面で「保存」 | **新たな一時 PUT は原則しない** | **既存 Pack PUT で正式反映** |
| 元の編集画面で「キャンセル」 | ローカル下書きを破棄。一時 S3 オブジェクトは Lifecycle で消える | 変更なし |

**上位仕様との変更点:** 旧 `spec.md` §6 にある「選択だけでは S3 に送信せず、保存時に初めてアップロード」は廃止し、本書の**選択時アップロード／編集画面保存時確定**を採用する。上位仕様の §6 も本 PR で合わせて改訂する。

## 2. TCA 状態と責務

### 2.1 編集 State が下書きの正本

`FestivalEditFeature.State` / `DistrictEditFeature.State` に、ライトとダークそれぞれの画像変更状態を保有する。**シートの表示状態を消しても下書きは消えない**。

| 状態（概念） | 意味 | 最終 PUT への変換 |
| --- | --- | --- |
| `unchanged` | 当初の公開 URL を保持 | 既存 `ImagePath` の値 |
| `uploading(localPreview)` | 選択直後、一時 S3 PUT 中 | 保存不可（未確定の一時キーを送らない） |
| `replace(temporaryPath, localPreview)` | S3 一時 PUT 完了、正式反映待ち | 対象 variant の `temporaryPath` |
| `failed(localPreview, error)` | アップロードに失敗 | 保存不可。再試行または選択取り消し |
| `remove` | 当該 variant の参照解除を保留 | `nil` |

これは実装モデルの**概念**であり、同等の Equatable/Sendable な State へ簡潔にまとめてよい。選択モード `light/dark` とシート開閉も Feature で扱う。画像用の永続 Entity や二重の Shared 状態は作らない。

- 既存 `festival.image` / `district.image` は正式保存されるまで変更しない。**未保存の一時キーを `AppState` に書かない**。
- シートの `PhotosPickerItem` は View 側の一時選択値。生の `UIImage` や PhotosPicker の寿命が短いファイル URL を TCA State に保持しない。
- `loadTransferable` 直後にアプリ管理の一時ファイルへコピーするか、安全に所有したデータから JPEG を生成する。完了後はその JPEG をプレビューとアップロード再試行に使用する。元の FileRepresentation の一時 URL を使い続けない。
- ローカル一時ファイルは選択し直した際の旧画像、画像削除、編集画面キャンセル、保存成功、編集 Feature の破棄時に片付ける。**シートの `xmark` では片付けない**。アップロード失敗中は再試行のため保持する。
- 同じ variant の連続選択は固定 S3 一時キーを上書きするため、選択・通信を直列化して古い完了が新しい下書きを上書きしないようにする。不要な汎用ジョブ管理は作らない。

### 2.2 Feature / View の配置

| ファイル | 変更内容 |
| --- | --- |
| `Presentation/View/Admin/Region/Edit/FestivalEditFeature.swift` | 画像下書き、シート表示、画像選択結果、アップロード成功／失敗、保存・キャンセル |
| `Presentation/View/Admin/Region/Edit/FestivalEditView.swift` | 「画像を変更」ボタン・シート表示を ContentView 側に構成 |
| `Presentation/View/Admin/District/Edit/DistrictEditFeature.swift` | 同上。現在の `DistrictPack` 保存を継続 |
| `Presentation/View/Admin/District/Edit/DistrictEditView.swift` | 同上 |
| 新規の共通 `ImageEditContentView`（名称案） | セグメント Picker、プレビュー、追加／変更／削除、`PhotosPicker`、右上 `xmark`、通信状態。**View は受け取った表示データと Action だけを扱う** |

既存ルールに従い、**ツールバーやシートの UI 構成は ContentView 側に置く**。`FestivalEditScreen` / `DistrictEditScreen` は Store を接続する薄いコンテナーとし、画面固有の画像管理ロジックをコピー＆ペーストしない。

## 3. Application / Data 層の処理

### 3.1 画像選択時に S3 一時アップロード

1. PhotosPicker の画像を読み込み、アプリ管理のローカル JPEG に変換・圧縮する。Client と Backend で合意した画素数・バイト数制限を守る（値を独自に決めない）。
2. 共通 `POST /images/upload-url` を、**既存の認証付き `HTTPClient`** から呼び出す。Shared 側の `ImageUploadURLRequest` / `ImageUploadURLResponse` / `ImageUploadTarget` をそのまま使用。Festival / District それぞれの ID と `light/dark` を指定。
3. 応答の `url` に向けて、**Backend API Client と別の S3 直接 PUT 用 Data Client**（名称案 `S3ImageUploadClient`）が `image/jpeg` を送信。S3 には Cognito の Bearer token を送らず、署名に必要なヘッダーだけを一致させる。
4. S3 の HTTP 2xx を確認してから、応答の `path` を該当 variant の `replace(temporaryPath, localPreview)` として確定する。
5. **この時点では Festival / District の既存 PUT を呼び出さない**。公開画面・`AppState` の URL は変わらない。

署名の期限切れ、通信失敗時は新しい署名 URL の取得から再試行する。HTTP 403 等の Backend 認可失敗を無期限自動再試行しない。S3 の異常ステータスも明示的に失敗にする。必要なヘッダーが `ImageUploadURLResponse` だけでは判別できない場合は、Backend の共通契約で固定する（新たな独自 API を生やさない）。

### 3.2 元の編集画面の「保存」時

1. 既存の文字項目等の検証を実施。いずれかの画像が `uploading/failed` なら、**正式 PUT しない**で状態を説明する。
2. `festival.image` または `district.image` の**既存現在値**に、ライト／ダークの下書きを variant ごとに適用し、新しい `ImagePath(light:dark:)` を構築する。変更なしは既存公開 URL、差し替えは S3 一時キー、削除は `nil`。
3. **既存の** `SaveFestivalUseCase` / `SaveDistrictPackUseCase` → `FestivalDataFetcher.update` / `DistrictDataFetcher.update` を使い、これまでどおり Pack を PUT する。署名 URL 取得や S3 一時 PUT をこの時点で繰り返さない。
4. Backend が返した正式公開 URL（差し替えごとに異なる `?v=` を含む）を、既存 Usecase が現在の `sessionId` と Festival/District ID を検査して `AppState` に適用。**レスポンス値だけ**を正本とし、下書きの `temporaryPath` を AppState に流入させない。
5. 成功したらローカル下書きを掃除して編集画面を閉じる。失敗したら画面を開いたまま、アップロード済みの一時パス・プレビューを残し、エラー表示と再試行を可能にする。S3/DB 非原子的な失敗の際は必要なら現在の Pack を再取得してから再度保存する。

既存 `SaveFestivalUseCase` / `SaveDistrictPackUseCase` の `appState.withLock` による `sessionId` ガードと、`saveTapped` 後の二重送信抑止を維持。編集途中のログイン／祭典切替や画面破棄では古い結果を別セッションに反映しない。画像確定のために新しい Backend API を増やさない。

**責務の配置:** 署名 URL の取得は Data/Fetcher または API Client、S3 PUT は Data/Client、画像変換・アップロード調停は Application 層のテスタブルな処理、表示・シート切替は Presentation 層。未変更／差替／削除から `ImagePath` への合成は双方の保存 Usecase で重複させず、小さな共通ヘルパーにまとめる。不要な独立 Repository や汎用アップロードフレームワークは作らない。

## 4. キャッシュと公開画面

- 現行 `InfoHeaderImageView` / `InfoImageBlurredBackgroundView` が行う colorScheme によるフォールバックは維持する。
- `WebImageView` の Kingfisher / `ImageCacheClient` は URL をキーとする。**Backend が更新ごとに新しい公開 URL を返す**既存契約に従い、新 URL が AppState に適用された後に表示・preload する。手動で全キャッシュを消す処理を標準にはしない。
- シート内の未確定画像は S3 非公開一時キーを `WebImageView` に渡さず、**所有するローカル JPEG**でプレビューする。
- CDN における `?v=` のキャッシュ分離と公開 GET → CDN GET は Backend / AWS の結合確認項目であり、iOS 側でも新 URL を使うことを確認する。

## 5. テスト仕様（Swift Testing）

| ID | 観点 | 必須確認 |
| --- | --- | --- |
| I01 | 見た目 | 既存 Festival / District 編集画面から「画像を変更」でシート表示。上部ライト／ダークの segmented Picker、プレビュー、画像追加／変更、`xmark` を確認 |
| I02 | 初期状態 | 各モードの画像の有無で「画像を追加」「画像を変更」が変わる。プレビューは各モードの実際の画像（公開画面の代替表示とは別） |
| I03 | 選択直後 | `PhotosPicker` 選択 → JPEG 化 → 共通署名 URL POST → S3 直接 PUT → 一時キー保留の順序。**編集画面の「保存」前にアップロードするが、Pack PUT は0回** |
| I04 | シート閉じる | ライト／ダーク各自の変更は `xmark` 後・シート再表示後も維持。未保存の `AppState` と公開画像は変わらない |
| I05 | 正式保存 | 変更した方の一時キー＋未変更側の公開 URL／削除した方の nil で**既存 Pack PUT を1回**だけ呼ぶ。Save Usecase が Backend 正式 URL を AppState へ適用。保存時の一時 S3 再 PUT は0回 |
| I06 | キャンセル | シートを閉じるだけでは保留を破棄せず、**元の編集画面のキャンセル**では正式 PUT をせずローカルファイルを掃除 |
| I07 | 失敗 | 署名取得失敗・S3 PUT 失敗・JPEG 変換失敗は保存を阻止して再試行可能。Pack PUT 失敗なら一時キーとプレビューを残して再保存可。二重タップや遅延完了による上書き防止 |
| I08 | ファイル寿命 | PhotosPicker 選択から時間経過・別項目編集・シート閉じ／再表示後にもプレビュー・再試行が可能。成功・キャンセル・再選択・破棄で適切に掃除 |
| I09 | セッション | 別祭典・ログイン切替後、旧画像の遅延 PUT／保存応答で別 `AppState` を汚染しない |
| I10 | 互換・表示 | 無変更なら署名 URL POST / S3 PUT なし。Light/Dark 切替、片方のみ、両方なし、差し替え後の新 URL を Kingfisher が取得。公開 GET → CDN GET の新画像は結合確認 |

- `FestivalEditFeature` / `DistrictEditFeature` の `TestStore` を中心に検証する。画像送信用 Client と保存 Usecase の Spy は **`iOSApp/Tests/Utility/`** に置き、テスト専用 Mock / Spy を Sources に含めない。
- 共通画像処理は追加したソースと1対1で対応する Swift Testing テストを設ける。依存関係の `testValue` 未設定や Live Client の誤呼出を残さない。
- UI の見た目と遷移は AGENTS.md に従ってシミュレータ上で実際にシート・追加・ライト／ダーク切替・閉じる・保存を操作し、スクリーンショットと画面状態を確認する。実環境の S3/Backend がなければ Spy で画面経路を検証し、実通信未検証を明記する。

## 6. 対象外

Store 広告画像、IAP、Backend の新 API、S3 バケット・CDN 設定、画像 UUID、アップロード確定専用 API、ETag/Versioning、画像の物理削除、公開画面の大規模変更。

**実装順:** 共通アップロード Data Client / Application 処理 → 画像編集シート → Festival / District 編集 Feature 連携 → 既存 SaveUseCase との統合 → テスト・画面動作確認。Backend 側の API と署名付き PUT ヘッダーの契約を事前に確認し、iOS 独自の DTO を増やさない。
