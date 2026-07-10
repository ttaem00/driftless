# Detachable Orphanless Control Module

Driftless includes a small public control module for teams that coordinate work
across multiple agent profiles but do not want a private registry or one vendor
to become the source of truth.

The module answers four narrow questions:

1. Is an owner a real, readable native session or only a pending handle?
2. Does that owner hold a current lease for this exact proof?
3. If a proof is blocked, which child proofs and dispatch actions exist?
4. Were all child results adopted by the parent before closeout?

It does not launch agents. A runtime-specific adapter performs native issuance,
readback, and persistence, then supplies generic evidence envelopes to the
module. This keeps product-specific paths, identifiers, credentials, and user
data outside the public contract.

## Identity envelope

A materialized owner must carry all of the following:

- a stable public `ownerKey` used by the controller;
- a native owner id and URI returned by the runtime adapter;
- successful native-session readback evidence;
- successful cwd and worktree evidence;
- a proof id, a task-card id that may name an issue, ticket, or task reference,
  and successful task readback evidence;
- an observation timestamp.

An adapter may record a pending handle while it waits for native issuance, but
that envelope resolves to `WAITING_NATIVE_THREAD_MATERIALIZATION`. It cannot be
treated as active execution.

## Proof-scoped leases

A lease binds one materialized identity digest to one proof id, with explicit
issuance, expiration, and monotonically positive revision fields. Reconcile
fails closed when the identity changes, the proof differs, the lease is not yet
active, or the lease has expired.

For a completed child, the controller validates the lease at the child
evidence's `observedAt` time. This proves the child owned the proof when it
produced evidence without forcing a finished session to renew its lease while
the parent performs a later adoption review. Future or missing child evidence
timestamps fail closed.

The module does not read the wall clock. The controller supplies an observation
time. That makes fixture replay and receipt comparison deterministic.

## Reconcile states

| State | Meaning | Required next step |
| --- | --- | --- |
| `WAITING_NATIVE_THREAD_MATERIALIZATION` | No owner exists, or only a pending handle exists. | Execute `ISSUE_NATIVE_OWNER` or `READBACK_NATIVE_OWNER`. |
| `BLOCKED_OWNER_EVIDENCE` | Native/workspace/task evidence is incomplete. | Repair the identity envelope. |
| `LEASE_REQUIRED` / `LEASE_EXPIRED` | Identity exists but proof ownership is not current. | Issue or renew a proof-scoped lease. |
| `ACTIVE` | Materialized identity and current lease both pass. | Continue the owned proof; `adoptionAllowed` remains false. |
| `BLOCKED_FISSION_REQUIRED` | An agent-solvable blocker lacks valid atomic slices. | Repair the structured fission input; do not leave a prose-only next action. |
| `BLOCKED_FISSION_IN_PROGRESS` | Child Proof IDs exist, but issuance, readback, lease, or evidence is incomplete. | Execute every structured action in the receipt. |
| `READY_FOR_PARENT_ADOPTION` | Every child proof passed, but exact parent adoption is absent. | Record adoption of the exact child set. |
| `ADOPTED` | The controller verified all child evidence and the exact adoption record. | `adoptionAllowed` becomes true; the consuming parent may evaluate its broader Done gate. |

`ADOPTED` is deliberately not root Done. It is evidence that one parent proof
accepted its children. A project, epic, or manager goal may still have other
proofs and release gates.

`adoptionAllowed` is therefore false for `ACTIVE` owners and every intermediate
state. Native ownership and parent adoption are separate decisions. Adoption
also fails closed when its timestamp predates any child evidence timestamp.

## Blocked Atom Fission

The caller supplies small semantic slices because a generic module should not
invent product meaning. The module sorts slices by key and derives stable child
Proof IDs from the parent id, blocker class, proof gap, and slice key. Each
child carries its owner key, owner mode, and acceptance statement.

The receipt never leaves an agent-solvable blocker as bare prose. It emits one
or more structured actions with a proof id, owner, owner mode, and validation
gate. Runtime adapters execute those actions and feed materialization evidence
back into the next reconcile pass.

## Deterministic receipts

Receipt input and output use recursively sorted canonical JSON and SHA-256
digests. With the same input and observation time, a caller receives the same
`inputDigest`, child Proof IDs, actions, and `receiptDigest`. The receipt schema
is `profiles/shared/schemas/orphanless-reconcile-receipt.schema.json`.

## Adapter boundary

A consuming adapter should follow this loop:

1. translate native runtime state into identity envelopes and proof outcomes;
2. call `Invoke-OrphanlessReconcile` with an explicit observation time;
3. persist the compact receipt;
4. execute each structured action through the native runtime;
5. read back native identity, workspace, task, and evidence state;
6. reconcile again;
7. accept child evidence only after the receipt reaches `ADOPTED`.

Static fixture tests prove the public state machine and deterministic contract.
They do not prove that a particular private adapter can issue or read a live
native session; that remains `UNVERIFIED` until the adapter runs its own bounded
end-to-end test.
