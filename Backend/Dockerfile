# ============================================================
# Stage 1 — Build Swift Lambda binary
# ============================================================

# ⚙️ 現在は Amazon Linux 2 ベース
#    → Swift for Amazon Linux 2023 が出たらこの行だけ差し替え！
# FROM swift:6.2.0-amazonlinux2 AS build
# ↓ 公式提供後はこちらに変更予定：
# FROM swift:6.2.0-amazonlinux2023 AS build

FROM swift:6.2.0-amazonlinux2 AS build

# Swift 環境の初期化
WORKDIR /workspace/Backend

# Backend の Package 設定を Backend 内にコピー
COPY Backend/Package.swift ./Package.swift
COPY Backend/Package.resolved ./Package.resolved
COPY Backend/.env ./.env

# Shared をコピー
COPY Shared ./Shared

# Backend のソースコードを Sources にコピー
COPY Backend/Sources ./Sources

# Tests をコピーしたい場合
COPY Backend/Tests ./Tests

# パッケージ解決
RUN swift package resolve

# 最適化ビルド
RUN swift build -c release --static-swift-stdlib

# ============================================================
# Stage 2 — Lambda Runtime (provided.al2 / provided.al2023)
# ============================================================

# ⚙️ 現在は provided.al2 で運用
#    → AL2023 へ移行する際はこの1行を置き換えるだけ
# FROM public.ecr.aws/lambda/provided:al2023
FROM public.ecr.aws/lambda/provided:al2

# Lambda が実行するエントリポイント（bootstrap）配置
COPY --from=build /workspace/Backend/.build/release/Backend /var/runtime/bootstrap

RUN chmod +x /var/runtime/bootstrap

# Lambda の起動エントリポイント
ENTRYPOINT ["/var/runtime/bootstrap"]
