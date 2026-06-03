---
name: student-autopilot
description: >
  Use when a non-developer student, maintainer, or manager asks the agent to
  handle work end-to-end without making them choose git, GitHub, test,
  PR, merge, long-session, parallel-ticket, or overnight mechanics. 학생용 /
  비개발자 / 알아서 해줘 / 끝까지 처리 / git/GitHub는 네가 / student autopilot.
  Trigger / 트리거: "student autopilot", "non-developer", "학생용", "비개발자",
  "알아서 해줘", "끝까지 처리", "나는 개발자가 아니", "git/GitHub는 네가",
  "manager only decisions".
---

# Student Autopilot

`student-autopilot` is the shared Driftless entrypoint for non-developer users.
Its job is to hide toolchain choices behind one plain-language workflow.

The user should not have to choose between skills, branches, raw git commands,
test commands, PR checks, long-session companions, parallel workers, or
overnight prompts. The user states the desired outcome; the agent chooses the
internal workflow and asks only for real manager-only decisions.

## User Phrases

- "Handle this end-to-end. I am not a developer."
- "Use student autopilot. Do the git/GitHub/test/PR/merge mechanics for me."
- "If this is long or risky, monitor it so it does not drift."
- "Make this usable for non-developer students."
- "Run the remaining work while I am away, but keep the main session in charge."
- `학생용으로 알아서 끝까지 처리해줘.`
- `나는 개발자가 아니니까 내가 진짜 결정해야 하는 것만 물어봐.`

## Product Goal

Driftless is not trying to teach non-developer students how to operate an agent
toolchain. Driftless should let them apply practical agent workflows without
becoming the toolchain operator.

The target UX:

- The user talks to one main session.
- The agent owns routine ticketing, branch, validation, review, PR, merge, and
  sync mechanics.
- Long or drift-prone work gets a companion/checkpoint flow only when needed.
- Parallel or overnight work is planned by the agent, not pushed as raw chores.
- Internal skill names are evidence details, not the main user interface.
- Done requires evidence, not "a script exists" or "a note was written."

## User-Visible States

Prefer four plain states in reports:

- `In progress`: the agent can keep working.
- `Needs decision`: the user must choose product meaning, scope, permission, or
  release direction.
- `Blocked`: a credential, billing, public release, destructive action,
  host-global change, or hard external dependency stops progress.
- `Done`: implementation, validation, review, PR/merge/sync, or the stated
  completion line is complete.

For manager-facing reports, start with the shared report labels from the design
contract:

```markdown
built/inspected:
tested/evidence:
manager run/paste:
blocked/unverified:
```

## Internal Routing

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

## Main Session Rule

Default to one main control session.

1. Restate the user's outcome and completion line in plain language.
2. Decide whether this is a simple lane, long lane, parallel plan, or overnight
   plan.
3. Keep user decisions in the main session.
4. Use companion/worker sessions only when the work is long, drift-prone, or
   cleanly separable.
5. Keep merge/Done authority in the main session or the documented coordinator,
   not in an unattended worker.
6. If worker prompts are needed, make them fallback artifacts. Do not make the
   user design the worker system.

## Ask The User Only For

- Product direction, priority, or scope tradeoff.
- Login, OAuth, credential entry, or permission approval.
- Paid billing, quota, or paid resource use.
- Public release or external publication.
- Destructive or irreversible action.
- Host-global profile promotion.
- User data transfer.
- Force-push, history rewrite, or data deletion.

Do not ask the user to choose:

- branch names;
- git status/fetch/commit/push commands;
- test commands;
- PR creation mechanics;
- mergeability checks;
- raw review-thread/comment inspection;
- local repair scripts;
- hidden config toggles;
- which Driftless skill to use.

## Workflow

1. Translate the user's words into a product outcome.
2. State root intent: what must be visible to the user, what must not stay hidden
   as raw scripts or internal experiments, and what decision is truly
   user-owned.
3. If repository work is non-trivial, use `ticket-issue`.
4. Create or reuse visible completion criteria with `work-ledger` when the
   finish line is not obvious.
5. Route internally using the table above.
6. Execute, validate, review, and sync according to the selected workflow.
7. If a manager-only gate appears, ask one short question.
8. Report in plain language first; keep raw commands and file paths as evidence
   lines below the summary.

## UX Quality Bar

Good:

- The user can say one sentence and the agent chooses the workflow.
- The user sees status, evidence, and next decision without reading raw logs.
- Long sessions keep a compact state and do not lose the original goal.
- Parallel/overnight work remains coordinated.
- Done is backed by validation or an honest blocker.

Bad:

- The agent dumps a skill menu on the user.
- The user must inspect GitHub checks to know whether work is ready.
- "A script exists" is treated as a user-ready feature.
- Worker sessions finish independently and the main session loses state.
- A public-safe lesson is proven in one runtime but never evaluated for the
  shared tier.

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
```

End with the applicable completion signal from the selected workflow.
