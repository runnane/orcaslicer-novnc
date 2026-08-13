---
description: Plan an OSNV issue — read it, check the premise against upstream, propose an implementation plan, record it on the issue.
---

Plan **$ARGUMENTS**. Do not implement.

1. Read the issue in full (`include: ["comments","links","attachments"]`).
2. Explore what would change. That is a short list: the `Dockerfile`, the files
   under `root/` that get copied into the image, `compose.yml`, the CI workflow,
   or the docs. There is no application source.
3. **Settle any claim about upstream against upstream**, not by inference:
   - the release API (`OrcaSlicer/OrcaSlicer`, not `SoftFever`) for what ships,
     for which arch, under what asset name;
   - `linuxserver/docker-orcaslicer`'s current `Dockerfile` for what the base
     image expects — it is a moving target and has already changed base once;
   - the built image itself (`docker run --rm ... `) for what is actually there.

   Cite what you read. Plans in this repo go wrong by assuming an asset name or
   a package name that changed.
4. Propose the change: which build args, which layer, and **how it will be
   verified in the failing direction** — a resolve-block change can be exercised
   against an existing image in seconds, but anything touching packages or
   extraction needs a real `--no-cache` build, so say which and budget ~15
   minutes for the latter.
5. Note whether it is arm64-affecting. Since OSNV-4 nothing builds arm64 —
   not the gates, not CI — so an arm64-only change cannot be verified anywhere
   short of an arm machine. Say so in the plan rather than implying CI covers it.
6. Record the plan as a comment on the issue.

Call out explicitly if the work would change the **security posture** (auth,
exposed ports, what the desktop session can reach) or put anything internal into
a public repo.
