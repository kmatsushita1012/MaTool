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
| `PurchaseRecord` | transactionId、storeId、appAccountToken、productId、creditedAmount、purchasedAt、environment、revocationStatus | DynamoDB |
| `ImpressionRecord` | impressionId、storeId、placement、chargedAmount、chargedAt | DynamoDB |
| `UserRole`（既存変更） | headquarter / district / advertiser(sub) / guest | 認証情報から算出 |

Store 作成時に Backend が **店舗単位の購入用 purchaseAccountToken を1つだけ発行**。画像用 UUID ではない。ownerId・festivalId・purchaseAccountToken・moderationStatus・createdAt は広告主が変更できない。

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
| `PURCHASE#{transactionId}` | `METADATA` | PurchaseRecord |
| `STORE#{storeId}` | `IMPRESSION#{impressionId}` | ImpressionRecord |

- Festival 内 Store は PK + SK beginsWith、所有 Store は USER PK で Query。
- Store ID 単独取得は既存 `index-TYPE` と `sk` の検索方法を踏襲（ID は全体で一意）。Festival ID があれば直接 Get。
- Credit は STORE PK の直接 Get。購入・表示実績はそれぞれのキーで照合。

**金銭・Credit 操作だけに原子的整合性を要求する。**

- 購入: `PurchaseRecord` を `attribute_not_exists` で作成 + `CreditAccount.content.balance` を加算し最終購入日更新 → **DynamoDB TransactWriteItems**。
- 表示: `ImpressionRecord` の条件付き新規作成 + 残高 `balance >= cost` を条件とする減算 → **TransactWriteItems**。
- 既存 `DynamoDBEncoder` の `content` は map のため、UpdateExpression のネスト属性パスに注意して検証する。
- 購入台帳は二重付与防止のため保持。Impression は token の有効期間と再送可能期間を超えた後 TTL 等で整理。

Store 初回登録は Store / Owner Reference / Credit0 の保存を行う。途中で失敗しても部分欠損が放置されないよう再実行・整合処理を用意する。既存 DynamoDB Transaction の再利用も可能だが、**画像を含む分散 Transaction は作らない**。Store PUT に revision / If-Match は付けず、Last Write Wins を許容する。

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

Store PUT は既存 Store を読み、許可された編集フィールドだけ上書きする。既存 `DistrictUsecase` の権限別 merge に合わせる。

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
4. Store、Owner Reference、CreditAccount（balance=0）を保存。
5. 作成した Store を返す。**画像入稿は Store ID が発行された後**。

重複店舗ハッシュの専用索引や、登録前の運営承認は設けない。

### Store PUT

1. URL の Store ID・所有者を確認し、既存 Store を取得。
2. 編集可能な name / address / coordinate / businessHours / description / ownerPaused / 画像パスのみ適用。サーバー管理情報は維持。
3. 画像パスが一時キーなら `StoreImageUsecase` による S3 本配置を実行。
4. `updatedAt` を更新して DynamoDB 保存し、**保存した Store** を返す。

低頻度・単一管理アカウントの前提で Last Write Wins。Store revision と楽観ロックは導入しない。

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

## 9. Apple IAP と Credit 付与

- Store 作成時に **Store ごとの `purchaseAccountToken: UUID`** を生成・保存。
- iOS は購入開始時に StoreKit `.appAccountToken(store.purchaseAccountToken)` を付ける。
- Backend `AppStoreClient` は署名済み Transaction の Apple JWS / 証明書、Bundle ID、Environment、Product ID、取引状態、appAccountToken を検証する。**payload をデコードするだけでは検証としない**。
- `PurchaseUsecase` は所有者と Store、署名済み appAccountToken の一致を必須検証。Product ID → Credit 数は Backend 定義（500円→500、1000円→1000）。
- PurchaseRecord の条件付き作成と Credit 加算を **TransactWriteItems** で同時確定。transactionId は全店舗で一意。
- 同じ transactionId の再送は PurchaseRecord の元の Store・商品を照合し、**二重付与せず成功応答**。

iOS は **Backend で Credit 付与成功を確認するまで `Transaction.finish()` しない**。失敗時は `Transaction.unfinished` / `Transaction.updates` を再処理し、Backend の冪等 API に再送。レスポンスだけ失われた場合にも余計な Credit は付与されない。返金処理・Apple 署名検証の Swift 実装手段は実装前に確定する。

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

## 11. 運営停止・保持期間

- 広告主の停止: AdCandidate から除外、PublicStore の広告画像は非公開。Credit は保持。
- 運営の強制停止: Store 自体を公開一覧から除外。運営専用経路で停止・復旧（Festival 管理者には権限付与しない）。
- 通報: 最小限の受付→ID 指定停止→必要時電話確認→復旧。専用ダッシュボード・重複店舗の専用索引は作らない。
- 店舗登録にはアカウント当たりの数の上限を設ける。値は後決め。
- 整理起点: `creditAccount.lastPurchasedAt ?? store.createdAt`。残高があり画像がある Store は2年を超えても通常保持。Credit が残り画像がない場合や残高0で2年超の場合に `spec.md` に従い不要リソースのみ整理。Credit・購入台帳・必要な所有情報は失効させない。
- 一時画像は Lifecycle、正式画像は休眠・退会等で利用を停止した Store の整理時に限り削除する。

## 12. 実装時のファイル配置案

```text
Backend/Sources/
├── Backend.swift                         [変更: Router 登録]
├── Router/
│   ├── StoreRouter.swift                 [追加]
│   └── AdvertisementRouter.swift         [追加]
├── Controller/
│   ├── StoreController.swift             [追加]
│   ├── PurchaseController.swift          [追加]
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
│       └── AppStoreClient.swift          [追加]
├── Infrastructure/Application.swift      [変更]
└── Utils/Environment.swift               [変更]

Shared/Sources/Entity/                     [追加・変更]
Backend/Package.swift                     [必要な SDK 追加]
```

分割数は候補。委譲のみの薄い Usecase / Repository は実装時に統合してよい。`AGENTS.md` に従い Swift Testing、テスト対象とテストファイルを1対1、ソースのディレクトリ構成を再現する。

## 13. テスト計画（実装で追加）

**Router テストは `2.2` の R01〜R14 を全件実装。** その他は以下を必須テストとする。

| 対象 | ケース |
| --- | --- |
| Cognito / 認可 | sub 取得、広告主 Role、管理者への不正昇格拒否、他人の Store を拒否 |
| Store | 店舗数制限、サーバー管理値の改ざん拒否、更新後の Store 返却 |
| Store PUT | 固定一時／正式／明示 null、画像フィールド省略400 |
| S3 | 他店舗パス拒否、画像形式・サイズ不正、コピー失敗時の DB 未保存、一時画像の整理 |
| IAP | 署名不正、別 Bundle/Environment/Product、別 Store appAccountToken、二重付与なし |
| Consumable | Backend 成功前に finish しない、未完了 Transaction 再試行、応答消失後の冪等復旧 |
| Credit | 残高不足・同時消費でもマイナスにしない |
| Impression | token 改ざん／期限切れ、重複、候補発行後の停止・画像削除 |
| 公開 DTO | 運営停止で店舗非公開、本人停止で画像 null、ownerId 等の非公開 |
| 保持期間 | 未購入は createdAt 起点、残高のある店舗の権利保持 |
| Festival | 異なる Festival への広告混入を拒否 |

**非採用のテスト**：画像 ETag / S3 VersionId・画像世代 GC、Store revision、App Attest、重複店舗ハッシュ索引。これらは MVP の実装対象ではない。

## 14. 実装順序と残課題

順序：① Router の完全一致と回帰テスト → ② Shared モデル / Cognito Role → ③ Store CRUD と所有権 → ④ S3 入稿 → ⑤ Credit の原子的更新 → ⑥ Apple 取引検証と Purchase → ⑦ 広告配信 / Impression → ⑧ 運営停止・整理と結合テスト。

| 未確定 | 実装前の確認 |
| --- | --- |
| Cognito セルフ登録時の Role 付与 | App Client の属性書き込み権限を確認 |
| Apple 取引 JWS の検証方法 | Swift での証明書・署名検証の実装 |
| IAP 返金・取消 | Credit の調整ルール |
| S3 | 画像上限・公開配信 URL / キャッシュ・署名 URL の期限 |
| 運営 | Store 数上限、停止・復旧する経路 |
| 広告 | Viewable 閾値・全画面表示の条件 |
| セキュリティ | token の署名鍵管理と基本レート制限 |

> 本 PR は設計書だけを追加する。コード・AWS リソース・テスト実装は詳細設計のレビュー後に別 PR で実施する。