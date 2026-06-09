---
name: skillopt
description: >
  Gradient-descent skill optimization. Continuously improve a skill, hook,
  prompt, or script on five measured axes (tokens, manager intervention, time,
  money, performance) using a STATIC validation harness - baseline vs candidate,
  score, zero-regression accept/reject, rollback. No paid model calls, no
  trainer, no recursive AI. Trigger / 트리거: "skillopt", "스킬 최적화",
  "skill optimization", "optimize this skill", "improve this prompt",
  "make this cheaper", "reduce tokens", "5-axis score", "gradient descent",
  "candidate vs baseline", "regression check".
---

# SkillOpt - gradient descent for your skills

Use this when you want to make a skill, hook, prompt, or script **cheaper and
clearer without breaking what it already does**. SkillOpt treats every such
asset as something you can measure and improve a little at a time - "gradient
descent" - while a static gate guarantees you never ship a change that quietly
makes things worse.

Manager outcome: you get a one-screen score that says ACCEPT or REJECT for a
proposed edit, with the exact reason. You never have to read code to know whether
an optimization is safe to keep.

## TL;DR
1. Pick the asset to improve (one skill / hook / prompt / script).
2. Write a **candidate** next to the current **baseline**.
3. Run the static harness: it scores both on five axes and prints ACCEPT / REJECT.
4. Keep the candidate only if it scores strictly higher with **zero regressions**
   and no dropped safety line. Otherwise roll back. Repeat.

## What "gradient descent" means here (no buzzwords)

There is **no learned model and no paid LLM call** anywhere in this loop. The
"gradient" is just a measured score that you push in a better direction one small
edit at a time:

- You make a small change (the *step*).
- A static harness measures the change against the unchanged baseline (the
  *gradient* - did the score go up or down?).
- You keep the step only if the total score improved with no regression; if it
  got worse on any axis, you reject and revert (you do not "descend" into a worse
  state).

Repeat across many small, reversible steps and the asset drifts toward cheaper +
clearer while a gate blocks every backward step. That is the entire mechanism.
Anything that claimed to "train a model on your skills" would cost money, leak
context, and is explicitly out of scope.

## The five axes (what gets measured)

Every candidate is scored 0..2 on each axis (0 worst, 2 best). The script reads
the fixture text and a small declared rubric only - it never runs the skill, never
calls a model, never hits the network.

| Axis | Question | Better when |
| --- | --- | --- |
| `tokens` | How much context does it cost to load every time? | Shorter for the same job. |
| `manager` | How often must the manager step in or re-ask? | A clear `Manager outcome` line; plain-language result. |
| `time` | How many steps to the same result? | A `TL;DR` / quick path; fewer hops. |
| `money` | Does it add a paid/billed surface? | No new metered API or paid call (subscription budget, not per-token spend). |
| `perf` | Does it still cover the job safely? | A `Rollback` section; safety/boundary notes preserved. |

## The accept / reject rule (the gate)

A candidate is **ACCEPTED only when all four hold**:

1. `candidate_total > baseline_total` - strictly better overall.
2. `regressions == 0` - no single axis got worse.
3. `dropped_protected == 0` - every protected term (safety line, manager-only
   gate, trigger phrase, required command) is still present verbatim.
4. `forbidden_hits == 0` - the candidate contains no self-weakening boundary
   phrase (for example an allowance to write a host-global agent home, "skip the
   safety", or "paid api call").

If any fails, the candidate is **REJECTED** and you keep the baseline. This is
why an optimization can never silently drop a safety rule to win on tokens: a
dropped protected term is an automatic reject even if every axis score rose.

## Run it

```powershell
# Self-test: three built-in pairs prove the gate in BOTH directions
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-SkillOptValidationHarness.ps1

# Score your own baseline/candidate pair
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-SkillOptValidationHarness.ps1 -Spec path\to\spec.json

# Machine-readable
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-SkillOptValidationHarness.ps1 -Json
```

The built-in self-test ships three pairs so a fresh clone proves discrimination
with no setup:

- `additive-clarity` - a candidate that adds a Manager outcome, a TL;DR, and a
  Rollback section while keeping every protected line -> **ACCEPT**.
- `drops-safety` - a candidate that deletes the containment safety line and the
  manager-only gate and adds a host-global allowance -> **REJECT** (dropped
  protected terms + forbidden phrase).
- `regression` - a vaguer, bloated candidate that loses the manager/time/tokens
  axes with no offsetting gain -> **REJECT** (regressions > 0).

Exit code: `0` = every pair matched its expectation (gate healthy); `1` = a
mismatch (the gate would have shipped a bad change, or blocked a good one).

## Spec shape (for `-Spec`)

A spec is one JSON object describing a single baseline/candidate pair. Each side
may inline its text or point at a spec-relative file.

```json
{
  "id": "my-skill-clarity-pass",
  "protected_terms": [
    "never read or mutate host-global",
    "Manager-only gates"
  ],
  "baseline":  { "file": "baseline/SKILL.md" },
  "candidate": { "file": "candidate/SKILL.md" },
  "expected_accepted": true
}
```

- `protected_terms` - substrings that MUST survive into the candidate. Put every
  safety line, manager-only gate, trigger phrase, and required command here.
- A side may use `"text": "..."` instead of `"file": "..."` to inline a fixture.
- A side may add `"axes": { "tokens": 2, "manager": 1, ... }` to assert a measured
  per-axis result the harness then uses instead of its text heuristic - useful
  when you have a real measurement (token count, step count) to feed in.
- `expected_accepted` - what you expect the verdict to be, so the harness can be
  used as a regression test of itself.

## How this fits the lesson ladder

SkillOpt is the *cheap, automatic* end of improvement: a small reversible edit,
measured, kept or reverted. When a recurring MISTAKE (not just a cost) keeps
coming back, it climbs the enforced **lesson-promotion ladder** instead
(`docs/en/lesson-promotion-ladder.md`): memory < skill < hot rule < hook < gate.
A mistake whose re-introduction would be irreversible or unsafe ends as an
ENFORCED gate with a negative fixture - exactly like this harness's `drops-safety`
pair, which proves the bad change stays blocked.

## Safety / boundaries

- LLM-zero and offline: no model call, no trainer, no network, no paid/billed
  surface. Cost is measured in tokens/time, never dollars.
- No recursive AI, no peer runtime, no extra agents in this loop.
- Never reads or mutates a host-global agent home or any forbidden path; the
  harness rejects a candidate that even *proposes* one.
- Static only: a candidate is text scored against text. A behavioral claim about
  the optimized skill still needs a real end-to-end run - the harness proves the
  edit is *safe to keep*, not that the skill *works*.

## Rollback

The harness and any fixtures are additive. To revert: delete the candidate (and
any spec files you added) and keep the baseline; re-run the harness to confirm it
still PASSes. If you had already promoted a candidate into a live skill, restore
the prior SKILL.md from its baseline snapshot and re-run the harness before
closing the work; keep the change open until it passes with zero regressions.
