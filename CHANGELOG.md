# Changelog

All notable changes to Driftless are recorded here. Dates are ISO (YYYY-MM-DD).

## v0.1.0 — 2026-06-01

First public cut. Driftless is the self-improving, containment-first environment
that runs overnight maintainer-automation across Claude Code AND OpenAI Codex
from one source of truth.

### Added
- **Single-source two-profile mirror** (`profiles/shared/` consumed by both
  `profiles/claude/` and `profiles/codex/`) — one edit improves both profiles.
- **Containment gate** (`scripts/Test-Containment.ps1`) — proves the repo never
  reads or writes a forbidden path (host-global `~/.claude` / `~/.codex`, `.env`,
  `.ssh`, secrets, private keys, browser profiles) and never leaks a credential.
  Proven in both directions: PASS on a clean tree, FAIL on a planted violation.
- **Mirror-parity gate** (`scripts/Test-ProfileMirrorParity.ps1`) — FAILs when
  the two profiles drift apart, so they never silently diverge.
- **Windows text-safety gate** (`scripts/Test-WindowsTextSafety.ps1`) — enforces
  ASCII + no-BOM on `.ps1` / `.bat` / `.cmd` so Windows PowerShell 5.1 parses them.
- **Skill-optimization validation harness** (`scripts/Test-SkillOptValidationHarness.ps1`)
  — static, no-paid-LLM 5-axis (tokens / manager-intervention / time / money /
  performance) baseline-vs-candidate scoring that REJECTS regressions.
- **overnight-autonomous-work skill** — the parent/worker bundle: one prompt
  surveys open work, runs parallel workers, self-recovers, merges PRs, and
  escalates only risk/permission/product decisions.
- **skillopt skill** — gradient-descent skill optimization via the static harness.
- **Cross-platform installers** (`install.sh`, `install.ps1`) — materialize an
  isolated, repo-local agent home and ASK before installing any MCP server,
  plugin, or dependency (default NO).
- **KO + EN docs** under `docs/` and a public `evidence/` tree (overnight runs,
  5-axis ROI, a fully-climbed lesson-promotion-ladder example).
- MIT license, containment-first `.gitignore`, CRLF policy for Windows scripts.

### Honest status
- Windows PowerShell 5.1: all gates verified PASS (and FAIL on negative fixtures).
- macOS / Linux: the POSIX `install.sh` path runs; the PowerShell gates require
  PowerShell — see `docs/en/host-evidence-matrix.md`. Anything not yet run on a
  host is labeled UNVERIFIED rather than claimed.
