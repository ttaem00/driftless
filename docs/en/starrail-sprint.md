# Starrail Sprint

Starrail Sprint is a small shared vocabulary for an evidence-based work run.
It gives Claude, Codex, and a bounded Hermes adapter the same four meanings
without asking a student to learn separate orchestration systems:

- **Stelle** is one bounded step.
- **StarrailTopology** is the dependency-safe order of those steps.
- **Aemeth** is the verification gate that stops failed evidence.
- **Trailblazer** runs the topology and prints one receipt.

Run the included public-safe three-step example:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-StarrailSprint.ps1 -TopologyPath .\examples\starrail-sprint\topology.pass.json -ContractPath .\.runtime\codex-home\shared\contract\STARRAIL_SPRINT_CONTRACT.json -ReceiptPath .\.runtime\starrail-sprint\receipt.json
```

`Invoke-AemethSprint.ps1` is a second command name for the same runner. Tests
require both commands to return the same receipt.

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
that same contract and shared skill into the two full isolated profiles. The
installer can also put this one skill, contract, and all protected aliases into
the bounded repo-local Hermes Aemeth home with `-Tool hermes` / `--hermes`.
`hermes-worker` consumes the same public JSON fields. The Hermes adapter is not
a full third Driftless profile.
