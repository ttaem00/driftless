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

## What this profile consumes

This profile consumes **all** of the shared skills under `../shared/skills/` by
relative path — they are authored once and run identically here and in the Codex
profile:

- `../shared/skills/finish-to-done/`
- `../shared/skills/root-goal-check/`
- `../shared/skills/easy-briefing/`
- `../shared/skills/parallel-ticket-planner/`
- `../shared/skills/mission-control/`
- `../shared/skills/ticket-issue/`
- `../shared/skills/learning-loop/`
- `../shared/skills/goal-pair-guardian/`
- `../shared/skills/apply-driftless/`
- `../shared/skills/adopt-external-tool/`
- `../shared/skills/safety-guard/`
- `../shared/skills/review-before-done/`
- `../shared/skills/work-ledger/`
- `../shared/skills/handoff-guard/`

On top of those, this profile adds its **own tool-specific skills** that only make
sense for Claude Code and are never mirrored into Codex:

- `ultracode-orchestration` — Claude-only multi-agent / Workflow orchestration.

Editing a shared skill once updates this profile and the Codex profile together;
the `ultracode-orchestration` skill stays Claude-only by design.

## It never touches host-global config

This profile runs entirely against its repo-local isolated home via
`CLAUDE_CONFIG_DIR`. It **never** reads or mutates host-global `~/.claude`, and it
never touches `~/.codex` either. The containment guard consumes
`../shared/schemas/forbidden-paths.json` and must pass before any work is reported
done. Touching host-global config is a manager-only gate (see
`../shared/contract/SHARED_DESIGN_CONTRACT.md`, section 3).


## Continuous (infinite) maintainer loop

See [infinite-workflow (Claude workflow+schedule loop)](./prompts/infinite-workflow.md) for the paste-ready way to run this profile as a long, self-improving maintainer loop. Codex and Claude reach it differently (goal vs workflow+schedule) but share one set of rules, gates, and success criteria.
