# build frontend
FROM node:lts-alpine AS web_image

# 华为源
# RUN npm config set registry https://repo.huaweicloud.com/repository/npm/

RUN npm install pnpm -g

WORKDIR /build

COPY ./package.json /build
COPY ./pnpm-lock.yaml /build

RUN pnpm install

COPY . /build

RUN pnpm run build

# build backend - 支持多架构构建
FROM golang:1.21-alpine3.18 as server_image

# 安装多架构构建工具
RUN apk add --no-cache bash curl gcc git musl-dev build-base crossbuild

# 安装 ARMv5 交叉编译工具链
RUN apk add --no-cache crossbuild-armv5l-linux-musl crossbuild-armv6l-linux-musl crossbuild-armv7l-linux-musl

WORKDIR /build

COPY ./service .

# 中国国内源
# RUN sed -i "s@dl-cdn.alpinelinux.org@mirrors.aliyun.com@g" /etc/apk/repositories \
#     && go env -w GOPROXY=https://goproxy.cn,direct

# 设置构建环境变量
ENV GO111MODULE=on
ENV CGO_ENABLED=1

# 安装必要的 Go 工具
RUN go install -a -v github.com/go-bindata/go-bindata/...@latest \
    && go install -a -v github.com/elazarl/go-bindata-assetfs/...@latest

# 多架构构建脚本
RUN cat << 'EOF' > build-multiarch.sh
#!/bin/sh
set -e

ARCH=$1
GOARM=$2

case $ARCH in
    "amd64")
        export CC="gcc"
        export GOARCH="amd64"
        ;;
    "arm64")
        export CC="aarch64-alpine-linux-musl-gcc"
        export GOARCH="arm64"
        ;;
    "armv7")
        export CC="armv7-alpine-linux-musleabihf-gcc"
        export GOARCH="arm"
        export GOARM="7"
        ;;
    "armv6")
        export CC="armv6-alpine-linux-musleabihf-gcc"
        export GOARCH="arm"
        export GOARM="6"
        ;;
    "armv5")
        export CC="armv5-alpine-linux-musleabi-gcc"
        export GOARCH="arm"
        export GOARM="5"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Building for $ARCH with GOARM=$GOARM"

# 生成资源文件
go-bindata-assetfs -o=assets/bindata.go -pkg=assets assets/...

# 构建主程序
go build -o sun-panel-$ARCH \
    --ldflags="-X sun-panel/global.RUNCODE=release -X sun-panel/global.ISDOCKER=docker" \
    main.go

# 验证二进制文件
file sun-panel-$ARCH
EOF

RUN chmod +x build-multiarch.sh

# run_image - 使用多架构兼容的基础镜像
FROM alpine:3.18

WORKDIR /app

COPY --from=web_image /build/dist /app/web

# 根据 TARGETARCH 选择正确的二进制文件
ARG TARGETARCH
ARG TARGETVARIANT

# 复制对应的架构二进制文件
COPY --from=server_image /build/sun-panel-${TARGETARCH}${TARGETVARIANT:+v${TARGETVARIANT}} /app/sun-panel

# 中国国内源
# RUN sed -i "s@dl-cdn.alpinelinux.org@mirrors.aliyun.com@g" /etc/apk/repositories

EXPOSE 3002

RUN apk add --no-cache bash ca-certificates su-exec tzdata libgcc libstdc++ \
    && chmod +x ./sun-panel \
    && ./sun-panel -config

CMD ["./sun-panel"]