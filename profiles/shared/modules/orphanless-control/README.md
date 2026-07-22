# Detachable Orphanless Control Module

This public-safe PowerShell module is a pure reconciliation boundary for
cross-profile owner identity, proof-scoped leases, deterministic receipts, and
Blocked Atom Fission. It does not launch a particular agent runtime and it does
not read a registry, credential store, browser state directory, or user directory.

Private or product-specific adapters may translate their native session and
worktree evidence into the generic input contract. The adapter is also
responsible for executing structured receipt actions such as
`ISSUE_NATIVE_OWNER` and feeding the resulting identity envelope back into the
next reconcile call.

## Exported functions

- `Test-OrphanlessIdentityEnvelope` rejects pending-only or incomplete owner
  evidence as materialized identity.
- `New-OrphanlessOwnerLease` binds a materialized identity digest to one proof
  and an explicit expiration time.
- `Test-OrphanlessOwnerLease` fails closed for an identity mismatch, proof
  mismatch, invalid timestamp, or expired lease.
- `New-OrphanlessFissionPlan` converts named proof gaps into stable child Proof
  IDs, independent of array order.
- `Invoke-OrphanlessReconcile` compares desired and actual state and emits a
  canonical receipt with structured actions. The caller supplies `-At`, so the
  same input and observation time produce the same receipt digest.

## Non-negotiable invariants

1. `PENDING` is `WAITING_NATIVE_THREAD_MATERIALIZATION`, never `ACTIVE`.
2. Active ownership requires one unique native identity, non-future identity
   readback, task readback, cwd/worktree evidence, and an unexpired proof-scoped
   lease. Active ownership does not set `adoptionAllowed`.
3. An agent-solvable blocker with fission slices creates stable child Proof IDs
   and structured issuance/readback/lease/continuation actions.
4. Passing child evidence is not parent Done. The receipt remains
   `READY_FOR_PARENT_ADOPTION` until an exact child-set adoption record passes
   after every child evidence timestamp.
5. Completed child evidence is checked against lease validity at the child's
   evidence observation time; later parent adoption does not revive a finished
   owner merely to renew its lease.
6. `ADOPTED` is local controller evidence only. A consuming parent still owns
   its broader acceptance and Done boundary.

Import the module from a repo-relative path:

```powershell
Import-Module ./profiles/shared/modules/orphanless-control/OrphanlessControl.psm1 -Force
$receipt = Invoke-OrphanlessReconcile -InputObject $input -At '2030-01-01T00:05:00Z'
```

Run the focused contract gate:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File ./scripts/Test-OrphanlessControlModule.ps1
```

Before packaging or after updating, verify that every public module, schema,
and guide still matches the reviewed release manifest:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File ./scripts/Sync-OrphanlessControlReleaseManifest.ps1
```

Maintainers update hashes only after reviewing the package change by adding
`-Write`. The verifier rejects missing files, files added inside the managed
module without a manifest entry, and changed content with a stale hash.
