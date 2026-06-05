---
name: goal-pair-guardian
description: >
  목표동행(호환 ID: goal-pair-guardian): 긴 Codex Desktop `goal` 세션이 원래 목적에서
  벗어나는지, 컨텍스트 압축 뒤 방향을 잃었는지, 성공 기준을 못 채웠는데 스스로
  멈췄는지 점검하고 현재 goal을 계속 조정할지 새 continuation goal을 시작할지
  결정합니다. 병행티켓, overnight-all-tickets, finish-to-done, learning-loop,
  skill optimization 등 맞는 스킬로 라우팅하며 반복 실패 뒤 prompts, skills,
  hot rules, scripts, hooks, docs를 경사하강식으로 개선합니다.
  Trigger: "goal pair", "pair automation", "goal drift", "goal guardian",
  "context compaction", "goal stopped early", "새 goal", "목표 이탈",
  "중간에 끊음", "무한 진행", "경사하강", "목표 동행", "goal 세션 점검".
---

# 목표동행 Goal Pair

Use this skill as the lightweight companion around a long Codex goal. The
companion does not implement feature work. It checks direction, evidence, scope,
completion honesty, and continuation state; then it either steers the current
goal, routes to the right skill, or creates a fresh continuation goal when the
current session is too compressed or confused to trust.

Manager outcome: one short report says whether the current goal should continue,
be re-planned with parallel/overnight lanes, or restart as a fresh goal with a
paste-ready objective. The manager should not inspect raw git, logs, or skill
selection decisions.

## Placement Decision

1. Intended scope: long or autonomous goal sessions that can drift, self-stop,
   or need cross-skill routing.
2. Chosen location: on-demand skill, plus the small checkpoint script in
   `scripts/New-GoalPairCheckpoint.ps1`.
3. Why this scope is correct: always-hot rules would waste tokens; this workflow
   is only needed for long goals, audits, restarts, and repeated failure loops.
4. Hot vs on-demand: keep the hot rule to "long procedures live in skills"; load
   this skill only when goal drift, pair automation, or continuation is in scope.
5. Rejected alternatives: a global always-on prompt is too expensive; a peer AI
   bridge violates single-AI boundaries unless a current approved issue allows
   it; a timer-only automation misses finish-time drift and wastes money.

## Operating Model

Run as a companion check lane inside the same isolated Codex runtime. Do not call
another AI, bridge, agent framework, or host-global automation. If Codex app
thread or heartbeat tools are available and the manager explicitly asks to start
or attach two sessions, use those native tools; otherwise output paste-ready
prompts for fresh Codex threads. Never create a paid/billed, public,
credentialed, destructive, host-global, or user-data automation without a clear
manager decision.

## Two-Session Launch Mode

Use this mode when the manager gives one concrete goal and asks for a goal
session plus a goal-pair companion session, or says the skill should start both
automatically.

If Codex app thread tools are available, use them directly:

1. Create one goal thread for implementation work.
2. Create one goal-pair thread for direction/evidence/finish-honesty checks.
3. Send the goal thread id, title, root intent, and success criteria to the
   goal-pair thread.
4. Send the goal-pair thread id and steering contract to the goal thread.
5. Prefer a heartbeat attached to the goal-pair thread for repeated checks.
6. If an existing goal or goal-pair thread already matches the same objective,
   update/reuse it instead of creating duplicates.

Session visibility and rollover gate:

- Repo work must run under the target project or a repo-local worktree. A
  projectless folder or unrelated profile workspace is wrong-workspace unless
  the task is explicitly about that profile.
- After thread creation or rollover, verify title, role, `cwd`, live ids, and
  heartbeat target before reporting a pair active.
- A heartbeat prompt update alone is not a rollover. A valid rollover has a
  fresh implementation thread, fresh guardian thread, verified project `cwd`,
  retargeted heartbeat, and stale visible pairs stopped or archived.
- Before creating a single fresh continuation goal, run a split gate: inventory
  remaining work and route to `parallel-ticket-planner` when two or more
  agent-solvable items have disjoint write surfaces or output-only contracts.
  If not parallelized, report `split_gate=single_lane` and the reason.
- A goal that becomes idle/completed with uncommitted changes, no commit/push/PR,
  no `REVIEW_READY` packet, and unmet criteria has stopped early. Steer it to
  close out with validation, commit/push/draft PR, a review packet, or explicit
  blocker evidence.

User interaction boundary:

- The user should not have to ask whether the goal is alive, which thread is
  active, which automation is attached, or which worker prompt to paste next.
  Verify those internally and report one active mapping.
- Do not ask the user to inspect raw thread ids, stale previews, git status,
  branch/worktree choices, PR gates, or heartbeat schedules.
- If user input is needed, ask one meaning-level question only. Prefer direct
  session/automation repair when the tool exposes those controls; prompts are
  fallback artifacts when controls are unavailable or blocked.

Tool contract:

- use `create_thread` for the implementation goal thread;
- use `create_thread` for the 목표동행 companion thread;
- use `set_thread_title` so the manager can recognize both sessions;
- use `send_message_to_thread` only for actionable corrections, not routine
  heartbeat/status messages;
- use `automation_update` heartbeat only for repeated checks, and prefer
  updating an existing matching automation over creating a duplicate.

If thread tools are unavailable, run `scripts/New-GoalPairTwoSessionBundle.ps1`
or output two paste-ready prompts instead of pretending that sessions were
created.

Manager fast path:

```text
목표동행 2세션으로 실행해줘.
목표: <하고 싶은 작업>
완료 기준: <보이면 성공인 것>
금지/주의: <하지 말아야 할 것>
```

When this fast path is used, infer sensible defaults instead of asking the
manager to choose branch names, raw commands, app thread ids, schedule syntax, or
validation helpers. Ask only for true manager decisions such as credentials,
paid billing, public release, destructive action, host-global promotion, user
data transfer, or product priority.

Goal thread prompt content:

- the manager's original goal;
- `Use $goal-pair-guardian`;
- manager is non-developer; do not push raw git/log/script decisions to them;
- root intent, success criteria, scope, exclusions, evidence, remaining work;
- route to `parallel-ticket-planner`, `overnight-all-tickets`,
  `finish-to-done`, `learning-loop`, or skill optimization when appropriate;
- do not claim Done until every criterion has command/tool evidence;
- if context becomes unsafe, write/checkpoint state and ask the goal-pair thread
  for `START_FRESH_GOAL` continuation handling.

Goal-pair companion thread prompt content:

- read the goal thread through app thread tools;
- check root intent, success criteria, scope, evidence, remaining work, blockers,
  context health, routing, and finish honesty;
- run the split gate before a fresh single continuation goal;
- use `send_message_to_thread` to correct the goal thread when it drifts, stops
  early, defers agent-solvable work, or reports unverified Done;
- treat idle/completed plus uncommitted changes and no PR/review packet as
  early-stop closeout work, not Done and not user work;
- use `automation_update` heartbeat for repeated checks when requested or when a
  long run is expected;
- when current context is no longer trustworthy, write a checkpoint where safe
  and produce a paste-ready continuation `/goal`;
- report with `inspected`, `guardian_decision`, `corrected_sessions`,
  `fresh_goal_needed`, and `remaining_risk`.

Fallback bundle command:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "<skill>\scripts\New-GoalPairTwoSessionBundle.ps1" `
  -TargetRepo "<repo>" `
  -Goal "<manager goal>" `
  -SuccessCriteria "<verifiable done criteria>" `
  -Scope "<scope and exclusions>"
```

The 목표동행 companion owns these checks:

- original goal, success criteria, scope, exclusions;
- current evidence and whether each PASS claim came from real execution;
- whether the latest work still serves the goal;
- whether any agent-solvable work was deferred to "later";
- whether context compaction lost the goal, state, or next action;
- whether a different skill should be invoked before more ad-hoc work;
- whether the current session can continue safely or needs a fresh goal.

## When To Start Or Re-Run

Start or re-run the companion check when any signal appears:

- goal has run for a long burst, crossed a context compaction, or resumed from a
  summary;
- progress says "done", "idle", "waiting", or similar while success criteria are
  not proven;
- the session starts solving a nearby but different problem;
- the same blocker repeats twice;
- a worker output says `PARENT_REVIEW_READY`, `PR_READY`, `UNVERIFIED`,
  `NOT_RUN`, `follow-up`, `watch`, `후속`, or `보류`;
- the task grows into multiple independent write surfaces;
- the manager asks for overnight/all tickets, parallel sessions, or no-stop work;
- a skill/prompt/hook/doc change should become cheaper or more reliable over
  time.

## Routing Rules

Use the smallest matching skill instead of re-implementing it:

- Goal/success criteria unclear: use `codex-work-ledger` or `work-ledger`.
- Many runnable issues or "while I sleep": use `overnight-all-tickets`.
- Multiple independent write surfaces: use `parallel-ticket-planner`.
- A blocker is agent-solvable: use `finish-to-done`.
- Repeated mistake or recurrence prevention: use `codex-learning-loop` /
  `learning-loop`.
- Prompt, skill, hook, or instruction placement: use `instruction-edit-checklist`
  first.
- Skill/prompt optimization candidate: run the repo's skill optimization harness
  or Driftless `skillopt`; keep candidates only with zero protected-term loss and
  no axis regression.
- UI/layout/browser evidence: use the UI/browser skills required by the target
  repo before claiming behavior.
- PR/merge/issue close: use the target repo's PR, ticket-close, mergeability, and
  comment gates.

## Check Pass

Use this fixed order. Keep raw logs out of chat; cite file paths and short
summaries.

1. Restate the root intent in one sentence.
2. List the success criteria and mark each `PASS`, `FAIL`, `UNVERIFIED`,
   `BLOCKED`, or `PARTIAL` with command/tool evidence.
3. Compare recent work to the root intent. Any mismatch is drift.
4. Inspect unfinished work. Default to agent-solvable unless it is a true manager
   decision, verified hard-external block, serialized dependency, or explicit
   out-of-scope item.
5. Check context health. If the current session cannot name the goal, next
   action, changed files, blockers, and evidence without contradiction, treat it
   as unsafe to continue.
6. Check routing. If parallel or overnight flow is now appropriate, stop ad-hoc
   serial work and route.
7. Check five-axis pressure: tokens, manager intervention, time, money, and
   performance/recurrence prevention.
8. Write a checkpoint with `scripts/New-GoalPairCheckpoint.ps1` when files can be
   written safely.

## Decision

Return exactly one decision:

- `CONTINUE_CURRENT_GOAL`: goal is still aligned, evidence is fresh, and the next
  action is clear. Provide a short steering message for the current session.
- `REPLAN_WITH_PARALLEL_OR_OVERNIGHT`: the work should be decomposed or run as an
  overnight parent-owned bundle. Invoke the relevant skill before more work.
- `START_FRESH_GOAL`: the current session is too compressed, contradictory, or
  self-stopped with unfinished agent-solvable work. Write a checkpoint and output
  one paste-ready continuation goal.
- `BLOCKED_TRUE_MANAGER`: only for product/priority, credentials, paid billing,
  public release, destructive/irreversible action, host-global promotion, user
  data transfer, force-push/history rewrite, or proven hard-external access.

## Fresh Goal Threshold

Prefer `START_FRESH_GOAL` when any of these holds:

- two steering corrections failed to bring the current session back on target;
- the session cannot reconstruct success criteria or remaining work;
- summaries contradict command/tool evidence;
- final/report wording says done while `UNVERIFIED`, `NOT_RUN`,
  `PARENT_REVIEW_READY`, skipped validation, or open agent-solvable lanes remain;
- the current context is dominated by old logs, stale plans, or unrelated
  branches;
- the next action is clear but the session has already ended or self-disarmed.

Fresh goal prompt shape:

```text
/goal Resume from checkpoint "<checkpoint path>". Root intent: <one sentence>.
Success criteria: <verifiable bullets>. Scope/exclusions: <short list>.
Start by reading the checkpoint and current repo evidence, then continue only the
next runnable lane. Do not claim done until every success criterion has command
or tool evidence. If parallel or overnight flow is needed, invoke the matching
skill first. Ask the manager only for true manager decisions.
```

## Automatic Improvement Loop

After every companion pass, decide whether a prevention improvement is warranted.
This is automatic within repo-local boundaries; the manager is not asked to judge
raw implementation choices. The goal is that repeated use makes hot rules,
scripts, global/profile prompts, prompt templates, docs, other skills, this
skill, and hooks smaller, cheaper, clearer, and more reliable over time.

Use this ladder:

1. First occurrence: record the lesson and the measurable trigger.
2. Second occurrence: create a concrete proposal with target placement.
3. Third occurrence, or any serious done/safety regression: implement the
   smallest repo-local skill/script/hook/doc fix and validate it.

For every proposed or implemented change, score the five axes:

- `tokens`: does it reduce hot context or loaded text?
- `manager`: does it reduce manager intervention?
- `time`: does it remove repeated manual steps?
- `money`: does it avoid new paid/billed calls and reduce wasted long goals?
- `performance`: does it prevent recurrence without weakening safety?

Protected terms, manager-only gates, containment boundaries, trigger phrases,
and required validation commands must survive verbatim. Do not optimize by
deleting safety. Host-global changes are proposal-only. Natural-language profile
or instruction docs changed by an agent must run the repo's compression skill
where safe, or record the exact skip reason.

Optimization placement rule:

- hot rules: only short always-needed triggers or hard safety rules;
- hooks: only cheap routing or safety hints with low false-positive cost;
- scripts: repeatable mechanical work, checkpointing, prompt bundle generation,
  validation, and evidence collection;
- skills: conditional workflows and manager-facing procedures;
- docs: product intent, examples, and longer explanations;
- prompts/templates: reusable manager UX surfaces.

Never add a large always-loaded rule just because the skill found one failure.
Prefer the smallest validated placement that reduces tokens, manager effort,
time, money, or recurrence risk.

## Checkpoint Script

Use the script when the companion needs a durable state record:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "<skill>\scripts\New-GoalPairCheckpoint.ps1" `
  -TargetRepo "<repo>" `
  -RunId "<run-id>" `
  -Goal "<root intent>" `
  -SuccessCriteria "<criteria summary>" `
  -Scope "<scope/exclusions>" `
  -Observed "<short evidence summary>" `
  -Remaining "<next runnable work or blockers>" `
  -Decision "START_FRESH_GOAL" `
  -Reason "<why>"
```

The script writes JSON and Markdown under
`.runtime/goal-runs/<run-id>/goal-pair/checkpoints/`. It does not read secrets,
call a model, inspect host-global profiles, or mutate git state.

## Output Format

Use the manager-facing labels:

```text
built/inspected:
- <what goal/run/checkpoint was inspected>

tested/evidence:
- <short command/tool/file evidence>

manager run/paste:
- <none, steering message, or one fresh /goal prompt>

blocked/unverified:
- <true blockers or "none">

guardian decision:
- CONTINUE_CURRENT_GOAL | REPLAN_WITH_PARALLEL_OR_OVERNIGHT | START_FRESH_GOAL | BLOCKED_TRUE_MANAGER
```

## Self-Check

- [ ] The companion did not implement feature work.
- [ ] Root intent, success criteria, scope, and next action are explicit.
- [ ] PASS claims have real execution evidence; static-only proof is marked
  `UNVERIFIED`.
- [ ] Agent-solvable leftovers were not hidden behind "later" or "follow-up".
- [ ] The right skill was routed before ad-hoc work.
- [ ] Fresh goal threshold was applied when context was no longer trustworthy.
- [ ] A checkpoint was written or the skip reason is explicit.
- [ ] Automatic improvement followed the learning ladder and five-axis scoring.
- [ ] No peer/recursive AI, host-global mutation, credentials, environment
  secret files, SSH private material, browser profile, secret, paid, public,
  destructive, or user-data action was taken without the required manager gate.
