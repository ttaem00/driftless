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
2. **Trigger the next cycle when work FINISHES, not on a clock.** Prefer a **Stop
   hook** (settings.json) that fires the moment a task/turn ends and re-enters the
   loop immediately — "one task ends → next task starts now", not "wait N minutes".
   A Stop hook can return `{"decision":"block","reason":"...","additionalContext":"<next instruction>"}`
   to continue the conversation with the next gap as the instruction; there is NO
   built-in loop guard, so keep a small `.runtime` iteration counter and allow the
   stop once the backlog is genuinely converged. A time-based cron is only a
   *backup* re-entry for when the session is fully closed — not the primary trigger.
3. **Run a separate audit pass that catches drift** (driven by the same Stop-hook,
   e.g. every Nth iteration, or a low-frequency backup job) that does no feature
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
Trigger the next cycle the moment work FINISHES via a Stop hook (not a clock), and
run an audit pass (every Nth iteration) to catch context drift and optimistic
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
