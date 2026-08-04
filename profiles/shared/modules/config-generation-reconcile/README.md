# Config generation reconcile

This detachable shared module reconciles three explicit states before an updater
activates generated configuration:

- `base`: the official version from which the user customization started;
- `user`: the currently customized version;
- `target`: the newly generated official version.

The module writes only a candidate and a receipt. It never changes the active
file. Non-overlapping UTF-8 text changes use Git's three-way merge. Same-region
or binary divergence is held for review with no candidate, so an updater cannot
silently replace user work. The caller owns candidate validation, activation,
generation retention, and rollback.

```powershell
Import-Module ./profiles/shared/modules/config-generation-reconcile/ConfigGenerationReconcile.psm1
Invoke-DriftlessConfigGenerationReconcile `
  -BasePath ./state/base.txt `
  -UserPath ./active/config.txt `
  -TargetPath ./build/config.txt `
  -CandidatePath ./build/candidate.txt `
  -ReceiptPath ./state/reconcile.json `
  -GenerationId 2026-08-04T150000Z `
  -RollbackPath ./generations/previous/config.txt
```

The receipt uses `driftless.config-generation-reconcile.v1` and records hashes,
the decision, and whether a candidate is ready. Paths may be made relative or
redacted by a product adapter before publishing the receipt.
