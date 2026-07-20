
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

## 2026-07-21 - Route automatic closeout through one umbrella

### Tier
tool: shared
reach: public OSS

### Observed Pattern
Installing several closeout skills did not make them automatic, while enabling
every leaf independently would over-trigger simple questions and read-only work.

### Evidence
- The shipped leaf registrations were explicit-only and the existing record
  validator did not test routing decisions.
- Issue #50 adds one policy-driven umbrella route with positive and negative
  fixtures and verifies the normal two-profile installer output.

### Lesson
**Principle-based Learning:** automate the stable decision boundary, not every
procedure behind it. One implicit umbrella can select explicit leaf workflows
and preserve negative cases.

**Structural Analogical Learning:** this matches an API gateway routing to
explicit services and a state machine requiring receipts before transitions;
the shared relation is `classify -> select -> prove -> transition`.

**Far Transfer:** use the same shape for release gates, Kanban Done transitions,
and parent-worker adoption without copying tool-specific runtimes.

### Promotion
- status: implemented
- placement: shared policy, existing validator, thin profile adapters, and
  installer materialization gate
- rollback: remove the policy adapter and restore explicit-only umbrella use

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

## 2026-07-10 - Prevent implicit frontier routing in child issuance

### Tier
tool: codex
reach: repo-dev

### Project
- path: repository root (repo-relative)
- slug: ttaem00_driftless
- remote: https://github.com/ttaem00/driftless.git

### Observed Pattern
A role-only child issuance can silently inherit a costly frontier selection unless route provenance and selected-tier validation are executable.

### Evidence
- `scripts/Test-ModelTierRoutingContract.ps1 -Root .` PASS: rejects silent frontier inheritance, stale literals, missing provenance, and unjustified escalation.
- `install.ps1 -Tool both -Yes` materialized the shared contract for both public profiles; `scripts/Test-InstallerMaterialization.ps1 -Root .` PASS.
- PR #40 local aggregate gate: `scripts/Test-PrValidationGate.ps1 -Root .` PASS.

### Lesson
**Principle-based Learning:** route work by stable role, named risk, and observed quality evidence; choose the cheapest sufficient tier and keep volatile price/availability on demand. A child must record its chosen route rather than inherit authority.

**Schema Induction:** `bounded role -> root_cause_class: implicit authority/cost inheritance -> explicit tier and provenance -> contract fixture + install path -> revert shared role/alias mapping`.

**Structural Analogical Learning:** this is the same control relation as SRE service tiers (cheap default capacity, explicit high-criticality exception) and a database query planner (cheap plan unless observed cost/selectivity justifies a costlier one).

**Far Transfer:** apply the schema to CI workload classes, human-escalation triage, and cloud-instance selection: preserve the role/evidence boundary while changing the resource catalog.

### Recommended Change
Keep the provider-detachable policy in the shared registry, with thin profile adapters and an executable contract gate; do not move a live price or availability catalog into hot rules.

### Promotion
- status: implemented
- placement: `profiles/shared/schemas/model-tier-routing.json`, the shared mission-control adapter, fixtures, and the aggregate PR gate.
- validation: targeted routing contract, normal two-profile install/materialization, and PR validation gate.

### Scope
repo-local

### Rollback
Revert or edit the shared role/alias mapping and rerun the targeted routing and install/materialization tests; consumers keep their role names.

### Status
implemented
