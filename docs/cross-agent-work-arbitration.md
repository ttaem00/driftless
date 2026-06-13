# Cross-Agent Work Arbitration

When two agent sessions (Claude, Codex, or any future tool) work the same
repository at the same time, two failure classes appear: **unknowing duplicate
work** (both build the same thing on different surfaces) and **surface
contention** (both mutate the same files). This protocol (1) prevents both
classes deterministically, (2) arbitrates detected conflicts with fixed rules,
and (3) escalates only the residue a rule cannot decide to the manager.

Origin: this pattern was proven in a private deployment (2026-06) after a real
collision - one session merged a skill into the shared tier while another
session independently built a same-name twin on a tool-specific surface. Three
causes were identified: the claim helper was opt-in and never called, no gate
compared surfaces by asset name, and there was no defined procedure after
detection. Each cause maps to one layer below.

Coordination is grounded in shared code artifacts (claim stores, gates) and
objective signals (gate PASS/FAIL, merged state) - not in live model-to-model
negotiation. Discussion between models is at most a bounded, optional last step.

## Three defense layers

| Layer | When | Mechanism |
|---|---|---|
| L1 deterministic gates | PR / CI | `scripts/Test-WorkSurfaceDuplication.ps1` (one name, one surface) plus the existing discipline gates: `Test-WorkDiscipline.ps1` (placeholders, branch naming), `Test-PrimaryWorktreeClean.ps1` (worktree-first starts), `Test-ProfileMirrorParity.ps1` (shared tier integrity) |
| L2 session claims | Before starting work | `scripts/New-SessionClaim.ps1` Check/Acquire/Release. `scripts/New-IssueWorktree.ps1` acquires a claim automatically; manual starts acquire one explicitly. Hook-level enforcement (refusing mutations without a claim) is environment-specific and intentionally out of scope here. |
| L3 arbitration | When a conflict is detected anyway | The decision rules below, then manager escalation |

## Session claims (L2)

A claim records issue, taskId, branch, worktree, owner surfaces, owner, and
timestamps in a repo-local JSON store. Stores are per-tool by convention -
`.agent-work/` (tool-agnostic default), `.claude-work/`, `.codex-work/` - all
gitignored operational state, never committed.

- `Check` scans read-only; `Acquire` scans then writes a claim; `Release`
  removes matching claims when the work merges or stops.
- Overlap on issue/taskId/branch/worktree returns `DUPLICATE_WORK_DETECTED`
  (exit 2); overlap on an owner surface alone returns `WAIT_FOR_OTHER_SESSION`
  (exit 2); a stale counterpart claim returns `PARENT_REVIEW_NEEDED` (exit 3).
- A claim with no update for 24 hours (default) is stale: it no longer blocks
  outright but demands review before being overridden or released.
- By default the conflict scan reads ALL default stores while mutating only
  the primary one, so a Claude-side scan still sees a Codex-side claim and
  vice versa (rule R3 depends on this).

## Decision rules (L3 step 1 - decided by evidence, no discussion)

Apply top-down; the first rule that distinguishes the two sides is the verdict.
A tie on a rule falls through to the next.

| Rule | Statement | Basis |
|---|---|---|
| R1 | Work already merged to `main` wins over unmerged/untracked work | `main` is the authoritative state; objective signal |
| R2 | The session holding a tracked issue wins over issue-less work | Issue-first discipline, encoded |
| R3 | The earlier acquired, non-stale claim wins (compare `createdAt`; stale 24h+ claims are void). The comparison MUST read every claim store - `.agent-work/`, `.claude-work/`, AND `.codex-work/` - because reading only one store cannot decide a cross-agent conflict and biases the verdict toward one tool. | First-possession principle, cross-store comparison |
| R4 | The shared tier wins over a tool-specific twin: a `profiles/shared/` asset already reaches BOTH profiles in place, so a same-name twin under `profiles/claude/`, `profiles/codex/`, or `skills/` is structural duplication (enforced by `Test-WorkSurfaceDuplication.ps1`) | One name, one shipping surface |
| R5 | The side holding gate PASS evidence wins over unverified work | Verified beats unverified; objective signal |

Losing lane handling: mark the losing branch/worktree clearly as stopped with
the reason, and propose valuable unique pieces as cherry-picks into the winning
lane. The winner then carries the work to done - arbitration must never leave
the work orphaned.

## Manager escalation (L3 step 2)

If R1-R5 all tie, or the conflict touches a manager-only gate (destructive or
irreversible actions, public release, credentials, billing), escalate: present
both sides and a recommendation as one short plain-language question. Manager-
gate conflicts skip the rules and escalate immediately.

## Optional bounded discussion (off by default)

Some environments provide a manager-approved channel to ask the other agent
for its position (for example, a reviewer plugin). Where such a channel exists,
a repo MAY insert ONE bounded exchange between the rules and the escalation:

1. Record the conflict facts (surfaces, both claims, which rules tied) in a
   gitignored scratch folder, as files - a blackboard, not a live dialogue.
2. Each side states its position with verifiable evidence (commands, gate
   output) only.
3. The session that detected the conflict synthesizes a verdict from the
   evidence. One round maximum; no convergence means manager escalation.

Constraints: never spawn or drive a peer agent without an explicitly approved
channel; if the channel is missing or fails, record the position as unverified
and go straight to the manager. This step is environment-dependent and is NOT
part of the Driftless default - the default path is rules then manager.

## Lesson promotion

Arbitrating the same conflict class twice means the class is under-defended:
promote it into a new R-rule or an L1 gate instead of arbitrating it a third
time, following the repo lesson-promotion ladder
(`docs/en/lesson-promotion-ladder.md`).
