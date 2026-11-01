# 画像アップロードの AWS 設定要件

Festival・District と将来の Store 画像で共通の設定を使用する。実際のバケット名や配信ドメインは環境ごとに設定する。

## ストレージ

- 画像専用 S3 バケットを用意し、パブリックアクセスをブロックする。`temporary/` を含むオブジェクトに匿名アクセスを許可しない。
- `temporary/` 配下は短期の Lifecycle 有効期限で削除する（目安は 1 日）。正式画像にはこのルールを適用しない。
- キーは `temporary/festivals/{festivalId}/{light|dark}.jpg`、`temporary/festivals/{festivalId}/districts/{districtId}/{light|dark}.jpg` を使用する。正式キーは先頭の `temporary/` を除いたもの。ID はパス区切りを含まないよう UTF-8 のパーセント表記に変換する。
- 将来の Store 画像は同様に `temporary/stores/{storeId}/{banner|interstitial}.jpg` と `stores/{storeId}/{banner|interstitial}.jpg` を使用する。

## 配信

- 正式キーのみを CDN から配信する。S3 は非公開とし、CloudFront の Origin Access Control 等で CDN からのアクセスを許可する。`temporary/` は CDN 経由でも公開しない。
- キャッシュポリシーでクエリパラメータ `v` をキャッシュキーに含める。画像差し替え時の異なる `?v=` を別のキャッシュとして扱うこと。
- リリース前に、公開 API の返す URL と CDN GET を使い、連続差し替え後の新画像取得と旧 URL とのキャッシュ分離を確認する。

## Backend の権限と設定

- Lambda 実行ロールに対象バケットの `temporary/` への `s3:PutObject` と `s3:GetObject`、正式キーへの `s3:PutObject` を付与する。署名付き PUT はこのロールの権限を使用する。必要に応じて KMS 鍵の権限も付与する。
- `IMAGE_UPLOAD_BUCKET`: 対象バケット名。
- `IMAGE_PUBLIC_BASE_URL`: 正式キーを配信する HTTPS のベース URL（末尾スラッシュなし）。
- `AWS_REGION`: バケットのリージョン。既存の Lambda 環境設定を使用する。
- 署名 URL の有効期限は 15 分、JPEG は最大 10 MiB、長辺 10,000 ピクセル、総画素数 40,000,000、縦横比 10:1 までとする。広告を含め共通の制約として使用する。

設定後は実環境で署名 PUT → 通常の Pack PUT → 公開 GET → CDN GET を通して確認する。S3 と DynamoDB の更新は原子的ではない。
