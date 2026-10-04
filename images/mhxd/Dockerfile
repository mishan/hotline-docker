# mhxd test server for GtkHx integration / smoke testing.
#
# Builds a fresh mhxd from upstream master at image-build time, then
# overlays our checked-in config + patched user accounts so the
# container comes up in a known-good state. The set of customisations
# used to live as a sed/dd shell pipeline in this file (~200 LOC of
# shell and commentary); replacing those with concrete files in
# tests/mhxd/conf/ and tests/mhxd/patches/ keeps the source-of-truth
# auditable in git.
#
# Build:    docker build -t mhxd .
# Run:      docker run --rm -p 5500:5500 -p 5501:5501 mhxd
# Connect:  point GtkHx at localhost:5500
#
# The mhxd clone is PINNED to a specific commit (MHXD_REV below). It
# used to be an unpinned `--depth 1 master`, which bit us twice in one
# day:
#
#   1. Upstream merged our folder-xfer size patch (and reworked it
#      behind a CONFIG_HFS / operation.hfs gate), so `git apply` of the
#      checked-in patch started failing → the image build broke.
#   2. After removing the patch, the `git clone` layer was still cached
#      locally on the pre-fix revision, so the local container kept
#      running the *buggy* mhxd while CI (fresh runner, no layer cache)
#      built the fixed one — diverging behaviour between dev and CI.
#
# Pinning fixes both: the build is reproducible everywhere, and a new
# pin (a line change) busts the clone layer's cache deliberately. When
# you want a newer mhxd, bump MHXD_REV below and rebuild.

FROM debian:bookworm-slim AS build

# Build deps. Most are obvious; the less-obvious ones:
#   libssl-dev   — mhxd's --enable-cipher uses OpenSSL crypto for
#                  Blowfish + the HOPE handshake. (mhxd still
#                  compiles RC4 in too, but our client doesn't
#                  offer it.)
#   libpcre2-dev — pulled in by some optional features; harmless if
#                  unused.
#   pkg-config   — autotools macros lean on it for SSL detection.
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --no-install-recommends -y \
        ca-certificates \
        git \
        build-essential \
        autoconf \
        automake \
        libtool \
        pkg-config \
        libssl-dev \
        zlib1g-dev \
        libpcre2-dev \
        libncurses-dev \
    && rm -rf /var/lib/apt/lists/*

# Pull mhxd at a pinned revision
WORKDIR /build
ARG MHXD_REV=2551666d94b70087841966975311d81a65600bd5
RUN git clone https://github.com/kangsterizer/mhxd.git mhxd \
    && git -C mhxd checkout --quiet "$MHXD_REV"

# Local patches applied on top of the pinned revision. `git apply` fails the
# build on a patch that no longer applies, which is what we want: a silently
# skipped patch would ship a server with the bug still in it. Bumping
# MHXD_REV means re-checking these.
COPY patches/ /build/patches/
RUN for p in /build/patches/*.patch; do \
        [ -e "$p" ] || continue; \
        echo "applying $p" && git -C mhxd apply "$p"; \
    done

# Configure with the feature set GtkHx exercises:
#
#   --enable-hxd          — the actual server binary. Despite the help
#                           text saying --disable-hxd, the default is
#                           OFF: there's an auto-enable-if-nothing-else
#                           in configure.in, but it's defeated as soon
#                           as we pass --enable-hxtrackd. Explicit is
#                           safer than implicit, so we pass it. This
#                           ALSO trips the configure.in:779 guard that
#                           adds -I../cipher to COMMONINCLUDES, which
#                           is what src/common needs to find cipher.h.
#   --with-pthreads       — thread model (mhxd's default is fork/clone)
#   --enable-hope         — secure login handshake; GtkHx negotiates this
#   --enable-cipher       — Blowfish link encryption (mhxd also compiles
#                           in RC4 here but the GtkHx client doesn't
#                           offer it anymore)
#   --enable-compress     — zlib link compression
#   --enable-hxtrackd     — tracker server (port 5498); compile but
#                           skip exposing by default
#   --enable-hldump       — server-side wire-protocol dump for
#                           debugging; mirrors GTKHX_DEBUG=proto.
#   --disable-exec        — compile out CONFIG_EXEC entirely.
#                           Otherwise mhxd's cmd_exec forks
#                           unconditionally on login and on certain
#                           chat commands, producing [hxd] <defunct>
#                           zombies. (Setting paths.luser="" in the
#                           config does NOT work — the fork happens
#                           before the empty-path guard.)
#
# `make -j$(nproc) || make` because mhxd's autotools graph isn't
# fully parallel-safe — fall back to single-job if the parallel run
# stumbled.
RUN cd /build/mhxd \
    && ./autogen.sh \
    && ./configure \
        --prefix=/opt/mhxd \
        --enable-hxd \
        --with-pthreads \
        --enable-hope \
        --enable-cipher \
        --enable-compress \
        --enable-hxtrackd \
        --enable-hldump \
        --disable-exec \
    && (make -j"$(nproc)" || make) \
    && mkdir -p /opt/mhxd \
    && make install

# Lay down the runtime config tree: the upstream `run/hxd/` skeleton
# (accounts/, news/, banlist, MOTD, ...) plus our general hxd.conf. The
# only edits from upstream are container-friendly: ident=0 (no identd
# reachable in a container) and version=185 (modern SELFINFO login-reply
# flow). Banner and tracker registration are applied at runtime from env
# by docker-entrypoint.sh. Mount your own hxd.conf, accounts/, or files/
# to customise further.
RUN cp -a /build/mhxd/run/hxd /opt/mhxd/run
COPY conf/hxd.conf /opt/mhxd/run/hxd.conf

# `newsdir` — the 1.5+ threaded-news tree (hxd.conf paths.newsdir). The
# upstream run/hxd skeleton ships the flat 1.0/1.2 `news` file but not this
# directory, and `tnews yes` doesn't create it, so threaded news arrives
# half-configured: NEWSDIRLIST returns an empty root and creating a folder
# fails inside rcv_news_mkbundle's SYS_mkdir("<newsdir>/<name>"), which hands
# the client errno verbatim — "No such file or directory". Reading plain news
# still works throughout, which is what makes it confusing to diagnose.
#
# Empty on purpose: an empty root is a valid starting state, and seeding
# content here would show up in every consumer's news tree.
RUN mkdir -p /opt/mhxd/run/newsdir

# -----------------------------------------------------------------------------
# Runtime stage. Slim down to just the binary + runtime libs + config tree.
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

ARG DEBIAN_FRONTEND=noninteractive
# netcat-openbsd provides `nc` for the health probe (healthcheck.sh) — the
# base slim image ships neither nc nor bash's /dev/tcp.
RUN apt-get update && apt-get install --no-install-recommends -y \
        libssl3 \
        zlib1g \
        libpcre2-8-0 \
        netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --home-dir /var/lib/mhxd \
               --shell /usr/sbin/nologin mhxd

# Bring the built binaries + the run/ skeleton from the build stage.
COPY --from=build /opt/mhxd /opt/mhxd
RUN chown -R mhxd:mhxd /opt/mhxd/run

# Entrypoint script — patches hxd.conf's banner block based on
# the BANNER_MODE / BANNER_URL / BANNER_FILE env vars at startup,
# then runs hxd under a health watchdog (see the script + healthcheck.sh).
# With no env vars set, behaviour matches the URL-mode default committed in
# conf/hxd.conf.
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Hotline ports:
#   5500/tcp — HTLS server (clients connect here)
#   5501/tcp — HTXF file transfer
EXPOSE 5500/tcp 5501/tcp

# Report health by probing the Hotline handshake on 5500 (healthcheck.sh).
# This drives `docker ps` health + compose `depends_on: service_healthy` /
# `docker compose up --wait`; the entrypoint's own watchdog is what forces
# the container to exit + restart on a persistent wedge.
HEALTHCHECK --interval=15s --timeout=5s --start-period=15s --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]

USER mhxd
WORKDIR /opt/mhxd/run

# The entrypoint script patches hxd.conf in /opt/mhxd/run (which
# the mhxd user owns from the chown above) and exec's hxd in the
# foreground. We don't pass `-d` so stdout/stderr stay attached
# to `docker logs`.
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD []
