---
name: starrail-sprint
description: >
  starrail-sprint: Use when a maintainer says Aemeth/에이메스, Stelle/스텔레,
  StarrailTopology/스타레일 토폴로지/스타레일, or
  Trailblazer/개척자/개척자Trailblazer, Starrail Atlas/스타레일 아틀라스;
  also use for an ordered verification topology, deterministic receipt, Hermes
  adapter session, or Hermes worker handoff.
---

## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Prefer
principle-based guidance that generalizes; avoid spec/case overfitting and
special-casing unless evidence proves the bounded exception reduces user or
maintainer effort, time, cost, recurrence risk, or maintenance burden.

# Starrail Sprint

Use the installed `shared/contract/STARRAIL_SPRINT_CONTRACT.json` as the single
meaning and compatibility authority. Claude and Codex receive this exact skill
and contract as full Driftless profiles. Hermes receives the same files through
the bounded repo-local Aemeth adapter home.

## Starrail Atlas boundary

`Starrail Atlas` / `스타레일 아틀라스` is the contract's non-executable companion
projection. It may read existing public-safe state and show goals, plans, routes,
current work, owners, evidence, review, blockers, and the next action to a
manager or LLM. It is freshness-labelled and `projection-only`: it does not
schedule or mutate work and is never a source of truth.

An Atlas request must not run `Trailblazer`, call either sprint runner, or emit a
`trailblazer-run-receipt.v1` receipt. Use the execution steps below only when the
maintainer explicitly asks to build or run a Starrail sprint/topology.

1. Model each bounded step as a `Stelle` with explicit dependencies and evidence.
2. Put the steps in one acyclic `StarrailTopology`.
3. Let `Aemeth` reject missing or failed verification.
4. Run `Trailblazer` and report the resulting receipt; never rewrite a blocked
   receipt as success.

Normal repository command:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-StarrailSprint.ps1 -TopologyPath .\examples\starrail-sprint\topology.pass.json -ContractPath .\.runtime\codex-home\shared\contract\STARRAIL_SPRINT_CONTRACT.json -ReceiptPath .\.runtime\starrail-sprint\receipt.json
```

`scripts/Invoke-AemethSprint.ps1` is a compatibility name for this exact same
runner. It must produce the same receipt and must not become a second runtime.

The receipt's `compatibility.worker_role` and `compatibility.route` fields are
portable adapter data for `hermes-worker`. Driftless also offers a bounded
Hermes Aemeth adapter home; it is not a full third Driftless profile and does
not authorize peer-agent execution.

## Document organization across projects


For every Aemeth, reuse one project-owned document entry point and organize
records by role: plans (goal/acceptance), design (contracts/data flow),
experiments (dated attempts and evidence), decisions (why changed), lessons
(failures, corrections, successful mechanisms, retry conditions), history
(superseded plans/prompts), and sources (original locations and gaps).
The repository guide is `docs/en/starrail-sprint.md#document-organization`;
these self-contained roles also apply in installed profiles and projects using
different paths. Small tasks may use sections in an
existing document; create no empty folder tree or extra workflow stage.
Preserve original content, provenance, newer owner edits, old anchors and
relocation links. Consolidate exact duplicates into one retained full copy.
Connect each attempt to its decision, lesson and current plan; keep historical
instructions distinct from live authority and mark unread/missing sources.
Use descriptive filenames, update the entry map after moves, and check body
preservation and links. On resume read relevant changes and evidence, not all
history each turn. Documentation, delivery, implementation, quality acceptance,
main and stable adoption remain distinct. A status/explanation request stays
read-only; this convention adds no execution or approval gate.
