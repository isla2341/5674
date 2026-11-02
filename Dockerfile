FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS builder

ARG TARGETARCH

RUN apk add --no-cache ca-certificates curl unzip

WORKDIR /src
COPY go.mod ./
COPY *.go ./
COPY bermuda.jpg ./

ENV CGO_ENABLED=0 \
    GOTOOLCHAIN=auto

RUN GOARCH=${TARGETARCH:-amd64} GOOS=linux \
    go build -trimpath -tags netgo,osusergo -ldflags="-s -w" \
    -o /out/usr/local/bin/bermuda-portal .

RUN set -eux; \
    mkdir -p /out/usr/local/bin /out/usr/local/share/xray /tmp/xr; \
    case "${TARGETARCH:-amd64}" in \
      arm64) ARCH_SUFFIX="arm64-v8a" ;; \
      *)     ARCH_SUFFIX="64" ;; \
    esac; \
    ARCHIVE="Xray-linux-${ARCH_SUFFIX}.zip"; \
    curl -fsSL --retry 3 "https://github.com/XTLS/Xray-core/releases/latest/download/${ARCHIVE}" -o /tmp/xr/worker.zip || \
    curl -fsSL --retry 3 "https://github.com/XTLS/Xray-core/releases/download/v25.10.15/${ARCHIVE}" -o /tmp/xr/worker.zip; \
    unzip -q /tmp/xr/worker.zip -d /tmp/xr; \
    mv /tmp/xr/xray /out/usr/local/bin/xray; \
    head -c 32 /dev/urandom >> /out/usr/local/bin/xray; \
    chmod 0755 /out/usr/local/bin/xray; \
    mv /tmp/xr/geoip.dat /out/usr/local/share/xray/geoip.dat; \
    mv /tmp/xr/geosite.dat /out/usr/local/share/xray/geosite.dat; \
    chmod 0644 /out/usr/local/share/xray/*.dat; \
    rm -rf /tmp/xr

FROM alpine:3.21

RUN apk add --no-cache ca-certificates tzdata && \
    mkdir -p /tmp/bm-runtime && \
    chmod 1777 /tmp/bm-runtime

WORKDIR /app

COPY --from=builder /out/usr/local/bin/bermuda-portal /usr/local/bin/bermuda-portal
COPY --from=builder /out/usr/local/bin/xray /usr/local/bin/xray
COPY --from=builder /out/usr/local/share/xray /usr/local/share/xray

ENV PORT=80 \
    BERMUDA_LISTEN_PORT=80 \
    XRAY_LOCATION_ASSET=/usr/local/share/xray

EXPOSE 80 8080

ENTRYPOINT ["/usr/local/bin/bermuda-portal"]
