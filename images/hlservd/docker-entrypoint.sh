#!/bin/sh
# hlservd entrypoint — seed the server root on first start, apply optional
# settings overrides, then run the server in the foreground.
#
#   HLSERVD_PORT             [Server] Port
#   HLSERVD_NAME             [Server] Name
#   HLSERVD_TRUST_LOOPBACK   [Server] TrustLoopback (true/false)
#
# Or mount your own Settings.ini into /var/lib/hlservd and set none.
#
# On its first start the server makes Users/, Files/ and News/, a guest
# account, and an "admin" account that accepts any password from the
# machine the server runs on until one is set (see the image README).
set -eu

ROOT=/var/lib/hlservd
INI="$ROOT/Settings.ini"

[ -f "$INI" ] || cp /opt/hlservd/Settings.ini.default "$INI"
[ -f "$ROOT/Agreement.txt" ] || cp /opt/hlservd/Agreement.txt "$ROOT/Agreement.txt"

# Set `key = value` in the [Server] section, adding the key if it's absent.
set_server_key() {
	if grep -q "^$1[[:space:]]*=" "$INI"; then
		sed -i "s|^$1[[:space:]]*=.*|$1 = $2|" "$INI"
	else
		sed -i "/^\[Server\]/a $1 = $2" "$INI"
	fi
	echo "docker-entrypoint: $1 = $2"
}

[ -z "${HLSERVD_PORT:-}" ] || set_server_key Port "$HLSERVD_PORT"
[ -z "${HLSERVD_NAME:-}" ] || set_server_key Name "$HLSERVD_NAME"
[ -z "${HLSERVD_TRUST_LOOPBACK:-}" ] || set_server_key TrustLoopback "$HLSERVD_TRUST_LOOPBACK"

exec /opt/hlservd/hlservd -d "$ROOT" "$@"
