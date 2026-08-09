---
description: Work the OSNV issue queue in parallel — subagents per issue, each on its own branch and PR, verified between batches.
---

Discover the queue and work it.

1. `issues_list_issues { project: "orcaslicer-novnc", status: [...] }` —
   unassigned and claude-assigned issues are in scope. Order by priority, then
   age.
2. Fan out **two at a time**, each subagent in its **own git worktree** — see
   [`shared/agent-isolation.md`](shared/agent-isolation.md). This checkout is
   shared; never let two agents work the same tree, and remove a worktree once
   its PR is open.
3. Each subagent runs the `/fix` flow end to end and opens its own PR.
4. **Verify their claims between batches.** "the build passed" in a report is
   not evidence — this repo's failure mode is specific: a **cached** build goes
   green without re-running the release lookup, the download or the extraction,
   so a subagent can honestly report a green build that exercised nothing.
   Check that a `RUN`-layer change was built with `--no-cache --pull`, and
   re-run `scripts/gates.sh` yourself on the branch if the report is vague.
5. Re-sync `main` between batches.

**Two at a time is a hard limit here, and for a different reason than in the
sibling repos.** Concurrent uncached `docker build`s each pull a distinct ~1.5 GB
base and a 131 MB AppImage, and they contend for the same layer cache and disk.
Three or four in parallel is how you turn a 15-minute build into an hour.

Never let a subagent push an image to a registry — publishing is the owner's
call, and image layers are public and permanent.
