# Shared tier

This is the **shared tier** of Driftless. It holds everything that is *not*
specific to one AI tool: the design contract, the machine-readable safety
schemas, and the tool-agnostic skills. Both the Claude profile and the Codex
profile read these same files through repo-relative paths.

## The canonical model

> **One repo, two in-repo profiles, a repo-root shared tier consumed by both.**

```
driftless/
├── profiles/
│   ├── shared/          <- this tier (tool-agnostic; the single source)
│   │   ├── contract/    <- SHARED_DESIGN_CONTRACT.md (vocabulary + rules)
│   │   ├── schemas/     <- forbidden-paths.json and other machine-readable rules
│   │   └── skills/      <- tool-agnostic skills consumed by both profiles
│   ├── claude/          <- Claude Code profile (built from shared + Claude-specific)
│   └── codex/           <- Codex profile (built from shared + Codex-specific)
```

A built profile is **shared + tool-specific**. The shared tier is the part that
is identical for both tools; each tool profile adds only what is genuinely
different (launcher mechanics, hot-rules filename, model defaults, skill format).

## Why a shared tier exists

The whole point of Driftless is that the two tool profiles **never drift apart**.
If a safety rule, an evidence vocabulary, or a tool-agnostic skill lived in two
places, the two copies would slowly diverge and the profiles would become
incompatible. Instead, anything that should be the same for both tools lives here
**once**. Both profiles consume it by relative path.

That gives the load-bearing property:

> **One edit here improves BOTH profiles at the same time.**

Change a forbidden path in `schemas/forbidden-paths.json`, tighten a manager-only
gate in `contract/SHARED_DESIGN_CONTRACT.md`, or fix a tool-agnostic skill — and
both the Claude profile and the Codex profile pick up the change with no copying,
no mirroring, and no external sync step.

## What lives here

| Folder | Contents | Consumed by |
|---|---|---|
| `contract/` | `SHARED_DESIGN_CONTRACT.md` — evidence statuses, the four manager report labels, manager-only gates, and the run-status enum. | both profiles |
| `schemas/` | `forbidden-paths.json` — the machine-readable list of paths and secret patterns the containment guard must never touch or leak. | both profiles' containment guards |
| `skills/` | Tool-agnostic skills (one folder each) that behave the same regardless of which AI runs them. | both profiles |

### Shared skills present under `skills/`

These tool-agnostic skills live here **once** and are consumed by both the Claude
profile and the Codex profile:

- `finish-to-done/` — drive a task investigate -> fix -> verify -> done, with evidence.
- `root-goal-check/` — gate new info/ideas against the project's core goal before adopting.
- `easy-briefing/` — explain the current situation to a non-developer manager in plain language.
- `parallel-ticket-planner/` — split remaining work into low-conflict parallel tickets.
- `ticket-issue/` — the issue-before-edit gate for non-trivial repo work.
- `learning-loop/` — record recurring problems and promote only the proven ones into rules.

**Edit one of these once and both profiles get it.** Because each profile consumes
`skills/` by relative path (`../shared/skills/<name>/`), a single edit to any skill
above updates the Claude profile and the Codex profile at the same time — no
copying, no mirroring, no sync step.

## What does NOT live here

Anything that is legitimately different between the two tools stays in the
tool-specific profile, not here:

- Launcher mechanics (`CLAUDE_CONFIG_DIR` vs `CODEX_HOME`).
- The hot-rules filename (`CLAUDE.md` for Claude, `AGENTS.md` for Codex).
- Skill format details, model defaults, and effort levels.

When a rule or lesson is only proven for one tool, it belongs to that tool's
profile. It is promoted into the shared tier only after it is shown to be
genuinely tool-agnostic.

## The change rule

When you edit anything in this tier, you are editing the single source for both
profiles. Make the change here once; do not copy it into either profile. The
profiles reference the shared files by relative path, so the change reflects in
both automatically.
