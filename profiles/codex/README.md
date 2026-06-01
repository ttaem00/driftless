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

## What this profile consumes

This profile consumes **all** of the shared skills under `../shared/skills/` by
relative path — they are authored once and run identically here and in the Claude
profile:

- `../shared/skills/finish-to-done/`
- `../shared/skills/root-goal-check/`
- `../shared/skills/easy-briefing/`
- `../shared/skills/parallel-ticket-planner/`
- `../shared/skills/ticket-issue/`
- `../shared/skills/learning-loop/`

On top of those, this profile adds its **own tool-specific skills** that only make
sense for Codex and are never mirrored into Claude:

- `goal-mode` — Codex-only goal-mode run prompt / driving paradigm.

Editing a shared skill once updates this profile and the Claude profile together;
the `goal-mode` skill stays Codex-only by design.

## It never touches host-global config

This profile runs entirely against its repo-local isolated home via `CODEX_HOME`.
It **never** reads or mutates host-global `~/.codex`, and it never touches
`~/.claude` either. The containment guard consumes
`../shared/schemas/forbidden-paths.json` and must pass before any work is reported
done. Touching host-global config is a manager-only gate (see
`../shared/contract/SHARED_DESIGN_CONTRACT.md`, section 3).


## Continuous (infinite) maintainer loop

See [infinite-goal (Codex goal-mode continuous loop)](./prompts/infinite-goal.md) for the paste-ready way to run this profile as a long, self-improving maintainer loop. Codex and Claude reach it differently (goal vs workflow+schedule) but share one set of rules, gates, and success criteria.
