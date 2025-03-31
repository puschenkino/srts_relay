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

ARG SRT_LIVE_SERVER_VERSION=master
RUN set -xe; \
    mkdir -p /build; \
    git clone https://github.com/IRLDeck/srt-live-server.git /build/srt-live-server; \
    cd /build/srt-live-server; \
    git checkout $SRT_LIVE_SERVER_VERSION; \
    make -j4; \
    cp bin/* /usr/local/bin;

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

COPY files/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY files/logprefix /usr/local/bin/logprefix

RUN set -xe; \
    ldconfig; \
    chmod 755 /usr/local/bin/logprefix;

EXPOSE 5000/udp 8181/tcp 8282/udp

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
