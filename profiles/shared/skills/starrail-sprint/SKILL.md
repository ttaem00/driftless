---
name: starrail-sprint
description: >
  starrail-sprint: Use when a maintainer asks for a bounded Aemeth, Stelle,
  StarrailTopology, and Trailblazer evidence sprint, an ordered sprint,
  verification-gated topology, deterministic receipt, or Hermes-compatible
  worker handoff without adding another agent profile.
---

## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Prefer
principle-based guidance that generalizes; avoid spec/case overfitting and
special-casing unless evidence proves the bounded exception reduces user or
maintainer effort, time, cost, recurrence risk, or maintenance burden.

# Starrail Sprint

Use the installed `shared/contract/STARTRAIL_SPRINT_CONTRACT.json` as the single
meaning and compatibility authority. Both Claude and Codex receive this exact
skill and contract from the Driftless installer.

1. Model each bounded step as a `Stelle` with explicit dependencies and evidence.
2. Put the steps in one acyclic `StarrailTopology`.
3. Let `Aemeth` reject missing or failed verification.
4. Run `Trailblazer` and report the resulting receipt; never rewrite a blocked
   receipt as success.

Normal repository command:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-StarrailSprint.ps1 -TopologyPath .\examples\starrail-sprint\topology.pass.json -ContractPath .\.runtime\codex-home\shared\contract\STARTRAIL_SPRINT_CONTRACT.json -ReceiptPath .\.runtime\starrail-sprint\receipt.json
```

The receipt's `compatibility.worker_role` and `compatibility.route` fields are
portable adapter data for Hermes or `hermes-worker`. They do not create a third
Driftless profile and do not authorize peer-agent execution.
