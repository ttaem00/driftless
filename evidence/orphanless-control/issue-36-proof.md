# Issue 36 detachable Orphanless controller evidence

## Proof boundary

- Issue: `ttaem00/driftless#36`
- Proof ID: `POD-1563-DRIFTLESS-007`
- Branch: `codex/issue-36-orphanless-control-module`
- Result boundary: this packet is child evidence for parent review. It does not
  claim that a consuming private adapter, the parent objective, or any broader
  Orphanless rollout is Done.

## Implemented public contract

- A repo-relative shared PowerShell module validates native identity envelopes,
  task/workspace readback, proof-scoped owner leases, deterministic receipts,
  Blocked Atom Fission, and exact child-set parent adoption.
- Pending handles normalize to
  `WAITING_NATIVE_THREAD_MATERIALIZATION`; they never become active owners.
- Agent-solvable blocker slices receive stable child Proof IDs and structured
  actions containing owner, owner mode, evidence gate, and proof id.
- Passing children remain `READY_FOR_PARENT_ADOPTION` until an exact adoption
  record passes. `ADOPTED` is local controller evidence, not root Done.
- Completed child evidence is checked against lease validity at the evidence
  observation time, so later parent review does not revive a finished owner.
- Schemas, adapter-neutral fixtures, documentation, a focused gate, and the
  aggregate PR gate entry ship with the module.
- Active ownership and parent adoption are separate receipt decisions:
  `adoptionAllowed` is true only for `ADOPTED`.
- Duplicate or future-dated identity evidence, invalid blocker
  classification, and adoption earlier than child evidence all fail closed.

## Verification evidence

| Gate | Status | Evidence |
| --- | --- | --- |
| `scripts/Test-OrphanlessControlModule.ps1 -Root .` | PASS | Pending-only rejection, contract-version rejection, task/proof binding, active and expired leases, deterministic receipt digest, stable fission IDs, structured issuance, missing-fission repair, delayed adoption, exact adoption, and partial-adoption rejection all passed. |
| `scripts/task.ps1 lint` | PASS | PowerShell 7 shell contract passed. PSScriptAnalyzer was not installed, so its optional analyzer pass was skipped rather than claimed. |
| `scripts/task.ps1 test` | PASS | Shell contract, no-hosted-workflow, portability, and Windows text-safety checks passed. |
| `scripts/Test-WindowsTextSafety.ps1 -Root .` | PASS | Shippable PowerShell text was ASCII/no-BOM and no PowerShell 7-fragile cmdlet use was found. |
| `scripts/Test-Containment.ps1` | PASS | Working-tree diff and untracked issue files contained no forbidden path or credential finding. |
| Isolated Codex containment guard | PASS | The public working tree contained no private path, prompt-injection, or secret finding after two wording-only false positives were removed. |
| `scripts/Test-PublicPortabilityEvidence.ps1 -Root .` | PASS | Public portability and machine-path evidence gate passed. |
| `scripts/Test-ProfileNoMachineAbsolutePaths.ps1` | PASS | Public profile and hot text contained no machine-specific absolute path. |
| `scripts/Test-PrValidationGate.ps1 -Root . -Json` | PASS | Aggregate local gate reported `pass=24`, `fail=0`; the new detachable-controller row passed. |
| `git diff --check` | PASS | No whitespace error was reported. Line-ending normalization warnings on two pre-existing tracked text files were non-failing. |

The aggregate full-file containment row covers the tracked base surface. The
separate diff/untracked containment run covers every issue-owned new file in
this packet before commit.

## Bounded no-ship review

Original problem: a detachable public controller must not confuse pending
handles with active owners, must own blocked proofs, and must prevent child
evidence from bypassing parent adoption.

Material findings fixed by the bounded review and replacement-owner recovery:

1. Identity task Proof ID was not bound tightly enough to lease/reconcile Proof
   ID. The module now rejects mismatched lease creation and routes mismatched
   reconcile identity to `REPAIR_OWNER_EVIDENCE` with the
   `IDENTITY_TASK_PROOF_MATCH` gate.
2. Parent adoption originally required a child lease to remain active at the
   later adoption time. Child PASS now carries `observedAt`, and the controller
   proves lease validity at evidence production time while rejecting future or
   missing evidence timestamps.
3. Runtime functions now fail closed on unsupported contract versions and
   missing controller/lease contract fields instead of relying on JSON Schema
   validation alone.
4. `ACTIVE` previously set `adoptionAllowed=true`, which could let a consumer
   confuse current owner execution with parent adoption. Only `ADOPTED` now
   permits adoption, and the receipt schema enforces the same invariant.
5. A missing or string-valued `agentSolvable` field could silently become a
   human-only blocker under PowerShell conversion rules. Invalid blocker
   classification now produces a structured `REPAIR_FISSION_INPUT` action.
6. Duplicate owner identities and future-dated identity evidence could be
   selected without an explicit conflict. Both now route to proof-scoped
   owner-evidence repair gates.
7. Parent adoption could predate its child evidence. The controller now checks
   adoption time against every child evidence timestamp.

Replacement-owner result after fixes: no remaining high- or medium-material
finding against the issue acceptance boundary. Speculative
defense-of-defense ideas were not promoted to blockers.

## Residual boundary

- Static/module behavior: PASS through local fixture and aggregate gates.
- Live native session issuance/readback through a consuming private adapter:
  UNVERIFIED in this public worker, by design.
- Parent adapter adoption and root objective: NOT_DONE until the parent reads
  this commit, performs its public-boundary review, adopts the module through
  its private adapter, and reruns the parent gate.

## Parent adoption gate

The parent should accept this proof only after it verifies:

1. the commit contains only issue #36 owned public files;
2. its adapter maps native session, workspace, task, lease, child outcome, and
   adoption evidence into the published schemas without copying private data;
3. pending native issuance remains waiting after adapter readback;
4. structured receipt actions are actually dispatched and reread;
5. child PASS remains evidence until the parent records adoption;
6. the parent root gate is rerun after adapter adoption.
