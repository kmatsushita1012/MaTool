# MaTool-for-iOS_SwiftUI

「掛川祭」屋台位置配信アプリ「MaTool」iOS 版 SwiftUI

## Actions

[GitHubActions×Fastlane×Firebase で iOS アプリを配布する CI/CD を構築](https://note.com/resan0725/n/nc84186fa841c)

## Map

https://zenn.dev/oka_yuuji/articles/38afe965565002

## TCA

[TCA で Github リポジトリ検索アプリを作ってみよう ①](https://qiita.com/takehilo/items/814319d4666fef402a41)
[Refreshable API を TCA で使う](https://www.docswell.com/s/kalupas226/KEER8K-2021-11-13-123255#p30)
[SwiftUI の TCA と NavigationStack を使って画面遷移をする](https://qiita.com/YOSUKE8080/items/356386878f67b7ac3b73)

## yml

```
      - uses: actions/cache@v4
        with:
          path: .build
          key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
          restore-keys: |
            ${{ runner.os }}-spm-
            # - uses: actions/cache@v3
```
