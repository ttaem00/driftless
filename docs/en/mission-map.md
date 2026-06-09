# Mission Map

Mission Map is a public-safe UI pattern for showing agent work orchestration to
non-developer users. It is not a launcher, an IDE, or a private runtime adapter.
It answers one question: what is happening now, what is guarded, what is blocked,
and what can be done next?

The pattern keeps three tiers visible:

| Tier | User question | Public-safe fields |
| --- | --- | --- |
| Intent | What are we trying to finish? | `activeGoal`, `outcomeClass` |
| Progress | What is running or blocked? | `guardian`, `lanes`, `blockers` |
| Evidence | How do we know? | `pr`, `checks`, `evidence`, `nextAction` |

## Required UI summary

A Mission Map card should show:

- active parent goal in plain language;
- guardian or heartbeat status, if one is attached;
- PR or review gate state;
- check or validation state;
- blocker count and next retry condition;
- one next executable action.

The UI must not treat `review_ready`, `blocked`, or `unverified` as done.
Fixture/static checks prove only the example shape. They do not prove a real
runtime, agent, PR, or browser workflow.

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
