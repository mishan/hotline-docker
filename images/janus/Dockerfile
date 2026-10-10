# Janus Hotline server.
#
# Janus is VesperNet's closed-source Hotline server — a single, statically
# linked Go binary (~24 MB). This image pulls a sha256-pinned build and
# runs it with a general default config; nothing test-specific is baked
# in. Toggle features and provide a TLS certificate at runtime (see the
# entrypoint / conf/config.yaml), or mount your own config.yaml.
#
# Build:    docker build -t janus .
# Run:      docker run -d --network host janus
# Connect:  point a Hotline client at <host>:5500
#
# Common runtime env (all optional; see docker-entrypoint.sh):
#   JANUS_ENABLE_HOPE / JANUS_ENABLE_CHAT_HISTORY / JANUS_ENABLE_VOICE
#   JANUS_TLS_CERT / JANUS_TLS_KEY  (e.g. Let's Encrypt cert + key)
#   TRACKERS                        register with these trackers
#
# The binary is not redistributed — it's pulled fresh at build time and
# sha256-verified; bump JANUS_SHA256 when you point JANUS_URL at a new
# build.

FROM debian:bookworm-slim AS build

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Pinned Janus build: 2.0.23 (commit 23cb4cf). To bump: point JANUS_URL at
# the new version's tarball, and update JANUS_SHA256 and the version above
# (`janus --version` from the tarball prints both).
ARG JANUS_URL=https://get.vespernet.net/janus-2.0.23-linux-amd64.tar.gz
ARG JANUS_SHA256=8b4663383f98fc55a9ab5bceeee7bc56c51f3136f187672376edf1d0ef4b10e4

WORKDIR /build
RUN curl -fsSL "$JANUS_URL" -o janus.tar.gz \
 && echo "$JANUS_SHA256  janus.tar.gz" | sha256sum -c - \
 && tar xzf janus.tar.gz \
 && mv janus-linux-amd64 /opt/janus

# General default config: features off, conventional ports (5500 / TLS
# 5600), no fixtures. TLS is disabled until a cert is provided. Mount your
# own config.yaml over this to fully customise.
COPY conf/config.yaml /opt/janus/Server/config.yaml

# Pre-create the relative-path directories Janus validates at config load
# (newer builds fail-fast if DataRoot / FileRoot / PluginsDir / the log
# dir are missing).
RUN mkdir -p \
        /opt/janus/Server/Data \
        /opt/janus/Server/Files \
        /opt/janus/Server/Plugins \
        /opt/janus/Server/Logs

# Give `admin` a password anyone can actually use.
#
# The upstream tarball ships Users/admin.yaml with a bcrypt hash of some
# password that isn't published anywhere, which leaves the image's only
# privileged account unusable — you get a full-access account you cannot log
# into. Overwrite the hash with one whose plaintext is documented ("adminpass",
# see README).
#
# The hash is precomputed and pinned rather than generated at build time —
# bcrypt embeds its own salt, so a fixed string is reproducible and needs no
# bcrypt tool in the build stage. Cross-checked against upstream's own
# guest.yaml hash, which verifies against the empty password, confirming Janus
# reads this field as plain bcrypt. Single quotes keep the shell away from the
# `$2a$` prefix.
RUN set -eux; \
    hash='$2a$10$e0LD5a0SsSjwGj1wBvXJQujPhHzxJ8DRQOfBbBrf5iy4XkyG7eQ4.'; \
    sed -i "s|^Password: .*|Password: ${hash}|" \
        /opt/janus/Server/Users/admin.yaml; \
    grep -qF "Password: ${hash}" /opt/janus/Server/Users/admin.yaml

# -----------------------------------------------------------------------------
# Runtime stage. The Janus binary is statically linked Go, so only
# ca-certificates is needed (outbound HTTPS to trackers / gateways).
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --no-install-recommends -y \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --home-dir /var/lib/janus \
               --shell /usr/sbin/nologin janus

COPY --from=build /opt/janus /opt/janus
RUN chown -R janus:janus /opt/janus

# Entrypoint applies optional env overrides (feature toggles, ports, TLS
# cert paths, tracker registration) to config.yaml, then execs Janus.
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh

# Default ports (config.yaml). File-transfer port is base + 1; TLS ports
# apply only when a cert is configured; the voice UDP port only when voice
# is enabled. Publish with -p, or use --network host.
#   5500/tcp — HTLS (clients connect here)
#   5501/tcp — HTXF file transfer
#   5514/udp — WebRTC voice (when enabled)
#   5600/tcp — HTLS over TLS (when a cert is set)
#   5601/tcp — HTXF over TLS
EXPOSE 5500/tcp 5501/tcp 5514/udp 5600/tcp 5601/tcp

USER janus
WORKDIR /opt/janus

# Janus looks for `Server/` next to the executable (our COPY put it at
# /opt/janus/Server). Logs go to stdout/stderr.
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD []
