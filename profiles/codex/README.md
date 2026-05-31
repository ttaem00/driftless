# Codex profile

This is the **materialized Codex profile** — the isolated home that Codex runs
against in Driftless.

## What it is

When the launcher starts Codex, it points `CODEX_HOME` at a **repo-local isolated
home** instead of the host-global `~/.codex`. That home holds Codex's hot rules
(`AGENTS.md`), its skills, its hooks, and its prompts. Because the config home is
repo-local, every session is contained to this repository and leaves your
machine's global Codex config untouched.

## Built from shared + Codex-specific

This profile is **not** authored as one monolith. It is materialized from two
inputs:

1. **The shared tier** (`../shared/`): the design contract, the
   `forbidden-paths.json` schema, and the tool-agnostic skills. These are
   consumed by relative path, so an edit in the shared tier improves this profile
   and the Claude profile at the same time.
2. **Codex-specific parts**: the `AGENTS.md` hot-rules filename, Codex skill
   format, codex-profile hooks, `prompts/`, and Codex model/effort defaults.

The materialized profile is the combination of the two. Keep shared rules in the
shared tier; keep only genuinely Codex-specific things here.

## It never touches host-global config

This profile runs entirely against its repo-local isolated home via `CODEX_HOME`.
It **never** reads or mutates host-global `~/.codex`, and it never touches
`~/.claude` either. The containment guard consumes
`../shared/schemas/forbidden-paths.json` and must pass before any work is reported
done. Touching host-global config is a manager-only gate (see
`../shared/contract/SHARED_DESIGN_CONTRACT.md`, section 3).
