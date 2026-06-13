
## 2026-06-05 - Prevent hot-context growth by indirection

### Observed Pattern
Customers may keep AGENTS.md small while adding always-loaded hot documents or broad-trigger skills, creating the same context burden under another filename.

### Evidence
- UNVERIFIED

### Lesson
Customers may keep AGENTS.md small while adding always-loaded hot documents or broad-trigger skills, creating the same context burden under another filename.

### Recommended Change
Add a repo-local hot-context discipline gate that distinguishes always-loaded files from on-demand docs/skills and fails broad auto-load references or oversized hot guidance.

### Promotion
- status: record_only
- placement: AGENTS.md or instruction doc, then caveman-compress
- next action: Track recurrence; promote on the second occurrence or any security/done signal.

### Scope
repo-local

### Rollback
Remove or revert the recorded change if it causes over-triggering or false positives.

### Status
recorded

## 2026-06-06 - Improvement principle must be behavior-gated

### Observed Pattern
The public improvement principle existed in shared guidance, but rule application could still be missed because the gate only checked static pointers and not shipped skills, learning-loop, finish-to-done, CI, or PR review surfaces.

### Evidence
- Implementation in issue #102 strengthens public behavior-gated surfaces;
  validation is recorded in the PR and final report.

### Lesson
The public improvement principle existed in shared guidance, but rule application could still be missed because the gate only checked static pointers and not shipped skills, learning-loop, finish-to-done, CI, or PR review surfaces.

### Recommended Change
Strengthen Test-ImprovementPrincipleDiscipline.ps1 to check public behavior-shaping surfaces, add compact Improvement Principle sections to shipped skills, wire the gate into CI, and require PR evidence for rule/skill/prompt/script/hook/doc changes.

### Promotion
- status: implementation_needed
- placement: script/check gate, shipped skills, CI, and PR template
- next action: Implemented in this change; keep the strengthened gate in CI and
  PR review.

### Scope
repo-local

### Rollback
Remove or revert the recorded change if it causes over-triggering or false positives.

### Status
implemented

## 2026-06-11 - Public-safe workflows must reserve high-judgment decisions for lead review

### Observed Pattern
Low-model or lightweight worker fallback is useful for bounded evidence recovery, but unsafe as the sole authority for architecture, security, adoption, release, or public-safe propagation decisions. Shared Driftless skills need the public-safe principle so broad system decisions remain with lead/coordinator synthesis.

### Evidence
- UNVERIFIED

### Lesson
Low-model or lightweight worker fallback is useful for bounded evidence recovery, but unsafe as the sole authority for architecture, security, adoption, release, or public-safe propagation decisions. Shared Driftless skills need the public-safe principle so broad system decisions remain with lead/coordinator synthesis.

### Recommended Change
Add shared skill guidance and validation: lightweight workers may gather bounded evidence, but high-judgment decisions require lead/coordinator or high-quality synthesis with explicit observed/inferred/unverified boundaries.

### Promotion
- status: implementation_needed
- placement: skill workflow
- next action: Apply the smallest repo-local/current-isolated-profile prevention now, then validate it. If the target is an instruction doc, run caveman-compress.

### Scope
repo-local

### Rollback
Remove or revert the recorded change if it causes over-triggering or false positives.

### Status
implementation_required

## 2026-06-13 - Default agent workflows must not expose legacy PowerShell launchers

### Observed Pattern
Real Windows use showed agent shell drift recurring across projects: default
agent instructions and helper scripts could still show or call legacy PowerShell
launcher routes even when the intended runtime contract was PowerShell 7.

### Evidence
- Issue #146 opened from the recurrence report.
- Local scan before the fix found default Driftless surfaces pointing normal
  worktree/session-claim flows at the legacy launcher route.
- Local validation after the fix: `check-no-powershell51.ps1`, shell-contract
  gate, `task.ps1 test`, and CI-equivalent Windows gates passed.

### Lesson
For public shared workflows, a compatibility path is not enough to prevent
drift. The default manager/agent path must show and execute only the PowerShell
7 command contract; legacy compatibility probes must stay isolated and excluded
from default instruction surfaces.

### Recommended Change
Keep default worktree helpers, quickstarts, README commands, and CI gates on
`pwsh.exe -NoProfile -ExecutionPolicy Bypass -File`. Keep any legacy probe under
an explicit isolated compatibility path, and gate default surfaces for launcher
cues.

### Promotion
- status: implementation_needed
- placement: AGENTS.md, default helper scripts, README/quickstart docs, and CI
  no-legacy-launcher gate
- next action: Implemented in issue #146; keep the cue gate in CI so recurrence
  fails before merge.

### Scope
shared tier

### Rollback
Revert issue #146 if the cue gate blocks valid public installation paths; keep
the PowerShell 7 default route and narrow the exception instead of removing the
gate.

### Status
implemented
## 2026-06-11 - Recover capacity/context-failed worker lanes before Done

### Observed Pattern
Public shared skills can coordinate worker, goal, or subagent lanes, but a lane may fail from model capacity or context pressure before returning a usable report. The coordinator needs a public-safe recovery contract: classify, compact, retry safely when reversible, and refuse Done until every lane is complete, retried, or explicitly blocked.

### Evidence
- UNVERIFIED

### Lesson
Public shared skills can coordinate worker, goal, or subagent lanes, but a lane may fail from model capacity or context pressure before returning a usable report. The coordinator needs a public-safe recovery contract: classify, compact, retry safely when reversible, and refuse Done until every lane is complete, retried, or explicitly blocked.

### Recommended Change
Add public-safe worker failure recovery guidance to shared multi-worker-capable skills and extend existing validation gates to preserve recovery state vocabulary and parent closeout inventory.

### Promotion
- status: implementation_needed
- placement: skill workflow
- next action: Apply the smallest repo-local/current-isolated-profile prevention now, then validate it. If the target is an instruction doc, run caveman-compress.

### Scope
repo-local

### Rollback
Remove or revert the recorded change if it causes over-triggering or false positives.

### Status
implementation_required
