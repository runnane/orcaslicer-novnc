---
description: Work an explicit list of OSNV issues back-to-back, autonomously — one PR each, split what's too big, log and skip what you can't decide.
---

Work **$ARGUMENTS** in the order given, without stopping to ask. Serial by
default; `--parallel N` (max **2**) works two issues at once — see below for
what that is worth here and what it costs.

For each issue, run the `/fix` flow: read it in full, verify its premise, comment
that you have started, branch from fresh `main`, implement, verify in the failing
direction, `scripts/gates.sh`, PR with `--base main` and the key in the branch,
comment what changed.

Between issues, re-sync `main` — an earlier PR in the list may have landed.

**Budget for the build.** A change to the `Dockerfile`'s `RUN` layer needs a
`--no-cache --pull` build, which is ~15 minutes. Sequence the list so you are not
rebuilding for a docs-only change, and never skip the uncached build on the
grounds that the list is long.

**Skip rather than guess.** If an issue needs a decision only the owner can make
(publishing an image, changing the security posture, taking a dependency on a
different base image), comment saying precisely what you need and move on.

**Split rather than half-ship.** If an issue turns out too big, break its *whole*
scope into sub-issues and leave the parent as a small epic. A remainder that
exists only as prose in a comment is the failure this rule prevents.

`tracksProduction` is **off** here — there is no deploy target, so `MERGED` is
genuinely the end of the line. Do not imply a shipped image unless one was
actually pushed.

## `--parallel N` — measured, not assumed

**Default `1`. Ceiling `2`.** Each issue gets its own worktree
([`shared/agent-isolation.md`](shared/agent-isolation.md)), and you tear each
one down once its PR is open.

The sibling repos cap parallelism because their e2e binds fixed ports and one
worktree's Playwright adopts another's server. **None of that applies here** —
`gates.sh` publishes with `-P`, so the host ports are random and two runs cannot
contend for one. The constraint here is the build, so the ceiling was measured
rather than copied.

On a 16-core host, cold `--no-cache --pull` builds of two *differing* trees:

| | |
| --- | --- |
| one build, alone (expensive `RUN`) | **1025.6 s** |
| two concurrently (each one's `RUN`) | **1158.7 s** and **1149 s** |
| two concurrently (wall clock, pair) | **1172 s** |
| the same two, serially | 2051 s |

So **1.75× throughput, at 13% slower per build** — parallelism genuinely pays,
which is the opposite of what "they contend for one docker daemon" suggests.
The reason is that the build is barely CPU-bound: load average stayed near 1.0
on 16 cores throughout, because the expensive layer is mostly `apt` and one
131 MB download waiting on the network. Two of them interleave rather than queue.

Two other things the measurement settled:

- **The base image is shared, not duplicated.** Both builds resolved
  `baseimage-selkies:debiantrixie` to the same digest and reported `FROM` as
  `DONE 0.0s` — one dockerd, one image store, no second download, however many
  worktrees are involved.
- **`N=3` is untested.** Nothing here says it would not also work; the point is
  that nobody has run it. Raise the ceiling by re-running the measurement, not
  by reasoning about it — the reasoning is what got the `N=2` justification
  wrong in the first place.

**One hard requirement before running parallel: never test an image by a shared
tag.** `gates.sh` builds a per-run tag for exactly this reason. Two runs both
writing `orcaslicer-novnc:gates` means the second build moves the tag and the
first boots its neighbour's image and passes — observed, not theorised: of two
concurrent runs, one built `40e7485f` and smoke-tested `ed65bbbb`. Resolving the
image ID right after the build is **not** enough of a fix; the gap between
`docker build -t` and `docker image inspect` is wide enough, and was hit on the
first attempt. If you add a step that builds or runs an image, give it a tag
carrying `$$` or the branch name.

## Never send a subagent to a big reference skill

If a task needs a fact from a large reference skill — `claude-api` is the one
that bites — **invoke it yourself, in your own context**, and put the extracted
fact in the brief, **quoted**. Then say so explicitly:

> Do **not** invoke the `claude-api` skill. The facts you need are quoted above.
> If one is missing, stop and ask rather than going to look.

Its trigger fires on anything merely **LLM-shaped** — an agent, an MCP tool
definition, a prompt, a summarize/classify/extract feature — with no provider
named anywhere. It is a **user-level** skill, so it is loaded here too, despite
this repo being a Dockerfile with no application code. And this repo hands it
plenty to catch on: `AGENTS.md` describes issue tracking over the
`respawn-control` **MCP server**, so a brief that only says "file the follow-up
issue" already reads as MCP-shaped. A subagent that pulls it in unprompted
spends most of its window on it and has that much less left for the build log —
which was the one thing it actually needed to read closely.

Small repo-specific files are the opposite case: point at them **by name** and
let the subagent load them. `local/gates.md`, `shared/gate-failures.md` and
`shared/agent-isolation.md` are each shorter than the brief explaining why you
did not include them.
