# MaTool 独自広告システム設計

- 案件 ID: 20261031_original_advertisement
- 初版: 2026-10-31
- 状態: 設計案（プロダクト方針確定・実装細部は要検証）
- 対象: Shared / Backend / iOSApp
- 目的: 祭典に属する店舗の広告を、店舗自身が入稿・購入・配信できるようにする

> この文書は実装前の設計合意を保存するもの。**「確定済み仕様」「推奨実装」「未確定事項」**を区別する。コード・AWS 設定・App Store Connect の変更は含まない。

## 1. 背景・目的・MVP の境界

MaTool の Festival に属する加盟店舗が、認証付きの店舗管理画面から店舗情報と広告画像を登録し、iOS アプリ内課金（IAP）で広告表示用 Credit を購入する。来場者には地図上の店舗情報・バナー・全画面広告を提供し、実際の広告表示が成立したときだけ Credit を消費する。

優先順位は (1) 正確な課金とアクセス制御、(2) 小さい実装量、(3) 運営の手作業削減。既存の Swift / AWS Lambda / DynamoDB / Cognito / Shared / iOS TCA を流用する。管理者向けの大規模広告審査 UI、複雑なキャンペーン・入札・配信重み付けは初期対象外。

**本書での区別**
- **確定**: 今回までの合意。
- **推奨**: 実装時に選ぶ技術的な具体化。レビューで調整可能。
- **未確定**: プロダクトまたは外部制約の判断が未了。

## 2. 確定済みのプロダクト仕様

| 項目 | 確定内容 |
| --- | --- |
| 認証 | 既存 Cognito User Pool を管理者と共有。広告主は自由登録可 |
| 店舗の所有 | 1 店舗につき管理アカウントは 1 つ。1 アカウントは複数店舗を所有可能 |
| 範囲 | Store は 1 Festival に属し、祭典をまたいだ広告配信はしない |
| 店舗情報 | 店名、住所、営業時間、自由記述、位置座標。位置は自動設定を基本に手動調整可能 |
| 広告形式 | 地図上の店舗情報、バナー画像、全画面画像 |
| 広告画像 | バナー・全画面それぞれ 1 枚。画像なしの形式は配信不可 |
| 配信選択 | 同一 Festival の掲載可能店舗から **単純ランダム**（各店舗を等確率で選択） |
| バナー | 地図下部。5 秒で消去し、画面遷移を機に次の広告を選ぶ。自動ローテーションではない |
| 広告タップ | アプリ内の店舗詳細に移動 |
| 広告在庫なし | Google AdMob にフォールバック |
| Credit | 店舗ごとに残高 1 つ。形式間で共通。年度をまたいで持ち越す |
| 単価 | バナー表示 1 Credit、全画面表示 2 Credit |
| 購入 | iOS IAP、500 円／1,000 円でそれぞれ 500／1,000 Credit |
| 減算 | Viewable（実表示）を成立条件とし、表示報告を Backend が確定後に減算 |
| 全画面残高不足 | 必要な 2 Credit がなければ全画面の選択対象外 |
| 通信失敗 | 表示報告が Backend に受理されなければ減算しない。端末に積んで後日請求しない |
| 本人確認 | 登録後すぐ掲載可能。疑わしい場合に電話確認 |
| 審査 | 原則即時公開・事後審査。定期的な簡易 AI チェックと必要時の運営対応 |
| 停止 | 不備・運営停止・本人による停止の間も購入済み Credit は保持 |
| データ保持 | 最終購入から 2 年を長期未利用リソース整理の基準とする（Credit の失効期限ではない） |
| 画像なし・2 年超 | 残高があっても画像がなく、最終購入から 2 年を超えたときは不要なデータを最小化 |
| 削除・退会 | 直ちにすべて物理削除せず、掲出停止と最低限の記録保持で管理 |
| 運用責任 | Festival 管理者は広告管理を担当しない |
| 画像送信 | 店舗・広告形式ごとの固定一時 S3 パスに直接 PUT し、通常の Store PUT にそのパスを入れる。Backend が正式配置へコピーして Entity のパスを置換・保存する。画像ごとの UUID と専用確定／削除 API は不要 |

**補足**: 「同一店舗の重複登録をどう判定するか」「地図ピン自体に従量課金するか」などは、確定したものとして扱わず後段に残す。

## 3. 既存実装との接続点

| 既存実装 | 現状と追加方針 |
| --- | --- |
| [Shared/Sources/Entity/Auth.swift](../../../Shared/Sources/Entity/Auth.swift) | UserRole は guest / headquarter / district。広告主 Role と識別子の意味を追加する |
| [Backend/Sources/Data/Auth/CognitoAuthManager.swift](../../../Backend/Sources/Data/Auth/CognitoAuthManager.swift) | 現在の role 判定は region / district。広告主の登録・認証に対応する |
| [Backend/Sources/Infrastructure/Midleware/AuthMiddleware.swift](../../../Backend/Sources/Infrastructure/Midleware/AuthMiddleware.swift) | Bearer access token → UserRole。広告主が既存管理者 API にアクセスできないことを確認 |
| [Backend/Sources/Data/Database/DynamoDBStore.swift](../../../Backend/Sources/Data/Database/DynamoDBStore.swift) | 現行の CRUD / query を流用し、原子的な Credit 更新に必要な条件付き更新・取引操作を追加 |
| [Backend/Sources/Data/Repository/Festival/FestivalRepository.swift](../../../Backend/Sources/Data/Repository/Festival/FestivalRepository.swift) | matool テーブルの Record(pk, sk, type, content) 形式と index-TYPE を参照 |
| [Backend/Sources/Data/Repository/DistrictRepository.swift](../../../Backend/Sources/Data/Repository/DistrictRepository.swift) | FESTIVAL# 配下の子レコード設計を参考にする |
| [Backend/Sources/Router/FestivalRouter.swift](../../../Backend/Sources/Router/FestivalRouter.swift) | 既存の Router → Controller → Usecase → Repository 方式に追加する |
| [iOSApp/Sources/Data/Client/AuthProvider.swift](../../../iOSApp/Sources/Data/Client/AuthProvider.swift) | Amplify の SignUp・メール確認を追加。advertiser の identity は Cognito sub から取得 |
| [iOSApp/Sources/Application/PublicMapAdUsecase.swift](../../../iOSApp/Sources/Application/PublicMapAdUsecase.swift) | 既存 AdMob 表示制御。店舗広告の配信・消費とは分離 |
| [iOSApp/Sources/Data/Client/AdManager.swift](../../../iOSApp/Sources/Data/Client/AdManager.swift) | AdMob は現状無効化フラグあり。フォールバック稼働時に調整。既存の AdPlacement と区別し、店舗広告の種類は StoreAdPlacement とする |
| [AGENTS.md](../../../AGENTS.md) | レイヤード Backend / TCA iOS / Swift Testing / PR ブランチ方針を遵守 |

**注意**: UserRole に case を足すと、既存の switch の網羅性・管理者権限判定・AppState の生成経路に影響する。広告主を管理者権限として扱わないよう、コンパイラエラーの修正だけでなく認可テストを行う。

## 4. 認証・認可

### 4.1 アカウント

**推奨**: 新規広告主は既存 Cognito User Pool のセルフサインアップを使う。既存の region / district は現在のサーバー側管理者作成フローを維持する。広告主の認証識別子は変更されない Cognito sub を採用する（メールアドレスや username を ownerId としない）。

- iOS: 登録 → メール確認 → ログイン → Festival 選択 → Store 作成。
- Backend: access token を検証し、「認証ユーザー」「役割」「sub」を取得する。
- Cognito の custom:role は広告主が任意に region / district を設定・更新できない構成にする。セルフサインアップが許可されているか、App Client の属性書込権限・Pre Sign-up 等の設定を先に点検する。
- **実装案**: 新規ユーザーを advertiser として確実に分類する。custom:role を明示設定するか、role 未設定の通常認証済みユーザーを広告主として分類するかは Cognito 設定の確認後に決める。guest（未認証）と混同しない。

### 4.2 店舗操作権限

Store.ownerId は Backend が認証結果から設定し、クライアントの指定は受け取らない。店舗編集・画像・購入・残高・履歴 API は、操作対象店舗の ownerId と Cognito sub の一致を必須とする。1 アカウントから複数店舗を所有できる。

本部・町の管理者 Role に広告主の編集権限を自動付与しない。運営側の掲載停止は別の運用権限で実行し、広告主自身が強制停止を解除できないようにする。

## 5. Entity と公開 DTO（全型一覧・推奨）

この案件で追加・変更する型を **Entity／未認証公開 DTO／認証・書き込み DTO／内部補助型** に分け、全件を表にまとめる。既存の Festival・District 等は対象外。型名・細部は実装前の案。

### 5.1 Entity（正本として保持）

| Entity | フィールド（型の例） | 責務・保存先 | 公開範囲 |
| --- | --- | --- | --- |
| **Store** | id: String, festivalId: Festival.ID, ownerId: String, **purchaseAccountToken: UUID**, name: String, address: String, coordinate: Coordinate, businessHours: String, description: String?, bannerImagePath: String?, interstitialImagePath: String?, **bannerImageVersionId: String?**, **interstitialImageVersionId: String?**, ownerPaused: Bool, moderationStatus: ModerationStatus, **revision: Int**, createdAt: Date, updatedAt: Date | 店舗・画像の有効な S3 VersionId・購入先識別・更新競合を管理。FESTIVAL# 配下 | 所有者のみフル Entity を返却 |
| **CreditAccount** | storeId: Store.ID, balance: Int, lastPurchasedAt: Date? | 店舗ごとに1つの Credit。STORE# 配下 | 所有者のみ |
| **PurchaseRecord** | transactionId: String, storeId: Store.ID, **appAccountToken: UUID**, productId: String, creditedAmount: Int, purchasedAt: Date, environment: String, revocationStatus: String? | グローバル一意の Apple 取引台帳 | 非公開。広告主には PurchaseHistoryItem |
| **ImpressionRecord** | impressionId: String, storeId: Store.ID, festivalId: Festival.ID, placement: StoreAdPlacement, **imageVersionId: String**, chargedAmount: Int, chargedAt: Date | 画像世代と請求内容を含む重複防止台帳 | 非公開 |
| **UserRole（既存変更）** | headquarter(festivalId), district(districtId), advertiser(cognitoSub), guest | 認証・認可の Role | API の認証コンテキストで使用 |

Store の画像パスは **固定一時パス（新画像）・正式パス（維持）・明示 JSON null（削除）**。Store の作成時に Backend が **店舗単位の appAccountToken（UUID）を一度だけ**発行する。画像ごとの UUID ではない。`revision` は Store PUT が成功するごとに条件付きで増やし、古い版の書き込みには 409 を返す。クライアントからの ownerId・festivalId・purchaseAccountToken・moderationStatus 等のサーバー管理値の変更は拒否する。

### 5.2 公開 DTO（未認証の来場者に返却可能）

| DTO | フィールド（型の例） | 使用先 | 含めない情報 |
| --- | --- | --- | --- |
| **PublicStore** | id: String, festivalId: Festival.ID, name: String, address: String, coordinate: Coordinate, businessHours: String, description: String?, bannerImagePath: String?, **bannerImageVersionId: String?**, interstitialImagePath: String?, **interstitialImageVersionId: String?** | `GET /festivals/:festivalId/stores`・地図・店舗詳細 | ownerId、Credit、購入・審査台帳を除く。停止・審査 NG の画像は null。運営が店舗を非公開にした場合は一覧から除外 |
| **AdCandidate** | storeId: Store.ID, festivalId: Festival.ID, placement: StoreAdPlacement, imagePath: String, **imageVersionId: String**, impressionId: String, impressionToken: String | `GET /festivals/:festivalId/advertisements/next` | 現在配信可能な正式画像だけを返す |

PublicStore / AdCandidate の画像は **正式パスと公開中の S3 VersionId を必ずセットで返却**する。配信側は「キーの最新版」を無条件に取得せず、指定 VersionId に一致する内容を返す。停止中・審査 NG・対象画像なしのときは PublicStore の画像フィールド（パス・VersionId）を null にし、AdCandidate の対象からも除外。既発行 URL・CDN キャッシュの失効方針は第10章に記載。

### 5.3 認証・書き込み用 DTO（API 境界）

| DTO | フィールド（型の例） | 用途 | アクセス |
| --- | --- | --- | --- |
| **StoreCreateRequest** | name: String, address: String, coordinate: Coordinate, businessHours: String, description: String? | `POST /festivals/:festivalId/stores`。id / ownerId は Backend が設定 | 広告主 |
| **ImageUploadURLRequest** | kind: StoreAdPlacement, contentType: String | `POST /stores/:storeId/images/upload-url` | 所有者 |
| **ImageUploadURLResponse** | url: String, path: String, expiresAt: Date | 固定一時 S3 PUT 用 URL（S3 PUT の応答 ETag を CORS で公開）。uploadId 不要 | 所有者 |
| **PurchaseClaimRequest** | signedTransactionInfo: String | `POST /stores/:storeId/purchases` | 所有者 |
| **PurchaseResult** | transactionId: String, creditedAmount: Int, balance: Int | 同 API の購入確定結果 | 所有者 |
| **PurchaseHistoryItem** | transactionId: String, productId: String, creditedAmount: Int, purchasedAt: Date | `GET /stores/:storeId/purchases` の表示用 | 所有者 |
| **ImpressionReportRequest** | impressionId: String, impressionToken: String | `POST /advertisements/impressions` | 来場者 |
| **AdvertisementReportRequest** | storeId: Store.ID, placement: StoreAdPlacement?, reason: String | `POST /advertisements/reports` | 来場者 |

Store 更新は Store Entity 自体を PUT し、更新後の Store を返す。全体置換の **両画像パスには JSON キーを必須**とし、nil は既存の `@NullEncodable` と同様に明示的に `null` で送る。省略は 400。ETag は画像アップロード後にヘッダーで、Store revision は `If-Match` ヘッダーで送る（第7・10章）。残高 GET は CreditAccount をそのまま返し、専用の画像確定 DTO は作らない。

### 5.4 補助型・索引レコード（ドメイン Entity を増やさない）

| 型・レコード | 内容 | 目的 |
| --- | --- | --- |
| **StoreAdPlacement** | banner / interstitial | 画像種別・必要 Credit（1 / 2）を表す。既存 AdMob 用 AdPlacement と別型 |
| **ModerationStatus** | approved / suspended 等 | 運営停止と広告主停止の分離 |
| **StoreOwnerReference** | ownerId、storeId、festivalId | `USER#{cognitoSub} / STORE#{storeId}` の検索用参照 |
| **VerifiedPurchase** | 検証済み取引データ | 未検証入力と Credit Repository の境界 |
| **VerifiedImpression** | 検証済み表示データ | 未検証入力と減算処理の境界 |

**初期には作らない型**: 独立 Advertiser、Advertisement、Campaign、StoreMember、画像ごとの Upload Entity／uploadId／UUID。1店舗につきバナー1枚・全画面1枚の固定パスで十分。

## 6. DynamoDB レコード設計（推奨）

既存 matool テーブルの pk / sk / type / content に合わせる。以下は **論理キー**であり、本番で必要な GSI との整合は実装前に確認する。

| PK | SK | 内容 |
| --- | --- | --- |
| FESTIVAL#{festivalId} | STORE#{storeId} | Store |
| USER#{cognitoSub} | STORE#{storeId} | 広告主の所有店舗参照（festivalId を含む） |
| STORE#{storeId} | CREDIT | CreditAccount |
| PURCHASE#{appleTransactionId} | METADATA | 取引の一意な購入台帳 |
| STORE#{storeId} | IMPRESSION#{impressionId} | 重複防止・短期表示実績 |

アクセスパターン:
1. Festival の公開店舗一覧: FESTIVAL# 内で STORE# 前方一致。
2. 広告主の管理店舗一覧: USER# 内で STORE# 前方一致。
3. 個別 Store の取得: festivalId + storeId の直接キー、または既存 GSI に準じた ID 検索。
4. Credit: STORE# + CREDIT の直接取得。
5. 購入の二重付与排除: PURCHASE#transactionId を条件付き作成。
6. 消費の重複排除: STORE#storeId + IMPRESSION#impressionId を条件付き作成。

**原子的な処理**:
- Store 作成: Store / USER 参照 / CreditAccount 初期値をトランザクションで保存。
- IAP: 取引の条件付き新規作成 + 残高加算を一体として確定。
- Impression: impressionId の条件付き新規作成 + 残高が必要量以上であることを条件に減算。
- 同時表示報告で残高を負にしない。残高不足なら表示実績を課金確定させない。

実装では DynamoDB の条件付き UpdateItem / TransactWriteItems の追加が必要。型安全なラッパーを DataStore / Repository に置き、Usecase で直接 AWS SDK を呼ばない。

**台帳の保管**: 消費イベントを無期限・無制限に保持するとコストが増える。少なくともトークン有効期限・再送可能期間より長く重複防止記録を保持し、必要に応じて TTL / 集計を設ける。購入の一意性台帳は TTL で消さない。

## 7. API 設計（推奨）

既存 Router / Controller と同様の形で追加。認証付き GET と署名付き URL は `Cache-Control: no-store`。課金対象広告の候補発行もキャッシュさせない。

| Method | Path | 用途 / 認可 | 型 |
| --- | --- | --- | --- |
| — | Cognito SignUp / ConfirmSignUp / SignIn | 広告主登録・ログイン（Amplify） | Cognito 標準 |
| GET | /advertisers/me/stores | 所有店舗一覧 | [Store] |
| POST | /festivals/:festivalId/stores | 店舗作成。新規登録制限を必ず判定 | StoreCreateRequest → Store |
| GET / PUT | /stores/:storeId | 店舗取得・編集・画像確定・画像削除 | Store → Store（PUT は全体置換、revision 条件付き） |
| POST | /stores/:storeId/images/upload-url | **唯一の画像専用 API**。固定一時キーへの署名付き PUT URL 発行 | ImageUploadURLRequest → ImageUploadURLResponse |
| GET | /stores/:storeId/credits | Credit 残高 | CreditAccount |
| POST | /stores/:storeId/purchases | Apple 署名済み取引の検証・付与 | PurchaseClaimRequest → PurchaseResult |
| GET | /stores/:storeId/purchases | 購入履歴 | [PurchaseHistoryItem] |
| GET | /festivals/:festivalId/stores | 公開店舗（停止と画像公開条件を投影） | [PublicStore] |
| GET | /festivals/:festivalId/advertisements/next?placement=banner | レート制限付きの候補と表示トークン | AdCandidate? |
| POST | /advertisements/impressions | 表示検証と原子的 Credit 減算 | ImpressionReportRequest → 空応答 |
| POST | /advertisements/reports | 不適切広告の通報 | AdvertisementReportRequest → 空応答 |

### 7.1 既存ルーターとの衝突（実装前の必須修正）

現在の `Backend/Sources/Infrastructure/Application.swift` の `match` は `route.count <= pathParts.count` の前方一致になっている。`Backend.swift` の `FestivalRouter()` 内の `GET /festivals/:festivalId` が、`GET /festivals/:festivalId/stores` と `GET /festivals/:festivalId/advertisements/next` を先取りしてしまう。

**広告 API の追加前に、HTTP method が指定されたエンドポイントはパス要素数も完全一致に変更**する。`AuthMiddleware(path: "/")` 等の `method == nil` なミドルウェアは、従来どおりパスの接頭辞に適用できるよう別条件で処理する。ルーターの登録順のみに依存しない。`GET /festivals/F`、`GET /festivals/F/stores`、`GET /festivals/F/advertisements/next`、全域認証 Middleware のテストを追加する。**この設計書 PR ではコードは変更しない。**

### 7.2 Store PUT の契約

- `If-Match` で送られる **Store.revision** と現在の DB revision が一致するときのみ更新。DB 側は条件付き更新して revision +1。不一致は **409 Conflict**、欠落は 428 Precondition Required（既存エラーハンドリングで 400 とする場合は統一する）。クライアントは 409 で再取得し、編集内容を確認してから再送。無条件の自動上書きは禁止。
- **全体置換**なので `bannerImagePath`・`interstitialImagePath` は両方とも JSON キー必須。Swift 側は既存の `@NullEncodable` 等で nil を JSON `null` としてエンコードし、Backend はキー省略を 400 とする。
- 画像パスが **固定一時パス**なら、その kind に限り iOS の S3 PUT 応答 `ETag` を `X-MaTool-Banner-ETag` / `X-MaTool-Interstitial-ETag` ヘッダーで送る。ETag がない／不一致は 409 または 400 とし、黙って最新の一時画像を採用しない。
- 画像パスが **現在の正式パス**なら画像変更なし。正式パスへの任意書換えやサーバー管理属性の変更は禁止。
- 画像パスが **明示 null** なら公開参照を解除。正式 S3 オブジェクトの即時削除を伴わず、後の安全な整理処理に任せる（第10章）。
- Store ID を先に発行してから画像をアップロード。既存の店舗所有者認可を必ず検証する。

## 8. IAP と Credit

### 8.1 商品

StoreKit 2 の Consumable。500 円 → 500 Credit、1,000 円 → 1,000 Credit。Product ID は App Store Connect と一致させ、iOS に表示する価格は StoreKit の Product を使用する。

### 8.2 購入先の厳密な紐付け（必須）

Store 作成時、Backend が **Store ごとに固有かつ不変の `purchaseAccountToken: UUID`** を1つ生成し保存する。これは **広告画像の UUID ではない**。広告主が自分の Store を取得するときに返却する。購入開始時は、その Store の token を StoreKit 2 の `.appAccountToken(store.purchaseAccountToken)` として必ず付与する。

購入 API の URL `/stores/:storeId/purchases` と認証ユーザーの所有権に加え、**Apple 署名済み取引の `appAccountToken` が DB 内の対象 Store の token と完全一致することを必須検証**する。token のない取引、別店舗の token、別所有者の取引は付与拒否。`transactionId` の全体一意制約はこの検証の代わりではなく、二重付与防止として別途必要。

### 8.3 購入確定・未完了取引の復旧

1. iOS が購入対象 Store と `purchaseAccountToken` を確認して StoreKit 購入を開始する。
2. StoreKit が検証済み Transaction を返しても、**ただちに `Transaction.finish()` しない**。署名済み取引を Backend の `POST /stores/:storeId/purchases` に送る。
3. Backend は Apple の署名、Bundle ID、環境、商品 ID、取引状態、`appAccountToken` と所有権を検証する。
4. `transactionId` をグローバル一意の購入台帳へ条件付き作成し、**Credit 加算を同じ DynamoDB Transaction** で確定。同一取引の再送なら追加付与せず、確定済み結果を返す。
5. **iOS は Backend の確定成功（または既に処理済みという冪等成功）を確認してから `transaction.finish()`** を呼ぶ。通信失敗・サーバーエラーでは finish せず、未完了のまま残す。
6. 起動時・ログイン後・通信回復時は `Transaction.unfinished` / `Transaction.updates` を処理し、購入時の token に一致する Store を確認して同じ署名済み取引を再送。Backend が処理済みなのに応答だけ失われた場合も冪等応答で安全に finish できる。
7. Store が取得不能・所有権変更等により復旧不能なときは取引を安易に finish せず、サポートで照合できるようにする。

**返金・取消**: App Store Server Notifications、購入済み Credit 消費後の返金調整、負残高の回避はリリース前に決める。返金を検知できないまま課金機能を完成扱いしない。

**規約上の前提**: 購入済み Credit に有効期限を設けず、2年ルールで消去しない。公開時点の Apple App Review Guidelines と StoreKit 仕様を再確認する。

## 9. 配信・Viewable・消費

### 9.1 掲載可能条件

Festival が一致し、店舗が停止されておらず、その形式の画像があり、残高が形式の消費量（バナー 1 / 全画面 2）以上の店舗だけを候補にする。地図ピンに画像がなくても店舗詳細を残すか、ピンの課金有無は後述の未確定事項。

候補から **各店舗等確率**で選択する。過去表示回数に基づく重み付け、直近除外、時間帯・Period 別出し分けは作らない。店舗が多数の場合の候補取得最適化はパフォーマンスを測ってから対応する。

### 9.2 広告表示

- バナー: 地図下部に表示し、5 秒経過で消す。画面遷移時に次候補を選ぶ。5 秒ごとに別広告へ入れ替えない。
- 全画面: 2 Credit。表示タイミングは **未確定**。
- タップ: MaTool 内の店舗詳細へ。
- 店舗広告が掲載不可: 既存 Google AdMob にフォールバック。現状の AdManager は広告停止フラグを持つため稼働時に調整する。
- iOS 上の広告プレビューでは表示実績を送らず、Credit を消費しない。

### 9.3 Impression プロトコル（推奨）

1. Backend が選択した storeId / placement / impressionId / 短命な署名付き impressionToken を返す。表示候補の取得だけでは減算しない。
2. iOS が画像を取得し、**Viewable 条件を満たした場合だけ** token を Backend に送る。
3. Backend が token の署名・期限・対象店舗・形式を照合し、残高の条件付き減算と impressionId の重複防止記録を原子的に確定する。
4. 通信に失敗してサーバーで確定されなかった報告は請求しない。オフラインキューによる後日請求はしない。
5. タイムアウト等で応答だけが失われ、Backend では確定済みの場合は減算済みと扱う。クライアントの通信エラーだけを理由に確定済み減算を取り消さない。
6. 同時に候補として選ばれた後で Credit が尽きた場合、減算が失敗した表示は課金しない。残高は負にしない。

**未確定**: Viewable の閾値（可視割合・最短時間など）。全画面の表示タイミングとともに公開前に確定する。

## 10. S3 画像入稿（固定パス + Store PUT）

### 10.1 決定した方式

**画像ごとの UUID / uploadId を発行しない。** 1 店舗につき画像はバナー1枚と全画面1枚だけなので、一時キー・正式キーともに storeId と画像種別による固定パスとする。

    temporary/stores/{storeId}/banner.jpg
    temporary/stores/{storeId}/interstitial.jpg
    stores/{storeId}/banner.jpg
    stores/{storeId}/interstitial.jpg

画像は必要なら iOS で JPEG に圧縮。署名付き PUT URL により **iOS から一時 S3 パスに直接送信**する。Store Entity の画像フィールドに一時パスを設定して **通常の Store PUT** に含める。Backend はそのパスを検証し、本配置へのコピー、Entity のパス置換、DynamoDB 保存までを Store 更新の処理として行う。画像付きの API Gateway リクエストや画像専用確定 API は設けない。

### 10.2 具体的な処理

1. `POST /festivals/:festivalId/stores` で Store を先に作成し、storeId を得る。
2. `POST /stores/:storeId/images/upload-url` で所有権・画像種別をチェックし、指定した **固定一時キーにだけ PUT できる**短寿命 URL と一時キーを返す。
3. iOS → S3: `temporary/stores/{storeId}/{kind}.jpg` に画像を PUT。次回は同じ一時パスを上書きする。
4. iOS → `PUT /stores/:storeId`: Store の `bannerImagePath` または `interstitialImagePath` に返却済み一時キーを指定。他の Store フィールドも通常どおり送信。
5. Backend: Store の所有権・パスが当該 storeId と kind に完全一致すること・画像の実体とサイズ等を検証し、S3 CopyObject で `stores/{storeId}/{kind}.jpg` に上書きコピー。
6. Backend: Store Entity 内の該当フィールドを **正式パスに置換**して DynamoDB に保存し、確定した Store を応答する。画像のない形式は `null`、正式パスが送られた形式は維持と解釈。
7. 画像削除は画像フィールドを `null` にして同じ Store PUT を実行する。S3 の正式オブジェクトは参照解除後に削除。不要な一時画像は Lifecycle で後日削除（例: 1 日）。

Store PUT 例（その他の必須フィールドは省略した概念例）:

```json
{
  "id": "store-123",
  "name": "店舗A",
  "bannerImagePath": "temporary/stores/store-123/banner.jpg",
  "interstitialImagePath": "stores/store-123/interstitial.jpg"
}
```

成功後、レスポンスの `bannerImagePath` は `stores/store-123/banner.jpg` になる。画像選択のキャンセルや PUT 未実行でも正式な Store は更新されず、一時画像のみが残る。

### 10.3 整合性・セキュリティ（MVP）

**S3 のコピーと DynamoDB の Store 更新を一体のトランザクションにはしない。** コピー成功後に DB 更新が失敗した場合、正式キーの画像だけ更新されてしまう可能性を許容する。Store PUT は再実行でき、一時画像は Lifecycle に任せる。

- 一時・正式パスは勝手な文字列を受け付けず、現在の Store と kind からサーバー側で期待パスを計算する。UUID は不要だが URL の有効期間内は同じ一時キーの上書きが可能。
- 署名付き URL 発行時・Store PUT 時とも所有権を確認する。S3 オブジェクトが存在するだけで安全とはみなさず、画像の実データ・寸法・容量を検証する。
- 固定正式パスは上書きされるため、画像キャッシュには Store.updatedAt 等のバージョン値を利用する実装案とする。
- S3 バケットは原則非公開。正式画像の配信方法は既存環境に合わせて決める。
- 画像なしの形式は掲出不可だが、Credit は保持。長期未利用画像の削除方針は第12章に従う。

**未確定**: 画像最大サイズ、画素、縦横比、署名 URL の有効期限、公開画像の配信方法。

## 11. 地図と一般利用者 UI

- Festival の公開 Store 一覧を取得し、地図上に店舗情報を表示する。
- 店舗詳細には名前、住所、営業時間、自由記述、位置、画像を表示する。
- バナー・全画面タップは同じ店舗詳細に遷移。
- Festival / 年度の切り替えでは広告の選択を更新するが、Store / Credit は年度に紐付けない。
- 公開用 Store には ownerId や購入履歴を含めない。
- **設計案**: 地図ピンの閲覧は Credit を消費せず、バナー・全画面の Viewable のみ従量課金する。ただし、この扱いは最終確認が必要。

## 12. 掲載停止・審査・保存期間

### 12.1 掲載停止と審査

- 自由登録直後から掲載条件を満たせば配信できる。
- 不審な店舗は電話確認、定期的な簡易 AI チェック、問題がある場合は運営が配信を停止する。
- 広告主の任意停止と運営による強制停止を区別する。
- 違反停止でも購入済み Credit を没収しない。
- 広告の通報・運営対応は簡易な経路から始める。専用審査ダッシュボードは初期対象外。

### 12.2 長期未利用データ

判定の起点は **最後の Credit 購入日**。購入済み Credit 自体の有効期限ではない。

| 条件 | 扱い |
| --- | --- |
| 残高 > 0、画像あり | 最終購入から 2 年を超えても通常保持 |
| 残高 > 0、画像なし、最終購入から 2 年超 | 広告停止のまま画像以外の不要なリソースも最小化。残高・所有権・取引記録は保持 |
| 残高 = 0、最終購入から 2 年以内 | 原則保持（配信不可） |
| 残高 = 0、最終購入から 2 年超 | 不要な画像等を削除し、必要な台帳・所有権情報だけを保持 |
| 広告主が退会・店舗削除を要求 | 掲載停止を先行。Credit や購入履歴を安易に物理削除しない |

画像がない広告形式は Credit があっても配信不可。アカウント削除や個人情報消去の要求と、購入記録保持の法令・契約上の取扱いは実装前に確認する。

S3 の temporary は Lifecycle で処理。正式画像・DB リソース整理は定期ジョブを設ける案。ただし、ジョブ頻度・実行環境は未確定。

## 13. iOS / Backend への配置

### Shared（新規モデルと DTO）
- Entity/Store.swift
- Entity/Credit.swift
- Entity/Advertisement.swift（独立した広告 Entity ではなく StoreAdPlacement と公開配信 DTO を含む）
- Entity/Auth.swift の UserRole 更新

### Backend（既存レイヤード構成に追加）
- Router/AdvertisementRouter.swift
- Controller/StoreController.swift、AdvertisementController.swift、PurchaseController.swift
- Usecase/StoreUsecase.swift、PurchaseUsecase.swift、AdDeliveryUsecase.swift、ImpressionUsecase.swift
- Data/Repository/StoreRepository.swift、CreditRepository.swift、PurchaseRepository.swift
- Data/Database/DynamoDBStore.swift（条件付き更新・トランザクション拡張）
- Data/Client/S3ImageClient.swift、AppStoreClient.swift（名称・配置は例）
- Data/Auth/CognitoAuthManager.swift、Infrastructure/Midleware/AuthMiddleware.swift の拡張

### iOSApp（TCA / Dependencies）
- Presentation/View/Advertiser/: 店舗一覧、店舗編集、広告画像入稿、Credit 購入・残高
- Presentation/Parts/Advertisement/: 店舗広告バナー・全画面・プレビュー
- Application/: Store 操作、広告表示、購入 Usecase
- Data/Client/: StoreKit 2、S3 直接 PUT、広告表示実績送信
- 既存の AdManager は Google AdMob の責務のまま維持する

AppState は可能な限り SSOT。公開地図で使う店舗情報は必要な範囲で Festival の実行時状態に保持し、購入履歴・Credit といった広告主管理情報とは分ける。View には AppState 内部を公開せず、TCA State の computed property 経由とする。更新後は API レスポンスを正本にする。

## 14. MVP 実装順

1. Shared: Store / Credit / 公開広告 DTO / Role
2. Backend: 広告主認証・Store 作成・所有者認可
3. Backend: S3 一時画像・正式登録
4. Backend: IAP 取引検証・購入台帳・Credit の原子的加算
5. Backend: 配信選択・impressionToken・Credit 原子的減算
6. iOS: 広告主の登録・店舗編集・画像プレビュー・IAP 購入
7. iOS: 地図店舗・バナー・全画面・AdMob フォールバック
8. 通報・運営停止・長期未利用整理・リリース前検証

AGENTS.md に従い、原則 Shared / Backend / iOS の PR を分け、Swift Testing を使う。Bootstrap は指示がない限り実行しない。

## 15. 最低限のテスト観点

- Cognito の広告主が region / district 権限に昇格できない。
- 他人の Store を取得・更新・画像登録・購入対象として操作できない。
- Store 作成で親データ・所有者参照・Credit の片方だけが保存されない。
- Apple の同じ transactionId が別店舗を含めて二重付与されない。
- Apple 取引の検証失敗・環境不一致・商品不一致を拒否する。
- 同時消費で残高を負にしない。残高 1 の全画面は候補に出ない。
- impressionId の再送は二重減算しない。トークンの期限切れ・改ざん・別店舗流用を拒否。
- 表示せず離脱した広告、受理されなかった報告には Credit を請求しない。
- S3 の一時画像は別人の店舗で確定できない。不正形式・サイズを拒否。
- 固定正式画像キーへのコピー後に DB 更新が失敗した場合、画像だけ先に更新され得ることを検証し、再 PUT で復旧できる。
- 広告主停止・運営停止・画像なし・残高不足が配信候補から除外される。
- 最終購入から 2 年を超えたリソース整理後も購入済み Credit が残る。
- Festival 切り替え後、異なる Festival の広告を表示しない。

## 16. 未確定事項（追加の承認が必要なもの）

| 項目 | 内容 |
| --- | --- |
| 全画面表示タイミング | どの操作・頻度で出すか |
| Viewable 条件 | 可視割合・時間・遮蔽等の判定値 |
| 地図ピンの課金 | ピン表示・店舗詳細閲覧は従量課金対象か（本書は無課金を仮置き） |
| 画像仕様 | 最大容量・画素・縦横比・対応画像形式 |
| 店舗重複防止 | どの条件を「同じ実店舗」とみなすか |
| 店舗数上限 | 1 アカウントの所有店舗数の具体値 |
| IAP 返金 | 取消通知と残高調整の確定仕様 |
| 公開画像配信 | 非公開 S3 の配信方法、キャッシュ、既存基盤との統合 |
| Google AdMob の再稼働 | 停止フラグと表示優先順位の動作確認 |
| Android / Web | 広告表示を初期スコープに含むか |
| 審査ジョブ | AI 簡易チェックの具体的実行環境・頻度 |

## 17. 実装時に検証する技術的事項

- Cognito Pool の SignUp 可否、App Client 属性書込権限、custom:role の安全な割り当て。
- iOS Amplify と Backend で Cognito sub の取得が一致しているか。
- DynamoDB の既存 index-TYPE と新規 Record 型の整合。
- Apple 署名付き取引情報のサーバー検証、StoreKit 2 の Consumable の復旧動線、App Store Server Notifications。
- S3 SDK / 署名付き PUT と Lambda 側の画像検証ライブラリ。
- 広告用 GET をキャッシュしない設定、広告取得頻度、S3・DynamoDB のコスト。
- StoreKit / App Review Guidelines / プライバシー・通報要件をリリース時点で確認。

## 18. 参照

- [リポジトリ開発ガイド](../../README.md)
- [エージェント規約](../../../AGENTS.md)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple App Store Server API](https://developer.apple.com/documentation/appstoreserverapi)
- [AWS S3 Presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html)
- [AWS DynamoDB Transactions](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/transaction-apis.html)
