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

## 5. Entity と公開 DTO（全型一覧・MVP）

追加・変更する全型を一覧にする。既存の Festival / District 等は対象外。**画像アップロード専用の Entity、画像 UUID、ETag・VersionId、Store revision は持たない。** Apple IAP の購入先照合に使う Store 単位の UUID は、画像識別子とは別の必須情報である。

### 5.1 Entity（永続化対象）

| Entity | フィールド（型の例） | 責務・公開範囲 |
| --- | --- | --- |
| **Store** | id: String、festivalId: Festival.ID、ownerId: String、**purchaseAccountToken: UUID**、name: String、address: String、coordinate: Coordinate、businessHours: String、description: String?、bannerImagePath: String?、interstitialImagePath: String?、ownerPaused: Bool、moderationStatus: ModerationStatus、createdAt: Date、updatedAt: Date | 1店舗の情報と2種類の広告画像。所有者向け管理 API ではフル Entity。年をまたいで維持 |
| **CreditAccount** | storeId: Store.ID、balance: Int、lastPurchasedAt: Date? | 店舗単位の共通 Credit。所有者のみ |
| **PurchaseRecord** | transactionId: String、storeId: Store.ID、appAccountToken: UUID、productId: String、creditedAmount: Int、purchasedAt: Date、environment: String、revocationStatus: String? | Apple 取引の店舗横断で一意な購入・付与台帳。内部のみ |
| **ImpressionRecord** | impressionId: String、storeId: Store.ID、placement: StoreAdPlacement、chargedAmount: Int、chargedAt: Date | 表示実績・重複減算防止。内部のみ |
| **UserRole（既存型を変更）** | headquarter(festivalId)、district(districtId)、advertiser(cognitoSub)、guest | 既存 Cognito Pool を使った認可の分類 |

Store 作成時に Backend が **店舗につき1つの購入用 `purchaseAccountToken`（UUID）**を発行して保存する。画像には UUID を使わない。Store 更新では ownerId・festivalId・purchaseAccountToken・運営停止状態・作成時刻などをサーバーが保護する。

### 5.2 公開 DTO（未認証閲覧者向け）

| DTO | フィールド（型の例） | 用途・公開条件 |
| --- | --- | --- |
| **PublicStore** | id、festivalId、name、address、coordinate、businessHours、description、bannerImagePath: String?、interstitialImagePath: String?、**updatedAt: Date** | `GET /festivals/:festivalId/stores`、地図と店舗詳細。広告主停止なら画像パスを null、運営が店舗を非公開にしたら店舗自体を除外。内部情報は含めない |
| **AdCandidate** | storeId、festivalId、placement: StoreAdPlacement、imagePath: String、**updatedAt: Date**、impressionId、impressionToken | 広告配信 API。配信可能な画像の正式パスと短命の表示 token のみ |

公開 DTO は画像の一時パス、ownerId、Credit、運営停止の理由、購入台帳を含めない。画像更新時のキャッシュ用バージョンは **Store.updatedAt** を流用し、画像ごとの世代を保存しない。停止後の新規公開レスポンスからは画像を除く。既に取得された画像 URL・キャッシュの残存は配信基盤の期限に依存する。

### 5.3 API 境界 DTO（認証・書き込み・応答）

| DTO | フィールド（型の例） | 対応 API・アクセス |
| --- | --- | --- |
| **StoreCreateRequest** | name、address、coordinate、businessHours、description? | 店舗作成。id / ownerId / purchaseAccountToken は Backend が採番。広告主のみ |
| **ImageUploadURLRequest** | kind: StoreAdPlacement、contentType: String | 一時画像アップロード URL 発行。店舗所有者のみ |
| **ImageUploadURLResponse** | url: String、path: String、expiresAt: Date | 固定一時パスと S3 PUT 署名 URL。店舗所有者のみ |
| **PurchaseClaimRequest** | signedTransactionInfo: String | Apple の署名済み取引を検証。店舗所有者のみ |
| **PurchaseResult** | transactionId、creditedAmount、balance | 購入確定結果。店舗所有者のみ |
| **PurchaseHistoryItem** | transactionId、productId、creditedAmount、purchasedAt | 購入履歴。店舗所有者のみ |
| **ImpressionReportRequest** | impressionId、impressionToken | 表示報告。一般クライアントから送信 |
| **AdvertisementReportRequest** | storeId、placement: StoreAdPlacement?、reason | 広告通報。一般クライアントから送信 |

Store PUT は Store Entity 全体を送受信する。画像2フィールドは **必ず JSON キーを含める**。Swift の既存 `@NullEncodable` 等で `nil` を JSON `null` にし、欠落キーは Backend で 400 とする。別途の画像確定・削除 DTO は作らない。

### 5.4 補助型と検索用参照（追加 Entity は不要）

| 型・レコード | 内容 |
| --- | --- |
| **StoreAdPlacement** | banner / interstitial（1 / 2 Credit）。既存 AdMob 用型とは分離 |
| **ModerationStatus** | approved / suspended 等。広告主自身の停止とは分離 |
| **StoreOwnerReference** | ownerId、storeId、festivalId。`USER#{cognitoSub} / STORE#{storeId}` で所有店舗を引く |
| **VerifiedPurchase** | Backend が署名と店舗との対応を検証済みの購入情報 |
| **VerifiedImpression** | Backend が表示 token を検証済みの消費情報 |

**MVP では追加しないもの**: Advertiser、Campaign、独立 Advertisement、StoreMember、アップロード用 Entity／UUID、S3 VersionId モデル、Store revision、重複店舗のハッシュ索引レコード。

## 6. DynamoDB レコード設計（推奨）

既存 `matool` の `pk` / `sk` / `type` / `content` と既存 GSI の規約に従う。

| PK | SK | 内容 |
| --- | --- | --- |
| FESTIVAL#{festivalId} | STORE#{storeId} | Store |
| USER#{cognitoSub} | STORE#{storeId} | 店舗所有者の検索用参照 |
| STORE#{storeId} | CREDIT | CreditAccount |
| PURCHASE#{appleTransactionId} | METADATA | 全店舗で一意の購入記録 |
| STORE#{storeId} | IMPRESSION#{impressionId} | 二重減算防止用の短期記録 |

アクセスパターンは Festival 内 Store 一覧、所有者の Store 一覧、Store 個別取得、Credit 直接取得、Apple transactionId の重複照合、impressionId の重複照合とする。

**原子的な整合性が必要なのは金銭・Credit 処理。** 購入は transactionId の条件付き新規作成と Credit 加算、表示実績は impressionId の条件付き新規作成と残高不足を防ぐ Credit 減算を、DynamoDB の原子的な書き込みで確定する。Store や画像の更新については追加の revision / CAS / 分散トランザクションを導入せず、通常の更新を使用する。Store 初回作成で店舗参照や残高初期化に失敗した際の再実行を可能にする。

Impression の重複防止レコードは、token の有効期間・再送期間を超えたら TTL 等で整理できる。購入の一意性台帳は削除しない。

## 7. API 設計（推奨）

| Method | Path | 用途 / 認可 | 型 |
| --- | --- | --- | --- |
| — | Cognito SignUp / ConfirmSignUp / SignIn | 広告主登録（Amplify） | Cognito 標準 |
| GET | /advertisers/me/stores | 所有店舗一覧 | [Store] |
| POST | /festivals/:festivalId/stores | 店舗作成（店舗数制限あり） | StoreCreateRequest → Store |
| GET / PUT | /stores/:storeId | 店舗取得・編集・**画像確定／参照削除** | Store → Store |
| POST | /stores/:storeId/images/upload-url | **唯一の画像専用 API**。固定一時キーへの署名付き URL 発行 | ImageUploadURLRequest → ImageUploadURLResponse |
| GET | /stores/:storeId/credits | 残高 | CreditAccount |
| POST | /stores/:storeId/purchases | Apple 署名済み取引の検証・Credit 付与 | PurchaseClaimRequest → PurchaseResult |
| GET | /stores/:storeId/purchases | 購入履歴 | [PurchaseHistoryItem] |
| GET | /festivals/:festivalId/stores | 公開店舗一覧 | [PublicStore] |
| GET | /festivals/:festivalId/advertisements/next?placement=banner | 次の広告候補と短命 token | AdCandidate? |
| POST | /advertisements/impressions | 表示報告と原子的減算 | ImpressionReportRequest → 空応答 |
| POST | /advertisements/reports | 不適切広告の通報 | AdvertisementReportRequest → 空応答 |

### 7.1 既存ルーティング衝突（採用した指摘）

現在の `Backend/Sources/Infrastructure/Application.swift` はメソッド付きルートでも前方一致するため、既存 `GET /festivals/:festivalId` が新規の `/stores` や `/advertisements/next` へ先にマッチする。**実装時には HTTP endpoint のパスを完全一致に変更する**。全域の `AuthMiddleware(path: "/")` のような method なし Middleware の前方一致だけは維持し、3つの URL の回帰テストを追加する。この PR は仕様書のみなのでコードは触らない。

### 7.2 Store PUT と画像パス

Store PUT は **全体置換・最後に受理された書き込みを採用**し、Store の revision や `If-Match`、画像の ETag ヘッダーは導入しない。低頻度・単一管理アカウントの編集であることを踏まえ、複数端末による古い上書きは MVP の許容事項とする。ユーザー画面は保存後の **Backend が返す Store を最新状態として反映**する。

- 固定一時キー（`temporary/stores/{storeId}/{kind}.jpg`）を指定: 所有権・種類・パス一致・画像実体・サイズを確認し、S3 正式キーにコピーして DB に正式パスを保存。
- 現在の正式パス（`stores/{storeId}/{kind}.jpg`）を指定: 画像変更なし。
- JSON `null`: DB の画像参照を解除。**物理画像をその場で削除しない**（第10章）。
- 両画像フィールドを省略せず送る。Swift `@NullEncodable` で null を明示し、欠落した場合は 400。
- ownerId、festivalId、purchaseAccountToken、運営停止状態等のサーバー管理フィールドをクライアントが改ざんできないよう検証。

署名付き URL は Store が作成されてから発行する。画像確定・削除専用 API は作らない。

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

### 9.1 広告選択（確定）

対象の Festival に属し、運営・広告主による掲載停止がなく、広告形式に対応する画像があり、必要 Credit（バナー1、全画面2）以上の店舗から、**各店舗等確率の単純ランダム**で選ぶ。過去の表示回数による重み付けはしない。

### 9.2 iOS 表示

- バナーは地図下部に表示し、5秒で消去。次回は画面遷移時に選択する（自動ローテーションしない）。
- 全画面は1表示2 Credit。表示タイミングは未確定。
- 広告のタップは MaTool 内の店舗詳細へ遷移。画像プレビューは課金対象外。
- 掲載可能な店舗広告がない場合は既存の Google AdMob で補完する。

### 9.3 Impression フロー

1. Backend は広告を選び、`storeId / festivalId / placement / impressionId / 短い有効期限` を署名 token に関連付けて返す。候補発行時には Credit を消費しない。
2. iOS が画像を表示し、Viewable 条件を満たしたときだけ impressionId と token を送信する。
3. Backend は署名・有効期限・対象店舗・広告形式を検証し、**減算時にも現在の Store の掲載停止、画像有無、Festival の一致を再確認**する。候補発行後に停止または画像削除されたら減算しない。
4. impressionId の条件付き新規記録と、残高不足を防ぐ Credit 減算を **DynamoDB の原子的書き込み**で確定。同じ impressionId は二重消費しない。Store の更新と消費の厳密な同時トランザクションまでは要求しない。
5. 表示報告が届かない、検証できない、残高が不足した場合は消費しない。端末に保留して後日請求しない。サーバーで確定後に応答だけ消失した場合は減算済みとする。

### 9.4 不正消費への最小限の対策

**署名 token は改ざん防止であって、実表示の証明ではない。** 未認証クライアントの偽報告を完全に防ぐことはできないが、MVP では既存 API Gateway 等で実現可能な **候補発行・報告 API の基本レート制限**、短命 token、二重減算防止を使う。高額消費の兆候や不正通報があれば運営が店舗の掲載を停止できる。

**採用しない**: 独自の端末／セッション追跡データストア、App Attest / DeviceCheck、IP ごとの高度な監視基盤、自動異常判定・請求保留の仕組み。規模に対して実装と運用が重いため、実害が出た場合に再評価する。API Gateway の総量制限だけでは特定の攻撃者を選別できない等の残余リスクは許容事項として明記する。

**未確定**: Viewable の閾値（可視割合・時間）、全画面表示のタイミング。課金開始前に決定する。

## 10. S3 画像入稿（固定パス + Store PUT）

### 10.1 確定した方式

画像は店舗ごとにバナー1枚・全画面1枚。**画像用 UUID、uploadId、専用確定／削除 API は不要**。iOS が署名付き URL で S3 の店舗別一時キーへ直接 PUT し、**Store Entity の画像パスに一時キーを入れ、通常の Store PUT で確定**する。

    temporary/stores/{storeId}/banner.jpg
    temporary/stores/{storeId}/interstitial.jpg
    stores/{storeId}/banner.jpg
    stores/{storeId}/interstitial.jpg

先に Store を作成して storeId を得る。画像は必要に応じて iOS で JPEG に圧縮。バケット名と CDN 等の配信方法は実装環境で決定する。

### 10.2 画像の登録・更新・削除

1. `POST /stores/:storeId/images/upload-url` で所有者と kind を確認して短寿命 S3 PUT URL と固定の一時パスを返す。
2. iOS が `temporary/stores/{storeId}/{kind}.jpg` にアップロード。再アップロード時は同じパスに上書き。
3. iOS が通常の `PUT /stores/:storeId` で画像パスを一時パスに設定する。
4. Backend は所有権・店舗 ID と kind に一致する固定パス・画像の存在、形式とサイズを検証し、S3 の `CopyObject` で `stores/{storeId}/{kind}.jpg` へ上書きコピーする。
5. Store Entity の画像パスを正式キーへ置き換え、DynamoDB に保存し、更新後の Store を返す。
6. 既存の正式キーが送られた場合はその画像を維持。`null` なら Store の画像参照を解除する。**画像の物理削除は通常の PUT では実行しない**。
7. `temporary/` の不要なオブジェクトは短い S3 Lifecycle（例: 1日）で整理。正式画像は長期未利用の整理でのみ扱う。

**PUT の例（概念。Store の他の必須フィールドは省略）**

```json
{
  "id": "store-123",
  "name": "店舗A",
  "bannerImagePath": "temporary/stores/store-123/banner.jpg",
  "interstitialImagePath": null
}
```

成功後の `bannerImagePath` は `stores/store-123/banner.jpg` になる。両画像フィールドは必須キーであり、未設定は明示 JSON `null`。欠落は400。

### 10.3 MVP で割り切る整合性・キャッシュ

- **S3 と DynamoDB を一括トランザクションにしない。** S3 Copy 成功後の DB 保存失敗で画像だけ先に更新され得るが、MVP では許容する。Store PUT は再実行できる。
- **固定一時キーの複数端末・古い署名 URL との上書き競合は検出しない。** 1店舗1管理アカウント、低頻度の画像変更を前提に最後の S3 書き込みを採用する。画像の UUID / ETag 照合 / S3 Versioning は導入しない。
- 画像を `null` にした直後に S3 の物理ファイルを消すと、次の画像更新と競合するため実施しない。通常の削除は公開参照を外す処理とし、長期未使用で休眠・退会した Store の整理時にのみ物理画像を削除する。
- 正式画像も固定パスのため、`PublicStore.updatedAt` と `AdCandidate.updatedAt` を画像 URL のキャッシュ更新に使う。公開 API は停止中の画像を返さず、短いキャッシュ期限で停止を反映する。**S3 上のファイルそのものを即時失効させる保証はしない**。
- S3 は原則非公開とし、画像配信方法は既存環境に合わせて選ぶ。新規 URL 発行がある場合、運営停止後は発行しない。

**未確定**: 画像の最大サイズ・画素・縦横比、署名 URL の期限、公開配信・キャッシュの具体方式。

## 11. 地図と一般利用者 UI

- Festival の公開 Store 一覧を取得し、地図上に店舗情報を表示する。
- 店舗詳細には名前、住所、営業時間、自由記述、位置、画像を表示する。
- バナー・全画面タップは同じ店舗詳細に遷移。
- Festival / 年度の切り替えでは広告の選択を更新するが、Store / Credit は年度に紐付けない。
- 公開用 Store には ownerId や購入履歴を含めない。
- **設計案**: 地図ピンの閲覧は Credit を消費せず、バナー・全画面の Viewable のみ従量課金する。ただし、この扱いは最終確認が必要。

## 12. 掲載停止・審査・保存期間

### 12.1 自由登録と公開範囲（MVP の悪用対策）

**本人確認を必須にせず即時公開できる方針は維持**する。ただし新規登録と公開は無制限に許可しない。公開 Store 一覧は Credit が 0 でも店舗基本情報を表示できるため、偽店舗・無料ピンの大量登録への対策を MVP 必須要件とする。

- **メール確認済みの広告主だけ作成可**。新規 Store 作成に所有者単位・IP 単位のレート制限を置く。実装開始時の運用初期値の例: **1アカウント最大5店舗、24時間で新規作成3件まで**（必要な正規店舗は運営が増枠対応）。IP 制限も設定する。上限値は運用設定で調整できるようにし、公開前テストで最終確定する。
- **同じ Festival + 正規化した店舗名 + 正規化住所**の組を重複登録候補として検出。正規化キーのハッシュに一意参照レコードを条件付きで作成し、単純な同時重複登録を拒否する。座標の近さは警告・運営照会に使う。同じ住所の別店舗を誤って拒否しないようにする。
- 登録直後の店舗は公開対象だが、通報・なりすまし・権利侵害を疑う場合は **運営がその Store の公開と全広告を即時停止**する。公開 Store API は以後 Store 自体を返さず、候補 API と画像の新規配信も停止する。
- **通報受付 → 公開停止 → 所有者への確認・必要時の電話 → 修正・権利確認 → 運営だけが再公開**、という最小の対応フローを必須とする。広告主は運営停止を解除できない。Credit を没収しない。
- **事後 AI 審査は補助**とし、これだけで登録のなりすまし・大量登録を防げるとはみなさない。審査ダッシュボードは不要だが、運営が ID 指定で停止・復旧できる最低限の操作経路を実装する。
- 店舗自体を非公開にする必要のない「広告主の配信一時停止」のときは、PublicStore に店舗の基本情報を残してもよいが、**バナー・全画面の画像パスと VersionId を必ず null** にする。運営による強制停止では Store 自体を公開対象から除外する。画像キャッシュの削除・失効は第10章に従う。

### 12.2 長期未利用データと未購入 Store

判定の基本起点は **最終購入日**。**一度も購入していない Store（`lastPurchasedAt == nil`）は Store.createdAt を起点**とする。購入済み Credit は有効期限を設けず、残高のある広告主の購入権利を失わせない。

| 条件 | 扱い |
| --- | --- |
| 残高 > 0、画像あり | 最終購入から2年超でも通常保持 |
| 残高 > 0、画像なし、最終購入から2年超 | 広告停止、不要リソースを最小化。Credit・所有権・台帳は保持 |
| 残高 = 0、最終購入から2年以内 | 原則保持、広告配信不可 |
| 残高 = 0、最終購入から2年超 | 不要な画像・店舗情報を整理し、必要記録だけを保持 |
| **購入履歴なし、作成から2年以内** | 原則保持。公開／停止は審査状態による |
| **購入履歴なし、作成から2年超** | 未購入・残高0の休眠店舗として公開停止し、不要画像等を整理。作成日が起点 |
| 広告主が退会・店舗削除を要求 | 公開停止を先行。Credit・購入記録を安易に物理削除しない |

S3 の一時領域は Lifecycle、正式領域は**参照中の VersionId を削除しない** GC を用いる。削除候補を選んだあとに参照状況が変わり得るので、DB 参照と画像世代を照合し、最新 Store が再公開された場合はその新世代を削除しない。運用期間の詳細は実装時に調整する。

個人情報の消去要求と、決済証跡の保持義務は分離し、保持すべき必要最小限の情報を確保する。

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

| 分野 | 必須テスト |
| --- | --- |
| **Router** | `GET /festivals/F` と `GET /festivals/F/stores`・`GET /festivals/F/advertisements/next` が互いに衝突しない。メソッド付きエンドポイントは完全一致、`AuthMiddleware(path: "/")` は全経路へ適用 |
| **認証・所有権** | 広告主が region / district になれない。他人の Store・画像・Credit・購入を操作できない |
| **登録悪用** | 同時の同一店舗登録を拒否。店舗数上限・作成頻度・IP 制限が働く。違う店舗を同一住所だけで誤拒否しない |
| **Store PUT** | 古い revision の全体置換に 409。再取得と編集内容の確認で再送。画像フィールドキー欠落 400、明示 `null` は削除扱い。勝手な ownerId / moderationStatus の変更を拒否 |
| **購入先** | Apple 署名済み `appAccountToken` と Store token の一致を必須検証。token なし、別 Store、他人の所有 Store、商品 ID 相違を拒否 |
| **Consumable 復旧** | Backend 成功まで `finish()` しない。未完了取引の起動時処理、サーバー成功後に応答消失した再送、取引の店舗横断の二重付与を検証 |
| **Credit** | 同時消費でも残高が負にならない。残高1の全画面は配信候補にならない |
| **広告不正消費** | 偽造・失効・異セッション token、連続発行・連続報告のレート超過、異常消費停止を検証。署名だけで「表示証明」とみなさない |
| **停止・画像差替** | 候補発行後に広告停止・画像更新・削除・Festival 切替が起きたら、その古い token での課金を拒否 |
| **公開 DTO** | 運営停止した Store は公開一覧から除外。本人停止時は PublicStore の画像を `null` にする。AdCandidate は停止画像を返さない |
| **S3 固定キー** | 別人の一時画像を採用できない。再アップロードによる ETag 不一致は 409。S3 コピー成功後に DB CAS が失敗しても、参照中の旧 VersionId の画像を維持 |
| **画像削除** | 削除直後の新規コピーで、古い削除・GC が新 VersionId を削除しない。公開 URL は VersionId 単位でキャッシュ分離 |
| **通報・運営** | なりすまし疑いを運営が即時非公開にできる。通報・確認後の復旧は運営のみ許可 |
| **保持期間** | `lastPurchasedAt == nil` の未購入 Store は createdAt から2年。購入済み Credit は2年経過でも消さない |
| **Festival** | 切替後に別 Festival の広告・店舗情報を表示しない |

文書のみの PR なので、ここに列挙したものは **実装時に追加すべきテスト**であり、この PR で実行済みという意味ではない。

## 16. 未確定事項（追加の承認が必要なもの）

**前章で「実装必須」とした安全対策は、この表の未確定項目を理由に省略しない。** 課金や公開の閾値はリリース前に決定する。

| 項目 | 内容 |
| --- | --- |
| 全画面表示タイミング | どの操作・頻度で出すか |
| Viewable 条件 | 可視割合・時間・遮蔽等の課金成立条件 |
| 地図ピンの課金 | ピン・店舗詳細の閲覧は従量課金対象か（本書は無課金を仮置き） |
| 画像仕様 | 最大容量・画素・縦横比・対応形式 |
| 店舗重複防止の調整 | 名前・住所の正規化方法、同じ住所の複数店舗の救済フロー |
| 店舗数・作成レート上限 | 第12章の初期案をリリース前の運用テストで調整 |
| Impression の運用閾値 | セッション／IP 制限と異常消費監視の実際の閾値、必要時の App Attest |
| IAP 返金 | 取消通知と残高調整のルール |
| 公開画像配信 | S3 VersionId 指定取得・CDN キャッシュと無効化の実装方法 |
| Google AdMob の再稼働 | 停止フラグと表示優先順位の動作確認 |
| Android / Web | 広告表示を初期スコープに含めるか |
| 審査ジョブ | AI チェックの実行環境・頻度 |

## 17. 実装時に検証する技術的事項

- Cognito Pool の SignUp 可否、App Client 属性書込権限、custom:role の安全な割り当て。
- iOS Amplify と Backend で Cognito sub の取得が一致しているか。
- DynamoDB の既存 index-TYPE と新規 Record 型の整合。
- Apple 署名付き取引情報のサーバー検証、StoreKit 2 の Consumable の復旧動線、App Store Server Notifications。
- S3 SDK / 署名付き PUT と Lambda 側の画像検証ライブラリ。広告バケットの Versioning、有効な CopySourceIfMatch、S3 PUT の CORS ETag 公開、正式画像 VersionId での GET を確認。
- 広告用 GET をキャッシュしない設定、広告取得頻度、S3・DynamoDB のコスト。
- StoreKit / App Review Guidelines / プライバシー・通報要件をリリース時点で確認。
- 公開 Store API に停止済み素材が残らないことと、既存 CDN／署名 URL の失効時間を確認。
- 未購入店舗の整理起点を Store.createdAt とし、残高が残る店舗の台帳を誤って削除しないことを確認。

## 18. 参照

- [リポジトリ開発ガイド](../../README.md)
- [エージェント規約](../../../AGENTS.md)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple App Store Server API](https://developer.apple.com/documentation/appstoreserverapi)
- [AWS S3 Presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html)
- [AWS DynamoDB Transactions](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/transaction-apis.html)
