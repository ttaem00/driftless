# Driftless gates

Two small, self-contained PowerShell gates that prove Driftless is
**containment-first**: the repo never reads or writes a forbidden path, never
leaks a credential, and never ships a Windows-fragile script. They are read-only
(no network, no secrets, no host-global access) and run the same on Windows
PowerShell 7 and PowerShell 7.

| Gate | What it proves | FAILs when |
| --- | --- | --- |
| `Test-PrValidationGate.ps1` | One manager-facing local PR validation entry point exists for agents and maintainers. | Any required repo-local gate below fails or the aggregate wrapper cannot run it. |
| `Test-Containment.ps1` | The code base never touches a forbidden path or leaks a secret. | A scanned file's own path is forbidden, references a forbidden path, or contains a credential token. |
| `Test-WindowsTextSafety.ps1` | Every shippable script parses identically on PowerShell 7. | Any `.ps1` / `.bat` / `.cmd` has a non-ASCII byte or a UTF-8 BOM. |
| `Test-AgentRuntimeHealth.ps1` | The agent is not trying to repair the product from a broken Codex runtime. | Repo-local Codex uses elevated Windows sandbox, has sandbox setup errors, or recent Codex 400/self-error markers. |
| `Test-ImprovementPrincipleDiscipline.ps1` | The shared root-cause / principle-based / no-overfit rule remains present and wired into shipped skills, learning-loop, finish-to-done, local gate docs, and PR guidance. | A rule/skill surface drops the improvement principle, or the gate stops being part of normal review. |
| `Test-HotContextDiscipline.ps1` | Hot rules stay small instead of moving always-loaded instructions into helper docs or every-task skills. | `AGENTS.md` / `CLAUDE.md` gets too large, always loads another instruction file, or a skill claims every-task scope. |
| `Test-ContextEngineeringDiscipline.ps1` | The shared context budget, compressed reference integrity, repo map freshness, and action/evidence ledger contract remains present, skill-wired, and documented as a local closeout gate. | The shared contract, handoff/ledger skills, or local gate docs drop those context-management anchors. |
| `Test-MissionControlCloseoutBoundary.ps1` | Mission-control and finish-to-done preserve parent closeout inventory and long command evidence before Done claims. | A shared closeout skill drops the parent-vs-child Done boundary, long command evidence, or aggregate PR-gate wiring. |
| `Test-WorkerFailureRecoveryContract.ps1` | Multi-lane skills keep worker capacity, context-window, and partial-output failures as recovery states, not Done. | A shared worker skill drops `worker_recovery_inventory` or the retry states needed before closeout. |
| `Test-CodeIntelligenceBenchmark.ps1` | The compiled context wiki remains useful enough to test code-intelligence ideas before installing external tools. | The wiki cannot build, average recall falls below the floor, token direction regresses, or source-traceability validation fails. |
| `Test-SkillAudit.ps1` | Shipped SKILL.md files are discoverable and their runnable repo-local `.ps1` command references exist. | A skill has broken frontmatter, a name/folder mismatch, no trigger signal, or a runnable command pointing at a missing repo-local script. |
| `Test-CompressedHandoffSummaryProtocol.ps1` | A compressed handoff/protocol summary keeps source pointer, scope, exclusions, manager-only gates, validation evidence, stale-map status, and next executable action. | The fixture drops one of those load-bearing fields, points outside the repo, or carries unusable evidence/action state. |
| `Test-MissionMapFixture.ps1` | The public Mission Map fixture has the required manager-visible fields and no private path/session/credential markers. | The fixture misses active goal, guardian, PR/check state, blockers, evidence, next action, or includes private runtime markers. |
| `Test-ExternalAdoptionSafetyGate.ps1` | External skills/repos/MCP packets are not treated as adoption-ready until static danger strings and adoption-lane closeout are checked. | A candidate has unresolved arbitrary exec, download-pipe-exec, host-global/secret refs, credential/cloud/billing/MCP surfaces, daemon startup, a truncated scan, or missing pilot closeout decisions. |
| `Test-PublicExportClassifier.ps1` | Private lessons, prompts, notes, or workflow examples are classified before being copied into public Driftless surfaces. | A candidate is shared-internal, needs sanitizing, is private-only, needs a manager publication decision, is empty, or the classifier self-test regresses. |

## Run them

```powershell
# Aggregate PR validation: preferred before PR_READY / merge.
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-PrValidationGate.ps1

# Containment: scan the working-tree diff and untracked files (pre-commit default)
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-Containment.ps1

# Containment: scan every tracked file (full audit)
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-Containment.ps1 -AllFiles

# Containment: prove detection on a single fixture file (no exemptions applied)
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-Containment.ps1 -File path\to\fixture.txt

# Windows text safety: every tracked .ps1 / .bat / .cmd
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-WindowsTextSafety.ps1

# Agent runtime health: stop early if the agent itself is broken
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-AgentRuntimeHealth.ps1

# Improvement principle: keep root-cause/no-overfit discipline in shared guidance and shipped workflow surfaces
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-ImprovementPrincipleDiscipline.ps1

# Hot context: prevent AGENTS.md/CLAUDE.md bloat by indirection
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-HotContextDiscipline.ps1 -Root .

# Context engineering: keep compressed/resumed work verifiable
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-ContextEngineeringDiscipline.ps1 -Root .

# Mission-control closeout boundary: keep parent Done separate from child Done and require long command evidence
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-MissionControlCloseoutBoundary.ps1 -Root .

# Code intelligence: benchmark compiled wiki usefulness before external tool adoption
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-CodeIntelligenceBenchmark.ps1 -Root .

# Skill audit: keep shipped skill routing and runnable repo-local commands honest
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-SkillAudit.ps1 -Root .

# Compressed handoff protocol fixture: prove resumable summaries keep executable context
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-CompressedHandoffSummaryProtocol.ps1 -Root .

# Mission Map: validate the public-safe orchestration UI fixture
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-MissionMapFixture.ps1

# External adoption safety: prove the public-safe pre-adoption gate has teeth
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-ExternalAdoptionSafetyGate.ps1 -SelfTest

# Public export classifier: prove private-to-public routing has teeth
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-PublicExportClassifier.ps1 -SelfTest
```

Add `-Json` to any gate that supports it for a machine-readable summary.

## What `Test-ImprovementPrincipleDiscipline.ps1` checks

This read-only gate verifies that the public shared contract still carries the
root-cause / principle-based / no-overfit rule and that `AGENTS.md` still points
agents at it. It also checks the behavior-shaping surfaces that make the rule
fire in normal work: every shipped SKILL.md has the compact Improvement
Principle section, learning-loop still promotes recurring lessons to the
smallest public-safe surface, finish-to-done still blocks substitute Done, local
gate docs keep the command visible, and the PR template asks for
root-cause/principle evidence when rules, skills, prompts, scripts, hooks, or
docs change.

It is structural evidence only; behavioral improvement claims still need real
workflow evidence.

## What `Test-HotContextDiscipline.ps1` checks

This read-only gate keeps hot context honest: `AGENTS.md` / `CLAUDE.md` must stay
small, must not always read or load another long instruction file, and shipped
skills must not declare every-task triggers. Conditional references such as "for
UI work, read `docs/design/DESIGN.md`" remain valid on-demand routing.

## What `Test-ContextEngineeringDiscipline.ps1` checks

This read-only gate verifies that the shared contract still contains four public
context-management disciplines: context budget, compressed reference integrity,
repo map freshness, and action/evidence ledger. It also verifies that handoff
and work-ledger skills carry the operational guidance, and this gate is
documented here as a local closeout command. It is structural evidence only; a
workflow claim still needs current command or tool evidence.

## What `Test-MissionControlCloseoutBoundary.ps1` checks

This read-only gate keeps large-goal closeout honest. It verifies that
mission-control and finish-to-done keep child ticket completion separate from
parent Done through a parent closeout inventory, and that long or quiet commands
need long command evidence before they can support PASS, FAIL, merge, or Done.

It is structural evidence only. The parent goal still needs current issue/PR,
process, validation, and merge evidence before final closeout.

## What `Test-CodeIntelligenceBenchmark.ps1` checks

This public-safe benchmark uses the compiled context wiki as the local
code-intelligence baseline before installing any external repo-map, memory, MCP,
or semantic-search tool. It compares broad baseline discovery against wiki
search on four fixed Driftless tasks, then gates average recall, token-estimate
direction, and source-traceability validation through `Test-RepoContextWiki.ps1`.

It is an adoption guard, not a vendor benchmark. PASS means Driftless has a
small local measurement path and should keep using the compiled wiki first.
External tools remain `PILOT_ONLY` or `WATCH_LATER` until they beat this local
path without adding credential, cloud, daemon, or host-global risk.

## What `Test-SkillAudit.ps1` checks

This read-only gate keeps shipped skills from looking valid while failing at
runtime. It checks every tracked `SKILL.md` under `profiles/` and `skills/` for
frontmatter, name/folder match, trigger signal, and runnable repo-local `.ps1`
command examples under `scripts/`, `profiles/`, `skills/`, or `shared/`.

Plain prose mentions and generated host/runtime paths are out of scope. If a
workflow is not wired yet, the skill should say that plainly instead of giving a
runnable command for a missing helper.

## What `Test-ExternalAdoptionSafetyGate.ps1` checks

This public-safe gate is a small SkillSpector/SkillOpt-style transform: it does
not install external scanners or import a full external runtime. It scans a
bounded local candidate path for danger strings, host-global/secret references
from the shared containment schema, credential/cloud/billing/MCP surfaces,
global installs, and daemon/container startup. It can also validate an
adoption-lane ledger with `Test-AdoptionLaneCloseout.ps1` so pilots do not end
as "we tried it" without adopt/scale/watch/reject/block/manager-only closeout.

Use it before direct adoption:

```powershell
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-ExternalAdoptionSafetyGate.ps1 -CandidatePath path\to\candidate
```

Static PASS is not a behavioral safety claim. It means the bounded pre-adoption
gate found no unresolved string/closeout blockers in the scanned surface.

## What `Test-PublicExportClassifier.ps1` checks

This pre-publication classifier is for moving lessons, prompts, notes, issue
summaries, or workflow examples from private work into Driftless. It scans only
the explicit text or bounded path you pass and reuses the shared containment
schema. It classifies candidates as:

- `public-safe` -- no detected private markers; normal review can continue.
- `shared-internal` -- useful internally, but rewrite for public users first.
- `sanitize-first` -- remove machine paths, credential labels, or private
  references, then rerun.
- `private-only` -- raw logs, transcripts, customer/student data, private
  policy, or secret-like material; do not publish.
- `manager-only-decision` -- publication/copy-to-public requests need maintainer
  approval even when the text is otherwise clean.

Use it before copying private-derived material into public docs:

```powershell
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-PublicExportClassifier.ps1 -Path path\to\candidate.md
```

Only `public-safe` exits 0. A blocked result is a routing decision, not a
judgment that the idea is bad.

Exit codes: `0` = PASS, `1` = FAIL, `2` = BLOCKED (containment gate only, when
the target is not a git repository -- reported BLOCKED, never a silent PASS).

## What `Test-Containment.ps1` checks

The forbidden surface is the single shared rule set at
`profiles/shared/schemas/forbidden-paths.json` (one source of truth, applied to
both tool profiles). It blocks:

- `.env` / `.env.*` environment-secret files
- `.ssh` directories (private SSH material)
- `secrets/` directories
- private keys (`*.pem` / `*.key`)
- browser profiles / credential stores (`Login Data`, `Cookies`, `chrome-profile`)
- the host-global agent homes `~/.claude` and `~/.codex`
- leaked credential tokens: GitHub (`ghp_` ...), Anthropic (`sk-ant-` ...),
  OpenAI-style (`sk-` ...), AWS (`AKIA` ...), and inline `PRIVATE KEY` blocks

Three finding classes are reported:

- `forbidden_path` -- the scanned file's **own** path is forbidden. Its contents
  are never read.
- `forbidden_reference` -- a file's text references a forbidden path (reads or
  writes it).
- `forbidden_secret` -- a file's text contains a credential token.

**Containment invariant:** the gate never opens a forbidden / secret file. A file
whose own path is forbidden is flagged purely by its path.

**Reference exemption:** documentation and the gate infrastructure (`*.md`,
`.github/**`, `tests/**`, the `schemas/` folder, `.gitignore` / `.gitattributes`,
and the gate scripts themselves) may legitimately *name* a forbidden path to
describe or enforce the boundary, so `path`-rule content references are not
flagged there. The own-path check and **all** secret rules are never exempted, so
a real leaked credential is caught even inside a doc. The repo-local, gitignored
`.claude/` / `.codex/` runtime home is exempt from the own-path check only -- a
content reference to the host-global `~/.claude` / `~/.codex` still FAILs.

## What `Test-WindowsTextSafety.ps1` checks

1. **ASCII + no BOM** for every tracked `.ps1` / `.bat` / `.cmd`. Windows
   PowerShell 7 and `cmd.exe` read a BOM-less UTF-8 file as legacy CP1252, so a
   stray em dash, curly quote, or non-Latin character corrupts the bytes and
   breaks the parse.
2. **No PS 5.1-fragile cmdlets** -- a live (non-comment) use of a cmdlet that can
   be absent on the constrained 5.1 host (for example `Get-FileHash`) is flagged
   so it does not fail only at runtime.
3. **Forward-slash hook paths** -- any tracked `settings.json` must declare hook
   `command` paths with forward slashes, never backslashes, which collapse on
   Windows and can freeze the desktop agent host.

Both gates are ASCII-only and BOM-free, so each one passes its own text-safety
rule.
