---
name: starrail-sprint
description: >
  starrail-sprint: Use when a maintainer says Aemeth/에이메스, Stelle/스텔레,
  StarrailTopology/스타레일 토폴로지/스타레일, or
  Trailblazer/개척자/개척자Trailblazer; also use for an ordered verification
  topology, deterministic receipt, or metadata-only Hermes worker handoff.
---

## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Prefer
principle-based guidance that generalizes; avoid spec/case overfitting and
special-casing unless evidence proves the bounded exception reduces user or
maintainer effort, time, cost, recurrence risk, or maintenance burden.

# Starrail Sprint

Use the installed `shared/contract/STARRAIL_SPRINT_CONTRACT.json` as the single
meaning and compatibility authority. Both Claude and Codex receive this exact
skill and contract from the Driftless installer.

1. Model each bounded step as a `Stelle` with explicit dependencies and evidence.
2. Put the steps in one acyclic `StarrailTopology`.
3. Let `Aemeth` reject missing or failed verification.
4. Run `Trailblazer` and report the resulting receipt; never rewrite a blocked
   receipt as success.

Normal repository command:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-StarrailSprint.ps1 -TopologyPath .\examples\starrail-sprint\topology.pass.json -ContractPath .\.runtime\codex-home\shared\contract\STARRAIL_SPRINT_CONTRACT.json -ReceiptPath .\.runtime\starrail-sprint\receipt.json
```

The receipt's `compatibility.worker_role` and `compatibility.route` fields are
portable adapter data for Hermes or `hermes-worker`. They do not create a third
Driftless profile and do not authorize peer-agent execution.
