# Festival / District 紹介画像アップロード設計

- 案件 ID: `20261031_festival_district_images`
- 初版: 2026-10-31
- 状態: 実装前の設計案
- 対象: Shared / Backend / iOSApp / AWS S3
- 目的: Festival と District の紹介画像を管理者が Light / Dark 別に登録・差し替え・参照解除できるようにする
- 正本: [独自広告システム設計 §10「S3 画像入稿」](../20261031_original_advertisement/spec.md#10-s3-画像入稿固定パス--store-put)（マージ済み PR #377）

> **設計と実装を区別する。** 2026-10-31 現在、広告画像の S3 入稿はマージ済みの**設計仕様**であり、`main` に共通 S3 画像入稿実装はまだない。広告 Backend 詳細設計 PR #379 は未マージ。本書はその実装を既存機能として仮定しない。本 PR は文書のみ。

## 1. 結論と適用範囲

**広告入稿と同じ「固定一時キーへ署名付き PUT → 既存の Entity/Pack PUT で確定 → S3 CopyObject → 正式パスを保存」方式**を採用する。画像ごとの UUID、確定 API、削除 API、S3 ETag/Versioning、画像用 DynamoDB テーブルは増やさない。

| 対象 | Light | Dark | 更新主体 | 画像がない場合 |
| --- | --- | --- | --- | --- |
| Festival.image | 1枚 | 1枚 | その Festival の本部管理者 | 既存 UI の代替表示 |
| District.image | 1枚 | 1枚 | その District の町管理者 | 既存 UI の代替表示 |

対象は**祭典・町の紹介画像**。店舗広告画像（banner/interstitial）には手を加えない。既存の外部画像 URL を維持し、移行・一括再アップロードは行わない。画像の物理削除は通常の編集では行わない。

## 2. 既存実装と変更点

| 現状の正本 | 確認事項 / 必要な変更 |
| --- | --- |
| `Shared/Sources/Entity/Others.swift` | `ImagePath { let light: String?; let dark: String? }` は存在。**変更不要**、画像用永続 Entity は追加しない |
| `Shared/Sources/Entity/Festival.swift` / `District.swift` | 両方 `var image: ImagePath` を保持。既存 JSON 形状を維持 |
| `Backend/Sources/Router/FestivalRouter.swift` / `DistrictRouter.swift` | 署名 URL 発行用 POST をそれぞれ1ルート追加 |
| `Backend/Sources/Controller/FestivalController.swift` / `DistrictController.swift` | 新規署名 URL 要求の受け口を追加、既存 PUT の JSON 構造を変更しない |
| `Backend/Sources/Usecase/FestivalUsecase.swift` / `DistrictUsecase.swift` | 既存の認可を維持し、PUT 内で画像パスを検証・確定してから保存 |
| `Backend/Sources/Data/Repository/Festival/FestivalRepository.swift` / `DistrictRepository.swift` | 既存 DynamoDB Record を使用。画像の別レコードは作らない |
| `iOSApp/Sources/Presentation/View/Admin/Region/Edit/FestivalEditFeature.swift` / `FestivalEditView.swift` | Light/Dark の選択・プレビュー・解除を追加 |
| `iOSApp/Sources/Presentation/View/Admin/District/Edit/DistrictEditFeature.swift` / `DistrictEditView.swift` | 同上。既存 `DistrictPack` 保存フローを使用 |
| `iOSApp/Sources/Presentation/View/Public/Info/Components/InfoImageBackgroundView.swift` | 既に `colorScheme` に応じ Light/Dark を選択し、片方がなければもう片方へフォールバック |
| `iOSApp/Sources/Presentation/Parts/Others/WebImageView.swift` / `Data/Client/ImageCacheClient.swift` | Kingfisher は URL でキャッシュする。画像差し替え後に同じ URL のままにしないことが必要 |

**注意:** `ImagePath` の `light/dark` は `let` なので、編集中は `ImagePath(light: ..., dark: ...)` を構築し直す。Swift の合成 `Encodable` は `nil` のキーを省略し得るため、広告 Store の「必ず明示 JSON null」と混同しない。本件は `image` オブジェクト全体を渡す全体置換として扱い、`light/dark` の欠落と `null` はともに **nil（参照解除）**と解釈する。既存 `image` オブジェクト自体の欠落はデコードエラーとする。

## 3. S3 キー・参照パス

S3 の**一時キーと正式キーは固定**。サーバーが既存 Entity の ID から決め、クライアントの任意キーを信頼しない。

| 対象 | 一時キー | 正式キー |
| --- | --- | --- |
| Festival Light | `temporary/festivals/{festivalId}/light.jpg` | `festivals/{festivalId}/light.jpg` |
| Festival Dark | `temporary/festivals/{festivalId}/dark.jpg` | `festivals/{festivalId}/dark.jpg` |
| District Light | `temporary/festivals/{festivalId}/districts/{districtId}/light.jpg` | `festivals/{festivalId}/districts/{districtId}/light.jpg` |
| District Dark | `temporary/festivals/{festivalId}/districts/{districtId}/dark.jpg` | `festivals/{festivalId}/districts/{districtId}/dark.jpg` |

District の `festivalId` は **Backend が既存 District から取得**する。URL や request body の festivalId は信用しない。ID をキーのパス区切りとして悪用できないよう、既存 ID の許容文字を検証または安全にエンコードする。クライアントが `../`、別の Festival/District、別の Light/Dark のキーを任意に選べない構成にする。

- 一時画像は非公開。署名付き PUT URL は短命で、`image/jpeg` と対象キーに限定する。
- 正式画像も S3 を原則非公開とし、既存環境と広告設計で採用する公開配信手段（CDN 等）を共用する。**バケット名、CDN origin は実装環境で決める**。
- `ImagePath.light/dark` は現在の閲覧 UI が受け付ける **絶対 URL 文字列**を保存・返却する。成功応答に `temporary/` や非公開の S3 キーをそのまま残さない。
- 正式 S3 キーは固定だが、**画像を上書きした場合のみ**返却 URL に `?v={backendGeneratedTimestamp}` のようなキャッシュ更新用クエリを付ける（推奨）。通常の文字列 URL として扱い、画像用 revision Entity は追加しない。配信 CDN がクエリをキャッシュキーに含め、旧 URL が新画像と混線しないことを確認する。クエリが無視される環境では配信設定の修正または短いキャッシュ期限が必要。
- 差し替えず保持した URL はそのまま返す。既存の外部 URL は移行せず、**同じ現在値を送り返す限り**保持できる。新規の任意外部 URL への変更は禁止する。

## 4. API・DTO

署名 URL 取得 API **のみ新設**。画像の確定・参照解除は既存の FestivalPack / DistrictPack PUT を流用する。

| Method | Path | 認可 | Body → Response |
| --- | --- | --- | --- |
| POST | `/festivals/:festivalId/images/upload-url` | `headquarter(festivalId)` の一致 | `IntroductionImageUploadURLRequest` → `ImageUploadURLResponse` |
| POST | `/districts/:districtId/images/upload-url` | `district(districtId)` の一致 | 同上 |
| PUT（既存） | `/festivals/:festivalId` | 同一 Festival の本部管理者 | `FestivalPack` → `FestivalPack` |
| PUT（既存） | `/districts/:districtId` | 同一 District の町管理者 | `DistrictPack` → `DistrictPack` |

- `IntroductionImageUploadURLRequest { appearance: light | dark, contentType: String }`。広告の `StoreAdPlacement`（banner/interstitial）を流用しない。 `appearance` は永続 Entity ではなく API 境界の enum。
- `ImageUploadURLResponse { url: String, path: String, expiresAt: Date }` は広告入稿と**共通 DTO**にする。`path` は今回の一時 S3 キー、`url` は S3 へ PUT する署名付き URL。Shared で共通化する際に既存広告設計の型名・形を揃える。
- 通信日付は既存ルール通り Unix 秒。S3 直接 PUT には **Backend の Bearer token を送らない**。
- Festival / District の通常 PUT body では画像以外の必須項目・関連 Pack も従来通り送る。画像単独更新 API は作らない。
- 署名 URL は**対象 Entity の存在と認可**を検証した後に発行。不存在は 404、未認証は 401、他人の対象は権限エラーとする。既存 Backend のエラー規約に合わせる。

### 4.1 画像パスの PUT 解釈（light / dark それぞれ独立）

| PUT の値 | Backend の処理 |
| --- | --- |
| 発行対象と完全一致する一時キー | S3 実体・形式・容量を検証 → 正式キーへ `CopyObject` → 公開 URL に置換して保存 |
| DB に保存されている**現在値と一致**する公開 URL | 維持。S3 コピーなし（既存の外部 URL を含む） |
| `null` または `ImagePath` 内のキー省略 | 公開参照を解除。S3 の物理削除はしない |
| それ以外（別 Entity/variant、他の外部 URL、他ユーザーの一時パス、古い正式 URL） | 400 として拒否 |

`image` オブジェクトは全体置換であり、未変更側の現在値も必ず送る。Backend は**更新前の DB 現在値**と照合し、クライアントが自分以外の正式 S3 URL を流用できないようにする。旧クライアントとの互換性のため、画像を変更せず現在値をそのまま送る通常 PUT は許可する。

### 4.2 PUT body の部分例

既存 `FestivalPack` / `DistrictPack` の他のフィールドは説明のため省略している。

```json
{
  "festival": {
    "id": "festival-001",
    "image": {
      "light": "temporary/festivals/festival-001/light.jpg",
      "dark": null
    }
  }
}
```

成功時に `festival.image.light` は **配信可能な正式 URL** へ置換される。`district.image` も同様。レスポンス値を唯一の保存結果として扱い、送信した一時キーをローカルの正本に残さない。

## 5. Backend フローと責務

1. **署名 URL 発行:** Router → Controller で `appearance`/`contentType` を解析 → Usecase が Entity を取得・Role/ID 一致を確認 → 画像用 S3 Client が固定一時キーの署名 PUT URL を発行。署名済みヘッダー（Content-Type 等）は応答契約で iOS に伝えるか、値が固定なら仕様で一致させる。
2. **アップロード:** iOS が JPEG バイト列を S3 へ直接 PUT。HTTP 2xx を確認。アップロードが終わる前に Entity PUT を開始しない。
3. **既存 PUT:** Festival / District の既存 Controller が Pack をデコード。既存 Usecase がまず認可・ID・子要素の整合性を検査し、保存前に変更対象の画像を処理する。
4. **画像確定:** Usecase から共通の `S3ImageClient`（名称案）に実体確認・正式パスへのコピーを依頼。Backend は一時キーの完全一致を検証し、`HeadObject` 等で存在・Content-Type・容量、必要なら先頭バイトで JPEG 形式を確認。不正なら **DB は更新せず** 400 等で失敗。
5. **DB 保存:** 完成した `ImagePath` を既存 Festival/District Entity に組み込み、既存 Repository の `put` を実行する。成功後の Pack / Entity を返す。
6. **iOS 同期:** `SaveFestivalUseCase` / `SaveDistrictPackUseCase` が**Backend 応答を** AppState に反映。現在の `sessionId` ガードを維持し、祭典・ログインの切り替え後に古い結果を反映しない。

**役割分担:** `Router` は経路、`Controller` は入出力、`Usecase` は認可・更新判断・画像確定の調停、`Data/Client` は S3 SDK との通信、`Repository` は DynamoDB 永続化。画像用 Repository / DynamoDB Entity を作らない。広告側の実装時に同じ `S3ImageClient` と署名 URL 応答 DTO を共有し、Festival/District 固有の認可判断は共通 Client に持たせない。

### 5.1 認可の維持（重要）

- Festival の画像変更は `FestivalUsecase.put` と同じ **本部管理者限定**。
- District の画像変更は `DistrictUsecase.put(id:item:user:)` と同じ **町管理者限定**。`mergeForDistrictRole` が現状 `image` を反映することを維持。
- 本部管理者が使う `PUT /districts/:districtId/core` の `mergeForHQRole` は現状画像を変更しない。この制約を維持し、画像署名 URL も本部管理者には**自動的に許可しない**。
- 認可は署名 URL 発行時だけでなく、**最終 PUT でも実施**。すでに発行された URL を持っていても、他ユーザーとして DB に確定できない。
- Festival / District の ID と親子関係は DB の現在値に照らして確認。リクエストの ID 改ざんを拒否。

### 5.2 整合性、再試行、削除

広告設計と同じ MVP の割り切りを採用。

- **S3 と DynamoDB の分散トランザクションを導入しない。** S3 の正式画像コピー成功後に DB PUT が失敗すると、古い参照 URL のままで実体だけ新しくなる場合がある。2枚更新でも片方のコピーのみ成功し得る。未検証の画像が入らないよう、可能な限り**両方の一時画像を先に検証してからコピー**するが、厳密な原子性は保証しない。
- 同一対象・同一 variant の固定一時キー競合は検出しない（最新 S3 PUT の内容が対象）。ETag・画像 UUID・S3 Versioning・ロックは導入しない。1管理者による低頻度編集を前提とする。
- 失敗時には既存 Entity を再取得し、必要に応じて画像を**再アップロードして**通常 PUT を再送する。古い署名 URL は再発行する。アップロード成功だけでは公開画像は変わらない。
- `image.light/dark = nil` は参照解除のみ。S3 物理削除は要求しない。正式画像には広告 Store の**購入起点2年整理ルールを適用しない**（Festival / District には購入がない）。
- `temporary/` は短期 S3 Lifecycle（例: 1日）で掃除する。権限失効後も一時オブジェクトが残る間は非公開。

## 6. iOS 編集 UX / 保存順序

Festival / District の**既存編集画面**に「紹介画像」セクションを追加し、Light / Dark をそれぞれ独立して選択できるようにする。

- 各枠に現在のサムネイル、写真選択（`PhotosPicker`）、差し替え、参照解除。編集途中はローカル選択のプレビューを優先する。
- 選択だけでは S3 へ送信しない。画面の「保存」時に初めてアップロードする。キャンセル時は本体の DB 更新なし。
- TCA の編集 State は `unchanged / replace(localImage) / remove` の3状態を Light・Dark に持つ（実装例としてローカル一時ファイル URL など Equatable / Sendable な参照を保持）。**`AppState` には未保存の画像を置かない**。生の `UIImage` は Reducer の State に持たせない。
- 保存 Action → 画像選択を JPEG に変換・圧縮 → variant ごと署名 URL 発行 → S3 PUT 完了 → 既存 `FestivalPack` / `DistrictPack` の `image` を「新しい一時キー / 現在の公開 URL / nil」から構築 → 通常の Backend PUT → 応答を AppState へ反映。
- 保存中は二重タップを抑制し、進捗・失敗を表示する。失敗で画面を閉じず選択内容を保持し、再試行できるようにする。無変更時は画像アップロードを行わない。
- 通常の更新動線は `FestivalDataFetcher.update` / `DistrictDataFetcher.update` と既存の `SaveFestivalUseCase` / `SaveDistrictPackUseCase` を維持し、アップロード調停のみ Application Usecase に加える。S3 直接 PUT は API 用 `HTTPClient` と分離した Data/Client に閉じ込める。
- JPEG の圧縮をクライアントで行う。**サイズ・画素数・縦横比の上限は広告設計でも未確定**なので、本件だけで別の強制値を確定しない。初回実装時に共通制約として決定し、iOS の事前検証と Backend の強制検証を揃える。

### キャッシュと表示

現在 `InfoHeaderImageView` / `InfoImageBlurredBackgroundView` は Light/Dark のフォールバックに対応するため、表示ルールは変えない。Kingfisher が URL をキーにするので、差し替え後は**Backend から返した新 URL**でプレビュー・公開画面・preload を再取得する。変更しなかった側は既存 URL を維持する。削除した側はフォールバック先を選び直す。新しい公開 GET レスポンスにも更新後 URL を含めることを確認する。

## 7. AWS・公開配信の前提

- Lambda 実行 Role: 対象 bucket の一時 `PutObject` 署名発行、`HeadObject/GetObject`、一時 → 正式への `CopyObject` 等、必要最小限の権限。クライアントへ AWS 認証情報は渡さない。
- バケット: 一時オブジェクトを非公開にし、Lifecycle で自動削除。正式画像の閲覧は既存の CDN 等で提供。S3 公開設定を安易に開かない。
- CORS: iOS ネイティブの直接 PUT には Web の CORS は必須ではない。将来の Web 入稿も対象とするなら、対象 Origin/PUT/Content-Type だけ許可する。
- 署名 URL の有効期限、許容 Content-Type、最大バイト数、配信 URL のキャッシュキーは広告画像と**共通設定**にする。実装時に AWS 実環境を確認して確定する。

## 8. テスト仕様（Swift Testing）

| ID | 対象 | 必須確認 |
| --- | --- | --- |
| B01 | 署名 URL | Festival 本部/町自身のみ成功、guest・別 Festival/町・本部→District は拒否 |
| B02 | 署名 URL | 存在しない ID、無効 appearance / MIME / ID 埋め込み、署名期限と対象キー |
| B03 | 最終 PUT | 署名済み URL 発行済みでも別 Role に切り替えたら確定拒否 |
| B04 | Festival PUT | Light だけ新規、Dark 保持／削除、逆の組合せが正しく置換される |
| B05 | District PUT | 同様に片側だけ変更可能。HQ `/core` 経由で画像が変わらない |
| B06 | S3 確定 | 一時キーの完全一致、JPEG の実体・容量、コピー失敗時に DB PUT しない |
| B07 | パス検証 | 他 Entity / variant のキー、任意外部 URL、改ざんされた既存 URL は拒否 |
| B08 | 互換性 | 変更しない古い外部 URL を現在値として維持、nil の JSON 省略と null を処理 |
| B09 | 更新・失敗 | DB 失敗後の再アップロード・再試行、S3/DB の非原子的失敗条件を確認 |
| B10 | ルーティング | 新しい POST と既存 Festival/District GET/PUT・launch・districts の衝突なし（広告設計の完全一致修正に追従） |
| I01 | TCA | 選択・差し替え・解除・キャンセルで AppState を先に変えない |
| I02 | 保存 | Light/Dark の必要な分だけアップロードし、両 PUT 完了後に Pack PUT |
| I03 | 保存失敗 | S3/Backend エラー時は編集内容保持・アラート、再試行可・重複保存防止 |
| I04 | 同期 | Backend 応答の正式 URL のみ反映し、sessionId 変更後の古い応答を無視 |
| I05 | 表示 | Light/Dark 切替・片方のみ・両方なし・差し替え URL の Kingfisher キャッシュ更新 |

テストダブルは `Tests/Utility/` の Spy に置き、Sources にテスト専用実装を混ぜない。Backend は S3 Client/Repository を差し替えて Side Effect と権限を検証。iOS は TCA `TestStore` と Data/Client の Spy で署名取得 → S3 PUT → Pack PUT の順序を検証。実装時には既存 `AGENTS.md` のビルド・実機/シミュレータ・CI の指示に従う。

## 9. 非採用・未確定

**非採用（MVP には過剰）:** 画像の独立 Entity/Repository、画像 ID/UUID、アップロード確定/削除専用 API、S3 ETag / Versioning / 世代 GC、画像ごとの DynamoDB revision、専用画像審査基盤、既存画像一括移行。

**初回実装前に確定するもの:** 広告システムと共通の (1) 画像容量・画素・縦横比、(2) 署名 URL TTL、(3) S3 bucket と公開 CDN/origin、(4) URL の `v` クエリを含む CDN キャッシュ挙動、(5) `ImageUploadURLResponse` が PUT に必要な署名ヘッダーをどう渡すか。未決定でも**画像をアップロード・保存する設計の構造は上記の通り**。

## 10. 参照

- [マージ済み・独自広告システム設計 §10](../20261031_original_advertisement/spec.md#10-s3-画像入稿固定パス--store-put)
- [開発ガイド](../../README.md) / [AGENTS.md](../../../AGENTS.md)
- `Shared/Sources/Entity/Others.swift`、`Festival.swift`、`District.swift`
- `Backend/Sources/Usecase/FestivalUsecase.swift`、`DistrictUsecase.swift`
- `iOSApp/Sources/Presentation/View/Admin/Region/Edit/FestivalEditFeature.swift`
- `iOSApp/Sources/Presentation/View/Admin/District/Edit/DistrictEditFeature.swift`
