# CLAUDE.md

Entry point for Claude Code, and **load-bearing** — measured 2026-08-14 on
Claude Code 2.1.232, a project-root `AGENTS.md` with no `CLAUDE.md` is not
discovered. Shrink this file, never delete it. The project conventions live in
**AGENTS.md**, imported below so they load every session.

@AGENTS.md

On-demand references — open the relevant one when the work matches:

- [`.agents/gates.md`](.agents/gates.md) — the exact gate command, what each
  step is actually worth, and the traps that make a green run mean less than it
  looks. Named by [`.agents/repo.json`](.agents/repo.json) as `gatesDoc`.
- The `pr-hygiene`, `gate-failures` and `agent-isolation` **skills** come from
  the userspace bundle (`runnane/agent-userspace`) and load on their own; the
  copies that used to sit in `.claude/commands/shared/` were deleted by OSNV-6.

Three things worth loading into your head before touching this repo:

1. **A cached `docker build` proves almost nothing.** Every failure that
   matters — a moved release, a renamed asset, a dropped Debian package — lives
   in the single `RUN` layer, and Docker caches it wholesale. A green build
   after a README edit re-ran none of it. Use `--no-cache --pull` before
   drawing conclusions about upstream, and budget ~15 minutes.
2. **The name is not the transport.** "noVNC" is the repo name; the actual
   transport is selkies. Do not "fix" the code to match the name.
3. **This repo is public.** No portal hostname, LAN address, token or internal
   detail in a commit, an issue, a workflow or an image layer — all of which
   are permanent and world-readable.
