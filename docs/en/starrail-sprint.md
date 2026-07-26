# Starrail Sprint

Starrail Sprint is a small shared vocabulary for an evidence-based work run.
It gives Claude and Codex the same four meanings without asking a student to
learn two orchestration systems:

- **Stelle** is one bounded step.
- **StarrailTopology** is the dependency-safe order of those steps.
- **Aemeth** is the verification gate that stops failed evidence.
- **Trailblazer** runs the topology and prints one receipt.

Run the included public-safe three-step example:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-StarrailSprint.ps1 -TopologyPath .\examples\starrail-sprint\topology.pass.json -ContractPath .\.runtime\codex-home\shared\contract\STARRAIL_SPRINT_CONTRACT.json -ReceiptPath .\.runtime\starrail-sprint\receipt.json
```

The command returns zero only when every required verification passes. The
negative fixture at `examples/starrail-sprint/topology.fail.json` proves the
runner stops before a dependent step when Aemeth rejects evidence.

Receipt writes are restricted to the generated evidence subtree
`.runtime/starrail-sprint`. Topology and contract inputs may be read only from
inside the repository. A source file such as `README.md` cannot be used as a
receipt target, even through the direct Python entry point.

The language contract is `aemeth-sprint.v1`, its subordinate topology document
is `starrail-topology.v1`, and durable runs use
`trailblazer-run-receipt.v1`. These names match the portable cross-project wire
contract and are asserted by the installed-profile test.

The canonical meanings and adapter fields live once in
`profiles/shared/contract/STARRAIL_SPRINT_CONTRACT.json`; installation copies
that same contract and shared skill into both isolated homes. Public JSON fields
can be consumed by Hermes or `hermes-worker`, but Driftless still ships exactly
two profiles: Claude and Codex.
