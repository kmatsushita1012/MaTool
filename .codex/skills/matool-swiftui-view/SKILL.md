---
name: matool-swiftui-view
description: MaTool の SwiftUI 画面と TCA Presentation Feature を実装・設計するときに使う。標準 UI の選択、画面構成、状態と Action の境界、Simulator での画面確認を定める。
---

# MaTool SwiftUI View

## 対象と責務

- SwiftUI を優先し、View は表示とユーザー入力の受け渡しに集中させる。
- 画面状態、状態遷移、ナビゲーション、非同期処理は TCA の Feature に置く。ViewModel は作らない。
- View から API、DB、永続化、OS/SDK 操作を直接実行しない。必要な処理は Feature から Usecase など適切な境界を通す。
- アプリ全体で共有する実行時状態は `AppState` を可能な限り唯一の情報源（SSOT）にする。Feature 内の状態は画面固有の状態に限る。

## 標準 UI とレイアウト

- 管理画面で特別にリッチな表示が求められていない箇所は `Form`、`List`、`Section`、`LabeledContent`、`Picker`、`Toggle` など SwiftUI 標準 UI を使う。標準の整列や操作方法を維持する。
- まず標準コンポーネントの見た目、配置、インタラクションに任せる。`Button(title, systemImage:)` や SF Symbols など、意図に合う標準 API を優先する。
- 画面固有の装飾、カード化、独自の情報配置など、標準 UI を越える独自レイアウトは、ユーザーから明示的な要件または許可がある場合だけ追加する。標準コンポーネントを組み合わせるために必要な `VStack` / `HStack` は独自デザインに含めない。
- 数値を指定する `padding` と `spacing` は状況に応じて `8` または `16` を使う。それ以外の数値を新たに導入しない。システム標準の余白はそのまま使ってよい。
- フォントサイズやボタンなど操作 UI の大きさに数値を指定しない。`.font(.title)`、`.controlSize(.large)` のような SwiftUI の標準 enum/API を使う。
- 色は semantic color を優先し、独自色が要件に含まれる場合は Asset Catalog で定義する。`.white` / `.black` やコード内の RGB 値を直接使わない。
- Dynamic Type に追従する標準スタイルを使い、固定サイズで文字や操作 UI を縮めない。背景には可能な限り `.background` を使い、背景色だけのために `ZStack` を追加しない。

## View と TCA Feature の分担

- Feature は `State`、ユーザー意図を表す `Action`、状態遷移と副作用を扱う Reducer で構成する。View は State を表示し、ユーザー操作に対応する Action を送る。
- 一時的なフォーカスなど SwiftUI 固有の状態を除き、画面状態を View の `@State` に複製しない。入力値、ロード状態、選択状態、アラートや画面遷移は Feature State で管理する。
- `delegate` Action を機械的に増やさない。Feature 内で完結する操作はそこで処理し、子 Feature から親に伝える必要のある意味のある結果がある場合に限って Delegate を使う。単なる UI イベントの中継や、親が必要としない通知のために Delegate enum / case を作らない。
- Navigation は TCA の child state と tree 構造を基本にし、遷移先ごとの Boolean を増やさない。stack navigation は要件上 tree で扱いにくい場合に使う。
- 画面遷移やモーダルは TCA の Presentation State と SwiftUI 標準の navigation / sheet / dialog を組み合わせる。メニューや選択肢には `confirmationDialog` や `popover` を使い、内容量のある編集画面には `sheet` を検討する。
- Domain Logic を View や Feature に重複実装しない。Feature は Usecase などを呼び出して状態を更新し、ドメイン判断そのものは適切なレイヤーに置く。

## 構成と表示パターン

- 画面固有の View と Feature は対象画面の Presentation 配下にまとめる。複数画面から使う View は `/Presentation/View/Components/**` に置く。
- 入口となる View は Store と画面遷移を扱い、表示専用 View は値とイベントを受け取る形に分ける。読みやすさを損なうほど一つの View に責務を詰め込まない。
- `var` の `@ViewBuilder` は小さな表示分岐に使ってよい。肥大化する場合は別 View に分ける。`func` の `@ViewBuilder` は作らない。
- Preview は表示確認に役立つ画面・部品に付ける。Preview は Feature の状態やテスト用依存値で構成し、本番の外部依存を必要としない形にする。
- Empty State やエラーには SwiftUI 標準の表示手段を優先する。エラーは必要に応じて `alert`、Empty State は標準の仕組みを使う。
- コンテンツ量が少ない場合は `VStack`、多くなる場合は `LazyVStack` を選ぶ。暗黙のアニメーションを漫然と付けず、ユーザー体験上必要な箇所だけ明示する。

## 画面変更後の確認

- iOS の画面を実装・変更したら、XcodeBuildMCP で `iOSApp` を iPhone Simulator 上に起動する。
- `sim-use` の手順で対象画面まで実際に移動し、必要なタップ、入力、スクロールを行って動作を確認する。起動確認だけで完了としない。
- 最終状態のスクリーンショットと UI 情報を取得し、要件と照合する。実機操作で確認できない場合は、その具体的な理由と未確認の動作を報告する。
