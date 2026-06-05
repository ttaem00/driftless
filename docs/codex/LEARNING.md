
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
