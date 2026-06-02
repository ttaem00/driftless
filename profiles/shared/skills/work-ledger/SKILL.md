---
name: work-ledger
description: >
  Use when a task needs clear goal, success criteria, verification, and evidence
  tracking so a non-developer manager does not judge raw scripts or logs.
  Trigger: "work ledger", "criteria", "done criteria", "evidence ledger",
  "검증 기준", "완료 기준", "작업장부", "증거 장부".
---

# Work Ledger

This shared skill turns vague work into a small checklist the agent can verify.
It is not a project-management ceremony. It exists so a non-developer manager
can see what "done" means without reading code.

## Ledger Shape

Use this compact shape in an issue, PR body, or local notes:

```markdown
## Goal
<one sentence: what visible problem this solves>

## Success Criteria
- [ ] WDL-1 <observable result>
- [ ] WDL-2 <observable result>

## Verification
| Criterion | Evidence | Result | Status |
| --- | --- | --- | --- |
| WDL-1 | <command, screenshot, run, or artifact> | <result> | PASS/FAIL/UNVERIFIED |

## Manager Decision
None, unless credentials, billing, public release, destructive action,
host-global promotion, or user data is involved.
```

## Rules

- Criteria must be observable. "Works well" is not a criterion.
- Each criterion needs evidence before it becomes PASS.
- Static docs/schema/unit checks support behavior claims but do not prove a
  customer can use the feature unless the task is explicitly docs-only.
- If a criterion remains UNVERIFIED, create or reuse the smallest follow-up
  issue unless it is a manager-only decision.
- Keep the ledger short. If it is too long for a manager to scan, split the
  task.

## When To Use

Use the ledger for:

- installer, profile, launcher, or automation changes;
- public README/product claims;
- overnight maintainer work;
- release gates;
- any task where "done" could otherwise become a vague agent judgment.

Skip it for one-line typo fixes.
