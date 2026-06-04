---
name: mission-control
description: >
  Use when a non-developer student, maintainer, or manager gives one large goal
  and wants the main session to coordinate tickets, success criteria, child
  sessions, goal companions, evidence quality, validation, PR/merge, learning,
  and gradient optimization. 작업 관제 / mission control / main session control.
  Trigger / 트리거: "mission control", "work control", "작업 관제", "관제탑",
  "main session", "child sessions", "goal companion", "알아서 끝까지",
  "하위 세션", "목표동행", "경사하강 최적화".
---

# Mission Control

`mission-control` is the shared Driftless entrypoint for large work owned by one
main session. The main session becomes the control tower: it plans, dispatches,
monitors, arbitrates, validates, learns, and reports.

The user should not choose between git, GitHub, test commands, PR checks,
parallel workers, long-session companions, or overnight prompts. The user states
the outcome; the agent chooses the internal workflow and asks only for true
manager-only decisions.

## User Phrases

- "Use mission control. Handle this end-to-end."
- "Make the main session coordinate any child sessions and goal companions."
- "If this is long or risky, monitor it so it does not drift."
- "Collect the data, judge whether it is good data, learn from it, and improve
  the system."
- `작업 관제로 맡길게. 하위 세션, 목표동행, 검증, 학습, PR/merge까지 관제해줘.`

## Product Goal

Driftless exists so non-developer students and maintainers can apply practical
agent workflows without becoming toolchain operators.

The target UX:

- The user talks to one main session.
- The main session owns routine ticketing, criteria, branch, validation, review,
  PR, merge, and sync mechanics.
- Long or drift-prone work gets companion/checkpoint handling only when needed.
- Parallel or overnight work remains coordinated by the main session.
- Internal skill names are evidence details, not the user interface.
- Done requires evidence, not "a script exists" or "a note was written."

## Operating Modes

Do not ask the user to pick from this table. The agent applies it.

| Situation | Internal workflow |
|---|---|
| Goal or completion criteria are vague | `root-goal-check`, then `work-ledger` |
| Non-trivial repository work | `ticket-issue` before editing |
| Single task can be completed in one lane | `finish-to-done` |
| Long run, context pressure, resume risk | `handoff-guard` |
| Goal drift, early stop, missing evidence risk | `goal-pair-guardian` |
| Many independent work surfaces | `parallel-ticket-planner` |
| User asks to keep going while away | overnight/infinite-mode prompt for the current tool |
| External tool/repo adoption is proposed | `adopt-external-tool` |
| Security, secret, host-global, billing, release, destructive, or user-data risk | `safety-guard` |
| Before PR_READY, merge, close, release, or Done claim | `review-before-done` |
| User asks what happened or what to do next | `easy-briefing` |
| Repeated failure or system lesson | `learning-loop` |

Tool-specific launch mechanics stay in the tool profile. This skill may route
to a Claude workflow or Codex goal prompt, but it does not copy tool-specific
instructions into the shared tier.

## Control Tower Loop

For large work, follow this order:

1. Charter: restate the outcome, completion line, manager-only decisions, and
   safety boundaries.
2. Ticket: create or reuse a visible issue for non-trivial work.
3. Split: decide whether the work is a single lane, parallel plan, or overnight
   coordinator run.
4. Attach: add goal companion/checkpoint handling when drift, context, or Done
   honesty risk is high.
5. Dispatch: create child sessions or paste-ready worker prompts only when the
   work is separable.
6. Monitor: track worker heartbeat, blockers, checkpoints, and context pressure.
7. Arbitrate: inspect worker evidence. A worker saying "done" is not final Done.
8. Integrate: resolve conflicts, missing evidence, duplicate work, and weak data.
9. Validate: run tests, browser/user-path checks, PR checks, mergeability, and
   review gates as appropriate.
10. Learn: run Gradient Closeout before final report.
11. Report: explain user-visible result and next decision in plain language.

## Worker Contract

Child sessions are workers under the main session, not independent owners.

Every worker receives:

- goal;
- in-scope and out-of-scope boundaries;
- completion criteria;
- safety boundaries;
- evidence bundle shape;
- stop/return condition.

Workers must not:

- independently declare final Done;
- independently merge or sync main;
- ask the user to choose developer tools;
- overwrite another worker's result by assumption;
- claim data quality without evidence.

Worker return shape:

```markdown
worker result:
- scope:
- changed:
- evidence:
- blocked:
- conflicts:
- recommended next:
```

## Evidence Quality

For data collection, the main session must judge whether the data is good enough
for the decision.

Before collecting:

- define the question the data must answer;
- separate allowed and forbidden sources;
- check freshness, representativeness, bias, duplicates, permission, and cost.

After collecting:

- record source, query/command, timestamp, and sample size;
- judge sufficiency, reliability, reproducibility, missingness, and conflicts;
- mark ambiguous data `UNVERIFIED`;
- promote useful repeated lessons through `learning-loop`.

"Lots of data" is not the same as good data.

## Manager Review Queue Discipline

CHZZ real-use lesson, generalized: a user-facing review or approval queue should
show only items the user can safely and meaningfully approve for the current
purpose. Do not present debug rows, no-go/negative rows, uncertain candidates,
automatic failure evidence, or source-only candidates as normal approve cards.

- User can approve: safe, bounded, purpose-fit candidates only.
- Quarantine/debug: failures, no-go, negative, uncertain, source-only, and
  evidence-gathering rows.
- Keep counts separate: user-accepted, auto-verified, provisional,
  rejected/negative, and uncertain/debug are not the same evidence tier.
- `review-needed` is not a scalable completion state. Either continue an
  automated verification/quarantine path or leave an open follow-up with a retry
  condition.

## Gradient Closeout

Every mission-control run ends with a small optimization pass. This is not
uncontrolled self-modification. It means the agent should, within repo-local
safe boundaries, reduce future time, token use, cost/usage, manager
intervention, and repeated mistakes without waiting for the user to request it.

Measure these axes:

| Axis | Question |
|---|---|
| Manager intervention | Did the user do toolchain work the agent should own? |
| Time | Was a delay caused by a repeatable process gap? |
| Tokens | Did repeated explanation, raw logs, or bloated context waste tokens? |
| Cost/usage | Were unnecessary sessions, CI, browser runs, APIs, or resources used? |
| Quality | Was output, data quality, or verification weak? |
| Recurrence | Can the same failure be automatically prevented next time? |
| Safety | Did secret, credential, host-global, billing, release, or destructive gates wobble? |

Choose the cheapest improvement surface:

1. script/test/gate for repeated checks and bug classes;
2. prompt/template for repeated input shape;
3. skill for conditional workflow;
4. hook for prompt-time automatic detection;
5. hot rule only for tiny always-needed rules;
6. docs for user understanding and public-safe explanation;
7. this skill when the control loop itself is missing a rule.

Promotion rules:

- one-off low-risk issue: record only;
- repeated issue or manager intervention: `learning-loop`;
- safe repo-local fix: create/update issue, patch, validate, PR/merge;
- hot rule, hook, or global prompt change: placement review first;
- long prose: compress if safe;
- public-safe lesson: keep it in the shared tier.

## Ask The User Only For

- Product direction, priority, or scope tradeoff.
- Login, OAuth, credential entry, or permission approval.
- Paid billing, quota, or paid resource use.
- Public release or external publication.
- Destructive or irreversible action.
- Host-global profile promotion.
- User data transfer.
- Force-push, history rewrite, or data deletion.

Do not ask the user to choose branch names, test commands, PR mechanics,
mergeability checks, worker prompt design, or which Driftless skill to use.

## Final Report Shape

Use the shared report labels and keep the first line user-facing:

```markdown
built/inspected:
- <what changed in user-visible terms>

tested/evidence:
- <commands, checks, browser proof, PR/merge evidence>

manager run/paste:
- <0-2 user actions, or "none">

blocked/unverified:
- <none, or exact manager-only / hard-external blocker>

gradient closeout:
- intervention:
- time:
- tokens:
- cost/usage:
- quality:
- recurrence:
- optimization applied:
- follow-up:
```

End with the applicable completion signal from the selected workflow.
