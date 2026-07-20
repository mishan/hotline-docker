#!/bin/sh
# Janus entrypoint — apply optional env overrides to config.yaml, then run
# the server. Everything is off/empty unless you set the matching env var,
# so the checked-in general defaults stand unless you opt in.
#
#   JANUS_PORT                 base Hotline port           (default 5500)
#   JANUS_TLS_PORT             base TLS port               (default 5600)
#   JANUS_ENABLE_HOPE          true|false  HOPE secure login
#   JANUS_ENABLE_CHAT_HISTORY  true|false  chat history (SQLite-backed)
#   JANUS_ENABLE_VOICE         true|false  WebRTC voice
#   JANUS_TLS_CERT             path to a PEM certificate   (enables TLS)
#   JANUS_TLS_KEY              path to the matching PEM private key
#   TRACKERS                   comma/space list of host[:port] to register with
#
# TLS with a real certificate (e.g. Let's Encrypt / certbot on the host):
#
#   docker run -d --network host \
#     -v /etc/letsencrypt/live/example.com:/certs:ro \
#     -e JANUS_TLS_CERT=/certs/fullchain.pem \
#     -e JANUS_TLS_KEY=/certs/privkey.pem \
#     ghcr.io/<owner>/janus
#
# Bind-mounting certbot's live/ directory means renewals are picked up on
# a container restart with no image rebuild. You can also skip all of this
# and mount your own /opt/janus/Server/config.yaml.
set -eu

CONF=/opt/janus/Server/config.yaml

# sed-escape a replacement value (backslash, &, and our | delimiter).
esc() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

# set_scalar KEY VALUE — rewrite a top-level `KEY: ...` line in place.
set_scalar() {
	_v=$(esc "$2")
	sed -i "s|^$1:.*|$1: ${_v}|" "$CONF"
}

# Normalise a boolean-ish env value to true/false.
booly() {
	case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
		1 | true | yes | on) echo true ;;
		*) echo false ;;
	esac
}

[ -n "${JANUS_PORT:-}" ] && set_scalar Port "$JANUS_PORT"
[ -n "${JANUS_TLS_PORT:-}" ] && set_scalar TLSPort "$JANUS_TLS_PORT"
[ -n "${JANUS_ENABLE_HOPE:-}" ] && set_scalar EnableHOPE "$(booly "$JANUS_ENABLE_HOPE")"
[ -n "${JANUS_ENABLE_CHAT_HISTORY:-}" ] && set_scalar ChatHistoryEnabled "$(booly "$JANUS_ENABLE_CHAT_HISTORY")"
[ -n "${JANUS_ENABLE_VOICE:-}" ] && set_scalar EnableVoice "$(booly "$JANUS_ENABLE_VOICE")"
[ -n "${JANUS_TLS_CERT:-}" ] && set_scalar TLSCert "\"$JANUS_TLS_CERT\""
[ -n "${JANUS_TLS_KEY:-}" ] && set_scalar TLSKey "\"$JANUS_TLS_KEY\""

if [ -n "${JANUS_TLS_CERT:-}" ]; then
	echo "docker-entrypoint: TLS enabled (cert=$JANUS_TLS_CERT)"
fi

# Tracker registration. Setting TRACKERS flips EnableTrackerRegistration on
# and rewrites the Trackers list. Unset -> config's own value is honoured.
if [ -n "${TRACKERS:-}" ]; then
	set_scalar EnableTrackerRegistration true
	sed -i '/^[[:space:]]*-[[:space:]]*hltracker\.com:5499$/d' "$CONF"
	for t in $(printf '%s' "$TRACKERS" | tr ',' ' '); do
		[ -n "$t" ] || continue
		t_esc=$(printf '%s' "$t" | sed 's/\\/\\\\/g')
		sed -i "/^Trackers:/a\\  - ${t_esc}" "$CONF"
	done
	echo "docker-entrypoint: tracker registration -> $TRACKERS"
fi

exec /opt/janus/janus "$@"
