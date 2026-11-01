# Festival / District 紹介画像アップロード設計

- 案件 ID: `20261031_festival_district_images`
- 初版: 2026-10-31
- 状態: 実装前の設計案
- 対象: Shared / Backend / iOSApp / AWS S3
- 目的: Festival と District の紹介画像を管理者が Light / Dark 別に登録・差し替え・参照解除できるようにする
- 正本: [独自広告システム設計 §10「S3 画像入稿」](../20261031_original_advertisement/spec.md#10-s3-画像入稿固定パス--store-put)（マージ済み PR #377）

> **設計と実装を区別する。** 2026-10-31 現在、広告画像の S3 入稿はマージ済みの**設計仕様**であり、`main` に共通 S3 画像入稿実装はまだない。広告 Backend 詳細設計 PR #379 は**マージ済み**。旧 API を前提とした[同案件の backend.md](../20261031_original_advertisement/backend.md) も本 PR で共通 API へ修正する。本 PR は文書のみ。

## 1. 結論と適用範囲

**広告入稿と同じ「固定一時キーへ署名付き PUT → 既存の Entity/Pack PUT で確定 → S3 CopyObject → 正式パスを保存」方式**を採用する。**Festival / District 用の POST は新設しない。** 広告用に設計されていた署名 URL 発行 API を単一の共通 API（`POST /images/upload-url`）へ一般化し、Store/Festival/District の3種類を扱う。したがって、画像アップロード URL 発行の POST は**全体で1つ**だけ。画像ごとの UUID、確定 API、削除 API、S3 ETag/Versioning、画像用 DynamoDB テーブルは増やさない。

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
| `Backend/Sources/Router/FestivalRouter.swift` / `DistrictRouter.swift` | **追加ルートなし**。既存の FestivalPack / DistrictPack PUT をそのまま確定処理に使用 |
| `Backend/Sources/Controller/FestivalController.swift` / `DistrictController.swift` | **追加メソッドなし**。既存 PUT 内の画像パス検証・確定だけ拡張し、JSON 構造は変更しない |
| `Backend/Sources/Usecase/FestivalUsecase.swift` / `DistrictUsecase.swift` | 既存の認可を維持し、PUT 内で画像パスを検証・確定してから保存。署名発行側は3種類共通の ImageUploadUsecase で認可とキーを振り分ける |
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
- 正式 S3 キーは固定だが、**画像差し替えごとに異なる公開 URL を Backend が永続化して返すことを必須**とする（例: `?v={backendGeneratedEpochMillis}`）。`v` が現在保存済み URL と同値になり得る場合は次の値へ進め、同じ variant の連続差し替えで**必ず異なる値**にする。既存の `ImagePath` 文字列 URL を用い、画像用 revision Entity / UUID は追加しない。**公開 CDN は `v` をキャッシュキーに含める設定を必須**とし、公開 API・Kingfisher・CDN の全経路で新しい画像を取得できることを初回リリース条件とする。短いキャッシュ TTL **だけで代替しない**。
- 差し替えず保持した URL はそのまま返す。既存の外部 URL は移行せず、**同じ現在値を送り返す限り**保持できる。新規の任意外部 URL への変更は禁止する。

## 4. API・DTO

署名 URL の POST を増設するのではなく、**広告用に予定されていた `POST /stores/:storeId/images/upload-url` を `POST /images/upload-url` に置き換えて共通化する**。Store/Festival/District で合計1つの署名発行 API を使用する。この変更に合わせて[広告の設計書](../20261031_original_advertisement/spec.md)も更新する。画像の確定・参照解除は各 Entity の既存 PUT を流用する。

| Method | Path | 認可 | Body → Response |
| --- | --- | --- | --- |
| POST（広告と共用） | `/images/upload-url` | target 別に Store 所有者 / Festival 本部 / District 本人を判定 | `ImageUploadURLRequest` → `ImageUploadURLResponse` |
| PUT（既存） | `/festivals/:festivalId` | 同一 Festival の本部管理者 | `FestivalPack` → `FestivalPack` |
| PUT（既存） | `/districts/:districtId` | 同一 District の町管理者 | `DistrictPack` → `DistrictPack` |
| PUT（広告で設計済み） | `/stores/:storeId` | Store 所有者 | `Store` → `Store` |

- 共通の `ImageUploadURLRequest { target: ImageUploadTarget, contentType: String }` を使用。`ImageUploadTarget` は `type: store | festival | district`、`id`、`variant` を持つ **API 境界の判別可能な型**とする。
- `variant` は `type=store` なら `banner | interstitial`、`type=festival/district` なら `light | dark`。これ以外の組み合わせは 400。不正な `type`/`id`/`variant` も 400。
- `ImageUploadURLResponse { url: String, path: String, expiresAt: Date }` は広告入稿と**完全共通の DTO**。`path` は対象の一時 S3 キー、`url` は S3 へ PUT する署名付き URL。実体へ送る Content-Type 等は署名と一致させる。
- 通信日付は既存ルール通り Unix 秒。S3 直接 PUT には **Backend の Bearer token を送らない**。
- Festival / District の通常 PUT body では画像以外の必須項目・関連 Pack も従来通り送る。画像単独更新 API は作らない。
- 署名 URL は**対象 Entity の存在と認可**を検証した後に発行。Store は所有者 sub、Festival は `headquarter(id)`、District は `district(id)` をそれぞれ検証。不存在は 404、未認証は 401、他人の対象は権限エラーとする。

**共通 API リクエスト例（Festival の Light）**

```json
{
  "target": { "type": "festival", "id": "festival-001", "variant": "light" },
  "contentType": "image/jpeg"
}
```

Store の Banner も同じ API に `target: { "type": "store", "id": "store-123", "variant": "banner" }` を渡す。追加の Festival/District 専用 endpoint は存在しない。

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

1. **署名 URL 発行:** 広告と共通の `POST /images/upload-url` を Router → Controller が処理し、`target.type/id/variant` と `contentType` を解析 → Usecase が対象 Entity を取得・Role/ID 一致を確認 → 画像用 S3 Client が固定一時キーの署名 PUT URL を発行。署名済みヘッダー（Content-Type 等）は応答契約で iOS に伝えるか、値が固定なら仕様で一致させる。
2. **アップロード:** iOS が JPEG バイト列を S3 へ直接 PUT。HTTP 2xx を確認。アップロードが終わる前に Entity PUT を開始しない。
3. **既存 PUT:** Festival / District の既存 Controller が Pack をデコード。既存 Usecase がまず認可・ID・子要素の整合性を検査し、保存前に変更対象の画像を処理する。
4. **画像確定:** Usecase から共通の `S3ImageClient`（名称案）に実体確認・正式パスへのコピーを依頼。一時キー完全一致・`HeadObject` で存在/Content-Type/容量を確認したうえで、**画像データを読み込み、JPEG SOI/EOI シグネチャ・マーカー構造・解釈できる縦横画素数・サイズ上限をサーバー側で必須検証**する（軽量な JPEG 検証処理でよく、専用サービスや画像管理基盤は不要）。`Content-Type: image/jpeg` だけの非画像、途中で切れた JPEG、サイズ/画素数超過は **CopyObject 前に拒否**し、DB を更新しない。必要な JPEG 構造まで検証できない実装は採用しない。
5. **DB 保存:** コピー成功時に変更対象の公開 URL を**新しい `v` 付き URL**へ置換する。完成した `ImagePath` を既存 Festival/District Entity に組み込み、既存 Repository の `put` を実行する。成功後の Pack / Entity にも新 URL を返す。変更していない画像は従来 URL を維持する。
6. **iOS 同期:** `SaveFestivalUseCase` / `SaveDistrictPackUseCase` が**Backend 応答を** AppState に反映。現在の `sessionId` ガードを維持し、祭典・ログインの切り替え後に古い結果を反映しない。

**役割分担:** 共通 `ImageRouter`（名称例）→ `ImageUploadController` → `ImageUploadUsecase` が**1つの署名 URL 発行ルート**を担当し、`target.type` に応じて既存 Repository から Entity を取得・認可。既存 Festival/District/Store の PUT は各 Usecase が画像を確定する。共通 `Data/Client/S3ImageClient` は S3 SDK の署名・検証・コピーのみを実装し、認可は Usecase が担当。画像用 Repository / DynamoDB Entity は作らない。広告実装と二重に API / Client を作らない。

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

**[iOS 詳細設計](./ios.md)をこの章の実装仕様とする。** Festival / District の既存編集画面に「画像を変更」ボタンを追加し、`NavigationStack` のシートを表示する。

- シート上部は既存ルート編集と同じ大きな `segmented Picker` を **「ライト」「ダーク」** の2項目で表示。下に現在画像またはアップロード済みの新画像のプレビューを表示する。
- 画像がないときは **「画像を追加」**、あるときは **「画像を変更」**を表示する。画像の参照解除も可能。右上 `xmark` はシートを閉じるのみで、アップロード済みの下書きを破棄しない。
- **画像を PhotosPicker で選択した直後に JPEG へ変換 → 共通署名 URL 発行 API → S3 一時キーへ直接 PUT** する。この時点では Festival/District Pack PUT は行わず、本番表示は変更しない。
- 一時 PUT 成功後はモードごとに一時キーとローカルプレビューを編集中の Feature State に保持。シートを閉じて再表示しても保持する。PhotosPicker の一時 URL をそのまま保持せず、アプリが所有するローカルファイルを利用し、保存成功・元の画面のキャンセル・再選択等で掃除する。
- **元の Festival / District 編集画面で「保存」を押したときだけ**、各モードの「既存公開 URL / アップロード済み一時キー / nil」を `ImagePath` に反映して**既存 Pack PUT で本番確定**。保存時に画像を再アップロードしない。アップロード失敗・進行中は未確定キーで保存しない。
- `SaveFestivalUseCase` / `SaveDistrictPackUseCase` の `sessionId` ガードを維持し、Backend 応答の正式公開 URL のみ AppState に反映。保存失敗時は下書きを残して再試行可能にする。
- 表示は現在の `InfoHeaderImageView` / `InfoImageBlurredBackgroundView` の Light/Dark フォールバックと Kingfisher を維持する。公開 URL が差し替えごとに変わる Backend 契約を使用する。
- ツールバー・シート UI は ContentView 側に置き、`Tests/Utility/` の Spy と Swift Testing で通信順序・下書き・正式確定・表示を検証する。

### iOS の処理タイミング

| 操作 | 一時 S3 PUT | 既存 Festival/District Pack PUT |
| --- | --- | --- |
| PhotosPicker で画像を選択 | **その場で実行** | しない |
| シートを `xmark` で閉じる | しない | しない |
| 元の編集画面の「保存」 | **原則再実行しない** | **ここで初めて実行** |
| 元の編集画面の「キャンセル」 | しない（S3 一時キーは Lifecycle 整理） | しない |

## 7. AWS・公開配信の前提

- Lambda 実行 Role: 対象 bucket の一時 `PutObject` 署名発行、`HeadObject/GetObject`、一時 → 正式への `CopyObject` 等、必要最小限の権限。クライアントへ AWS 認証情報は渡さない。
- バケット: 一時オブジェクトを非公開にし、Lifecycle で自動削除。正式画像の閲覧は既存の CDN 等で提供。S3 公開設定を安易に開かない。
- CORS: iOS ネイティブの直接 PUT には Web の CORS は必須ではない。将来の Web 入稿も対象とするなら、対象 Origin/PUT/Content-Type だけ許可する。
- 署名 URL の有効期限、許容 Content-Type、最大バイト数は広告画像と**共通設定**にし、実装時に AWS 実環境を確認して確定する。**CDN は `?v=` をキャッシュキーに含める設定が必須**。公開 GET が返す新 URL を CDN へ要求し、新画像の取得と旧 URL のキャッシュ分離を確認するまで初回リリースしない。

## 8. テスト仕様（Swift Testing）

| ID | 対象 | 必須確認 |
| --- | --- | --- |
| B01 | 共通署名 URL | 1つの POST で Store/Festival/District を扱い、Store 所有者/Festival 本部/町本人のみ成功、guest・別対象・本部→District は拒否 |
| B02 | 共通署名 URL | 存在しない ID、type と variant の不一致（例: store/light）、無効 MIME / ID 埋め込み、署名期限と対象キー |
| B03 | 最終 PUT | 署名済み URL 発行済みでも別 Role に切り替えたら確定拒否 |
| B04 | Festival PUT | Light だけ新規、Dark 保持／削除、逆の組合せが正しく置換される |
| B05 | District PUT | 同様に片側だけ変更可能。HQ `/core` 経由で画像が変わらない |
| B06 | S3 確定 | 一時キーの完全一致。Content-Type だけ JPEG の非画像データ、SOI/EOI またはマーカー構造不正、途中で欠けた JPEG、画素数・容量超過を拒否し CopyObject/DB PUT しない。正常 JPEG のみ許可。コピー失敗時は DB PUT しない |
| B07 | パス検証 | 他 Entity / variant のキー、任意外部 URL、改ざんされた既存 URL は拒否 |
| B08 | 互換性 | 変更しない古い外部 URL を現在値として維持、nil の JSON 省略と null を処理 |
| B09 | 更新・失敗 | DB 失敗後の再アップロード・再試行、S3/DB の非原子的失敗条件を確認 |
| B10 | ルーティング | 共通の `POST /images/upload-url` と既存 Store/Festival/District GET/PUT・launch・districts の衝突なし（HTTP endpoint 完全一致に追従） |
| I01 | 画像シート | Festival / District 既存編集画面 → 「画像を変更」 → ライト/ダーク segmented Picker、現在/新画像プレビュー、追加/変更、`xmark` |
| I02 | 選択時アップロード | PhotosPicker 選択で**直ちに S3 一時 PUT**、編集画面保存前は Pack PUT **0回**。ライト/ダーク独立で保留 |
| I03 | 保留・失敗 | `xmark` は下書き維持、元の編集画面キャンセルは破棄。失敗時は再試行可能で未確定キーを保存しない。PhotosPicker 一時ファイルの寿命と掃除 |
| I04 | 正式保存・同期 | 元の画面の保存時に**既存 Pack PUT**、S3 再アップロードなし。Backend 正式 URL のみ AppState に反映。sessionId 変更後の古い応答は無視 |
| I05 | 表示・結合 | Light/Dark 切替・片方のみ・両方なし、変更後の URL の Kingfisher 更新。公開 GET → CDN GET の新画像取得・版クエリを確認 |

iOS の詳細な I01〜I10 ケースは [iOS 詳細設計](./ios.md#5-テスト仕様swift-testing) に定める。

テストダブルは `Tests/Utility/` の Spy に置き、Sources にテスト専用実装を混ぜない。Backend は S3 Client/Repository を差し替えて Side Effect と権限を検証。iOS は TCA `TestStore` と Data/Client の Spy で署名取得 → S3 PUT → Pack PUT の順序を検証。実装時には既存 `AGENTS.md` のビルド・実機/シミュレータ・CI の指示に従う。

## 9. 非採用・未確定

**非採用（MVP には過剰）:** Festival/District 専用の署名発行 POST、画像の独立 Entity/Repository、画像 ID/UUID、アップロード確定/削除専用 API、S3 ETag / Versioning / 世代 GC、画像ごとの DynamoDB revision、専用画像審査基盤、既存画像一括移行。

**設計正本の整合:** 広告 Backend 詳細設計 PR #379 は**マージ済み**。本 PR は同案件の [backend.md](../20261031_original_advertisement/backend.md) の旧 `/stores/:storeId/images/upload-url` / `StoreImageUsecase` / R07 / ファイル配置も共通 `/images/upload-url` / `ImageUploadTarget` / `ImageUploadUsecase` / `S3ImageClient` に更新し、上位 [spec.md](../20261031_original_advertisement/spec.md) と整合させる。

**初回実装前に確定するもの:** 広告システムと共通の (1) 画像容量・画素・縦横比、(2) 署名 URL TTL、(3) S3 bucket と公開 CDN/origin、(4) `ImageUploadURLResponse` が PUT に必要な署名ヘッダーをどう渡すか。**別途必須のリリース条件:** (a) JPEG の基本構造・画素数を Backend で検証、(b) 差し替えごとに異なる URL の生成・永続化、(c) CDN が `v` をキャッシュキーに含み、公開 GET → CDN GET で画像更新を確認。いずれも画像 ID や独立基盤を追加せず対応する。

## 10. 参照

- [マージ済み・独自広告システム設計 §10](../20261031_original_advertisement/spec.md#10-s3-画像入稿固定パス--store-put)
- [開発ガイド](../../README.md) / [AGENTS.md](../../../AGENTS.md)
- `Shared/Sources/Entity/Others.swift`、`Festival.swift`、`District.swift`
- `Backend/Sources/Usecase/FestivalUsecase.swift`、`DistrictUsecase.swift`
- `iOSApp/Sources/Presentation/View/Admin/Region/Edit/FestivalEditFeature.swift`
- `iOSApp/Sources/Presentation/View/Admin/District/Edit/DistrictEditFeature.swift`
