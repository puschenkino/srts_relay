FROM alpine:latest as build

# Set metadata
LABEL maintainer="Henrik Hansen <hhansen06@googlemail.com>"
LABEL version="0.1"
LABEL description="SRT Live Server (SLS)"

# Install build tools
RUN apk update --no-cache &&\
    apk add --no-cache linux-headers alpine-sdk cmake tcl openssl-dev zlib-dev &&\
    apk upgrade --no-cache

# Set workdir and clone GIT repositories for srt and srt live server
WORKDIR /srv/build
RUN git clone https://github.com/Haivision/srt.git &&\
    git clone https://github.com/Edward-Wu/srt-live-server.git

# Replace Makefile
COPY build/Makefile /srv/build/srt-live-server/Makefile

# Set workdir and build srt
WORKDIR /srv/build/srt
RUN ./configure --prefix=/srv/sls && make && make install

# Set workdir and build srt live server
WORKDIR /srv/build/srt-live-server
RUN make

# Create final Docker image from build image
FROM alpine:latest

# Set library path
ENV LD_LIBRARY_PATH /lib:/usr/lib:/srv/sls/lib64

# Install and setup runtime environment
RUN apk update --no-cache &&\
    apk add --no-cache openssl libstdc++ &&\
    apk upgrade --no-cache &&\
    mkdir -p /srv/sls/logs

# Install srt and sls application
COPY --from=build /srv/sls /srv/sls/
COPY --from=build /srv/build/srt-live-server/bin /srv/sls/bin/

# Copy configuration files
COPY root /

# Prepare SLS start
RUN chmod 755 /srv/run.sh

# Expose streaming port
EXPOSE 9710/udp

# Set workdir to srt user home directory
WORKDIR /srv/sls/tmp

# Start SLS instance
CMD ["/srv/run.sh"]
