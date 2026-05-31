# Claude profile

This is the **materialized Claude Code profile** — the isolated home that Claude
Code runs against in Driftless.

## What it is

When the launcher starts Claude Code, it points `CLAUDE_CONFIG_DIR` at a
**repo-local isolated home** instead of the host-global `~/.claude`. That home
holds Claude's hot rules (`CLAUDE.md`), its skills, its hooks (`settings.json`),
and its slash commands. Because the config home is repo-local, every session is
contained to this repository and leaves your machine's global Claude config
untouched.

## Built from shared + Claude-specific

This profile is **not** authored as one monolith. It is materialized from two
inputs:

1. **The shared tier** (`../shared/`): the design contract, the
   `forbidden-paths.json` schema, and the tool-agnostic skills. These are
   consumed by relative path, so an edit in the shared tier improves this profile
   and the Codex profile at the same time.
2. **Claude-specific parts**: the `CLAUDE.md` hot-rules filename, Claude skill
   format, `settings.json` hooks, `.claude/commands/` slash commands, and Claude
   model/effort defaults.

The materialized profile is the combination of the two. Keep shared rules in the
shared tier; keep only genuinely Claude-specific things here.

## It never touches host-global config

This profile runs entirely against its repo-local isolated home via
`CLAUDE_CONFIG_DIR`. It **never** reads or mutates host-global `~/.claude`, and it
never touches `~/.codex` either. The containment guard consumes
`../shared/schemas/forbidden-paths.json` and must pass before any work is reported
done. Touching host-global config is a manager-only gate (see
`../shared/contract/SHARED_DESIGN_CONTRACT.md`, section 3).
