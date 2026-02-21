# iOSApp Domain Layer Spec

## 1. 対象

- `iOSApp/Sources/Domain`
- `Shared/Sources/Entity`（共通モデル）

## 2. 責務

- クライアント利用時のドメイン型・制約の保持
- Entry/Extension を通じたドメイン表現の整備
- Backend と同一語彙での型整合

## 3. 非責務

- 画面遷移やUI制御
- APIクライアント実装

## 4. 依存ルール

- Domain は Presentation 詳細に依存しない。
- Shared モデルを正本とし、差分型は最小化する。

## 5. 参照

- `docs/spec/domain-model.md`
- `docs/spec/architecture-overview.md`
