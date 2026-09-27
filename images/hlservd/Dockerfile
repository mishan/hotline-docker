# hlservd Hotline server.
#
# hlservd is the Hotline Server 1.9.5 as a POSIX daemon: a port of the
# Hotsprings 2003 GPL source release (the "Openline" 1.9 server) by the
# author of Underline Hotline. The Linux build is a single statically
# linked binary with no GUI. It speaks the classic Hotline protocol, and is
# the closest thing to the original 1.9 server that runs headless.
#
# Build:    docker build -t hlservd .
# Run:      docker run -d -p 5500:5500 -p 5501:5501 hlservd
# Connect:  point a Hotline client at <host>:5500
#
# Optional runtime env (see docker-entrypoint.sh):
#   HLSERVD_PORT             control port (transfers on +1, HTTP tunnel on +2/+3)
#   HLSERVD_NAME             server name
#   HLSERVD_TRUST_LOOPBACK   true to exempt 127.0.0.1 from the flood ban
#
# The server state (Settings.ini, Users/, Files/, News/) lives in
# /var/lib/hlservd; mount a volume there to keep it.
#
# The binary is not redistributed from here — pulled at build time and
# sha256-verified; bump HLSERVD_URL / HLSERVD_SHA256 to track a new build.
# Its source isn't published yet; when it is, this should build from it.

FROM debian:bookworm-slim AS build

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

ARG HLSERVD_URL=https://www.199x.online/panorama/hlservd-1.9.5-d40d2b75-linux-amd64.tar.gz
ARG HLSERVD_SHA256=9097f19b2d44fa70c2ed9d00bd46d9d6d9b6e8b74917c0b7a312cdcc66713c8f

WORKDIR /build
RUN curl -fsSL "$HLSERVD_URL" -o hlservd.tar.gz \
 && echo "$HLSERVD_SHA256  hlservd.tar.gz" | sha256sum -c - \
 && tar xzf hlservd.tar.gz \
 && mv hlservd-*-linux-amd64 /opt/hlservd

# -----------------------------------------------------------------------------
# Runtime stage. The binary is statically linked; nothing else is needed.
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

RUN useradd --system --create-home --home-dir /var/lib/hlservd \
            --shell /usr/sbin/nologin hlservd

COPY --from=build /opt/hlservd /opt/hlservd
# General default config: the server's own defaults, tracker off.
COPY conf/Settings.ini /opt/hlservd/Settings.ini.default
COPY docker-entrypoint.sh /opt/hlservd/docker-entrypoint.sh
RUN chmod +x /opt/hlservd/docker-entrypoint.sh

# Hotline ports:
#   5500/tcp — control (HTLS)
#   5501/tcp — file transfers (HTXF)
#   5502/5503/tcp — HTTP tunnel
EXPOSE 5500/tcp 5501/tcp 5502/tcp 5503/tcp

USER hlservd
WORKDIR /var/lib/hlservd
VOLUME /var/lib/hlservd

ENTRYPOINT ["/opt/hlservd/docker-entrypoint.sh"]
CMD []
