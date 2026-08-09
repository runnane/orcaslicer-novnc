# syntax=docker/dockerfile:1

# Web-accessible OrcaSlicer, on the linuxserver.io selkies base image.
#
# One Dockerfile covers both architectures: buildx supplies TARGETARCH and the
# matching AppImage asset is selected from the release at build time. Upstream
# linuxserver/docker-orcaslicer keeps a separate Dockerfile.aarch64 for this.

FROM ghcr.io/linuxserver/baseimage-selkies:debiantrixie

ARG BUILD_DATE
ARG VERSION
# Pin a release ("v2.4.2") or leave empty to track the latest one.
ARG ORCASLICER_VERSION
# Bypass the GitHub API entirely by giving a direct AppImage URL. Useful for
# reproducible builds and for build hosts that hit the unauthenticated API's
# 60-requests-per-hour limit.
ARG ORCASLICER_APPIMAGE_URL
ARG TARGETARCH

LABEL org.opencontainers.image.title="OrcaSlicer"
LABEL org.opencontainers.image.description="Web accessible OrcaSlicer"
LABEL org.opencontainers.image.licenses="GPL-3.0-only"
LABEL org.opencontainers.image.source="https://github.com/runnane/orcaslicer-novnc"
LABEL build_version="version:- ${VERSION} Build-date:- ${BUILD_DATE}"

ENV TITLE=OrcaSlicer \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    PIXELFLUX_WAYLAND=true

# AppImage extraction happens here; WORKDIR rather than `cd` so hadolint's
# DL3003 stays clean and the working directory is visible in the build output.
WORKDIR /tmp

# DL3008 (pin apt versions) is deliberately ignored: the selkies base tracks
# Debian trixie's package set, and pinning every version here would break on the
# first upstream point release while buying nothing — upstream does not pin either.
# hadolint ignore=DL3008
RUN \
  echo "**** add icon ****" && \
  curl -fo \
    /usr/share/selkies/www/icon.png \
    https://raw.githubusercontent.com/OrcaSlicer/OrcaSlicer/main/resources/images/OrcaSlicer.png && \
  echo "**** add mozilla apt repo ****" && \
  install -d -m 0755 /etc/apt/keyrings && \
  curl -o \
    /etc/apt/keyrings/packages.mozilla.org.asc -L \
    https://packages.mozilla.org/apt/repo-signing-key.gpg && \
  echo \
    "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" > \
    /etc/apt/sources.list.d/mozilla.list && \
  printf \
    "Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n" > \
    /etc/apt/preferences.d/mozilla && \
  echo "**** install packages ****" && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install --no-install-recommends -y \
    firefox \
    gstreamer1.0-alsa \
    gstreamer1.0-gl \
    gstreamer1.0-gtk3 \
    gstreamer1.0-libav \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-pulseaudio \
    gstreamer1.0-qt5 \
    gstreamer1.0-tools \
    gstreamer1.0-x \
    jq \
    libgstreamer-plugins-bad1.0 \
    libmspack0 \
    libwebkit2gtk-4.1-0 \
    libwx-perl && \
  echo "**** resolve orcaslicer release ****" && \
  if [ -n "${ORCASLICER_APPIMAGE_URL}" ]; then \
    RELEASE_API=""; \
  elif [ -z "${ORCASLICER_VERSION}" ]; then \
    RELEASE_API="https://api.github.com/repos/OrcaSlicer/OrcaSlicer/releases/latest"; \
  else \
    RELEASE_API="https://api.github.com/repos/OrcaSlicer/OrcaSlicer/releases/tags/${ORCASLICER_VERSION}"; \
  fi && \
  if [ -z "${RELEASE_API}" ]; then \
    DOWNLOAD_URL="${ORCASLICER_APPIMAGE_URL}"; \
    RESOLVED_VERSION="${ORCASLICER_VERSION:-$(basename "${ORCASLICER_APPIMAGE_URL}")}"; \
  else \
    case "${TARGETARCH}" in \
      amd64) ASSET_MATCH="Ubuntu2404_V" ;; \
      arm64) ASSET_MATCH="Ubuntu2404_aarch64" ;; \
      *) echo "!!!! unsupported TARGETARCH '${TARGETARCH}' — OrcaSlicer ships AppImages for amd64 and arm64 only !!!!" && exit 1 ;; \
    esac && \
    curl -fsSL -o /tmp/release.json "${RELEASE_API}" && \
    RESOLVED_VERSION=$(jq -r '.tag_name' /tmp/release.json) && \
    DOWNLOAD_URL=$(jq -r --arg m "${ASSET_MATCH}" \
      'first(.assets[] | select(.name | endswith(".AppImage")) | select(.name | contains($m)) | .browser_download_url) // ""' \
      /tmp/release.json); \
  fi && \
  if [ -z "${DOWNLOAD_URL}" ] || [ "${DOWNLOAD_URL}" = "null" ]; then \
    echo "!!!! no AppImage asset found for TARGETARCH '${TARGETARCH}' in ${RELEASE_API} !!!!" && exit 1; \
  fi && \
  echo "**** install orcaslicer ${RESOLVED_VERSION} (${TARGETARCH}) from ${DOWNLOAD_URL} ****" && \
  curl -fo \
    /tmp/orca.app -L \
    "${DOWNLOAD_URL}" && \
  chmod +x /tmp/orca.app && \
  ./orca.app --appimage-extract && \
  mv squashfs-root /opt/orcaslicer && \
  test -x /opt/orcaslicer/AppRun && \
  localedef -i en_GB -f UTF-8 en_GB.UTF-8 && \
  chmod +x /opt/orcaslicer/libexec/orca-slicer-env && \
  printf "OrcaSlicer version: %s\nImage version: %s\nBuild-date: %s\n" \
    "${RESOLVED_VERSION}" "${VERSION}" "${BUILD_DATE}" > /build_version && \
  echo "**** cleanup ****" && \
  apt-get autoclean && \
  rm -rf \
    /config/.cache \
    /config/.launchpadlib \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*

# Back to / so the container's runtime working directory matches upstream's —
# WORKDIR above was only for the AppImage extraction.
WORKDIR /

# add local files
COPY /root /

# ports and volumes
EXPOSE 3000 3001
VOLUME /config
