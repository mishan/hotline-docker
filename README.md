# hotline-docker

General-purpose Hotline **server / tracker container images**, plus a CI
base image, built once here and published to a registry. They're usable
for real deployments, and are also what [GtkHx](https://github.com/mishan/gtkhx)'s
CI pulls instead of rebuilding on every run.

## Images

| Image (`images/<dir>`) | Published tag    | Default ports        | Role |
|------------------------|------------------|----------------------|------|
| `mhxd`                 | `mhxd`     | 5500 / 5501          | Hotline server (mhxd) |
| `janus`                | `janus`    | 5500 / 5501 (+TLS)   | Hotline server (VesperNet Janus) |
| `argus`                | `argus`    | 5498 tcp / 5499 udp  | Tracker (v1/v2/v3, VesperNet Argus) |
| `hxtrackd`             | `hxtrackd` | 5498 tcp / 5499 udp  | Tracker (pre-spec v1, mhxd's hxtrackd) |
| `socks-proxy`          | `gtkhx-socks`    | 1080                 | SOCKS5 proxy (microsocks) |
| `ci-base`              | `gtkhx-ci-base` | —                    | Fedora + the GtkHx build/test toolchain |

Each image runs a **general default config** (features off, conventional
ports, no seeded content). Customise at runtime with env vars or by
mounting your own config — see below and each image's `README.md`.

## Configuration

All servers accept a mounted config file (over the image's default) and a
few env knobs applied by the entrypoint:

- **Janus** — `JANUS_PORT`, `JANUS_TLS_PORT`, `JANUS_ENABLE_HOPE`,
  `JANUS_ENABLE_CHAT_HISTORY`, `JANUS_ENABLE_VOICE`, `JANUS_TLS_CERT` /
  `JANUS_TLS_KEY`, `TRACKERS`.
- **mhxd** — `TRACKERS`, `BANNER_MODE` / `BANNER_URL` / `BANNER_FILE`.
- **Argus** — `ARGUS_TCP_PORT`, `ARGUS_UDP_PORT`.
- **hxtrackd** — none (its ports are hardcoded); mount `hxtrackd.conf` to
  tune the drop interval etc.

### TLS (e.g. Let's Encrypt / certbot)

Janus serves TLS when given a cert + key. Mount them and point Janus at
them — no image rebuild, and certbot renewals are picked up on restart:

```sh
docker run -d --network host \
  -v /etc/letsencrypt/live/example.com:/certs:ro \
  -e JANUS_TLS_CERT=/certs/fullchain.pem \
  -e JANUS_TLS_KEY=/certs/privkey.pem \
  ghcr.io/mishan/janus
```

## Where images are published

GitHub Container Registry (GHCR), under the repo owner's namespace:

```
ghcr.io/mishan/mhxd:latest
ghcr.io/mishan/janus:latest
ghcr.io/mishan/argus:latest
ghcr.io/mishan/hxtrackd:latest
ghcr.io/mishan/gtkhx-socks:latest
ghcr.io/mishan/gtkhx-ci-base:latest      # also :fedora43
```

Each is also tagged with the commit SHA; server images get the git tag
name on `v*` releases. Two workflows publish (both push with the built-in
`GITHUB_TOKEN` — enable `packages: write`, already declared):

- `.github/workflows/publish-images.yml` — the five server/proxy images,
  matrix-built with per-image GHA layer caching. Triggers on `images/**`
  changes, weekly, and manually.
- `.github/workflows/publish-ci-base.yml` — the CI base. Triggers on
  `images/ci-base/**`, weekly (Fedora updates), and manually.

After the first run, make the packages **public** (or grant readers) on
GHCR so they can be pulled without auth — new packages are private by
default.

## Running the images

Each image is an independent server — run whichever one you need on its
own. A typical deployment is a single server on its conventional port:

```sh
# mhxd Hotline server
docker run -d -p 5500:5500 -p 5501:5501 ghcr.io/mishan/mhxd

# Janus Hotline server (with HOPE + a Let's Encrypt cert)
docker run -d --network host \
  -v /etc/letsencrypt/live/example.com:/certs:ro \
  -e JANUS_ENABLE_HOPE=true \
  -e JANUS_TLS_CERT=/certs/fullchain.pem \
  -e JANUS_TLS_KEY=/certs/privkey.pem \
  ghcr.io/mishan/janus

# Argus tracker
docker run -d -p 5498:5498 -p 5499:5499/udp ghcr.io/mishan/argus

# hxtrackd tracker
docker run -d -p 5498:5498 -p 5499:5499/udp ghcr.io/mishan/hxtrackd
```

To have a server register with a tracker, pass `TRACKERS` (mhxd/Janus) —
see each image's `README.md`. Use `--network host` for Janus if you're
running its WebRTC voice path.

## Using in GtkHx's CI

GtkHx's CI pulls these images and the `gtkhx-ci-base` toolchain instead of
building/installing on every run, and layers its **test-specific**
configuration (seeded accounts, fixtures, rate-limit-off, promoted
tracker entries, the Argus TLS sidecar, the collision-avoidance ports) on
top as a thin overlay — so the base images here stay general. The exact
GtkHx-side changes are in
[docs/consuming-in-gtkhx-ci.md](docs/consuming-in-gtkhx-ci.md).

## Keeping in sync with GtkHx

`images/ci-base/Dockerfile`'s package list mirrors GtkHx's CI build step —
if GtkHx grows a build dep, add it there and re-publish. The server
images are independent of GtkHx's port matrices (the overlay pins those).
