# Portfolio Operating Layer

Broad agent goals fail when vision, user outcome, product opportunity,
implementation capability, execution task, and governance gate all live in the
same sentence. The agent then treats an example as the whole scope, opens vague
follow-up work, or reports "done" after a small slice.

This guide gives maintainers a public-safe way to split a large goal before it
becomes issue sprawl.

## The six layers

| Layer | Question | Good artifact |
| --- | --- | --- |
| Vision | What should be more true for users over time? | Product promise or north-star doc |
| Outcome | What should the user be able to do or decide? | Manager-facing workflow, report, or UI state |
| Opportunity | What repeated pain or market gap makes this worth doing? | Research note, adoption review, or issue body |
| Capability | What reusable system ability must exist? | Shared skill, script, schema, gate, or adapter |
| Execution | What concrete change can an agent finish now? | Issue branch, PR, validation evidence |
| Governance | What prevents unsafe, stale, or false-done work? | Containment, work-discipline, closeout, or follow-up gate |

A goal may need all six layers, but one issue rarely owns all six. A good split
keeps the layers linked while giving each issue a clear finish line.

## How to classify a broad request

Start with the user sentence, then ask these in order:

1. Is this a long-term product direction? Put it in `Vision`.
2. Is this something a non-developer user must see or decide? Put it in
   `Outcome`.
3. Is this a reason to invest, compare alternatives, or watch a market/tool?
   Put it in `Opportunity`.
4. Is this a reusable ability shared by many future tasks? Put it in
   `Capability`.
5. Is this the scoped change that can be validated now? Put it in `Execution`.
6. Is this a safety, evidence, cost, or completion boundary? Put it in
   `Governance`.

If an issue mixes more than two layers, split it or add a parent issue that owns
the synthesis. If a worker only touches `Execution`, the parent still owns
`Vision`, `Outcome`, and `Governance`.

## Anti-overfitting rules

- Examples are evidence, not the scope.
- A single file, one error string, or one failing test is usually a symptom.
  Ask what recurrence path it represents before adding a rule.
- A smoke test proves reachability, not real usefulness. Promotion needs a
  varied task matrix and parent closeout evidence.
- A worker result is not done until the parent records the decision, evidence,
  cost or effort impact, and next action.
- A static document can explain the layer; it does not prove the runtime uses
  it. Behavioral claims need a real run or an honest `UNVERIFIED` label.

## How this connects to existing Driftless pieces

- Use [Mission Map](./mission-map.md) to show the active outcome, lane state,
  evidence, blocker, and next action.
- Use [The Lesson-Promotion Ladder](./lesson-promotion-ladder.md) when a layer
  reveals a recurring mistake that needs memory, skill, hot rule, hook, or gate.
- Use [How Driftless learns](./how-driftless-learns.md) to decide whether a
  repeated failure has enough evidence to climb to an enforced surface.
- Use [Guardrails](./guardrails.md) before anything involving credentials,
  host-global config, browser profiles, private data, destructive actions, or
  public release.
- Use [The insight-inbox pattern](./insight-inbox-pattern.md) when external
  ideas need capture, review, decision ledger, and follow-up routing.

## Issue template

```markdown
## Layer
- Vision:
- Outcome:
- Opportunity:
- Capability:
- Execution:
- Governance:

## Scope
In:
Out:

## Acceptance criteria
- The user-visible outcome is named, or the issue states why it is internal.
- The reusable capability is named if this is more than a one-off fix.
- The governance gate is named for any safety, cost, credential, public release,
  destructive, or false-done risk.
- Validation says whether it proves behavior or only static shape.

## Closeout
- Adopt:
- Watch:
- Reject:
- Blocked:
- Follow-up issue:
```

Do not leave all five closeout rows blank. A pilot or experiment is not a final
state; it must become adopt, watch, reject, blocked with a retry condition, or a
new scoped follow-up.

## Small example

Request: "Use cheaper helper models so the main agent spends fewer tokens."

- `Vision`: agent work should become cheaper and less tiring over time.
- `Outcome`: the maintainer sees which helper route was used, what it cost, and
  whether the parent accepted it.
- `Opportunity`: cheap models may handle scouting or review, but only if they
  do not increase rework.
- `Capability`: provider-neutral route aliases, usage ledger, parent closeout,
  and task matrix.
- `Execution`: one issue adds the ledger field; another adds the matrix; another
  wires the manager report.
- `Governance`: no secret values, no paid calls without approval, no promotion
  from a single smoke pass, and no "done" without parent judgment.

This turns one exciting idea into small, testable, conflict-safe work without
losing the original user value.
