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

See [`.claude/commands/local/gates.md`](.claude/commands/local/gates.md) for
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
- **Do not add application code.** If something needs real logic — a version
  checker, a profile sync — it belongs in a sibling repo (`orca-profiles` is
  the OrcaSlicer-config one) rather than growing a `src/` here.
- **Keep the `root/` files close to upstream.** They are byte-copied from
  `linuxserver/docker-orcaslicer` so that a future upstream change is a visible
  diff. Deviate only with a reason recorded in the commit message.
- **Follow-ups become issues — never inline TODO text.** Any deferred work must
  be filed via `issues_create_issue` in the `orcaslicer-novnc` project, after a
  dedupe **search** (`issues_list_issues {project, q, order: "newest"}` with no
  status filter). Never write "TODO:" or "worth doing later" as prose.
- **Branch → commit → PR, always from fresh `main`.** One issue → one PR → one
  merge. The issue key goes in the **branch or title**, never only the body.
  See [`.claude/commands/shared/pr-hygiene.md`](.claude/commands/shared/pr-hygiene.md).
- **Comment on the issue when you start and when you finish.**
- **Never leave an issue partly implemented — split it instead.**

## The agent tooling is mirrored across sibling repos

This repo is part of the agent-tooling sync set. `.claude/commands/shared/*.md`
are **byte-identical across every repo in the set** (verified with `sha256sum`)
and must never be edited in one repo alone;
`.claude/commands/local/gates.md` is this repo's own and is never synced. The
set is enumerated in `respawn-control`'s `AGENTS.md`, which is the one place it
is listed.

What differs here, and will need translating in both directions:

| Elsewhere in the set | Here |
| --- | --- |
| `pnpm gates` (tsc / lint / vitest / build) | `scripts/gates.sh` (hadolint / shellcheck / `docker build` / boot) |
| gates run in seconds | a cold build is **~15 minutes** |
| unit tests | none — there is no source to test |
| CI mirrors local exactly | CI additionally builds **arm64**, which local gates skip |

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
