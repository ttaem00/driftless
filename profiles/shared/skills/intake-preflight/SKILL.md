---
name: intake-preflight
description: >
  Use when a request is large, unclear, expensive, cross-project, current-state
  dependent, or likely to become tickets, workers, PR work, research, or a long
  plan before the agent has confirmed root intent, evidence, risks, and any one
  human-owned decision.
---

# Intake Preflight

`intake-preflight` runs before a broad request becomes a plan, tickets, worker
lanes, PR work, or implementation.

It is a general Driftless skill, not an Orphanless-only workflow. Use it when the
user gives a big goal and the agent might otherwise start planning from an
incomplete understanding.

## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Generalize as
principle-based guidance and avoid spec/case overfitting and special-casing
unless evidence proves a bounded exception reduces user effort, maintainer
effort, maintenance risk, or safety burden.

## Goal

Prevent wrong-direction work. A plan is ready only after the agent separates:

- facts the agent can inspect itself;
- assumptions that must be labeled;
- one decision that truly belongs to the human, if any.

## Intake Loop

1. State the current hypothesis and confidence.
2. Gather agent-solvable facts before asking the user:
   - repo/worktree state;
   - relevant docs, issues, PRs, project boards, and prior reports;
   - past learning or repeated failure records;
   - public web examples when the user gave links or current practice matters;
   - safety, privacy, release, credential, billing, destructive, or legal risks.
3. Do not ask the user for facts the agent can inspect.
4. If one human-owned decision remains, ask one question with a recommended
   default and the consequence of choosing differently.
5. Restate Outcome / User / Why now / Success / Constraint / Out of scope.
6. Route to the narrowest next skill, such as `mission-control`, `ticket-issue`,
   `parallel-ticket-planner`, `root-goal-check`, `review-before-done`, or
   `learning-loop`.

## Question Surface

Use the tool profile's native question surface when available:

- Codex-style profiles: use the product's short user-input UI when available;
  otherwise ask one concise chat/terminal question.
- Claude-style profiles: use the interactive user-question surface when
  available; otherwise ask one concise chat question.
- Hermes-style profiles: use TUI, dashboard, queue, or kanban-visible question
  state when available; otherwise ask one concise chat question and record the
  decision state durably.

Never batch questions. Never ask the user to inspect raw logs, GitHub setup,
repo state, or public web facts that the agent can inspect.

## Closeout

End with one status:

- `READY_FOR_PLAN`: evidence is sufficient for planning or implementation.
- `ASK_ONE_HUMAN_DECISION`: one human-owned decision remains.
- `BLOCKED_NEEDS_RESEARCH`: agent-solvable research is missing; do that first.
