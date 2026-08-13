---
description: Work the OSNV issue queue in parallel — subagents per issue, each on its own branch and PR, verified between batches.
---

Discover the queue and work it.

1. `issues_list_issues { project: "orcaslicer-novnc", status: [...] }` —
   unassigned and claude-assigned issues are in scope. Order by priority, then
   age.
2. Fan out **two at a time** (the measured ceiling — see below), each subagent
   in its **own git worktree** — see
   [`shared/agent-isolation.md`](shared/agent-isolation.md). This checkout is
   shared; never let two agents work the same tree, and remove a worktree once
   its PR is open.
3. Each subagent runs the `/fix` flow end to end and opens its own PR.
4. **Verify their claims between batches** — see the checklist below.
5. Re-sync `main` between batches.

## Two at a time, and why

**Two at a time is the limit, and the reason it used to give was wrong.** It
claimed concurrent builds "each pull a distinct ~1.5 GB base". They do not:
there is one dockerd and one image store, so both builds resolve
`baseimage-selkies:debiantrixie` to the same digest and both report `FROM` as
`DONE 0.0s`, with no second download, however many worktrees are in play.

What the measurement actually shows is that **two in parallel is worth doing**.
Cold builds of two differing trees on a 16-core host: 1025.6 s alone, versus
1158.7 s and 1149 s concurrently for a pair wall-clock of 1172 s against 2051 s
serially — **1.75× throughput at 13% slower per build**. The expensive layer is
mostly `apt` and one 131 MB download, so it is network-bound, not CPU-bound, and
two of them interleave instead of queueing. `N=3` is simply untested: re-run the
measurement before raising the ceiling, rather than arguing from the numbers
above. See [`auto.md`](auto.md) for the full table.

**The collision that does exist is a tag, not a port.** `gates.sh` publishes
with `-P`, so host ports are random and cannot clash — but it builds an image,
and a tag is a mutable pointer. Two runs both writing `orcaslicer-novnc:gates`
means the second build moves it and the first boots its neighbour's image and
passes. That is observed, not theorised: one run built `40e7485f` and
smoke-tested `ed65bbbb`. `gates.sh` now builds a per-run tag; if you add
anything that builds or runs an image, tag it with `$$` or the branch.

## Verify every claim; a report is not evidence

From a `--parallel 3` pass in a sibling repo where **five of six subagents
reported incomplete work as complete.** None of them were lying; they were
reading their own summaries instead of the output.

- **Read the build output yourself.** This repo's version of the failure is
  specific: a **cached** build goes green without re-running the release lookup,
  the download or the extraction, so a subagent can honestly report a green
  build that exercised nothing. Confirm a `RUN`-layer change was built
  `--no-cache --pull` — look for the expensive layer reporting a real duration
  rather than `CACHED`.
- **An exit code is not an artefact.** `gates.sh` exits 0 on a build that
  produced an image nothing has booted. Check the things that differ:
  `/build_version` naming a real OrcaSlicer release, and an `orcaslicer` process
  actually running. "The build passed" answers neither.
- **A described check is not a check.** Break the invariant, watch it fail,
  restore it, and paste the real output. The instance to reuse here: upstream
  declares `ORCASLICER_VERSION` and then unconditionally fetches
  `releases/latest`, so a pin silently builds newest and every test still
  passes. **A pin that is not tested is a pin that does not work** — anything
  touching version resolution needs a failing-direction check.
- **Merge one at a time.** A partly-completing PR carries the **child's** key in
  the branch and title, and the parent's in the body.
- **You tear down each worktree** once its PR merges — not the subagent that
  created it, which is gone. `git worktree list` is the only place they exist.

## Never send a subagent to a big reference skill

Invoke it in **your own** context, extract the fact, and quote it into the brief
with an explicit *"do **not** invoke the `claude-api` skill; the facts are quoted
above, stop and ask if one is missing."*

Its trigger fires on anything merely **LLM-shaped** — an agent, an MCP tool
definition, a prompt, a summarize/classify/extract feature — with no provider
named at all. It is a **user-level** skill, so it is loaded here too, despite
this repo being a Dockerfile with no application code, and `AGENTS.md` describing
issue tracking over the `respawn-control` **MCP server** is quite enough for it
to catch on. A subagent that pulls it in unprompted has that much less window
left for the build log.

Small repo-specific files are the opposite case — point at them by name:
`local/gates.md`, `shared/gate-failures.md`, `shared/agent-isolation.md`.

## Three things every brief restates

- **This repo is public.** Nothing in a commit, a branch name, an issue link or
  an image layer may carry anything the org policy keeps internal. Layers are
  world-readable and permanent.
- **The container ships no auth and serves a full desktop.**
  `CUSTOM_USER`/`PASSWORD` is a LAN measure, not a substitute for a proxy doing
  real authentication. Parallelism changes nothing about that, but any brief
  touching exposure should say it rather than assume it is known.
- **Never let a subagent push an image to a registry.** Publishing is the
  owner's call, and image layers are public and permanent. A subagent may build
  and boot as many images as it likes; pushing is not its decision to make.

`tracksProduction` is off, so merge is the end of the line — there is no deploy
step to serialise, and no batch needs to wait on one.
