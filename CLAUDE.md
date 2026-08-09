# CLAUDE.md

Entry point for Claude Code. The project conventions live in **AGENTS.md**,
imported below so they load every session.

@AGENTS.md

On-demand references — open the relevant one when the work matches:

- `.claude/commands/local/gates.md` — the exact gate command, what each step is
  actually worth, and the traps that make a green run mean less than it looks.
- `.claude/commands/shared/pr-hygiene.md` — branch/PR/tracker rules.
- `.claude/commands/shared/gate-failures.md` — what to do when a gate goes red.
- `.claude/commands/shared/agent-isolation.md` — one checkout one agent; commit
  only where you were invoked.

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
