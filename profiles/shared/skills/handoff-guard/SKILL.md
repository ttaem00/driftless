---
name: handoff-guard
description: >
  Use for long sessions, overnight work, context-window pressure, resume
  handoff, or when the agent might lose the thread. Trigger: "handoff",
  "resume", "context", "long session", "overnight handoff", "인계", "컨텍스트",
  "긴 세션", "밤샘 작업".
---
## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Generalize as principle-based guidance or design principles; avoid spec/case overfitting and special-casing unless evidence proves a bounded exception reduces user effort, maintainer effort, maintenance risk, or safety burden.
# Handoff Guard

This shared skill keeps a long autonomous run understandable after context is
lost or a new agent resumes it. The manager should not need to inspect raw logs
to know what happened.

## When To Start A Handoff

Start a handoff when:

- the run is long enough that context loss is plausible;
- several issues, branches, or pull requests are in flight;
- a verification step is still pending;
- a manager-only decision is waiting;
- the agent is about to stop without merging or closing.

## Handoff Shape

Write a compact handoff in the issue, PR body, or a repo-local artifact named by
the issue. Do not write secrets, session logs, browser state, or host-global
profile paths.

```markdown
## Handoff
Goal:
Current state:
Completed:
Evidence:
Open decisions:
Blocked/unverified:
Next action:
Do not do:
```

## Rules

- Separate observed facts from inference.
- Include exact issue/PR numbers and branch names when available.
- Include the last passing or failing command, not a long log.
- Mark missing evidence as UNVERIFIED. Empty output is not PASS.
- Never use a stale handoff to overwrite newer local or GitHub evidence.
- On resume, read the handoff, then verify current git/GitHub state before
  acting.

## Manager Report

Use the four Driftless labels and keep the manager action small:

- `built/inspected`: what was resumed or handed off;
- `tested/evidence`: what current state was rechecked;
- `manager run/paste`: only the next human action, if any;
- `blocked/unverified`: exact missing evidence or manager-only gate.
