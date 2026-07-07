---
name: mission-control
description: >
  Use when a non-developer student, maintainer, or manager gives one large goal
  and wants the main session to coordinate tickets, success criteria, child
  sessions, goal companions, evidence quality, validation, PR/merge, learning,
  and gradient optimization. 작업 관제 / mission control / main session control.
  Trigger / 트리거: "mission control", "work control", "작업 관제", "관제탑",
  "main session", "child sessions", "goal companion", "알아서 끝까지",
  "하위 세션", "목표동행", "학생용", "비개발자", "나는 개발자가 아니니까",
  "git/GitHub는 네가", "경사하강 최적화".
---
## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Generalize as principle-based guidance or design principles; avoid spec/case overfitting and special-casing unless evidence proves a bounded exception reduces user effort, maintainer effort, maintenance risk, or safety burden.
# Mission Control

`mission-control` is the shared Driftless entrypoint for large work owned by one
main session. The main session becomes the control tower: it plans, dispatches,
monitors, arbitrates, validates, learns, and reports.

Non-developer student/manager autopilot is not a separate shared workflow. Route
that UX to `mission-control` so one top-level skill owns the interaction
boundary and the tool profile owns launch mechanics.

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
- One user goal becomes an atomic work graph: the coordinator decomposes the
  goal into small lanes, retrieves the right existing skill/script/profile
  surface for each lane, and composes the lanes into a dependency-aware plan
  before launching or asking for help.
- Every worker/session knows its role, parent coordinator, allowed write
  surface, evidence contract, and any child-role boundary before it starts.
- Worker/session results roll up to one manager-facing interface, not several
  disconnected chats. The user should be able to understand state from one main
  session, work ledger, dashboard, or equivalent product surface.
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
| Large, unclear, current-state-dependent, or externally referenced goal before planning | `intake-preflight` |
| Goal or completion criteria are vague | `root-goal-check`, then `work-ledger` |
| Non-simple product, feature, extension, architecture, or verification goal | Epic Preparation mode |
| User asks for mission control, epic/child tickets, proof experiments, plan sessions, or goal companion | Epic Preparation mode |
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

## Orphanless Mission Contract

Use this public-safe contract when a goal spans multiple sessions, tools,
profiles, workers, or tickets. It adapts the Orphanless/SkillWeaver lesson
without importing a private runtime or bespoke framework.

1. **Decompose atomically.** Split the manager goal into lanes that each have one
   owner, one write surface, one acceptance condition, and one evidence path.
   Use `Outcome -> Proof -> Slice -> Task -> Evidence`: the proof is the atom;
   tasks only produce the proof.
2. **Retrieve existing surfaces first.** Before inventing a new worker prompt,
   check whether an existing Driftless skill, script, gate, profile rule,
   prompt, or plugin-like integration already owns that lane.
3. **Compose a role graph.** Record coordinator, worker, reviewer, guardian, and
   child-session relationships. A worker can define child roles only inside the
   boundary assigned by the coordinator.
4. **Keep one manager interface.** Parallel sessions may exist internally, but
   their state must roll up to the coordinator and one manager-visible ledger or
   dashboard-style surface. Do not make the non-developer user inspect multiple
   raw chats, branches, logs, or PR pages to understand progress.
5. **Close through the parent.** A worker result is evidence, not Done. Parent
   Done requires adoption, validation, learning, and cleanup by the coordinator.

This is a product/UX principle, not a private-runtime-only implementation detail: the
portable idea is "single user goal -> atomic lanes -> role-aware sessions -> one
manager-visible state surface".

## Atomic Proof Planning

Use `docs/en/atomic-proof-planning.md` whenever a
mission-control request asks for child sessions, tickets, broad implementation,
blocked work recovery, or proof-based Done.

The coordinator first writes the user outcome, then creates proof atoms. Each
proof atom must be independent, valuable, testable, small, observable,
rollbackable, and single-purpose before a worker receives it.

If validation is expected to exceed 180 seconds, mission-control treats it as a
parent validation proof, not one foreground gate. Split it into atomic validation lanes
with one command/procedure, one owner, one expected result, one durable evidence
artifact, elapsed-time evidence, blocker classification, and a next action.
Parent validation closes only after every required lane passes or is explicitly
classified as blocked, rejected, watched, waived, or not-Done with evidence.

When a proof atom blocks, run **Blocked Atom Fission** instead of hiding it in a
"later" bucket:

1. keep the parent proof open;
2. classify the blocker class;
3. state the proof gap;
4. create child proof atoms for the missing reproduction, diagnosis, decision,
   dependency, verification, fix, or guardrail;
5. adopt the child proof evidence back into the parent before Done.

Agent-solvable blockers stay with the agent loop. Human escalation is limited
to product priority, credentials, payment, public release, destructive action,
private data movement, host-global promotion, force push/history rewrite, or a
truth/content judgment only the maintainer can make.

## One-Skill Bootstrap

If the maintainer invokes only `mission-control` or another Orphanless-style
entry skill, bootstrap the control surface before reporting next work. Do not
assume a prepared APDM board, status file, guardian, worker ledger, or dashboard
already exists.

The first coordinator loop must:

1. identify the maintainer entry point, repository root, and requested outcome;
2. discover existing proof surfaces, owner rows, issue/PR links, status files,
   dashboards, guardian/monitor records, and active worker lanes;
3. create a minimal repo-local proof/control surface when none exists and local
   writes are allowed;
4. recover existing worker or lane results before issuing duplicate work;
5. reconcile each unsatisfied proof by executing it in the parent, assigning a
   real owner, splitting the blocked atom, or recording a true human-only
   decision;
6. run the narrowest available gate and leave a durable status artifact.

Do not end with a bare `next action`, prompt, plan, or handoff while an
agent-solvable proof remains. If the platform cannot issue workers, write
status, or run the gate, classify that as a tooling/environment blocker and
assign the recovery proof.

## Model And Judgment Routing

Use lightweight workers, lower-effort lanes, or separate sessions only for
bounded evidence and execution: file scans, small patches, UI/test runs, source
summaries, and contained probes. They must not be the sole final judge for
decisions that require understanding both the current system and the target
system.

Keep high-judgment decisions in the lead/coordinator or another high-quality
synthesis lane:

- architecture, runtime dependency, and multi-worker/process model choices;
- credential, secret, host-global, browser-profile, cloud, billing, and other
  security boundaries;
- external adoption verdicts, post-pilot decisions, release/merge/readiness
  calls, irreversible/destructive actions, and public-safe propagation;
- conflicts between worker reports, scope reductions, or manager-facing final
  recommendations.

Worker output for those lanes is evidence only. Before closeout, the
lead/coordinator must re-synthesize it with explicit `Observed locally`,
`Observed upstream`, `Inferred`, and `UNVERIFIED` boundaries. If the coordinator
cannot do that in the current context, checkpoint and continue in a fresh
coordinator lane instead of accepting the worker verdict.

## Worker Failure Recovery

Before Done, PR-ready, adoption, or public-safe propagation, verify every worker,
guardian, and fallback artifact. Classify each lane as `COMPLETE`,
`PARTIAL_RETRY_REQUIRED`, `MODEL_CAPACITY_RETRY`, `CONTEXT_ROLLOVER_RETRY`,
`FAILED`, or `BLOCKED`.

Model-capacity, service-unavailable, context-window, missing-closeout, and
partial-output failures are recovery states, not completion. The coordinator
must preserve compact evidence, retry reversible work through a fresh
context/fallback route, and keep a `worker_recovery_inventory`. Nonzero
`MODEL_CAPACITY_RETRY`, `CONTEXT_ROLLOVER_RETRY`, `PARTIAL_RETRY_REQUIRED`, or
agent-solvable `FAILED` blocks final Done until retried, completed, or converted
to an explicit not-Done tracker with the next retry condition.

## Parent Closeout Boundary

Large-goal closeout is a parent decision, not a child-ticket echo. A child issue,
PR, probe, or helper merge can be `MERGED_DONE` while the parent remains open.
Before claiming the parent is Done, mission control keeps a
`parent_closeout_inventory` with every requested lane, linked issue or PR,
current state, command evidence, and closeout state. Parent Done requires all
lanes to be merged/main-synced, rejected with evidence, watched with a trigger,
or left as an explicit not-Done tracker with the next retry condition.

Long or quiet commands are `long_command_evidence`, not a blank screen to infer
from. If a command can outlive the caller timeout, the coordinator records the
process id or log path, polls one owner run, adopts existing output when present,
and does not start a competing validation loop. Empty output, caller timeout, or
missing log tail is `UNVERIFIED` until the process is observed complete and its
result is captured.

## Control Tower Loop

For large work, follow this order:

1. Charter: restate the outcome, completion line, manager-only decisions, and
   safety boundaries.
2. Epic Preparation: for non-simple product, feature, extension, architecture,
   or verification work, run Epic Preparation Mode before implementation.
3. Ticket: create or reuse a visible issue for non-trivial work.
4. Split: decide whether the work is a single lane, parallel plan, or overnight
   coordinator run.
5. Attach: add goal companion/checkpoint handling when drift, context, or Done
   honesty risk is high.
6. Dispatch: create child sessions or paste-ready worker prompts only when the
   work is separable.
7. Monitor: track worker heartbeat, blockers, checkpoints, and context pressure.
8. Arbitrate: inspect worker evidence. A worker saying "done" is not final Done.
9. Integrate: resolve conflicts, missing evidence, duplicate work, and weak data.
10. Validate: run tests, browser/user-path checks, PR checks, mergeability, and
   review gates as appropriate.
11. Learn: run Gradient Closeout before final report.
12. Report: explain user-visible result and next decision in plain language.

## Epic Preparation Mode

This mode is mandatory when the user asks for mission control, an epic, child
tickets, end-to-end preparation, experiments/proof, plan sessions, or goal
companion handling. Also use it for non-simple product, feature, extension,
architecture, or verification goals even when the user does not name those
mechanics.

The main session must prepare the epic before implementation starts:

- Write a one-sentence charter for the parent goal: outcome class, visible
  product result, manager-only decisions, and safety boundaries.
- Inspect existing issue/PR/branch/worktree state for duplicate work. Reuse or
  promote an existing parent issue to the epic instead of creating a competing
  parent.
- Split uncertain feasibility into an experiment/probe lane before detailed
  planning. Examples include cross-origin iframe control, third-party
  login/session persistence, browser extension content script isolated world
  limits, external-site DOM automation, keyboard shortcut/player automation,
  browser permission/security policy, and top-level overlay feasibility.
- Each experiment/probe lane states the question, allowed local evidence,
  blocked condition, and next decision: adopt, design around, require an
  extension, require user credential/login approval, or stop.
- Create or update the epic, then create child tickets for implementation,
  UX/product design, evidence/probe, verification harness, onboarding/fallback,
  packaging/release gate, and parent cleanup when needed.
- Each child ticket includes scope, acceptance criteria, verification, Done
  criteria, dependencies, owner lane, and manager-only gates. Manager-only gates
  such as public store release, credential entry, paid resources, destructive
  action, user data transfer, or host-global promotion must not be hidden inside
  agent-solvable acceptance.
- Register the epic and child tickets in the configured project board when
  tools allow it. If unavailable, report `project_gate=unavailable` and preserve
  the order in the parent issue checklist.
- Update the parent epic with child checklist, execution order, dependency
  graph, parallel-safe lanes, serialized lanes, experiment/probe lanes, and a
  parent close gate.
- Attach a guardian: use goal companion tooling when available; otherwise leave
  a guardian checklist / stop-signal ledger on the parent issue. The guardian
  watches for early stop, ticket-only closeout, manager-only vs agent-solvable
  blocker confusion, child tickets shrinking the parent goal, and evidence-free
  Done claims.
- Dispatch plan-mode / sub-session work automatically when tools can create or
  retarget sessions. Verify created sessions before reporting them active. If
  tools are unavailable or policy blocks fan-out, state
  `split_gate=serial_direct` or `subsession_unavailable` and create the same
  charter, ticket, probe, and close-gate artifacts serially in the current
  session. Do not ask the user whether to open plan sessions.
- Final report states what is immediately executable: first lane to start,
  blocked lane if any, active guardian/ledger, and the parent close gate.

### Ticket Creation Is Not Done

Ticket creation is not Done for an implementation, product, architecture,
extension, adoption, or release request. It is Epic Preparation output.

- If the current turn only creates or updates epic/child tickets, report
  `completion line: EPIC_PREP_READY`.
- Report `completion line: PR_READY` only when a validated branch/PR or parent
  review packet exists and the remaining gate is review/merge, not first
  implementation.
- Report `completion line: MERGED_DONE` only after merge/main-sync evidence.
- Report `completion line: BLOCKED_NEEDS_MANAGER_DECISION` only for true
  manager-only gates such as credential/login approval, paid billing, public
  release, destructive action, user data, or host-global promotion.
- Never use Done or `PR_READY` for ticket-only output, a plan-only artifact, or
  an experiment that has not produced its post-probe decision.

### Experiment Before Planning

When feasibility is uncertain, create a small experiment/probe lane before
committing the detailed plan. This applies to browser and platform boundaries
such as cross-origin iframes, extension permissions, content script isolated
worlds, third-party cookie/session policy, external DOM automation,
keyboard/player control, local unpacked extension limits, and public
distribution policy.

Agent-solvable probes may use local code, docs, browser evidence, fixtures,
unpacked extensions, and no-login mocks. Manager-only actions are separate:
credential entry, account login, paid resources, public release, store
publication, destructive operations, user data transfer, and host-global
mutation. A blocked manager-only gate does not block independent local probes.

## Outcome Contract

Mission control must preserve the requested outcome shape before it splits work.
Do not collapse a multi-axis goal into one attractive axis, and do not let an
intermediate artifact replace the requested result.

- Charter records the outcome class: `decide`, `inspect`, `plan`, `apply`,
  `operate`, `release`, or `monitor`. A goal may have multiple classes.
- If any class is action-oriented (`apply`, `operate`, `release`, `monitor`),
  reports, tickets, worker summaries, and automations are intermediate evidence,
  not Done.
- Closeout must match the highest requested outcome class: implementation or
  runtime evidence for `apply/operate`, release gate evidence for `release`,
  active watch/backlog routing evidence for `monitor`, source-backed decision for
  `decide`, and explicit blocker with next retry condition only when local work
  cannot progress.
- When a goal has parallel value axes such as user-visible workflow, functional
  capability, architecture, code quality, cost, risk, and validation, keep them
  as independent lanes until synthesis. Do not subordinate one axis to another
  unless the user makes that tradeoff.
- Before final answer, name any remaining lane as adopted, scaled to an owned
  follow-up, watched, rejected, or blocked. Anything else is unfinished parent
  cleanup.
- A pilot lane is not a final state by itself. Any `PILOT_ONLY`, `C`, fixture,
  benchmark, mock, dry-run, or read-only experiment must end with a post-pilot decision:
  adopt the proven small surface, scale to an owned issue, watch with
  a trigger, reject with evidence, block on an exact external condition, or
  escalate a true manager-only gate.

## Scope Preservation Gate

Small safe steps are an execution tactic, not a success definition. Mission
control must not shrink a broad user objective into the first low-risk patch
unless the user explicitly narrows the goal.

- For broad review, adoption, apply/discard, end-to-end, or ticket-push goals,
  keep a parent-owned lane ledger before final answer. Each lane should have:
  target, value axis, owner, write surface, status, evidence, next action, and
  closeout state.
- Broad adoption work should keep multiple value axes open: architecture, code,
  feature ideas, user-visible workflow, validation/quality, development process,
  security/credentials, operations/cost, and public-safe propagation.
- A useful first patch may close one lane, but it cannot close the parent goal.
- Large agent harness, orchestration, skill-pack, IDE-agent, MCP/plugin, or
  automation-control repos must be split across concrete surfaces before parent
  synthesis: hooks, scripts, skills, rules, commands/prompts,
  multi-agent/workflow control, dashboard/status UI, credential/API/security
  boundary, architecture, code-level reusable patterns, feature ideas, new
  technology/libraries, test/fixture strategy, and development process.
- Star/high-signal external repos need a star-reason and strong-feature gate
  before classification. Workers must identify why the repo plausibly earned
  adoption or attention, then extract strongest detailed features one by one
  with source evidence, local transform, expected Driftless benefit, adoption
  cost, and closeout. Popularity is discovery evidence, not adoption evidence.
- When a candidate is too broad for direct import, transform each viable surface
  into a local lane before rejecting the whole system.
- When a candidate is risky but plausibly valuable, prefer a contained pilot over
  rejection: fixture credentials, dry-run installers, local-only mocks, static
  dashboards, bounded benchmarks, and read-only audits.
- Contained pilots must record the decision they answered before closeout. Good
  outcomes are not "pilot completed"; they are "adopt this bounded gate",
  "scale to this owned issue", "watch until this trigger", "reject because
  measured value failed", "blocked on this exact access", or "manager-only
  approval required".
- Mission-control Done for an implementation/adoption/release request requires
  merged/main-synced change, ready PR/draft PR with validation and owner,
  parent-reviewed patch set ready for merge gate, or true manager-only blocker.
  One safe subset applied is progress, not Done, when the parent objective is
  broader.

## Split And Closeout Gates

Run this before long-goal rollover, after major handoff, and whenever a worker
stops with unmet criteria.

- Inventory remaining work from the goal/companion threads, handoff, repo
  status, issue/PR state, and validation gates.
- Classify each item as `start-now`, `serialized`, `blocked`, `manager-only`, or
  `coordinator-cleanup`.
- Parallelize only `start-now` items with disjoint write surfaces or output-only
  contracts. Separate implementation, read-only audit, data/probe, docs/skill
  prevention, and release/root-sync cleanup lanes when safe.
- Do not split one ticket into serial micro-goals. A worker lane owns one
  coherent ticket until `REVIEW_READY`, draft PR, or blocker evidence.
- If there are two or more safe lanes, route to `parallel-ticket-planner` or the
  tool's native dispatch path before creating another single continuation goal.
- If there is only one lane, report `split_gate=single_lane` and the concrete
  reason.
- If a worker goes idle/completed with uncommitted changes and no
  commit/push/PR/`REVIEW_READY`, treat it as early stop. Continue or steer the
  worker through closeout instead of asking the user to judge raw git.

## User Interaction Boundary

The non-developer user/manager interaction surface should be simple, narrow, and
meaning-level. Mission control expands agent-owned work instead of expanding user
chores.

- The user should see what changed, what was verified, what they can safely
  click/run, and which true decision remains.
- Do not ask the user to choose worker prompts, branch names, worktrees,
  heartbeat ids, raw git commands, PR gate interpretation, test commands, stale
  thread cleanup, or which internal skill to use.
- If the current tool can create/retarget sessions, workers, automations, PRs,
  comments, and cleanup directly, do it and report the active mapping. Manual
  paste prompts are fallback artifacts.
- Ask only for meaning-level decisions: product priority/scope, account/login or
  credential approval, paid billing, public release, destructive action,
  host-global promotion, user data transfer, or a domain/content judgment that
  tools cannot infer.

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
- star reason / strong features:
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
- skill, prompt, hook, script, hot-rule, or instruction changes: automatically
  classify as `merge-now`, `wrapper-alias`, `narrow-trigger`,
  `keep-internal-engine`, or `delete-candidate` before adding a new surface;
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
