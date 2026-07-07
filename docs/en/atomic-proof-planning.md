# Atomic Proof Planning

Large agent goals fail when the work is sliced by activity instead of proof.
An issue can contain many tasks, but it should only be accepted when the smallest
meaningful proof has evidence.

This page gives Driftless a public-safe way to split broad work into units that
a non-developer maintainer can review without reading raw branches, logs, or
chat transcripts.

## The Flow

Use this order:

```text
Outcome -> Proof -> Slice -> Task -> Evidence
```

| Layer | Question | Output |
| --- | --- | --- |
| Outcome | What should become true for the user or maintainer? | A visible state, decision, or operating condition |
| Proof | What smallest fact would prove that outcome? | One proof statement with a pass/fail test |
| Slice | What narrow vertical path can create that proof? | One user/system flow with clear boundaries |
| Task | What work is needed to create the proof? | Small implementation, doc, test, or review tasks |
| Evidence | What artifact decides pass or fail? | Test output, screenshot, fixture, PR, review note, or ledger row |

The proof is the atom. A task is only a way to produce the proof.

## Atomicity Gate

A proof atom is ready for execution only when it is:

- **Independent:** one owner can move it without waiting on unrelated work.
- **Valuable:** it proves something a user, maintainer, operator, or reviewer
  can care about.
- **Testable:** pass/fail can be decided from evidence.
- **Small:** one PR, worker lane, or review pass can handle it.
- **Observable:** the result leaves a durable artifact.
- **Rollbackable:** failure can be reverted, isolated, or handed off.
- **Single-purpose:** it has one reason to exist.

If a proposed atom fails this gate, split it before dispatching workers.

## Long Validation Gates

A validation gate expected to run longer than 180 seconds is not a single
foreground proof by default. Treat it as a parent validation proof and split it
into atomic validation lanes.

Each lane needs one command or procedure, one owner, one expected result, one
durable evidence artifact, elapsed-time evidence, and blocker classification
with a next action when it fails, skips, or times out.

The parent validation proof is accepted only after all required child lanes pass,
or after each unfinished lane is explicitly classified as blocked, rejected,
watched, waived, or tracked as not-Done with evidence. A timeout, empty output,
or missing log tail is `UNVERIFIED`, not PASS.

## Case-Based Splits

| Case | Preferred split | Required proof |
| --- | --- | --- |
| Product or UX | Vertical user flow, not UI/API/data layers | User reaches the visible state, including failure and recovery where relevant |
| Bug or debug | Reproducer -> localizer -> fixer -> verifier -> guardrail | Baseline failure, narrowed cause, minimal fix, regression proof |
| Operations | measurement, alert, rollback, runbook slice | Measured health, recovery, or readiness evidence |
| Security or data | boundary, denied path, audit trail, rollback | No secret exposure, no unauthorized action, data integrity evidence |
| Docs, rule, or skill | trigger, placement, anti-overfitting, validation | Correct surface placement and a gate or review proving it |
| Multi-agent work | parent proof, child proof, owner surface, adoption gate | Worker output is adopted by the parent, not accepted as standalone Done |
| Release or merge | PR evidence, linked issue, review, mergeability | Current PR truth and post-merge sync evidence |

## Blocker Classes

Classify a blocked proof before retrying work:

| Class | Meaning | Next split |
| --- | --- | --- |
| Spec | The required behavior or acceptance boundary is unclear | Decision or criteria proof |
| Knowledge | The agent must learn docs, code, or domain facts | Spike proof with a decision output |
| Dependency | Another system, permission, issue, or upstream state is needed | Dependency proof or exact blocked condition |
| Reproduction | The failure cannot be reproduced | Reproducer proof |
| Localization | The cause location is unknown | Diagnosis proof |
| Verification | There is no reliable pass/fail method | Test-design proof |
| Scope | The atom bundles several proof reasons | Vertical-slice fission |
| Risk | Security, data, billing, destructive, or public-release risk exists | Human decision proof or safety review proof |
| Agent drift | The agent changed scope, guessed, or optimized for task Done | Instruction or guardrail proof |
| Tooling/environment | Local tool, path, runtime, or route is wrong | Environment diagnosis and route proof |
| Review/merge | PR, review, mergeability, or sync state is stale | Release gate proof |

Most blocked atoms are agent-solvable. Human escalation is reserved for
product priority, credentials, payment, public release, destructive action,
private data movement, host-global promotion, force push/history rewrite, or
a truth/content judgment only the maintainer can make.

## Blocked Atom Fission

When an atom blocks, do not keep patching inside the same proof by guesswork.
Split from the missing proof:

1. Stop and keep the parent proof open.
2. Classify the blocker.
3. State the root cause in proof terms.
4. Name the missing evidence, decision, dependency, reproduction, localizer, or
   verification method.
5. Create child proof atoms for the gap.
6. Run the child proofs.
7. Adopt the child results back into the parent before closing it.
8. Turn repeated blocker classes into a gate, test, template, or skill update.

Useful fission sentence:

```text
Parent proof remains blocked because <class>. The proof gap is <missing fact>.
Child proofs are <ids or issue rows>. Parent closes only after those child
proofs pass and the coordinator records adoption.
```

## Mission-Control Use

`mission-control` uses this page when a broad request needs multiple tickets,
workers, or profile-specific lanes. The coordinator should:

1. state the outcome in plain language;
2. create one or more proof atoms;
3. dispatch only atoms that pass the atomicity gate;
4. keep blocked atoms visible;
5. split agent-solvable blockers into child proofs;
6. close through parent adoption, validation, and cleanup.

## One-Skill Bootstrap

When a maintainer invokes only one mission-control or Orphanless-style skill, the
coordinator must not assume that a proof board, control plane, heartbeat, or
worker ledger already exists. The first loop is a bootstrap loop:

1. identify the maintainer entry point, repository root, and requested outcome;
2. discover existing proof surfaces such as APDM rows, ledgers, issue/PR links,
   status files, dashboards, guardian/monitor records, and active owners;
3. create a minimal repo-local proof/control surface when none exists and local
   writes are allowed;
4. recover existing worker or lane results before issuing duplicate work;
5. reconcile the next proof by doing it in the parent, assigning an active
   owner, splitting a blocked atom, or recording a true human-only decision;
6. leave a durable status artifact and run the narrowest available gate.

The coordinator may not close with only a prompt, plan, handoff, or bare
`next action` row while an agent-solvable proof remains. If the platform cannot
issue workers, write status, or run the gate, that is a blocked proof with a
tooling/environment class and a concrete recovery owner, not Done.

## Parent Closeout Controller Gate

For long-running or multi-session APDM work, a parent coordinator should behave
like a small controller loop:

- **Desired state:** the APDM board or status file lists proof atoms, owners,
  dependencies, accepted evidence, and terminal conditions.
- **Actual state:** current sessions, issue or project state, artifacts, PRs,
  validation logs, and working tree state.
- **Reconcile action:** if actual state does not satisfy desired state, the
  coordinator executes the next small proof, assigns a real owner, splits the
  blocked proof, or records a true human-only decision.

A parent closeout is not valid when it contains only a plan, prompt, handoff, or
`next action` while an agent-solvable proof remains. One of these must be true:

- the proof is accepted with evidence and review;
- the proof has an active owner and freshness signal;
- the proof is split into child proof atoms with owners;
- the blocker is explicitly human-only;
- a fresh continuation controller is already active.

Use an executable gate where possible. A minimal gate checks that the status
surface has a manager or maintainer entry point, active coordinator, active
guardian or monitor when required, proof snapshot, owner or dependency for each
running/rework proof, and no orphan `next action` rows. This gate proves the
control topology, not product behavior; product behavior still needs its own
proof evidence.

## Public-Safe Boundary

This contract is intentionally generic. Do not copy private runtime paths,
private issue numbers, internal board identifiers, customer data, credentials,
or local session details into Driftless examples. Public examples should use
repo-relative paths, fixture data, and explicit `UNVERIFIED` labels when behavior
has not been proven by a real run.
