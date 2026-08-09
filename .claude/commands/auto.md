---
description: Work an explicit list of OSNV issues back-to-back, autonomously — one PR each, split what's too big, log and skip what you can't decide.
---

Work **$ARGUMENTS** in the order given, one at a time, without stopping to ask.

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
