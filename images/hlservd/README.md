# hlservd

> **General-purpose image.** Runtime configuration (env knobs, mounting
> your own config) is documented in the repo-root `README.md`. The
> GtkHx-test-specific tuning lives in GtkHx's overlay, not in this image.

hlservd is the Hotline Server 1.9.5 as a POSIX daemon: a port of the
Hotsprings 2003 GPL source release (the "Openline" 1.9 server) by the
author of [Underline Hotline](https://199x.online/underline/). The Linux
build is one statically linked binary with no GUI, so unlike the official
1.9 servers it runs headless, without Wine or an X display. It is the
closest thing to the original 1.9 server that does.

The binary is pulled from `199x.online` at image-build time and
sha256-verified (`HLSERVD_URL` / `HLSERVD_SHA256` in the Dockerfile). Its
source hasn't been published yet; once it is, this image should build from
it.

## Running

```sh
docker run -d -p 5500:5500 -p 5501:5501 \
  -v hlservd-data:/var/lib/hlservd \
  ghcr.io/mishan/hlservd
```

The server root is `/var/lib/hlservd`: `Settings.ini`, `Agreement.txt`,
and the `Users/`, `Files/` and `News/` folders the server makes on its
first start. Accounts are YAML files in `Users/`.

| Env | Setting |
|---|---|
| `HLSERVD_PORT` | `[Server] Port`. Transfers use the next port, the HTTP tunnel the two after. |
| `HLSERVD_NAME` | `[Server] Name` |
| `HLSERVD_TRUST_LOOPBACK` | `[Server] TrustLoopback`: `true` exempts 127.0.0.1 from the flood ban. |

## The admin account

On its first start, with no accounts yet, the server makes a guest account
and an `admin` account. Until `admin` has a password, it logs in with any
password but **only from the machine running the server**; set one to use
it from anywhere. In a container, "this machine" means connections the
server sees from 127.0.0.1, so either set the password from inside the
container's network (`--network host`, or `docker exec`), or write
`Users/admin.yaml` yourself before the first start.

## Settings it reads but doesn't write

The generated `Settings.ini` doesn't list these `[Server]` keys, but the
server reads them: `MaxConnectRate`, `BanBaseSecs`,
`AccountFloodMultiplier`, `DownloadIdleTimeout` and `TrustLoopback`.

The flood ban is aggressive: more than about ten connections in thirty
seconds from one address gets it banned, and each new strike lengthens the
ban. A test suite or anything else that opens connections quickly from one
address wants `TrustLoopback = true` and connects over loopback.

## What the Linux build doesn't keep

Per its README, the Linux server doesn't keep classic Mac file data: type
and creator codes, Finder comments and resource forks. Files list with
empty type codes; folders list as `fldr`.
