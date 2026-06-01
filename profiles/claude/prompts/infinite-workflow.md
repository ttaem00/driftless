# Claude infinite maintainer loop — workflow + schedule (paste-ready)

This is the **Claude** counterpart of the Codex `goal` infinite loop
([codex/prompts/infinite-goal.md](../../codex/prompts/infinite-goal.md)). Same
outcome, different mechanism: Codex runs a long `goal`; **Claude runs it with
dynamic workflow orchestration + a scheduled re-trigger**, because a conversational
agent goes idle when its turn ends and does not restart itself.

> The shared rules, success criteria, and gates are identical — one source drives
> both profiles. Only the *driving mechanism* differs per tool.

## The loop, the Claude way

1. **Orchestrate cycles with the Workflow tool, not by hand.** One Workflow call
   runs many cycles in the background (find the highest-value gap → ticket →
   branch → implement → gates → PR → merge → next), independent of any single
   reply ending. That is what keeps it going after a turn finishes.
2. **Schedule a re-trigger.** Add a recurring (cron-style) job that re-enters the
   loop on an interval and re-reads the mission + rules, so the loop survives turn
   end and session boundaries.
3. **Run a separate audit pass on a short interval** (~15 min) that does no feature
   work — it re-reads the mission, checks recent work still serves the goal, checks
   every "done/PASS" has real gate/command evidence (no optimistic reporting), and
   confirms main is clean with no PR hanging. Long autonomous runs get
   auto-compacted and drift; the audit steers them back. See the audit-worker
   discipline in `skills/overnight-autonomous-work/SKILL.md`.
4. **Leave a resume note + next ticket every cycle** so a fresh session continues
   exactly where the last stopped.

## Paste this to Claude (in the repo you want maintained)

```text
Run this repo's infinite maintainer loop. Use the Workflow tool to run cycles in
the background (don't hand-crank them, and don't stop to ask after each unit).
Each cycle: survey open issues, pick the highest-value gap (no reinventing what
exists), ticket -> branch -> implement -> run the safety gates (containment,
text-safety, mirror-parity) -> PR -> merge only on green. Improve at least one of:
onboarding / trust / Codex+Claude applicability / non-dev ease / tokens-time-
money-intervention / recurring-mistake prevention / security / reach per cycle.
Also schedule a short-interval audit pass to catch context drift and optimistic
reporting. Only pause for a human decision on: product/priority, credentials,
money, public release, destructive/irreversible actions, host-global promotion,
user-data moves, or force-push/history rewrite. Evidence honesty: a static change
is UNVERIFIED until a gate/run proves it. Containment: never touch host-global
agent config or secrets. Leave a resume note + next ticket each cycle.
```

## Why both files exist

Driftless is for **both** Codex and Claude. A Codex user gets the same continuous
maintenance via `goal`; a Claude user gets it via workflow + schedule. Neither is
a translation of the other — each plays to its tool's strength — but they share
one set of rules, gates, and success criteria (the single-source mirror).
