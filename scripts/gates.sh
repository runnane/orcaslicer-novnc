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

if [ "$NO_BUILD" = "1" ]; then
  step "docker build — SKIPPED (--no-build); CI still builds"
else
  step "docker build"
  docker build \
    --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --build-arg VERSION=gates \
    -t "$IMAGE" .
fi

if [ "$NO_SMOKE" = "1" ]; then
  step "smoke — SKIPPED (--no-smoke)"
  exit 0
fi

step "smoke (boot the container and prove the GUI answers)"
cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$CONTAINER" --shm-size=2gb -P "$IMAGE" >/dev/null
port=$(docker port "$CONTAINER" 3001/tcp | head -1 | sed 's/.*://')

for _ in $(seq 1 60); do
  code=$(curl -sk -o /dev/null -w '%{http_code}' "https://localhost:${port}/" || true)
  [ "$code" = "200" ] && break
  sleep 2
done
[ "${code:-}" = "200" ] || { echo "!! GUI never answered 200 on :${port} (last: ${code:-none})"; docker logs "$CONTAINER" | tail -40; exit 1; }
echo "GUI answered 200 on :${port}"

# A version the build could not have resolved is a silently-broken image.
version=$(docker run --rm "$IMAGE" cat /build_version | awk '/^OrcaSlicer version/{print $3}')
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
