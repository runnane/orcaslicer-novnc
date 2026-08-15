# The gates in this repo

`.agents/repo.json` names this file as `gatesDoc`, which is how a repo-agnostic
command finds this repo's particulars without carrying them. Its counterpart is
the **`gate-failures` skill** in the userspace bundle: that one names no command
or runner, so it can be shared. This repo is the reason that split matters — it
has **no `pnpm` at all**, so every piece of shared prose that says `pnpm gates`
or "add a changeset" was simply false here for as long as the copies existed.

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
  took 872 s, of which 105 s was the 131 MB AppImage download.
- **Never `ARG VERSION` or `ARG BUILD_DATE` above the expensive `RUN` — the
  DECLARATION is what costs you, not the use.** BuildKit puts a declared `ARG`
  into the environment of every subsequent `RUN`, so an `ARG BUILD_DATE` at the
  top of the file invalidates the big layer below it **even though that layer
  never mentions it**. Both the declaration and the use live at the bottom of
  the Dockerfile, next to a comment explaining why.

  This is not hypothetical, and it is worth knowing how it hid: the stamp
  started *inside* the big `RUN` (where upstream keeps it), so **every gates run
  was a cold 15-minute build** and the cache never hit at all. It reads as
  ordinary Docker slowness, not as a bug. Moving only the *reference* to the
  bottom did not fix it — the second build still took 15 minutes — because the
  declarations were still at the top.

  Measured on a two-line Dockerfile, which is how to check this in seconds
  rather than half an hour:

  | change | expensive `RUN` |
  | --- | --- |
  | identical args | `CACHED` |
  | `BUILD_DATE` changed, `RUN` references it | re-executes |
  | `BUILD_DATE` changed, `RUN` does **not** reference it, declared above | re-executes |
  | declarations moved below the `RUN` | `CACHED` |

  If a gates run that should have been cached takes ~15 minutes, suspect this
  first.
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
- **`docker build` here is amd64, and so is everything else.** Since OSNV-4
  only amd64 is published and only amd64 is built in CI, so the gates and CI
  now agree and there is no architecture gap between them.
- **arm64 is buildable but watched by nothing.** The Dockerfile still selects an
  aarch64 AppImage when `TARGETARCH` says so, and it works on arm hardware — but
  no gate and no CI job exercises it, so an arm64 regression is invisible
  everywhere, not merely locally. Do not try to cover it with binfmt: that
  AppImage is static-pie and `qemu-user` cannot exec it at all, so an emulated
  build fails with `Exec format error` rather than merely running slowly.

## CI

`.github/workflows/ci.yml`, `pull_request` only, `ubuntu-latest`. This repo is
**public**, so hosted Actions minutes are free — do not move it to the
self-hosted fleet that the private repos in the set have to use.

CI runs the same lint steps, then builds **both** architectures via buildx +
QEMU. That is the one thing CI does which the local gates do not, and it is why
a green local run is necessary but not sufficient here.
