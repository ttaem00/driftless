# Mission Map

Mission Map is a public-safe UI pattern for showing agent work orchestration to
non-developer users. It is not a launcher, an IDE, or a private runtime adapter.
It answers one question: what is happening now, what is guarded, what is blocked,
and what can be done next?

The pattern keeps three tiers visible:

| Tier | User question | Public-safe fields |
| --- | --- | --- |
| Intent | What are we trying to finish? | `activeGoal`, `outcomeClass` |
| Progress | What is running or blocked? | `guardian`, `lanes`, `controlPlane`, `blockers` |
| Evidence | How do we know? | `pr`, `checks`, `evidence`, `nextAction` |

## Required UI summary

A Mission Map card should show:

- active parent goal in plain language;
- guardian or heartbeat status, if one is attached;
- runtime control-plane state, if any worker/session/automation is attached;
- PR or review gate state;
- check or validation state;
- blocker count and next retry condition;
- one next executable action.

The UI must not treat `review_ready`, `blocked`, or `unverified` as done.
Fixture/static checks prove only the example shape. They do not prove a real
runtime, agent, PR, or browser workflow.

## Control-plane status must fail closed

Mission Map can summarize live agent work, but it must not invent aliveness. A
row is only `ACTIVE` when the runtime can show all of these public-safe facts:

- a native work/session id from the tool that is actually doing the work;
- runtime driver semantics for the attached tool: lifecycle shape, stdin
  delivery mode, in-flight wake behavior, and which events count as real
  progress rather than internal progress;
- workspace-root evidence from the repo or project that owns the work;
- heartbeat evidence that the worker is still monitored;
- parent, manager, or issue adoption evidence showing where the final result
  will be received.

If a row has only a pending work id, a mismatched workspace root, no heartbeat,
no adoption evidence, no runtime-driver declaration, or a tool-specific status
string that is not normalized, show it as `BLOCKED` or `UNVERIFIED`, never as
active. Keep tool-specific detail in `detail`; keep the machine state in
`normalizedState`.

Runtime-driver fields are public-safe adapter facts, not private session data.
For example, a public row may say a driver is `persistent` or `per_turn`, uses
`direct`, `gated`, or `none` stdin delivery, and distinguishes real progress
events from internal thinking/telemetry. It must not expose private thread ids,
profile homes, credentials, logs, browser state, or account-specific runtime
paths.


## Runtime cards and optional node graph

Runtime cards are the smallest public-safe Mission Map projection. Each card
summarizes one visible unit of work without exposing private runtime state:

| Field | Meaning | Rule |
| --- | --- | --- |
| `id` | stable public fixture id | repo-relative or descriptive, never a private session id |
| `label` | user-facing name | plain language, not a tool log line |
| `kind` | `intent`, `runtime`, `evidence`, `blocker`, or `next-action` | explains why the card exists |
| `normalizedState` | `PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED`, `PARTIAL`, or a control-plane state | must not upgrade the underlying source state |
| `authority` | `projection-only` | card UI is a projection, not execution authority |
| `evidenceRefs` | public-safe links or fixture ids | no private paths, credentials, logs, browser state, or account ids |
| `nextAction` | one executable next step | points back to the owning runtime, repo gate, issue, or PR |

The optional node graph uses the same vocabulary as the cards. A node can mirror
an intent, runtime, evidence, blocker, or next-action card; an edge only explains
public relationships such as `summarizes`, `guards`, `blocks`, or `validates`.
It is useful for showing dependencies, but it is not a scheduler, lock service,
worker queue, or merge authority.

Graph and card UI must remain a projection, not execution authority. A graph may
show that a lane is blocked or that a validation step is next, but the source of
truth stays with the owning runtime control plane, local gate output, issue, PR,
or manager-approved action. If the graph has stale, missing, or private-only
runtime evidence, render that node as `BLOCKED` or `UNVERIFIED` rather than
inferring `ACTIVE` or `DONE`.

## Public fixture

The public example lives at
[`examples/mission-map-state.json`](../../examples/mission-map-state.json). It
contains no private path, account, thread, browser profile, credential, or
runtime-specific session id. Validate it with:

```powershell
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-MissionMapFixture.ps1
```

Use this fixture as a demo/spec seed. Runtime-specific adapters should live in
the runtime that owns those private state files, then propagate only sanitized
field lessons back here.
