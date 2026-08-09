# LOCAL — the gates in this repo

**Never synced.** This file is orcaslicer-novnc's own; a difference from a
sibling repo's copy is not drift. The byte-identical rules live in
[`../shared/`](../shared/).

## The command

```bash
scripts/gates.sh              # hadolint → shellcheck → docker build → smoke
scripts/gates.sh --no-build   # lint + smoke against the existing image
scripts/gates.sh --no-smoke   # lint + build only
```

There is no `pnpm` here. This repo has no application source — it is a
Dockerfile, a compose file and five files that get copied into the image — so
the gate set is a linter, a build and a boot.

## What each step is actually worth

| Step | Catches | Blind to |
| --- | --- | --- |
| `hadolint` | shell and Dockerfile smells, unpinned `apt` patterns | anything about OrcaSlicer |
| `shellcheck` | quoting/globbing bugs in `gates.sh` and the s6 run script | the Dockerfile's inline shell (it is one `RUN`, not a script) |
| `docker build` | a dead URL, a renamed asset, a removed Debian package, a moved `libexec/orca-slicer-env` | whether the thing runs |
| smoke | selkies not serving, autostart broken, `/build_version` empty | whether the slicer is *usable* — nobody has clicked anything |

## Traps

- **A cached build proves almost nothing.** The interesting failures all live in
  the one big `RUN` layer — the release lookup, the AppImage download, the
  extraction. Docker caches that layer wholesale, so a rebuild after editing
  only `compose.yml` or the README re-runs none of it and goes green in
  seconds. Before believing a green build says anything about *upstream*, force
  it: `docker build --no-cache --pull`. Budget ~15 minutes; the cold build here
  took 885 s, of which 105 s was the 131 MB AppImage download.
- **The smoke test's 200 does not mean OrcaSlicer started.** selkies serves its
  own web UI whether or not the autostart worked, so the HTTP check passes on a
  container with no slicer in it. That is why the script also greps the process
  list — do not remove that check on the grounds that the curl already passed.
- **`--no-build` runs the smoke against whatever `orcaslicer-novnc:gates`
  happens to be.** That is fine for iterating on the smoke logic and misleading
  for anything else; the image may predate your change entirely.
- **Both linters run in containers**, because neither is installed on this host
  and neither is packaged for Arch. First run pulls `hadolint/hadolint` and
  `koalaman/shellcheck` — a few seconds, once.
- **`docker build` is amd64-only here unless you ask for more.** Multi-arch
  needs `docker buildx build --platform linux/amd64,linux/arm64`, and building
  arm64 on this x86 host additionally needs binfmt registered
  (`docker run --privileged --rm tonistiigi/binfmt --install arm64`). The gates
  deliberately do not do this — it turns a 15-minute build into a much longer
  one — so **an arm64 regression is invisible locally** and only CI will see it.

## CI

`.github/workflows/ci.yml`, `pull_request` only, `ubuntu-latest`. This repo is
**public**, so hosted Actions minutes are free — do not move it to the
self-hosted fleet that the private repos in the set have to use.

CI runs the same lint steps, then builds **both** architectures via buildx +
QEMU. That is the one thing CI does which the local gates do not, and it is why
a green local run is necessary but not sufficient here.
