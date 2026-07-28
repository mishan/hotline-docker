#!/bin/sh
# healthcheck.sh — is mhxd actually serving Hotline, or just alive?
#
# mhxd occasionally wedges: the process stays running (so Docker's own
# restart-on-exit never fires) but it stops accepting / answering
# connections. A plain TCP-accept probe can pass in that state — the listen
# socket may still be open while the worker is deadlocked — so this does a
# real protocol handshake: it sends the 12-byte Hotline client hello
# (`TRTP` `HOTL` + version 1, sub-version 2) and checks the server replies
# with its `TRTP…` acknowledgement.
#
# Exit 0 = mhxd answered (healthy); non-zero = wedged / down.
#
# Used both by the Docker HEALTHCHECK (for `docker ps` status +
# compose `depends_on: condition: service_healthy`) and by the entrypoint's
# watchdog, which is what actually forces a restart on a persistent wedge.
#
# Tunables (env):
#   HX_HEALTH_HOST     host to probe          (default 127.0.0.1)
#   HX_HEALTH_PORT     HTLS port to probe     (default 5500)
#   HX_HEALTH_TIMEOUT  per-probe timeout secs (default 3)

set -u

HOST="${HX_HEALTH_HOST:-127.0.0.1}"
PORT="${HX_HEALTH_PORT:-5500}"
TIMEOUT="${HX_HEALTH_TIMEOUT:-3}"

# 'T''R''T''P' 'H''O''T''L' + version 0x0001 + sub-version 0x0002.
# `head -c 4` reads only the first 4 bytes of the reply then closes the
# pipe, which makes nc drop the connection instead of blocking on the rest
# of the server's hello. `-w` bounds the case where mhxd never answers.
reply=$(printf 'TRTPHOTL\000\001\000\002' \
    | nc -w "$TIMEOUT" "$HOST" "$PORT" 2>/dev/null \
    | head -c 4 2>/dev/null)

[ "$reply" = "TRTP" ]
