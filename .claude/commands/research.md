---
description: Research a question or OSNV issue, then record findings back on the issue.
---

Research **$ARGUMENTS** and write the answer down where it will be found.

- Questions about **what OrcaSlicer ships** are answered by the release API, not
  from memory: `https://api.github.com/repos/OrcaSlicer/OrcaSlicer/releases/latest`
  (or `/tags/<version>` for a specific one). Asset names carry the arch and the
  Ubuntu build target and have changed shape before — quote the actual name.
  The project moved org from `SoftFever`; the old path 301s.
- Questions about **what the base image provides** are answered by
  `linuxserver/docker-orcaslicer`'s current `Dockerfile` and by the selkies
  baseimage repo — fetch them with `gh api`, since raw URLs 404 on a `main`
  branch that is actually called `master`.
- Questions about **what is in our image** are answered by running it:
  `docker run --rm orcaslicer-novnc:latest <cmd>`. What the Dockerfile appears
  to install and what survived the cleanup step are different questions.
- Record the outcome on the issue **either way** — a premise confirmed is worth
  as much as one refuted.
- Anything durable belongs in `AGENTS.md`, the README, or `local/gates.md`, in
  the same change.

This repo is public: never put an internal hostname, LAN address, token or
anything else the org keeps internal into an issue, a commit or a workflow file.
