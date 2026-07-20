#!/bin/sh
# Argus entrypoint — apply optional listen-port overrides, then run the
# tracker. Both are optional; unset means the config.yaml value stands.
#
#   ARGUS_TCP_PORT   client listing port      (default 5498)
#   ARGUS_UDP_PORT   registration heartbeat    (default 5499)
#
# Or mount your own /opt/argus/config.yaml and set neither.
set -eu

CONF=/opt/argus/config.yaml

if [ -n "${ARGUS_TCP_PORT:-}" ]; then
	sed -i "s|^\([[:space:]]*\)tcp_port:.*|\1tcp_port: ${ARGUS_TCP_PORT}|" "$CONF"
	echo "docker-entrypoint: tcp_port=${ARGUS_TCP_PORT}"
fi
if [ -n "${ARGUS_UDP_PORT:-}" ]; then
	sed -i "s|^\([[:space:]]*\)udp_port:.*|\1udp_port: ${ARGUS_UDP_PORT}|" "$CONF"
	echo "docker-entrypoint: udp_port=${ARGUS_UDP_PORT}"
fi

# Argus reads config.yaml from its cwd.
cd /opt/argus
exec /opt/argus/argus "$@"
