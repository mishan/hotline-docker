#!/bin/sh
# hxtrackd entrypoint — run the tracker in the foreground.
#
# hxtrackd reads its config from the working directory; the binary lives
# at run/bin/hxtrackd (mhxd's autotools plant it inside the build tree's
# run/hxtrackd/ subdir, carried into /opt/hxtrackd/run/ by the Dockerfile).
# Servers populate the listing by registering via UDP on 5499.
set -eu

cd /opt/hxtrackd/run
exec /opt/hxtrackd/run/bin/hxtrackd "$@"
