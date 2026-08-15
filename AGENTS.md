# AGENTS.md

Guidance for coding agents (and humans) working in this repo. Follows the
[agents.md](https://agents.md) convention.

## What this is

A container that serves [OrcaSlicer](https://github.com/OrcaSlicer/OrcaSlicer)
to a browser — a from-scratch recreation of the abandoned
`helfrichmichael/orcaslicer-novnc`, on a current base image with current
dependencies and the latest OrcaSlicer release.

**There is no application source here.** The whole repo is a `Dockerfile`, a
`compose.yml`, five files copied into the image under `root/`, and a gate
script. That shapes everything below: there is nothing to unit-test, and the
only way to learn whether a change works is to build and boot it.

Work is tracked in the **OSNV** project of our control-plane portal, reached
over the `respawn-control` MCP server. [`.mcp.json`](.mcp.json) wires it up but
deliberately contains **no URL and no token** — this repository is public, so
both come from the environment:

```bash
export RESPAWN_MCP_URL='https://<portal-host>/mcp?modules=issues'
export RESPAWN_MCP_TOKEN='<api key>'
```

Set those in your shell profile, not in a file in this repo.

## The name is not the transport

The repo is called `orcaslicer-novnc` because that is what people search for.
The transport is **selkies** (KasmVNC-derived), inherited from the linuxserver
base image. Nothing here runs `websockify` or upstream noVNC. Say "selkies" in
code and comments; keep "noVNC" for the repo name and the search-engine
paragraph in the README.

## Build / test / lint (run before finishing any change)

```bash
scripts/gates.sh            # hadolint → shellcheck → docker build → smoke
```

See [`.agents/gates.md`](.agents/gates.md) — named by `.agents/repo.json` as
`gatesDoc` — for
what each step is worth, and for the three traps — chiefly that **a cached
build proves almost nothing**, because every interesting failure lives in the
one `RUN` layer that Docker caches wholesale. Force `--no-cache --pull` before
believing a green build says anything about upstream.

## Non-negotiable conventions

- **This repo is public.** Nothing internal may appear in a commit, an issue,
  a workflow file or a generated artifact: no portal hostname, no LAN address,
  no printer name, no token. Image layers are world-readable and permanent.
- **Upstream is `OrcaSlicer/OrcaSlicer`, not `SoftFever/OrcaSlicer`.** The
  project moved org; the old API path 301s. `curl` without `-L` against the old
  path returns an empty body and a 301, which is exactly the shape that makes a
  build fail three steps later with an unrelated message.
- **Pin by tag, never by "latest" plus a comment.** `ORCASLICER_VERSION` hits
  `releases/tags/<version>`. If you ever find yourself reading
  `releases/latest` while a version arg is set, that is the upstream bug this
  repo exists to not have — see the README table.
- **A new build arg needs a README row.** The parameter table is the only
  documentation this repo has; an undocumented arg is an invisible one.
- **Layer order is load-bearing: neither the declaration nor the use of
  `VERSION` / `BUILD_DATE` may appear above the stamping layer at the bottom of
  the Dockerfile.** A declared `ARG` joins the environment of every following
  `RUN`, so `ARG BUILD_DATE` at the top invalidates the expensive layer *even
  though that layer never reads it* — making every build a cold 15-minute one,
  silently, because it reads as ordinary slowness. That is not hypothetical; it
  is how this repo's first four builds behaved, and moving only the reference
  did not fix it.
- **Do not add application code.** If something needs real logic — a version
  checker, a profile sync — it belongs in a sibling repo (`orca-profiles` is
  the OrcaSlicer-config one) rather than growing a `src/` here.
- **Keep the `root/` files close to upstream.** They are byte-copied from
  `linuxserver/docker-orcaslicer` so that a future upstream change is a visible
  diff. Deviate only with a reason recorded in the commit message.

The branch/PR/tracker discipline — follow-ups become issues, one issue one PR,
the key in the branch or title, comment on start and finish, split rather than
half-ship — is in the userspace bundle and is not repeated here. Issues live in
the `orcaslicer-novnc` project, key `OSNV`; both are in
[`.agents/repo.json`](.agents/repo.json).

## How agent instructions reach this repo

Ten repos run the same agent workflow against one tracker and one PR webhook.
They used to do it by copying `.claude/commands/` between each other, which
drifted measurably; RCP-878 replaced that with one bundle plus one manifest per
repo, and OSNV-6 adopted it here. There is nothing left to sync and no
`sha256sum` check to run.

- **The bundle** — `runnane/agent-userspace`: the constitution, the
  repo-agnostic workflow commands, and the `pr-hygiene`, `gate-failures` and
  `agent-isolation` skills.
- **[`.agents/repo.json`](.agents/repo.json)** — the facts that differ. This
  repo is the strongest argument for the manifest existing, because more differs
  here than anywhere else in the set.

**This repo is why "adapt, don't copy" was a rule and why a manifest replaced
it.** Every difference below was, until now, prose that had to be kept in sync
by hand — and the copied commands still said `pnpm gates`:

| Elsewhere in the set | Here |
| --- | --- |
| `pnpm gates` (tsc / lint / vitest / build) | `scripts/gates.sh` (hadolint / shellcheck / `docker build` / boot) — **there is no `pnpm` and no `package.json` at all** |
| gates run in seconds | a cold build is **~15 minutes**, which changes what "just re-run it" costs |
| unit tests | none — there is no application source to test |
| CI mirrors local exactly | CI builds the same **amd64** image the gates do; arm64 is neither built nor published (OSNV-4) |
| a changeset for user-visible changes | no release process at all; the image is the artifact |

## Where things are

| Area | Path |
| --- | --- |
| The image | `Dockerfile` |
| Runtime defaults copied into the image | `root/` |
| Local run | `compose.yml` |
| Gates | `scripts/gates.sh` |
| CI | `.github/workflows/ci.yml` |

## Definition of done

`scripts/gates.sh` green (with a `--no-cache` build if the change touches the
`RUN` layer), README updated if a parameter or behaviour changed, the issue
commented and its PR open against `main`.
