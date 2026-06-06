
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
