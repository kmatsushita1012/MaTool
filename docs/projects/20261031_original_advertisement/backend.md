# MaTool 独自広告システム — Backend 詳細設計

- 案件: `20261031_original_advertisement`
- 状態: **ドラフト／レビュー対象**
- 上位仕様: [spec.md](./spec.md)
- 対象: Shared / Backend / DynamoDB / Cognito / S3
- 本 PR は設計書のみ。ソース・AWS 設定・テストコードは変更しない。

> `spec.md` の確定事項を正本とする。画像用 UUID・S3 Versioning / ETag・Store revision・高度な不正監視など、レビューで非採用にした仕組みは導入しない。実装前に確定が必要なものは末尾に記載する。

## 1. アーキテクチャと変更対象

既存の **Router → Controller → Usecase → Repository → DataStore** を維持。AWS API 操作は Repository / Data Client 内に閉じ、Controller は入力 decode・Usecase 呼出・出力 encode のみ。`Dependencies`、既存 `Application.Error` と `Record<Content>` を活用する。

| 既存実装 | 確認した内容 | 変更 |
| --- | --- | --- |
| `Infrastructure/Application.swift` | endpoint も Middleware も前方一致 | **endpoint 完全一致 / `use` Middleware 前方一致**へ |
| `Backend.swift`、`Router/FestivalRouter.swift` | FestivalRouter が `GET /festivals/:festivalId` を登録 | 広告 Router を追加、先行登録による衝突解消 |
| `Data/Auth/CognitoAuthManager.swift` | region / district のみ認証 | advertiser と Cognito sub に対応 |
| `Infrastructure/Midleware/AuthMiddleware.swift` | Bearer なしは guest | 既存動作を維持。広告主権限は Usecase 側で判定 |
| `Data/Database/DataStore.swift` | CRUD / Scan / Query のみ | Credit の原子的操作用に最小限拡張 |
| `Data/Database/DynamoDBStore.swift` | 通常の Put / Get / Query | ConditionExpression / TransactWriteItems に対応 |
| `Data/Database/Record.swift` | pk / sk / type / content | 同一形式で新 Record を保存 |
| `Data/Repository/DistrictRepository.swift` | index-TYPE と FESTIVAL# の参照 | Store でも既存パターンを使用 |
| `Shared/Sources/Utils/JSON.swift` | `@NullEncodable` がある | Store の画像2フィールドの明示 JSON null に流用 |
| `Backend/Package.swift` | AWS DynamoDB / Cognito の SDK | S3 と Apple 検証に必要な依存を追加 |

### 分割方針

| 新しい領域 | 主な責務 |
| --- | --- |
| StoreRouter / StoreController / StoreUsecase | 登録・公開一覧・所有者 CRUD |
| StoreImageUsecase / StoreImageClient | presigned PUT 発行、画像チェック、正式配置 |
| PurchaseController / PurchaseUsecase / AppStoreClient | Apple 取引検証と購入先確認 |
| AdvertisementRouter / AdvertisementController / AdvertisementUsecase | 広告選択・通報 |
| ImpressionUsecase | 表示 token 検証と Credit 減算 |
| StoreRepository / CreditRepository / PurchaseRepository / ImpressionRepository | DB キー、永続化、必要な原子的更新 |

薄い Usecase・Repository は実装段階で統合してよい。汎用トランザクション DSL や新しいサービスレイヤーを作らない。

## 2. Router：HTTP 完全一致、use は前方一致

### 2.1 マッチング規則

**HTTP endpoint**（`get/post/put/delete`）はパス要素数まで一致を要求する。`app.use(...)` で登録される **method == nil の Middleware は前方一致**。Express のルートと Middleware の区別に合わせる。

既存 `Application.Layer.method: Method?` だけで両者を判別できるため、優先順位ルーター・正規表現・Trie は不要。動的パス要素 `:festivalId` は従来どおり1要素にマッチする。

| 登録 | `/festivals/F` | `/festivals/F/stores` |
| --- | --- | --- |
| `app.get("/festivals/:festivalId", ...)` | 一致 | **不一致** |
| `app.get("/festivals/:festivalId/stores", ...)` | 不一致 | 一致 |
| `app.use("/festivals/:festivalId", ...)` | 一致 | 一致 |
| `app.use("/", ...)` | 一致 | 一致 |

現在 `Backend.swift` で先に登録する `AuthMiddleware(path: "/")` は全 API に作用する。`FestivalRouter` の `GET /festivals/:festivalId` が新しい子 API を横取りしない。末尾スラッシュは既存 `split(separator: "/")` に従い同一扱い。クエリは URL パス判定に含めず `Request.parameters` から取得。未登録 URL は 404。

### 2.2 Router 回帰テスト（必須）

`Backend/Tests/Router` に Swift Testing で追加。Controller を Spy に差し替え、HTTP status **だけでなく正しい Controller の呼出回数と誤呼出0回**を検証する。以下は**コード実装時に作成するテスト項目**であり、本 PR では未実行。

| ID | 入力・条件 | 期待 |
| --- | --- | --- |
| R01 | `GET /festivals/F` | FestivalController.get のみ1回 |
| R02 | FestivalRouter が先に登録された状態で `GET /festivals/F/stores` | 公開 Store Controller のみ1回。FestivalController.get は0回 |
| R03 | `GET /festivals/F/advertisements/next?placement=banner` | 広告 Controller のみ1回。`placement` を取得。FestivalController.get は0回 |
| R04 | 既存 `GET /festivals/F/launch` | 既存 SceneController に到達する |
| R05 | `GET /festivals/F/unknown` | ルートがなければ404。FestivalController.get は0回 |
| R06 | `GET /stores/S` と `PUT /stores/S` | Path が同じでも HTTP Method で別 handler |
| R07 | POST だけ登録された `/stores/S/images/upload-url` へ GET | 404。POST handler は0回 |
| R08 | `GET /festivals/F/stores/extra` | 公開 Store の GET に前方一致せず404 |
| R09 | `app.use("/")` に加え Bearer token 付きの子ルート | AuthMiddleware が1回、user が後続 handler に渡る |
| R10 | `app.use("/")`、Bearer 不在 | middleware が guest を渡す（保護 API なら Usecase で拒否） |
| R11 | `app.use("/festivals/:festivalId")` | 同パスとその配下に適用。別 Prefix `/festivalish/F` には適用されない |
| R12 | `GET /festivals/F/` | `GET /festivals/F` と同じルート |
| R13 | `GET /festivals/F/stores` で F を複数切替 | `festivalId` が正確に抽出される |
| R14 | 複数 Middleware と1 endpoint を登録 | Middleware の実行順序・next 処理を維持 |

Router の責務は**到達先とパラメータの正しさ**。所有権などの認可は Usecase テストで検証する。

## 3. Entity / DTO

Shared に置く共通型を使用し、Backend 独自の同一 Entity を増やさない。

### 3.1 永続化 Entity

| Entity | 主要フィールド | 正本 |
| --- | --- | --- |
| `Store` | id、festivalId、ownerId、purchaseAccountToken(UUID)、name、address、coordinate、businessHours、description、bannerImagePath、interstitialImagePath、ownerPaused、moderationStatus、createdAt、updatedAt | DynamoDB |
| `CreditAccount` | storeId、balance、lastPurchasedAt | DynamoDB |
| `PurchaseRecord` | transactionId、storeId?、appAccountToken?、productId、creditedAmount、purchasedAt、environment、**creditGranted**、**refundStatus**、**refundDeductedCredits**、**lastRefundEventSignedDate**、refundedAt など | DynamoDB。付与済み・返金済み・未付与の正本。`storeId` の省略は返金先着の未付与レコードに限定 |
| **StorePurchaseReference（検索用 Record）** | storeId、transactionId、productId、creditedAmount、purchasedAt | 店舗別購入履歴の Query 専用参照。**独立したドメイン Entity ではない**。Credit を付与した取引だけを作成し、`PurchaseHistoryItem` に変換 |
| `ImpressionRecord` | impressionId、storeId、placement、chargedAmount、chargedAt | DynamoDB |
| `UserRole`（既存変更） | headquarter / district / advertiser(sub) / guest | 認証情報から算出 |

Store 作成時に Backend が **店舗単位の購入用 purchaseAccountToken を1つだけ発行**。画像用 UUID ではない。ownerId・festivalId・purchaseAccountToken・moderationStatus・createdAt は広告主が変更できない。返金先着を扱う `PurchaseRecord.creditGranted` / `refundStatus` は第9章で詳細化する。

### 3.2 API 境界

| DTO | 用途 |
| --- | --- |
| `StoreCreateRequest` | Store 作成。id / ownerId / token は Backend が決定 |
| `PublicStore` | 未認証向けの店舗・画像パス（公開可能なもののみ）、`updatedAt` |
| `AdCandidate` | 配信対象、正式画像パス、`updatedAt`、短命 impressionId / token |
| `ImageUploadURLRequest` / `ImageUploadURLResponse` | 固定 S3 一時キーへの署名 URL |
| `PurchaseClaimRequest` / `PurchaseResult` / `PurchaseHistoryItem` | Apple 署名取引・付与結果・履歴 |
| `ImpressionReportRequest` | impressionId と署名 token |
| `AdvertisementReportRequest` | Store の通報 |

管理用 Store GET/PUT は `Store`、残高 GET は `CreditAccount` をそのまま返す。別の画像確定 DTO は作らない。PUT の両画像パスは **JSON キー必須、nil は `@NullEncodable` 等で JSON null、省略は400**。

## 4. DynamoDB

既存 `matool` テーブルの `Record<Content>`（pk / sk / type / content）形式を再利用する。

| PK | SK | 保存内容 |
| --- | --- | --- |
| `FESTIVAL#{festivalId}` | `STORE#{storeId}` | Store |
| `USER#{cognitoSub}` | `STORE#{storeId}` | Store 所有者参照（festivalId を含む） |
| `STORE#{storeId}` | `CREDIT` | CreditAccount |
| `PURCHASE#{transactionId}` | `METADATA` | **PurchaseRecord の正本・全店舗一意** |
| `STORE#{storeId}` | `PURCHASE#{purchasedAtUTC}#{transactionId}` | **StorePurchaseReference（店舗別購入履歴の検索用参照）** |
| `STORE#{storeId}` | `IMPRESSION#{impressionId}` | ImpressionRecord |

- Festival 内 Store は FESTIVAL PK + SK beginsWith で Query。公開一覧の結果整合性は許容する。
- **所有者操作（Store GET / PUT・画像 URL・購入・残高）の Store 取得**は GSI を使わず、認証済み Cognito sub から **`USER#{sub} / STORE#{storeId}` をベーステーブルの一貫性の強い GetItem で取得**して festivalId を得て、次に **`FESTIVAL#{festivalId} / STORE#{storeId}` を一貫性の強い GetItem** で読む。所有参照の存在だけに頼らず、取得した Store の ownerId == sub を再確認する。参照不在・不一致なら拒否。Store ID 単独で GSI を Query する処理をこの経路で使わない。
- **所有 Store 一覧**も `USER#{sub}` PK をベーステーブルの **ConsistentRead 付き Query** で取得し、参照の festivalId から Store 本体を取得する。作成直後の一覧・画像入稿で 404／欠落しないことを保証する。直接 Get / Query で必要な箇所だけ `ConsistentRead: true` を DataStore に渡せるよう最小限拡張する（既存呼出のデフォルトは変更しない）。
- **店舗別の購入履歴**は `STORE#{storeId}` PK、`PURCHASE#` SK prefix で Query する。SK の日時は UTC の**辞書順に時系列となる固定形式**（例: `2026-10-31T12:30:00.000Z`）とし、transactionId を付けて同時刻の衝突を防ぐ。必要なら降順で返す。全 PurchaseRecord の Scan / Filter は使わない。
- Credit は STORE PK の直接 Get。購入の正本は transactionId で Get、Impression は storeId + impressionId で照合。

**金銭・Credit 操作だけに原子的整合性を要求する。**

- 購入: **PurchaseRecord のグローバル一意な条件付き作成／未付与マーカー更新 + StorePurchaseReference の条件付き作成 + Credit 加算**を **同一 DynamoDB TransactWriteItems** で確定。購入の正本の transactionId で二重付与を防ぎ、同一店舗の履歴を効率よく取得する。StorePurchaseReference は初回付与に成功する場合のみ作成し、返金が先に届いた未付与マーカーには作らない。返金後も付与済みの参照は保持する。
- **`lastPurchasedAt` は `max(既存値, Apple の署名済み purchasedAt)` として単調増加**させる。購入・未完了取引の到着順は信頼しない。CreditAccount を読み、現在の `lastPurchasedAt`（未設定を含む）との一致を **TransactWriteItems 内の Credit 更新条件**にして、より新しい日時のみ採用する。競合時は再取得して再計算し、正本・参照・残高をすべて原子的に確定する。**単純な GET→PUT や日時の無条件上書きは禁止**。返金では `lastPurchasedAt` を巻き戻さない。
- 表示: `ImpressionRecord` の条件付き新規作成 + 残高 `balance >= cost` を条件とする減算 → **TransactWriteItems**。
- DynamoDBEncoder は `.convertToSnakeCase`、Decoder は `.convertFromSnakeCase`。**保存属性は `content.balance` と `content.last_purchased_at`**（後者を `lastPurchasedAt` と書かない）。DynamoDB のネストマップの式を実際にテストし、**購入後の再読込で最終購入日時が正しく復元される**ことを検証する。
- 購入台帳は二重付与防止のため保持。**返金も同じ PURCHASE キーの状態更新と Credit 残高調整を同一 TransactWriteItems で確定**し、未付与で返金が先着した取引は同じキーにマーカーを保存する。Impression は token の有効期間と再送可能期間を超えた後 TTL 等で整理。

**Store の初回登録は Store / Owner Reference / CreditAccount(balance=0) の3レコードを一回の TransactWriteItems で条件付き作成する。** 書込み途中の部分成功・孤立参照を許容しない（S3 は巻き込まない）。Store ID の衝突も条件式で拒否する。
HTTP 応答をクライアントが受け取れなかった場合、**iOS は POST を自動再送して新しい Store を作らず、まず所有 Store 一覧を一貫性の強い読取りで再取得して作成結果を確認する**。新しい冪等キー専用の台帳は MVP で追加しない。重複を完全には防げない残余リスクと、同時作成時の店舗数上限チェックの競合は許容する。Store PUT に revision / If-Match は付けず、**広告主の書込みは編集可能な `content` の属性に限定した `UpdateItem`** にする。`moderationStatus` や ownerId 等のサーバー管理属性を書き戻さない。広告主同士の編集は Last Write Wins を許容するが、**運営の停止状態は古い広告主 PUT で解除できない**。

## 5. 認証・認可（Cognito）

既存 User Pool を共有。`CognitoAuthManager` は現状 `custom:role = region / district` しか解釈しないので広告主 Role を追加する。

| Cognito | UserRole | ID |
| --- | --- | --- |
| `region` | `.headquarter(username)` | 既存ルール |
| `district` | `.district(username)` | 既存ルール |
| `advertiser` | `.advertiser(sub)` | **Cognito sub** |
| Bearer なし | `.guest` | なし |
| 不明・権限不正 | 401 | — |

広告主は自由サインアップ・メール確認。Cognito の App Client が `custom:role = region/district` を書き換えられない構成を必須とする。広告主の role 付与は、Cognito 設定を確認して「role なし通常ユーザーを advertiser と解釈」か Cognito 側で固定付与を選択する。**GetUserOutput.username を広告主 ID に流用しない**。

| 操作 | 認可 |
| --- | --- |
| Store 作成 | 認証済み advertiser + Store 登録数上限 |
| Store 編集・画像・残高・購入履歴 | `store.ownerId == cognitoSub` |
| 購入 | 所有者一致 **かつ Apple 署名取引の appAccountToken 一致** |
| 公開店舗・広告候補・Impression・通報 | 未認証も可能。公開条件や token 検証を別途実施 |
| 運営による公開停止・解除 | 広告主不可。Festival 管理者にも自動付与しない |

Store PUT は所有権を確認後、既存 Store を読み、**変更禁止フィールドの受信値が現在値と同一であることを検証（不一致 400）**してから許可項目だけ反映する。URL と body の ID 不一致も400、他人の Store は403。**永続化には `PutItem` の全レコード置換を使わず、編集可能フィールドだけの `UpdateItem`** を使う。`updatedAt` は Backend が発行する時刻であって revision ではない。運営が並行して状態を変更しても、広告主更新で元に戻らないことを保証する。

## 6. API 一覧

| Method | Path | Controller → Usecase | Req / Res |
| --- | --- | --- | --- |
| GET | `/advertisers/me/stores` | Store → StoreUsecase | [Store] |
| POST | `/festivals/:festivalId/stores` | Store → StoreUsecase | StoreCreateRequest → Store |
| GET | `/stores/:storeId` | Store → StoreUsecase | Store |
| PUT | `/stores/:storeId` | Store → StoreUsecase | Store → Store |
| POST | `/stores/:storeId/images/upload-url` | Store → StoreImageUsecase | ImageUploadURLRequest → ImageUploadURLResponse |
| GET | `/stores/:storeId/credits` | Purchase → PurchaseUsecase | CreditAccount |
| POST | `/stores/:storeId/purchases` | Purchase → PurchaseUsecase | PurchaseClaimRequest → PurchaseResult |
| GET | `/stores/:storeId/purchases` | Purchase → PurchaseUsecase | [PurchaseHistoryItem] |
| GET | `/festivals/:festivalId/stores` | Store → StoreUsecase | [PublicStore] |
| GET | `/festivals/:festivalId/advertisements/next?placement=banner` | Advertisement → AdvertisementUsecase | AdCandidate? |
| POST | `/advertisements/impressions` | Advertisement → ImpressionUsecase | ImpressionReportRequest → 空 |
| POST | `/advertisements/reports` | Advertisement → AdvertisementUsecase | AdvertisementReportRequest → 空 |

Controller は decode / parameter / user / Usecase / encode のみ。使用する HTTP コードは、400 不正入力、401 認証なし、403 他人の Store、404 不在、409 重複・競合、429 基本レート制限、500 外部障害。購入時の**処理済み transactionId 再送は追加付与せず正常応答**し、StoreKit の復旧を妨げない。

## 7. StoreUsecase

### Store 作成

1. `advertiser(sub)` と Festival 存在を確認。
2. 本人の Store 一覧で登録上限を確認。
3. Store ID / Store ごとの `purchaseAccountToken` を生成。
4. Store、Owner Reference、CreditAccount（balance=0）を**同一 TransactWriteItems で条件付き作成**。
5. 作成した Store を返す。**画像入稿は Store ID が発行された後**。POST の応答が失われたら iOS は新規 POST を即再送せず、強い整合性の所有 Store 一覧を再読込して存在を確認する。

重複店舗ハッシュの専用索引や、登録前の運営承認は設けない。

### Store PUT

1. URL の Store ID・所有者を確認し、**ベーステーブルの ConsistentRead** で Store を取得する。
2. **body の id が URL と不一致、または festivalId / ownerId / purchaseAccountToken / moderationStatus / createdAt が読取時の Store と不一致なら400**。認証 sub が Store.ownerId と異なれば403。編集可能な name / address / coordinate / businessHours / description / ownerPaused / 画像パスだけ採用し、updatedAt は Backend が発行する。
3. 一時画像パスは `StoreImageUsecase` で S3 正式キーにコピーし、DB 更新対象には正式キーを渡す。
4. **`StoreRepository.updateEditableFields`**（名前は案）で、DynamoDB の **`UpdateItem` + `UpdateExpression`** を実行する。`content.name`、`content.address`、`content.coordinate`、`content.business_hours`、`content.description`、`content.owner_paused`、`content.banner_image_path`、`content.interstitial_image_path`、`content.updated_at` など **広告主が更新できる属性だけを `SET` する**。画像 `null` は明示した DynamoDB NULL 属性をセットし、**`content` マップ全体を置換しない**。実際の snake_case 名は Encoder と照合する。
5. `ConditionExpression` で Store の存在と ownerId 一致を確認し、存在しない Record を `UpdateItem` が新規作成しないようにする。`ReturnValues: ALL_NEW` から**保存後の正しい Store** を返す。

**重要な並行操作**: 広告主 PUT が `approved` を読んだ後、運営 CLI が `suspended` を保存し、その後に広告主 PUT が到着しても、広告主の `UpdateExpression` は **`content.moderation_status` / ownerId / festivalId / purchaseAccountToken / createdAt を一切書かない**。したがって運営停止は解除されない。運営 CLI 側も運営管理の属性のみを更新する。広告主同士の編集は Last Write Wins とし、Store revision / 汎用 CAS は導入しない。S3→DB の非原子的なコピーは従来どおりの許容範囲。

### PublicStore

公開 DTO は Store をそのまま返さず、運営停止なら Store 自体を除外、本人停止なら画像パスを null にする。ownerId・Credit・購入 token・内部状態は返さない。画像 URL のキャッシュ更新には `updatedAt` を使う。

## 8. S3 入稿と画像確定

**画像はバナー1枚・全画面1枚。画像 UUID と専用確定／削除 API は不要。**

```text
temporary/stores/{storeId}/banner.jpg
temporary/stores/{storeId}/interstitial.jpg

stores/{storeId}/banner.jpg
stores/{storeId}/interstitial.jpg
```

1. `POST /stores/:id/images/upload-url` は ownerId と kind を確認し、固定一時キーにだけ直接 PUT 可能な署名 URL とそのキーを返す。
2. iOS が一時 S3 キーへ画像を PUT。再アップロードは同じキーを上書き。
3. iOS は **通常の Store PUT** で該当画像パスを一時パスにする。
4. Backend は期待した storeId / kind に一致するパス・画像実在・サイズ・内容を確認し、`CopyObject` で正式キーへコピー。
5. Store の画像パスを正式キーに置換して DB 保存。

| 画像フィールド | 意味 |
| --- | --- |
| `temporary/stores/{storeId}/{kind}.jpg` | 画像を正式配置へコピー |
| `stores/{storeId}/{kind}.jpg` | 現在の正式パスなら画像維持 |
| JSON `null` | DB から画像参照を解除（即時 S3 削除なし） |
| 他の文字列 | 400。特に他人の Store パスを拒否 |

S3 と DB の同一 Transaction は作らず、コピー成功・DB 失敗の一時的な不整合を許容。固定キーの複数端末更新は最後の S3 上書きを採用する。`temporary/` は Lifecycle で整理。正式画像の物理削除は休眠・退会などで更新を停止した Store の整理時に限定。S3 bucket / CDN / IAM / サイズ上限は実装前に確認。

## 9. Apple IAP・返金通知・Credit 調整

### 9.1 購入確定（既定）

- Store 作成時に Store ごとの不変な `purchaseAccountToken: UUID` を生成し、iOS は購入時に `.appAccountToken(store.purchaseAccountToken)` を指定。画像用 UUID とは別。
- `AppStoreClient` は Apple の署名済み Transaction、Bundle ID、Environment、Product ID、取引状態、appAccountToken を検証。**Base64 デコードだけでは検証としない。**
- `PurchaseUsecase` は Store 所有権と署名済み appAccountToken の一致を必須とする。Product ID → 500 / 1000 Credit は Backend が決める。
- `PurchaseRecord` の付与済みへの条件付き作成／更新と、`CreditAccount` の加算を同一 DynamoDB `TransactWriteItems` で確定。全 Store で transactionId は一意。付与済み Transaction の再送は二重加算せず成功を返す。
- **未付与かつ返金済み**の取引に、古い署名済み購入情報だけで Credit を付与しない。返金取消後の未付与取引は、正当な購入 Claim を再検証してから一度だけ付与する。**未付与マーカーから付与済みに更新するとき、`lastRefundEventSignedDate` と `refundStatus` を維持し、後着した古い REFUND を再適用させない**。
- iOS は Backend の付与成功を確認してから `Transaction.finish()` を実行。未完了取引は `Transaction.unfinished` / `Transaction.updates` で冪等に再送。

### 9.2 Apple 通知の入口と既存クラスへの追加

Apple **App Store Server Notifications V2** の HTTPS エンドポイントを App Store Connect に登録する。HTTP リクエストは `{ "signedPayload": "..." }`。Cognito Bearer は付けられないため、**Apple の署名検証を通るまで DB の状態を一切変更しない**。

| 型・構成 | 役割 |
| --- | --- |
| `PurchaseRouter`（または既存 Router に追加） | `POST /app-store/notifications` を登録。所有者用 Store API と異なるパス |
| `PurchaseController.notification` | body decode → Usecase 呼出 → 2xx / 失敗応答。新しい返金専用 Controller は不要 |
| `AppStoreClient.verifyNotification` | Apple 公式 [App Store Server Swift Library](https://github.com/apple/app-store-server-library-swift) の `SignedDataVerifier` で V2 の `signedPayload` と内包する `signedTransactionInfo` を検証 |
| `PurchaseUsecase.applyNotification` | 返金状態遷移、最新イベント・未付与の判定、Credit 調整指示 |
| `PurchaseRepository` / `CreditRepository` | 購入台帳の状態更新と残高更新を **同一 DynamoDB Transaction** で確定 |
| `PurchaseRecord`（Shared） | `creditGranted: Bool`、`refundStatus: active / refunded`、`refundedAt`、`refundDeductedCredits: Int`、`lastRefundEventSignedDate` を持つ |

**RefundUsecase、RefundRepository、RefundRecord、専用管理画面は作らない。** Bundle ID・環境、Production の Apple App ID、Apple Root CA の設定を管理し、証明書チェーンの検証を自作しない。検証済み Transaction の productId / appAccountToken / transactionId は既存台帳と照合する。

### 9.3 通知フロー

| Apple `notificationType` | Backend |
| --- | --- |
| `REFUND` | 返金**成立**。購入状態を refunded にし、付与済みなら残高調整 |
| `REFUND_REVERSED` | 返金の**取り消し**。前回実際に差し引いた Credit だけ戻す |
| `CONSUMPTION_REQUEST` | 返金申請に伴う問い合わせ。**まだ返金ではない**ため減算しない（Apple に消費情報を提供するかは別途検討） |
| `REFUND_DECLINED` | 申請却下。残高変更なし |
| その他の検証済み通知 | 本機能の対象外なら変更なしで正常受理 |

1. `PurchaseController` が受信し、`AppStoreClient` が通知と取引の署名・Bundle / Environment / Product を検証する。
2. `PurchaseUsecase` は `notificationType`、`notificationUUID`、`signedDate`、`transactionId`、`appAccountToken`、`revocationDate` 等を検証済み値から取得。
3. `PURCHASE#{transactionId} / METADATA` を直接参照する。既存レコードがあれば Store・商品・appAccountToken・環境の一致を検証。
4. **`REFUND` と `REFUND_REVERSED` は「残高を変えない場合」も必ず処理済み通知時刻を永続化する**。各取引の `lastRefundEventSignedDate` を比較して、**`signedDate <= lastRefundEventSignedDate` の通知は古い／重複として再適用しない**。より新しければ、現在の `refundStatus` と同じイベントでも **`lastRefundEventSignedDate = signedDate` を条件付き UpdateItem で保存**する。購入台帳がない場合は第9.5節の未付与マーカーを保存する。`notificationUUID` は診断に利用し、専用の通知台帳は設けない。
5. 第9.4節の Credit 調整（必要な場合）または **時刻だけの状態確定**を DynamoDB で完了した後、**HTTP 200**。既処理・対象外も200。**新しい signedDate を保存できなかった段階で成功扱いしない**。DB 障害等で確定できなければ **5xx** として再送可能にする。確定前に200を返さない。
6. Apple の Production には通知再送があるが Sandbox には同じ再送を期待しない。障害で取りこぼした通知は Apple の **Get Notification History** を使って運営が再取得・再処理する。常時ポーリング基盤は初期には作らない。

### 9.4 返金時の残高調整（方針 A・採用）

**現在残高から差し引ける分だけ減算し、残高を0未満にしない。** 購入単位の消費追跡は追加しない。

- 付与済み取引が返金されたときの `deduction = min(purchase.creditedAmount, creditAccount.balance)`。
- 500 Credit 購入 → 350 消費 → 残高150で返金なら **150だけ差し引いて残高0**。消費済み350を後から請求しない。
- 購入Bの Credit が残っている場合、購入Aの返金で**購入Bに由来する残高も差し引かれ得る**ことを MVP の割り切りとして許容する。
- `PurchaseRecord.refundDeductedCredits = deduction` を必ず保存し、`refundStatus = refunded` にする。
- `REFUND_REVERSED` は **前回の `refundDeductedCredits` だけ加算**し、状態を active に戻す。返金時に回収しなかった消費済み Credit は復元しない。二重加算はしない。
- 未付与での REFUND / REFUND_REVERSED は **残高を操作しないが `lastRefundEventSignedDate` は必ず更新**する。取消後の初回 Credit 加算は、後日正当な購入 Claim があった場合だけ。付与済みで既に `active` の状態への `REFUND_REVERSED` も **残高は触らず signedDate だけ更新**し、後着した古い `REFUND` を防ぐ。

**DynamoDB の処理**: PurchaseRecord と CreditAccount を読み `deduction` を計算。同一 `TransactWriteItems` で (1) PurchaseRecord の前状態・`signedDate` に対する条件付き更新、(2) CreditAccount の **読取残高一致条件付き**減算を実行する。Impression や他購入と競合した場合は最新値を取得して再計算・再試行する。残高を負にしない。返金取り消しの再加算も同様に一回限りの原子的更新で行う。

### 9.5 付与前に REFUND が先着する場合

- 購入が先に Apple で返金されたが、通信失敗で **PurchaseRecord も Credit 付与もまだない**ケースを扱う。
- 検証済み `REFUND` を受信したら、同じ `PURCHASE#{transactionId} / METADATA` キーに **`creditGranted = false / refundStatus = refunded` の未付与マーカーを条件付きで新規保存**する。**`REFUND_REVERSED` が先に届き PurchaseRecord がない場合も、`creditGranted = false / refundStatus = active / lastRefundEventSignedDate = T2` の未付与マーカーを保存**する。残高はどちらの場合も変更しない。別の Refund Entity やテーブルは不要。
- マーカーには Apple が署名した transactionId・productId・appAccountToken・Environment・signedDate を保持。**付与前は Store の逆引きができないため `storeId` は任意**とし、付与済み状態では必須とする。
- iOS が後から古い購入情報を送っても、マーカーが `refunded` なら付与を拒否。`REFUND_REVERSED` を受けたら `active` に戻すが**自動付与せず**、iOS の検証済み Claim により初回加算する。その際、未付与マーカーの **最新 `lastRefundEventSignedDate` は保持**する。
- Claim と通知が同時でも同じ PURCHASE キーの条件付き作成・更新で競合を検出し、最新レコードを再取得して判断する。
- **必須の順序逆転テスト**：取引が付与済み・`refundStatus=active` の状態で `REFUND_REVERSED(T2)` が届く → Credit を変えず `lastRefundEventSignedDate=T2` を保存 → 後着の `REFUND(T1<T2)` は無視する。**購入台帳がない場合**も、`REFUND_REVERSED(T2)` が active の未付与マーカーを作成 → `REFUND(T1)` は無視 → 後日の検証済み Claim だけが1回付与できる。DB 条件付き更新の競合・再送を確認する。

### 9.6 リリース条件

**REFUND の検知・署名検証・残高反映・重複処理・REFUND_REVERSED を動作確認できるまで IAP をリリースしない。** App Store Connect に Sandbox / Production の V2 通知先を設定し、Apple 署名済みテスト通知、再送、DB 障害時の応答、通知履歴による復旧を検証する。

参考：Apple Developer Documentation の App Store Server Notifications V2 / notificationType / signedDate / Responding to App Store Server Notifications、Apple 公式 Swift Library。

## 10. 広告配信と Impression

### AdCandidate 発行

1. Festival 内の Store 一覧を取得。
2. 運営・本人の停止、画像なしを除外。
3. Credit 残高（banner=1、interstitial=2 以上）を確認。
4. 掲載可能な**各店舗を等確率**で1店舗選択。
5. 正式画像パス、`updatedAt`、短命 `impressionId` / 署名 token を返す。

token の対象は impressionId / storeId / festivalId / placement / expiry。候補取得時は Credit を減算しない。

### Impression 確定

1. token の署名・期限・対象を確認。
2. **減算直前に現在の Store を再取得**し、停止・Festival 不一致・該当画像の削除をチェック。
3. `ImpressionRecord` の条件付き新規作成と `CreditAccount.balance >= cost` を条件とする減算を **TransactWriteItems** で確定。
4. 重複 impressionId、残高不足、停止、期限切れは減算しない。
5. Backend に届かない報告は課金せず後日請求しない。Backend 成功後の応答消失は減算済み。

署名 token は実表示の証明ではない。MVP は短命 token、重複防止、API Gateway 等の基本レート制限に留める。高度なセッション追跡、App Attest、異常消費自動検出は導入しない。Store 停止と消費の厳密な同時 Transaction も要求しない。

## 11. 運営停止・通報・保持期間

### 11.1 運営による強制停止・復旧

**運営専用の IAM 権限を用いた小さな管理スクリプト**で Store の状態を変更する。**管理画面・一般用の停止 API・新しい Cognito Role は作らない**。Festival の本部・町管理者にも権限を付与しない。

- **実行主体**: 運営者が引き受ける AWS IAM ロール。通常の Lambda 実行ロールや広告主の権限とは分離し、対象 DynamoDB テーブルに必要な書込み権限だけを許可。運営者認証・操作記録（監査ログ）を必須にする。
- **操作経路**: 例 `scripts/moderate-store`（CLI）。`festivalId`、`storeId`、`suspend / approve`、理由を引数に受け、ベーステーブルの `FESTIVAL#{festivalId} / STORE#{storeId}` を直接取得。存在・一致を検証し、**`content.moderation_status` と `content.updated_at` だけを更新**する。Record 全体の無条件上書きは避ける。Enum の実際の保存形は Shared の Codable と Encoder で確認する。
- **公開への反映**: 強制停止は店舗自体を PublicStore の一覧から除外、AdCandidate に出さず、Impression も減算前の状態確認で拒否。復旧は運営判断のみ。既発行の画像 URL の残存は `spec.md` の許容範囲。
- **停止中の Credit** は保持。広告主自身による `ownerPaused` の変更と、運営の `moderationStatus` は別物として扱う。

**運営停止の実装前テスト**: 認可されていない IAM 主体は更新不可、存在しない Store / Festival 不一致を拒否、停止後の PublicStore / AdCandidate / Impression の動作、**広告主 PUT が approved を読取 → 運営 CLI が suspended を更新 → 広告主が UpdateItem を実行する順序でも suspended を保持**、運営による復旧が可能なこと。停止スクリプトは最小の操作手段として用意し、公開ユーザー向け API は増やさない。

### 11.2 通報を運営に届ける

`POST /advertisements/reports` は、公開 API から匿名でも利用できる**最小の通知経路**として実装する。

1. `AdvertisementController` は `AdvertisementReportRequest(storeId, placement?, reason)` を decode。Store の存在を確認し、reason の長さ・空白、入力形式を検証。未認証利用者も送信可能だが、**API Gateway 等の基本レート制限**を適用する。
2. `AdvertisementUsecase` は通報対象 Store / Festival と受信日時（UTC）を添えて、**運営者が確認できる既存の連絡先へ通知**する。既存手段がなければ **Amazon SNS Topic → 運営メール（購読を確認済み）**を初期実装とする。
3. `ReportNotificationClient` は SNS Publish などの外部操作だけを担当する薄い Data Client。通知には Store ID、Festival ID、理由、日時を含め、不要な IP・個人情報を保存しない。成功したら API は正常応答。
4. **通知先に届く前に成功応答しない**。SNS Publish 失敗なら 5xx を返す。初期は専用の通報 Entity、DB 台帳、審査画面・キューを増やさない。再送で運営に重複通知され得ることは MVP として許容。
5. 運営は届いた通報を確認し、必要なら前節の **IAM 管理スクリプトで Store ID を指定して停止**、電話確認してから同じ経路で復旧する。

**定期的な簡易 AI チェック**は `spec.md` の運用方針として維持。ただし **今回の Backend Lambda 詳細設計とは別の運用タスク**として実装する。頻度・実行環境・異常時の通知先は初期公開前に確定し、専用の管理システムを本案件に追加しない。AI の判定のみで Credit 没収や自動的な不可逆削除はしない。

### 11.3 Store 数制限・長期保持

- 登録数の上限は1アカウント単位で設ける。具体値は実装前に決める。店舗名・住所のハッシュ索引による厳密な重複防止は行わない。
- 整理起点: `creditAccount.lastPurchasedAt ?? store.createdAt`。**未完了購入の到着順で lastPurchasedAt を逆行させない**（`4`）。
- Credit が残り画像がある店舗は2年後も通常保持。Credit が残り画像がない場合や、残高0で2年超の場合は `spec.md` に従い不要なリソースのみ整理する。
- **購入済み Credit・購入台帳・必要な所有者情報は失効させない。** 一時画像は S3 Lifecycle、正式画像は休眠・退会等で更新を停止した店舗の整理時に限り削除する。


## 12. 実装時のファイル配置案

```text
Backend/Sources/
├── Backend.swift                         [変更: Router 登録]
├── Router/
│   ├── StoreRouter.swift                 [追加]
│   ├── PurchaseRouter.swift              [追加: Apple通知のHTTP入口]
│   └── AdvertisementRouter.swift         [追加]
├── Controller/
│   ├── StoreController.swift             [追加]
│   ├── PurchaseController.swift          [追加: 購入＋通知受付]
│   └── AdvertisementController.swift     [追加]
├── Usecase/
│   ├── StoreUsecase.swift                [追加]
│   ├── StoreImageUsecase.swift           [追加]
│   ├── PurchaseUsecase.swift             [追加]
│   ├── AdvertisementUsecase.swift        [追加]
│   └── ImpressionUsecase.swift           [追加]
├── Data/
│   ├── Auth/CognitoAuthManager.swift     [変更]
│   ├── Database/DataStore.swift          [変更]
│   ├── Database/DynamoDBStore.swift      [変更]
│   ├── Repository/
│   │   ├── StoreRepository.swift         [追加]
│   │   ├── CreditRepository.swift        [追加]
│   │   ├── PurchaseRepository.swift      [追加]
│   │   └── ImpressionRepository.swift    [追加]
│   └── Client/
│       ├── StoreImageClient.swift        [追加]
│       ├── AppStoreClient.swift          [追加: 購入＋Apple通知検証]
│       └── ReportNotificationClient.swift [追加: SNS等の運営通知]
├── Infrastructure/Application.swift      [変更]
└── Utils/Environment.swift               [変更]

Shared/Sources/Entity/                     [追加・変更]
Backend/Package.swift                     [S3 / 必要に応じて SNS SDK＋Apple公式Swift Library]
scripts/moderate-store                    [追加案: IAM権限の運営停止・復旧CLI]
```

分割数は候補。委譲のみの薄い Usecase / Repository は実装時に統合してよい。`AGENTS.md` に従い Swift Testing、テスト対象とテストファイルを1対1、ソースのディレクトリ構成を再現する。

## 13. テスト計画（実装で追加）

**Router テストは `2.2` の R01〜R14 を全件実装。** その他は以下を必須テストとする。

| 対象 | ケース |
| --- | --- |
| Cognito / 認可 | sub 取得、広告主 Role、管理者への不正昇格拒否、他人の Store を拒否 |
| Store 作成 | Store / Owner Reference / Credit0 を**単一 Transaction** で作成。条件付き書込み失敗時に3件とも未作成。HTTP 応答消失時は POST 自動再送せず強整合な所有 Store 一覧で作成結果を確認。Store ID の一意性と所有店舗数上限 |
| Store 読取 | 作成直後の所有 Store GET・画像 URL 発行・所有一覧で **GSI を使わず ConsistentRead**。User Reference → Festival Store の直接 Get、認証 sub と Store.ownerId の一致・別人の Store 拒否 |
| 購入履歴 | 同じ Store の複数購入を SK `PURCHASE#{purchasedAtUTC}#{transactionId}` で Query。順序・同時刻の重複・他 Store 混入・未付与返金マーカーが履歴にならないこと・トランザクション失敗で参照だけ残らないこと |
| Store PUT | ID / festivalId / ownerId / purchaseAccountToken / moderationStatus / createdAt の不一致 400、他人の Store 403。**UpdateItem は編集可能なネスト属性のみ SET**、updatedAt は Backend が設定、ReturnValues ALL_NEW は現在の運営状態を返す。**広告主が approved を読取 → 運営が suspended → 広告主の PUT 完了でも suspended のまま**。管理フィールドを変更する UpdateExpression が生成されないこと |
| Store PUT | 固定一時／正式／明示 null、画像フィールド省略400 |
| S3 | 他店舗パス拒否、画像形式・サイズ不正、コピー失敗時の DB 未保存、一時画像の整理 |
| IAP | 署名不正、別 Bundle/Environment/Product、別 Store appAccountToken、二重付与なし |
| **返金・返金取消** | 未使用500 Credit返金で残高0、使用後は `min(購入 Credit, 残高)`、複数購入・他購入分の残高、REFUND_REVERSEDで実減算額だけ復元、同一通知・古いsignedDateを再適用しない、返金とImpressionの競合時にも負残高なし、未付与REFUND先着→後日Claim拒否、未付与の取消→Claimで一度だけ付与。**REFUND_REVERSED(T2)→REFUND(T1<T2) は (a) 付与済みactive、(b) PurchaseRecord未作成の両方で最新時刻を保持し、古い REFUND を無視**。署名不正、DBエラー時5xx・処理済み200、通知履歴からの再処理 |
| Consumable | Backend 成功前に finish しない、未完了 Transaction 再試行、応答消失後の冪等復旧 |
| Credit と日時 | 残高不足・同時消費で負残高なし。**購入日が新→旧の順に到着しても lastPurchasedAt は逆行しない**、条件付き更新競合時の再取得。**DynamoDBEncoder/Decoder の実属性 `content.last_purchased_at` で更新し、Credit と日時を再取得して round-trip 検証** |
| Impression | token 改ざん／期限切れ、重複、候補発行後の停止・画像削除 |
| 公開 DTO | 運営停止で店舗非公開、本人停止で画像 null、ownerId 等の非公開 |
| 保持期間 | 未購入は createdAt 起点、残高のある店舗の権利保持 |
| Festival | 異なる Festival への広告混入を拒否 |
| 運営停止 | IAM 非許可主体の書込み禁止、対象 Festival / Store ID の照合、停止で公開店舗・候補・減算が停止、広告主 PUT による解除拒否、運営スクリプトで復旧 |
| 通報 | 公開 POST の入力検証・基本レート制限・運営通知の Publish 成功、SNS 送信失敗時 5xx、運営受信内容の確認。簡易 AI チェックは**別運用タスク**に分割して初期公開前に実施方法確定 |

**非採用のテスト**：画像 ETag / S3 VersionId・画像世代 GC、Store revision、App Attest、重複店舗ハッシュ索引。これらは MVP の実装対象ではない。

## 14. 実装順序と残課題

順序：① Router の完全一致と回帰テスト → ② Shared モデル / Cognito Role → ③ Store CRUD（**初回3件 Transaction + 強整合 Store 取得**）と所有権 → ④ S3 入稿 → ⑤ Credit 原子的操作（**購入履歴参照・lastPurchasedAt 逆行防止・snake_case 実属性テスト**） → ⑥ Apple 取引検証と Purchase → **⑦ Apple V2通知・返金／取消と原子的テスト** → ⑧ 広告配信 / Impression → ⑨ **IAM 運営停止 CLI + 通報通知経路**・整理と結合テスト。**⑦まで検証するまで IAP リリース不可。運営停止・通報の受信と運用経路も初期公開前に動作確認する。**

| 未確定 | 実装前の確認 |
| --- | --- |
| Cognito セルフ登録時の Role 付与 | App Client の属性書き込み権限を確認 |
| Apple 取引 JWS の検証方法 | Apple 公式 Swift Library を基本とし、証明書・Production / Sandbox 設定を検証 |
| IAP 返金・取消 | **方針A採用**：現在残高の範囲で減算・返金取消は実減算額だけ復元。残課題は通知先設定と本番／Sandbox 疎通・再送テスト |
| S3 | 画像上限・公開配信 URL / キャッシュ・署名 URL の期限 |
| 運営 | Store 数上限と IAM 管理スクリプトの認可・監査設定を確定。**停止・復旧手段は第11.1節で決定済み**。通報通知先の SNS Topic / 運営メール購読を設定し実際の受信を確認。**簡易 AI チェックは別運用タスク**として頻度と実行方法を初期公開前に決める |
| 広告 | Viewable 閾値・全画面表示の条件 |
| セキュリティ | token の署名鍵管理と基本レート制限 |

> 本 PR は設計書だけを追加する。コード・AWS リソース・テスト実装は詳細設計のレビュー後に別 PR で実施する。