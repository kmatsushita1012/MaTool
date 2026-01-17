# ============================
# Stage 1: Build Swift Lambda binary (AL2023)
# ============================
FROM amazonlinux:2023 AS build

# 必要なツールとライブラリをインストール
RUN dnf update -y && \
    dnf install -y \
        swiftlang \
        gcc \
        make \
        tar \
        gzip \
        git \
        openssl-devel \
        libxml2-devel \
        libcurl-devel \
        binutils \
    && dnf clean all

WORKDIR /workspace

# SQLite ソースを取得して snapshot 有効でビルド
RUN curl -L -O https://www.sqlite.org/2026/sqlite-autoconf-3510200.tar.gz && \
    tar xzf sqlite-autoconf-3510200.tar.gz && \
    cd sqlite-autoconf-3510200 && \
    CFLAGS="-DSQLITE_ENABLE_SNAPSHOT" ./configure --prefix=/usr/local --disable-shared && \
    make && make install

# パスにインストールディレクトリを追加
ENV PATH="/usr/local/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH}"

# Backend と Shared をコピー
COPY Shared ./Shared
COPY Backend ./Backend

WORKDIR /workspace/Backend

# Swift Package の依存解決
RUN swift package resolve

# Swift build（静的ライブラリ込み）
RUN swift build -c release --static-swift-stdlib

RUN ls -lh .build/release/Backend
# デバッグシンボルを削除してサイズ圧縮
RUN strip .build/release/Backend

RUN ls -lh .build/release/Backend

# ============================
# Stage 2: Lambda Runtime (AL2023)
# ============================
FROM public.ecr.aws/lambda/provided:al2023

# ビルド済みバイナリをコピー
COPY --from=build /workspace/Backend/.build/release/Backend /var/runtime/bootstrap

RUN chmod +x /var/runtime/bootstrap

ENTRYPOINT ["/var/runtime/bootstrap"]