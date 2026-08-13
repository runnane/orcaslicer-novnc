#!/usr/bin/env bash
# Everything CI runs, in CI's order. See .claude/commands/local/gates.md.
set -euo pipefail

cd "$(dirname "$0")/.."

IMAGE="${IMAGE:-orcaslicer-novnc:gates}"
CONTAINER="orcaslicer-gates-$$"
NO_BUILD=0
NO_SMOKE=0

for arg in "$@"; do
  case "$arg" in
    --no-build) NO_BUILD=1 ;;
    --no-smoke) NO_SMOKE=1 ;;
    -h|--help)
      echo "usage: scripts/gates.sh [--no-build] [--no-smoke]"
      exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

step "hadolint (Dockerfile)"
docker run --rm -i hadolint/hadolint hadolint --failure-threshold warning - < Dockerfile

step "shellcheck (shell scripts)"
# The s6 run scripts use `#!/usr/bin/with-contenv bash`, which shellcheck cannot
# resolve — tell it the shell explicitly rather than adding a directive to a file
# that is byte-copied from upstream.
docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable \
  --shell=bash scripts/gates.sh root/etc/s6-overlay/s6-rc.d/svc-dbus/run

# Each run builds its OWN tag and smoke-tests that one.
#
# A tag is a mutable pointer and IMAGE defaults to a fixed name, so two
# concurrent runs — which /sweep and /auto --parallel both produce — write the
# same one, and whichever build finishes second moves it out from under the
# first. The loser then boots the OTHER worktree's image and passes, having
# never booted what it built.
#
# Resolving the image ID straight after the build does NOT fix this, which was
# worth finding out the hard way: the window between `docker build -t` and
# `docker image inspect` is enough, and two runs from differing trees hit it on
# the first attempt — one built 40e7485f and tested ed65bbbb, its neighbour's
# image. A per-run tag is the only version with no window at all.
#
# IMAGE is still applied, so `orcaslicer-novnc:gates` remains there afterwards
# for a human to poke at; nothing automated reads it.
RUN_TAG="${IMAGE}-run-$$"

if [ "$NO_BUILD" = "1" ]; then
  step "docker build — SKIPPED (--no-build); CI still builds"
  RUN_TAG="$IMAGE"
else
  step "docker build"
  docker build \
    --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --build-arg VERSION=gates \
    -t "$IMAGE" -t "$RUN_TAG" .
fi

if [ "$NO_SMOKE" = "1" ]; then
  step "smoke — SKIPPED (--no-smoke)"
  exit 0
fi

step "smoke (boot the container and prove the GUI answers)"
cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  # Drop only this run's private tag. IMAGE still points at whichever build
  # finished last, so the image itself survives for inspection.
  [ "$RUN_TAG" = "$IMAGE" ] || docker rmi "$RUN_TAG" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run -d --name "$CONTAINER" --shm-size=2gb -P "$RUN_TAG" >/dev/null
port=$(docker port "$CONTAINER" 3001/tcp | head -1 | sed 's/.*://')

for _ in $(seq 1 60); do
  code=$(curl -sk -o /dev/null -w '%{http_code}' "https://localhost:${port}/" || true)
  [ "$code" = "200" ] && break
  sleep 2
done
[ "${code:-}" = "200" ] || { echo "!! GUI never answered 200 on :${port} (last: ${code:-none})"; docker logs "$CONTAINER" | tail -40; exit 1; }
echo "GUI answered 200 on :${port} (image $(docker image inspect -f '{{.Id}}' "$RUN_TAG" | cut -c8-19))"

# A version the build could not have resolved is a silently-broken image.
version=$(docker run --rm "$RUN_TAG" cat /build_version | awk '/^OrcaSlicer version/{print $3}')
case "$version" in
  v[0-9]*) echo "OrcaSlicer ${version} recorded in /build_version" ;;
  *) echo "!! /build_version does not name an OrcaSlicer release (got: '${version}')"; exit 1 ;;
esac

# The GUI answering does not prove the slicer launched — selkies serves its own
# page either way. Autostart is the thing that actually differs.
if docker exec "$CONTAINER" ps -eo comm --no-headers | grep -q orcaslicer; then
  echo "orcaslicer process is running"
else
  echo "!! selkies is up but no orcaslicer process — autostart is broken"
  docker exec "$CONTAINER" ps -eo comm --no-headers | sort -u
  exit 1
fi

printf '\n\033[1;32mgates green\033[0m\n'
