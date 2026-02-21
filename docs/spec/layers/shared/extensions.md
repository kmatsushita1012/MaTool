# Shared Extensions 仕様

本仕様は、Extension の配置ルールと命名規約を定義する。

## 1. 基本方針

- 共通ドメインで再利用可能な Extension は `Shared/Sources/Extensions` に集約する。
- iOSApp/Backend に閉じる Extension は各レイヤーへ残す。
- Presentation 表示ロジック（Text/Format/UI補助）のみ iOS 側に残す。

## 2. 分離ルール

- Domain Extension:
  - Entity/ValueObject の振る舞い拡張
  - コピー/並び替え/比較/参照補助など
- Infrastructure Extension:
  - SQLiteData などストレージ・I/O都合の拡張
  - クエリ補助や `FetchOne`/`FetchAll` の簡略化
- Presentation Extension:
  - 文字列整形、見た目に依存するフォーマット
  - UI のみで消費される拡張

## 3. 命名規約

- 形式は `+<拡張対象>` を使う。
- 例:
  - `Entity+Copy.swift`
  - `Entity+SQLiteData.swift`
  - `Period+Text.swift`
  - `View+LiquidGlass.swift`

## 4. 現在の適用

- Sharedへ移行済み:
  - `Shared/Sources/Extensions/Entity+Copy.swift`
  - `Shared/Sources/Extensions/Entity+SQLiteData.swift`
  - `Shared/Sources/Extensions/Array+AsyncDiff.swift`
  - `Shared/Sources/Extensions/Array+Upsert.swift`
  - `Shared/Sources/Extensions/Array+Diff.swift`
  - `Shared/Sources/Extensions/Array+Mutation.swift`
  - `Shared/Sources/Extensions/Sequence+KeyPath.swift`
  - `Shared/Sources/Extensions/Collection+KeyPath.swift`
  - `Shared/Sources/Extensions/Collection+Identifiable.swift`
- iOSに残す（Presentation専用）:
  - `iOSApp/Sources/Presentation/Utils/Anchor+Text.swift`
  - `iOSApp/Sources/Presentation/Utils/Period+Text.swift`
- 旧 `Extension.swift` / `Extensions.swift` は廃止し、用途別に分割済み。

## 5. 今後の運用

- 新規 Extension 追加時は、まず Shared へ置けるかを判定する。
- Shared に置けない根拠（UI依存、OS依存、外部SDK依存）がある場合のみ iOS/Backend に置く。
