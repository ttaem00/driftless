---
name: ticket-issue
description: >
  티켓발행 ticket-issue: 비단순 코드/저장소 작업 전 GitHub Issue 확인, 생성,
  Project 등록, 수행 gate를 담당한다. Use for /티켓발행, ticket issue, GitHub
  Issue creation, work-before-edit issue gates, Project board registration, or
  non-trivial code/repo work needing an issue # before the first edit. Backlog/
  deferred requests delegate to backlog-register for the pending-issue + memory
  note + code-comment 3-layer safety.
  Trigger / 트리거: "/티켓발행", "티켓 발행", "issue 생성", "GitHub Issue 만들기",
  "작업 전 이슈 만들기", "Project 등록", "board 등록", "backlog issue", "ticket gate".
---

# Ticket Issue (shared)

GitHub Issue first. Non-trivial repo mutation needs issue evidence before the
first edit. This is the shared, tool-agnostic version: both agent profiles
consume this one file, so edit it once and both pick up the change.

Resolve the target repo from the workspace itself (auto-detect via
`gh repo view --json nameWithOwner -q .nameWithOwner` or
`git remote get-url origin`, never a hardcoded name). Name the work branch
`agent/issue-<n>-<slug>`.

## Router
- `/티켓발행`, issue 생성, Project 등록: use this skill.
- `/백로그`, backlog issue, pending 등록, 보류, 재평가 예약, 데이터 부족 보류,
  `TODO: 나중에`: call `backlog-register`.
- A backlog/deferred input into `ticket-issue` triggers `backlog-register`'s
  3-layer safety. Normal tickets do not create memory/code comments.

## Gate (before first edit)
Answer: `이 작업의 issue #는?` Order:
1. Run the Preflight (duplicate search + ownership) below.
2. Reuse or create the issue + register it on the Project (registration is real
   only when `gh project item-add` returns an `id`).
3. For risky work, run an adversarial (no-ship) review pass (one reviewer for
   destructive/irreversible work) or an equivalent local no-ship checklist.
4. Execute under `finish-to-done`.

Skip the gate only for: a one-line typo, the user says `바로 해`, or a handoff
that continues an existing issue/PR. Report the skip reason.

## Preflight (always duplicate-check first)
Run in the target repo (always duplicate-check before a new issue):

```sh
git remote get-url origin
git status --short
gh issue list --state all --search "<keyword>"
```

Ownership preflight before create/reopen/close/body-edit/PR/merge/Project change:
also check open PRs, the issue body, worktrees, branches, and Project status for
the same issue/keyword. Compact states: `OWNERSHIP_CLEAR_TO_START`,
`PARENT_REVIEW_NEEDED`, `DUPLICATE_WORK_DETECTED`, `WAIT_FOR_OTHER_SESSION`,
`BLOCKED_NEEDS_MANAGER_DECISION`. If an open PR exists, the issue body already
has a recent execution result/validation, the Project is In Progress without a
handoff, or a matching worktree/branch has dirty work -> report the state and
review/adopt the existing output instead of redoing it.

Multiple issues: draft a dry-run list (title + one-line summary + source),
duplicate-check each, drop rejected items, ask approval for the final list,
create at most 10 per run. Do not edit an existing issue body; suggest the update
in the report.

## Issue Creation
Labels: routine -> `auto-created`; backlog/deferred -> `pending` via
`backlog-register`. Durable execution rules go in the issue **body** (a dated
`## 추가/수정 사항` section), not comments. Body-edit blocked -> report
`Blocked`/`UNVERIFIED`; never comment-only instructions.

User-visible features, runtime workflows, automations, tool integrations, CLI/
script launchers, UI flows, cross-host behavior, and manager-facing claims must
name a real-use / end-to-end acceptance in `Success Criteria`, `Verification`,
and `Done criteria` -- or explicitly state the ticket is static docs/schema/
fixture-only. Fixture/schema/unit/static checks are supporting evidence only;
behavioral claims stay `UNVERIFIED`, not Done.

Manager-visible features also need a discoverable entry point named in the issue
(UI/nav/report/command/manager-guide/issue link) or an explicit internal-only
reason. Raw localhost URLs, hidden routes, config toggles, and internal commands
alone are not enough. Name the operating placement: `automatic`,
`release-triggered`, `on-demand`, or `not-yet-wired`.

Body minimum (shared ticket template):

```markdown
## Goal
## Scope (In / Out)
## Acceptance Criteria
## Token/Context Budget (hot-default vs on-demand + trigger)
## Manager Decision (only if a manager-only gate applies)
```

## Verified Deferred Follow-up
When current work is validated enough to stop/merge but agent-solvable work
remains, auto-create or reuse the smallest follow-up issue before the final
report when any holds: an `UNVERIFIED`/`PARTIAL`/`BLOCKED` item with a concrete
retry trigger; a validated fixture/telemetry/smoke that needs later real-use or
cross-host work; a manager-facing feature lacking a discoverable entry point; a
prototype/experiment with material positive evidence but no adopt/defer/reject
decision; a no-ship note saying later/next/todo/follow-up/나중/보류/후속 for
agent-solvable work. Keep it low-token (one focused `gh issue list --search`;
shared body template; Project-register when auth allows, else `UNVERIFIED`).

Do NOT auto-create when the remaining work is manager-only: product priority,
paid billing, public release, destructive/irreversible action, host-global
promotion, or credential entry/use -> ask one short Korean question instead.

## Close Gate
Before close/ready: read the shared decision register for pending/deferred
conflicts; stop if the change conflicts with a pending decision; include a
5-column Decisions table (`Decision`, `Why`, `Evidence`, `Status`, `Follow-up`)
in the issue/PR body; do not reopen decided items.

## Git Rules
No direct push to `main`. Big work: branch + PR. Never commit secrets, env files,
private keys, or browser profiles (the canonical forbidden-path set lives in the
shared schemas and is enforced by the containment guard). Dirty unrelated files:
report; no stash/reset/clean without approval.

## Report (plain Korean, one of four labels)
`built/inspected` (issue/draft made) - `tested/evidence` (commands + result) -
`manager run/paste` (next exact command) - `blocked/unverified` (exact blocker).
Raw commands/paths go in evidence lines under the summary.

NEVER: peer/recursive AI calls in the active path; mutation of any host-global
agent home outside the isolated runtime; reporting a hidden/internal-only path as
a manager-facing Done.
