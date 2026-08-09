---
description: Implement a fix/feature for an OSNV issue end-to-end, verify, open a PR, and update the issue.
---

Work issue **$ARGUMENTS** to completion.

1. **Read all of it.** `issues_get_issue` with
   `include: ["comments","links","attachments"]` — the slim call returns counts,
   not content, and decisions live in comments. Fetch and view every attachment.
   An issue still `blockedBy` an open one is not ready.
2. **Treat its premise as a claim.** "The base image can't do X", "OrcaSlicer
   doesn't ship Y for arm64" is what someone believed when filing. In this repo
   the two minutes that settle it are nearly always one of:
   - `curl -sSL https://api.github.com/repos/OrcaSlicer/OrcaSlicer/releases/latest`
     — what the release *actually* offers, per arch. Note the org moved from
     `SoftFever`; the old path 301s and returns an empty body without `-L`.
   - `gh api repos/linuxserver/docker-orcaslicer/contents/Dockerfile --jq .content | base64 -d`
     — what upstream is doing *now*. It has changed base image at least once.
   - `docker run --rm orcaslicer-novnc:latest <cmd>` — what is actually in the
     image, rather than what the Dockerfile appears to put there.

   Record the outcome on the issue either way.
3. **Comment that you have started**, with the approach.
4. **Branch from fresh `main`** — see
   [`shared/agent-isolation.md`](shared/agent-isolation.md) first: if `HEAD` is
   already a topic branch, stop and report it.
   `<type>/<osnv-lower>-<kebab-title>`.
5. **Implement.** There is no application source here — the change is the
   `Dockerfile`, `compose.yml`, something under `root/`, or the docs. If it
   seems to need real logic, that is a sign it belongs in a sibling repo
   (`orca-profiles` is the OrcaSlicer-config one), not a new `src/` here. Keep
   the `root/` files close to upstream's so a future upstream change stays a
   visible diff.
6. **Verify in the failing direction.** The build is the test, so make it refuse
   before you make it pass — a new guard that has never failed proves nothing.
   For anything in the resolve block, the cheap way to exercise every branch
   without a 15-minute rebuild is to run the same shell against an existing
   image: `docker run --rm --entrypoint sh <image> -c '<the block>'` with the
   ARGs substituted. Cover the unsupported-arch and no-asset paths too.
7. **`scripts/gates.sh`.** If you touched the `RUN` layer, that run must be
   `docker build --no-cache --pull` — a cached build re-runs none of the
   interesting steps and goes green regardless. See
   [`local/gates.md`](local/gates.md); if a gate goes red,
   [`shared/gate-failures.md`](shared/gate-failures.md).
8. **PR** — `gh pr create --base main`, issue key in the branch or title (not
   only the body, or nothing transitions). See
   [`shared/pr-hygiene.md`](shared/pr-hygiene.md). CI builds **arm64** as well,
   which your local gates did not; do not call it done before CI is green.
9. **Comment what changed** — files, build args, behaviour — and let the webhook
   move the status.

If it turns out too big, **split it** into sub-issues covering the whole scope
rather than shipping half. `tracksProduction` is **off** here: there is no
deploy target, so `MERGED` is the end of the line.
