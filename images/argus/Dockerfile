# Argus Hotline tracker.
#
# Argus is VesperNet's closed-source Hotline tracker — a single, statically
# linked Go binary that speaks v1 + v2 + v3 on one port with automatic
# version detection. This image runs it with a general default config;
# nothing test-specific is baked in.
#
# Build:    docker build -t argus .
# Run:      docker run -d -p 5498:5498 -p 5499:5499/udp argus
# Connect:  point a Hotline client's tracker fetcher at <host>:5498
#
# Optional runtime env (see docker-entrypoint.sh):
#   ARGUS_TCP_PORT / ARGUS_UDP_PORT   override the listen ports
#
# Argus has no native TLS — if you want a TLS-terminated listing port,
# front it with a reverse proxy / stunnel of your own.
#
# The binary is not redistributed — pulled fresh at build time and
# sha256-verified; bump ARGUS_SHA256 to track a new build.

FROM debian:bookworm-slim AS build

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

ARG ARGUS_URL=https://misha.nasledov.com/argus-linux-amd64.tar.gz
ARG ARGUS_SHA256=8759cb59383c2b1bb7f210ea3bf47912f4cca6f9e46c1b28974f01937eed5628

# A real-browser User-Agent sidesteps a UA-based 403 some CDNs return to
# curl's default agent.
WORKDIR /build
RUN curl -fsSL \
        -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
        "$ARGUS_URL" -o argus.tar.gz \
 && echo "$ARGUS_SHA256  argus.tar.gz" | sha256sum -c - \
 && tar xzf argus.tar.gz \
 && mv argus-linux-amd64 /opt/argus

# General default config (conventional 5498/5499, no promoted fixtures,
# info-level logging). Mount your own config.yaml over this to customise.
COPY conf/config.yaml /opt/argus/config.yaml

# -----------------------------------------------------------------------------
# Runtime stage. Argus is statically linked Go, so only ca-certificates is
# needed.
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --no-install-recommends -y \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --home-dir /var/lib/argus \
               --shell /usr/sbin/nologin argus

COPY --from=build /opt/argus /opt/argus
COPY docker-entrypoint.sh /opt/argus/docker-entrypoint.sh
RUN chmod +x /opt/argus/docker-entrypoint.sh \
    && chown -R argus:argus /opt/argus

# Tracker ports:
#   5498/tcp — client listing requests (v1/v2/v3, auto-detected)
#   5499/udp — server registration heartbeats
EXPOSE 5498/tcp 5499/udp

USER argus
WORKDIR /opt/argus

# Entrypoint applies optional ARGUS_TCP_PORT / ARGUS_UDP_PORT overrides,
# then execs argus (which reads config.yaml from its cwd).
ENTRYPOINT ["/opt/argus/docker-entrypoint.sh"]
CMD []
