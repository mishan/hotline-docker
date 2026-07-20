# Consuming the published images in GtkHx's CI

This is the payoff: GtkHx's `build-and-test` job stops building the five
test containers and stops `dnf install`-ing the toolchain on every run,
and instead **pulls** the images this repo publishes. Below are the exact
edits to GtkHx's `.github/workflows/tests.yml`.

Replace `OWNER` with your lowercased GHCR namespace (e.g. `mishan`).
Prefer pinning `:latest` to a specific tag — a commit SHA or a release
`v*` tag — so a fresh image publish can't change a GtkHx run out from
under you. Bump the pin deliberately.

## 0. Package visibility / auth

The publish workflows push with the built-in `GITHUB_TOKEN`. For GtkHx's
CI to *pull* them:

- **Easiest:** make each GHCR package **public** (package → Settings →
  Change visibility). Then no login is needed to pull.
- **Or** keep them private and grant the GtkHx repo read access
  (package → Settings → Manage Actions access → add the GtkHx repo), and
  add a login step before the pulls:

  ```yaml
  - name: log in to GHCR
    uses: docker/login-action@v3
    with:
      registry: ghcr.io
      username: ${{ github.actor }}
      password: ${{ secrets.GITHUB_TOKEN }}
  ```

## 1. Toolchain: use `gtkhx-ci-base` instead of `fedora:43` + `dnf`

In the **build + unit + proto** step, change the container image and drop
the two `dnf -y install` blocks (the deps are baked into `gtkhx-ci-base`). The
MSRV assertion and the builds stay exactly as they are.

```diff
       run: |
         docker run --name gtkhx-build --network host \
           -v "$PWD:/src" -w /src \
           -e CARGO_HOME=/src/.cargo-home \
           -e CARGO_TARGET_DIR=/src/rust-cargo-target \
           -e GTKHX_GLYCIN_NO_SANDBOX=1 \
           -e CI=true \
-          fedora:43 bash -c '
+          ghcr.io/OWNER/gtkhx-ci-base:latest bash -c '
             set -e
-
-            # Base deps (no GStreamer) for the voice-disabled build.
-            dnf -y install \
-              meson ninja-build pkgconf-pkg-config gcc \
-              ... (whole first dnf block) ...
-              git rust cargo

             MIN_MSRV="1.92.0"
             ... (MSRV check unchanged) ...

             # Build 1: voice DISABLED
             meson setup build-novoice -Dvoice=disabled ...
             ... (unchanged) ...

-            # Install GStreamer, then Build 2: voice ENABLED.
-            dnf -y install \
-              libnice-gstreamer1 \
-              ... (whole second dnf block) ...
-              gstreamer1-plugins-good
             # Build 2: voice ENABLED
             meson setup build ...
             ... (unchanged) ...
           '
```

Nothing else in that step changes — the snapshot step
(`docker commit gtkhx-build gtkhx-buildenv`) and the integration step
that reuses `gtkhx-buildenv` still work, they just start from a
deps-preloaded base.

> Keep `images/ci-base/Dockerfile` in this repo in sync with that package
> list. If GtkHx grows a new build dep, add it there and re-publish.

## 2. Test containers: a thin overlay on the base images

The base images here are **general** — they don't carry GtkHx's test
tuning (seeded HOPE accounts, deterministic Files/ fixtures, promoted
tracker entries, rate-limit-off, the collision-avoidance ports, the Argus
TLS sidecar). GtkHx's tests need all of that, so instead of building the
servers from scratch, each `tests/<name>/Dockerfile` becomes a thin
**overlay** that starts `FROM` the published base and re-applies the
test-specific config on top. The heavy part (the mhxd compile, the
Janus/Argus tarball pulls) happens once on publish; the overlay is just a
few `COPY`/`RUN` layers, so GtkHx CI builds it in seconds.

The test config, seed scripts, fixtures, `stunnel.conf`, and `UserData`
already live in `tests/<name>/` — the overlay just re-applies them, so
this is mostly a change to the top of each `tests/<name>/Dockerfile`:
replace the "pull tarball / compile mhxd" build stage with a single
`FROM`, and keep the existing config-application steps.

Example — `tests/janus/Dockerfile`:

```dockerfile
ARG BASE=ghcr.io/OWNER/janus:latest
FROM ${BASE}

# Test tuning happens as root, then drops back to the janus user.
USER root

# The base image dropped openssl/curl (general images don't need them);
# the seeding + self-signed cert below do.
RUN apt-get update \
 && apt-get install --no-install-recommends -y openssl curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Re-apply GtkHx's test config: HOPE/chat-history/voice ON, rate limits
# off, admin API + key for seeding, matrix ports (5510/5610/5514), the
# promoted/banner fixtures, etc. (this is tests/janus/conf/config.yaml,
# unchanged from today).
COPY conf/config.yaml /opt/janus/Server/config.yaml

# Self-signed cert for the TLS tests.
RUN mkdir -p /opt/janus/Server/tls \
 && openssl req -x509 -newkey rsa:2048 -nodes \
      -keyout /opt/janus/Server/tls/key.pem \
      -out    /opt/janus/Server/tls/cert.pem \
      -days 3650 -subj "/CN=localhost" \
      -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

# Seed HOPE passwords + fixtures + banner (existing scripts/steps).
COPY seed-hope-passwords.sh /usr/local/bin/seed-hope-passwords
RUN chmod +x /usr/local/bin/seed-hope-passwords && /usr/local/bin/seed-hope-passwords
# ... the Files/ fixture + banner.gif RUN steps from today's Dockerfile ...

RUN chown -R janus:janus /opt/janus
USER janus
```

The other three follow the same shape:

- **`tests/mhxd/Dockerfile`** → `FROM ghcr.io/OWNER/mhxd:latest`, then
  `COPY conf/hxd.conf` (nospam-off test variant), `COPY conf/accounts/guest/UserData`,
  and the `files/` fixture + banner `RUN` steps.
- **`tests/argus/Dockerfile`** → `FROM ghcr.io/OWNER/argus:latest`, then
  install `stunnel4`/`openssl`, `COPY conf/config.yaml` (promoted servers,
  debug, `tcp_port: 5698`), `COPY conf/stunnel.conf`, generate the cert,
  and use the argus+stunnel `entrypoint.sh`.
- **`tests/hxtrackd/Dockerfile`** → `FROM ghcr.io/OWNER/hxtrackd:latest`,
  install `python3-minimal`, `COPY conf/hxtrackd.conf` (24h interval) +
  `seed-tracker.py`, and use the seed-loop `docker-entrypoint.sh`.
- **gtkhx-socks** has no test tuning — point GtkHx's compose at
  `ghcr.io/OWNER/gtkhx-socks` directly (no overlay needed).

`OWNER` is best passed as a build arg / `${{ github.repository_owner }}`
rather than hard-coded. In CI, keep the existing
`docker/build-push-action` steps but point their `context` at
`tests/<name>` (unchanged) — they now build the thin overlay instead of
the full server, so they stay fast and still tag `gtkhx-<name>`, leaving
`tests/docker-compose.yml` and the rest of the job untouched.

> Ordering: publish the base images from this repo **first**. Until they
> exist in your GHCR namespace, the overlay `FROM` can't resolve and
> GtkHx CI will fail on the image build.

## 3. What you save

Per GtkHx CI run you drop the expensive work: the mhxd compile, the
Janus/Argus tarball pull + verify, and two `dnf install` passes (hundreds
of MB of Fedora packages). Those happen once here on publish and are
cached in GHCR. GtkHx CI just pulls layers and builds the thin test
overlays (a handful of `COPY`/`RUN` on top of the cached base — seconds,
not minutes).

The trade you take on: image freshness is now a publish event, not every
run. The weekly `schedule` in both publish workflows keeps them current
with upstream mhxd / microsocks / Fedora, and you can always trigger
`workflow_dispatch` to refresh on demand.
