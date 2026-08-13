# orcaslicer-novnc

Web-accessible [OrcaSlicer](https://github.com/OrcaSlicer/OrcaSlicer) in a container —
a from-scratch recreation of the old `orcaslicer-novnc` idea on a current base image,
current dependencies, and the latest OrcaSlicer release.

> **On the name.** The transport here is **selkies** (KasmVNC-derived), not classic
> noVNC. The repo keeps the familiar name because that is what people search for, but
> nothing in the image runs `websockify` or upstream noVNC. If you specifically need
> classic noVNC, this is not it.

## Why not just use the old one

[helfrichmichael/orcaslicer-novnc](https://github.com/helfrichmichael/orcaslicer-novnc),
the container this recreates, is built on `debian:bullseye` with
[`easy-novnc@v1.1.0`](https://github.com/geek1011/easy-novnc), `libwebkit2gtk-4.0-37`
and `libwxgtk3.0` — packages that no longer exist in any current Debian or Ubuntu, on a
release whose glibc is older than the one OrcaSlicer's AppImage is built against. It
cannot be brought forward by patching; the base and every graphics dependency have to
change together.

This image instead builds on
[`ghcr.io/linuxserver/baseimage-selkies:debiantrixie`](https://github.com/linuxserver/docker-baseimage-selkies),
which is what [linuxserver/docker-orcaslicer](https://github.com/linuxserver/docker-orcaslicer)
itself now uses, and which brings HTTPS, optional auth, audio, GPU support and s6
supervision with it.

### What this does differently from linuxserver/docker-orcaslicer

| | linuxserver | here |
| --- | --- | --- |
| Architectures | two files — `Dockerfile` + `Dockerfile.aarch64` | **one** Dockerfile; buildx's `TARGETARCH` picks the asset |
| `ORCASLICER_VERSION` | declared, but the build always reads `releases/latest` — **pinning has no effect** | pinning hits `releases/tags/<version>` and actually pins |
| Asset selection | `awk '/browser_download_url.*Ubuntu2404_V/'` over raw JSON | `jq`, filtered on both arch and `.AppImage` |
| Air-gapped / rate-limited builds | not possible without editing the Dockerfile | `ORCASLICER_APPIMAGE_URL` skips the GitHub API entirely |
| Failure mode on a missing asset | downloads an empty file, fails later and obscurely | explicit `exit 1` naming the arch, plus a `test -x AppRun` after extraction |
| Recorded version | image version only | `/build_version` records the resolved **OrcaSlicer** version |

## Usage

The image is published to GHCR for `linux/amd64` and `linux/arm64`, and the package is
public — no `docker login`, no token:

```bash
docker compose up -d
```

or without compose:

```bash
docker run -d --name orcaslicer \
  -p 3001:3001 --shm-size=2gb -v "$(pwd)/config:/config" \
  ghcr.io/runnane/orcaslicer-novnc:latest
```

Then open **<https://localhost:3001/>**. Port 3000 is plain HTTP and is only useful
behind a reverse proxy that terminates TLS — several browser features the slicer relies
on require a secure context.

### Tags

| Tag | What it is |
| --- | --- |
| `latest` | Rebuilt and republished on every push to `main` |
| `2.4.2` | The image carrying that OrcaSlicer release — pin this if you want to stay put |

Both are multi-arch: `docker pull` picks the right one for the host. Check what actually
landed:

```bash
docker run --rm ghcr.io/runnane/orcaslicer-novnc:latest cat /build_version
```

That records the resolved OrcaSlicer version and the commit of this repo that built the
image.

Nothing yet republishes when OrcaSlicer releases without a corresponding push here, so
`latest` can lag upstream by a release; pull it again after a new OrcaSlicer version to
be sure.

## Building it yourself

Building is the slow path — a cold build is roughly 15 minutes against a pull of a few
minutes — and is worth it to pin an OrcaSlicer release the tags do not cover, or to
change the image.

```bash
docker build -t orcaslicer-novnc:latest .
```

To build via `compose.yml`, uncomment its `build:` block and point `image:` at a local
tag first.

### Pinning a release

```bash
docker build --build-arg ORCASLICER_VERSION=v2.4.2 -t orcaslicer-novnc:2.4.2 .
```

Unset means "whatever `releases/latest` says at build time", which is reproducible only
for as long as that stays put — pin for anything you care about.

### Multi-arch

OrcaSlicer publishes AppImages for `x86_64` and `aarch64`, and the selkies base is
available for both, so one build command covers both:

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t orcaslicer-novnc:latest .
```

Building `linux/arm64` on an x86 host needs binfmt emulation registered first
(`docker run --privileged --rm tonistiigi/binfmt --install arm64`), and it is slow. The
published images avoid that by building each architecture on a native runner. Any other
`TARGETARCH` fails the build with a message rather than producing a broken image.

### Avoiding the GitHub API

Unauthenticated GitHub API calls are limited to 60/hour per IP, which a CI host can
exhaust. Give the URL directly and the build makes no API call at all:

```bash
docker build \
  --build-arg ORCASLICER_APPIMAGE_URL=https://github.com/OrcaSlicer/OrcaSlicer/releases/download/v2.4.2/OrcaSlicer_Linux_AppImage_Ubuntu2404_V2.4.2.AppImage \
  --build-arg ORCASLICER_VERSION=v2.4.2 \
  -t orcaslicer-novnc:2.4.2 .
```

### Publishing from a fork

`.github/workflows/publish.yml` needs no secrets — the built-in `GITHUB_TOKEN` with
`packages: write` is the whole credential. One thing will still catch you out: a newly
created GHCR package is **private**, and its visibility is a **web-UI-only toggle**
(the package's page → *Package settings* → *Change visibility*). There is no REST API
for it — `PATCH /user/packages/container/<name>` answers `404 Not Found` even for a
package the same token can `GET` fine. Until it is flipped, `docker pull` fails with a
bare `denied` that mentions nothing about visibility.

## Parameters

| Parameter | Function |
| --- | --- |
| `-p 3001:3001` | Desktop GUI over HTTPS — **the one you want** |
| `-p 3000:3000` | Same GUI over HTTP; proxy it or leave it closed |
| `-e PUID=1000` | User ID owning `/config` |
| `-e PGID=1000` | Group ID owning `/config` |
| `-e TZ=Europe/Oslo` | Timezone |
| `-e CUSTOM_USER=abc` | Optional basic-auth username |
| `-e PASSWORD=secret` | Optional basic-auth password |
| `-e PIXELFLUX_WAYLAND=true` | Wayland session (default on; set `false` for X11) |
| `-e DRINODE=/dev/dri/renderD128` | Render node for GPU acceleration |
| `-v /config` | Home directory — settings, profiles, projects |
| `--shm-size=2gb` | Prevents renderer crashes; the default 64 MB is not enough |

`/config` is the only thing worth backing up: OrcaSlicer keeps printer profiles,
filament profiles and its own configuration there.

## Security

**This container has no authentication by default**, and it exposes a full desktop
session with a file manager and a browser to anyone who can reach the port. On a trusted
LAN, set `CUSTOM_USER` and `PASSWORD` for basic auth. Do not put it on the public
internet without a reverse proxy doing real authentication in front of it — basic auth
over a shared password is not that.

## Hardware acceleration

3D rendering works without a GPU (llvmpipe), just slowly. `compose.yml` carries
commented-out blocks for both cases:

- **Intel / AMD** — pass `/dev/dri` through and set `DRINODE`.
- **Nvidia** — proprietary driver 580+, `nvidia-drm.modeset=1` on the kernel command
  line, `nvidia-ctk runtime configure --runtime=docker`, then the `deploy.resources`
  block.

## Credits

- [OrcaSlicer](https://github.com/OrcaSlicer/OrcaSlicer) — the slicer.
- [linuxserver.io](https://linuxserver.io/) — the selkies base image and the
  `docker-orcaslicer` container this borrows its defaults from.
- [helfrichmichael/orcaslicer-novnc](https://github.com/helfrichmichael/orcaslicer-novnc)
  — the original this recreates.

## License

GPL-3.0-only, following linuxserver/docker-orcaslicer.
