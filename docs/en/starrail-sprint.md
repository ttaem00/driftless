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

## Document organization


This convention applies to every Aemeth project, version, and executor. Its
purpose is to let the next reader find the current goal, the reason for a
decision, what was actually tried, and the original evidence without rebuilding
the history. It is a documentation convention, not a new product stage,
execution gate, approval requirement, board, or source of live execution state.

### One project entry point and distinct roles

Reuse the project's existing document entry point and owned documentation root.
For a new collection, `docs/aemeth/<goal>/README.md` is an example, not a required
literal path. The entry point maps reader questions to the relevant documents,
explains their roles, identifies current versus historical authority, and lists
old-to-new paths after moves. Keep project data in that project; shared Aemeth
definitions and skills contain the reusable convention, not project histories.

| Role / suggested directory | Content it owns |
|---|---|
| `plans/` | User outcome, scope, acceptance, dependencies, next development work, and implementation/experiment plan. |
| `design/` | Intended structure, actual producer/input/output/consumer contracts, owner boundaries, and relevant data-flow diagrams; distinguish implemented behavior from proposed changes. |
| `experiments/` | Dated attempts: hypothesis, source revision, inputs/conditions, method, observed outputs, measurements, limitations, and evidence locations; include failed and inconclusive attempts. |
| `decisions/` | Why a mechanism was retained, added, changed, combined, separated, deferred, rejected, or removed; connect before/after, alternatives, experiment evidence, tradeoffs, and superseded decisions. |
| `lessons/` | Failure conditions, first failing layer, confirmed cause versus hypothesis, correction, successful mechanisms to preserve, recurrence prevention, and conditions for reconsideration. |
| `history/` | Superseded plans/designs and dated execution instructions; historical authority is explicit, including in `history/prompts/` when needed. |
| `sources/` | An index of original evidence, exact path/ref/revision, availability and inspection limits; large/protected raw artifacts stay at their owned locations. |

Use these roles proportionately. A small task may use clearly named sections in
one existing document. Create folders and split files when content warrants it;
do not create empty trees, mandatory forms, or a new planning task to answer a
simple question. Shared contracts with independent owners retain their canonical
location and are linked from the project entry point.

Use descriptive filenames with consistent casing and separators within a
collection. Include a version only when it distinguishes a real contract;
include a date or attempt/issue identifier for frozen records. Avoid volatile
`latest`, `final`, and `current` labels on historical filenames. Keep a stable
entry pointer and meaningful document titles. A filename change is not evidence
that content has been classified or understood.

### Preserve content and maintain the connections

- Before moving or splitting, read the affected content and its incoming links;
  check current owners and concurrent edits. Never overwrite another writer's
  newer work while applying an older organizational change.
- Preserve original historical bodies, evidence, source identities, meaningful
  headings, and qualifications. Rebase links, retain old heading anchors and
  relocation notices where referenced, and verify old-to-new navigation. Replace
  exact duplicate passages with a link to one retained full copy. A summary or
  lesson index does not replace the evidence from which it was derived.
- Put a new attempt in experiments, its adoption/rejection reasoning in
  decisions, its reusable correction in lessons, and the resulting current
  requirements in plans/design. Link these records rather than repeating a
  growing execution log in every document. An unresolved item keeps its limits
  and next evidence needed; do not relabel it a rejection or proven cause.
- Retain successful mechanisms as well as failures. A past failure is not an
  unconditional ban: record the tested conditions and what would justify a
  retry. Historical prompts and old "next/current" instructions are evidence,
  not permission to resume that run or a replacement for current owner readback.
- Record missing, unread, Git-only, external, and recovered sources distinctly.
  Do not turn a broken link into a claim that its evidence was inspected or
  recovered. A search/index, documentation commit, message, implementation,
  normal execution, quality acceptance, main merge, stable adoption, and Publish
  are separate facts; report only the states supported by evidence.
- Keep transient owner/session/ref/budget status in the existing execution
  authority. Dated experiment records may bind exact snapshots for reproduction;
  do not copy those snapshots into multiple current plans as live status.
- On resume or a material change, follow the entry point to the affected plans,
  contracts, decisions, and success/failure evidence. Reuse that understanding
  while scope and evidence are unchanged; do not reread every historical file on
  every turn or copy this convention into global hooks and hot instructions.

Completion of a document reorganization requires checking preserved bodies,
changed references/anchors, discoverability, current-versus-history labels,
unresolved source locations, and preservation of newer owner changes. Report the
actual checked scope and source, main, installed-profile, and stable adoption
separately. Link and content checks establish document integrity, not product
quality or proof that every future session has read the documents.
