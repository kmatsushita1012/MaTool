# ============================================================
# Stage 1 — Build Swift Lambda binary
# ============================================================

# ⚙️ 現在は Amazon Linux 2 ベース
#    → Swift for Amazon Linux 2023 が出たらこの行だけ差し替え！
# FROM swift:6.2.0-amazonlinux2 AS build
# ↓ 公式提供後はこちらに変更予定：
# FROM swift:6.2.0-amazonlinux2023 AS build

FROM amazonlinux:2023 AS build

# 基本ツール
RUN dnf update -y && \
    dnf install -y \
        swiftlang \
        clang \
        sqlite-devel \
        openssl-devel \
        libxml2-devel \
        libcurl-devel \
        git \
        tar \
        gzip \
    && dnf clean all
# Swift 環境の初期化
WORKDIR /workspace

# Backend のパッケージ設定とソース
COPY Backend ./Backend

# Shared は並列でコピー
COPY Shared ./Shared

# Backend 内でビルド
WORKDIR /workspace/Backend
RUN swift package resolve
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
