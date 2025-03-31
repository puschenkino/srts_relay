# Use the slim version of Debian for the builder stage
FROM debian:bullseye-slim AS builder

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV DEBIAN_FRONTEND=noninteractive

RUN set -xe; \
    apt-get update; \
    apt-get -y upgrade; \
    apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    git \
    libssl-dev \
    libz-dev \
    tcl \
    # For RUST installation
    curl \
    pkg-config \
    openssl \
    # For NOALBS build
    musl-tools; \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# belabox patched srt
#
ARG BELABOX_SRT_VERSION=master
RUN set -xe; \
    mkdir -p /build; \
    git clone https://github.com/BELABOX/srt.git /build/srt; \
    cd /build/srt; \
    git checkout $BELABOX_SRT_VERSION; \
    ./configure --prefix=/usr/local; \
    make -j4; \
    make install; \
    ldconfig;

# belabox srtla
#
ARG SRTLA_VERSION=main
RUN set -xe; \
    mkdir -p /build; \
    git clone https://github.com/BELABOX/srtla.git /build/srtla; \
    cd /build/srtla; \
    git checkout $SRTLA_VERSION; \
    make -j4;

RUN cp /build/srtla/srtla_rec /build/srtla/srtla_send /usr/local/bin

# srt-live-server
# Notes
# - upstream patch for logging on arm
COPY patches/480f73dd17320666944d3864863382ba63694046.patch /tmp/

ARG SRT_LIVE_SERVER_VERSION=master
RUN set -xe; \
    mkdir -p /build; \
    git clone https://github.com/IRLDeck/srt-live-server.git /build/srt-live-server; \
    cd /build/srt-live-server; \
    git checkout $SRT_LIVE_SERVER_VERSION; \
    patch -p1 < /tmp/480f73dd17320666944d3864863382ba63694046.patch; \
    make -j4; \
    cp bin/* /usr/local/bin;

ARG NOALBS_VERSION=v2.11.2
RUN set -xe; \
    git clone https://github.com/715209/nginx-obs-automatic-low-bitrate-switching /build/noalbs; \
    cd /build/noalbs; \
    git checkout $NOALBS_VERSION; \
    # Taken from https://github.com/NOALBS/nginx-obs-automatic-low-bitrate-switching/blob/v2/.github/workflows/release.yml
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; \
    . "$HOME/.cargo/env"; \
    cargo build --release; \
    cp target/release/noalbs /usr/local/bin;

# runtime container with NOALBS
# Use the slim version for the runtime container with NOALBS
FROM debian:bullseye-slim

RUN set -xe; \
    apt-get update; \
    apt-get -y upgrade; \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    supervisor; \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /usr/local/include /usr/local/include
COPY --from=builder /usr/local/bin /usr/local/bin

COPY files/sls.conf /etc/sls/sls.conf
COPY files/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY files/logprefix /usr/local/bin/logprefix

RUN set -xe; \
    ldconfig; \
    chmod 755 /usr/local/bin/logprefix;

EXPOSE 5000/udp 8181/tcp 8282/udp

VOLUME [ "/app/config.json", "/app/.env" ]

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
