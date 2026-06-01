# Changelog

All notable changes to Driftless are recorded here. Dates are ISO (YYYY-MM-DD).

## [Unreleased]

Work since v0.1.0, merged in the open (this repo maintains itself — each item is
a merged PR you can browse). Not tagged as a new version yet.

### Added
- **apply-driftless skill** — "apply this repo to my Claude/Codex" is now a real
  procedure both profiles follow (detect tool, dry-run, ask-before-install, verify
  the isolated home + gates, report in plain language).
- **5-minute non-developer quickstart** (EN + KO): clone → installer → start agent
  → one prompt → morning report, with honest limits.
- **SECURITY.md** and **CODE_OF_CONDUCT.md**.
- **docs/codex-and-claude** (EN + KO) — how each tool uses Driftless (Codex goal
  mode vs Claude dynamic workflow / ultracode) and the shared core.
- **docs/how-driftless-learns** (EN + KO) — the lesson-promotion ladder, the five
  axes trending down, **model-specific mistake learning** (Codex and Claude fail
  differently, so each is optimized per profile), and an honest lessons changelog.
- **Both-tool infinite maintainer loop**: `profiles/codex/prompts/infinite-goal.md`
  (Codex goal) and `profiles/claude/prompts/infinite-workflow.md` (Claude
  workflow + schedule + audit) — same shared rules/gates, tool-specific mechanism.
- **adopt-external-tool skill** + safe-adoption guide (EN + KO) — vet an external
  repo before applying it.
- **GitHub issue + PR templates** — non-developer task-request, bug-report, and a
  gate-aware PR template.
- **evidence/loop-log** and a **redacted development-runtime PR list** — the
  private method-proof numbers vs this repo's public, growing graph, side by side.
- README: a five-axis gradient section, a day-one honesty banner, and a maintainer
  declaration (MAINTAINERS.md).

- **Test-SkillAudit gate** — a 6th gate that holds every shipped `SKILL.md` to
  structural soundness (name matches its folder, a non-empty description with a
  trigger signal) so a skill can never land that silently never fires. Ships the
  skillspector *idea* (scan a skill before you trust it) in the lean in-repo
  form, with a `-SelfTest` that proves it FAILs on planted-bad fixtures.
- **work-discipline gate** + **overnight reversibility / retry-safety gate** —
  mechanical checks that an unresolved placeholder cannot ship as a rule, and
  that a recovery retry stays reversible (12-factor-agents principles, adopted
  in the lean in-repo form).
- **Measured real-use verification** — a fresh-clone non-developer path timed
  end-to-end (~16s), plus a real captured 60-second-proof demo transcript.
- **Navigation** — a docs index and a shared-skills index for onboarding.
- **Honest skill count** — the public kit ships 12 starter skills (8 shared +
  1 Claude + 1 Codex + 2 standalone), now stated consistently in both READMEs
  with a verify command that counts the whole repo.

### Changed
- The single-source mirror is populated with real shared skills; the mirror-parity
  gate now enforces them (13 checks).
- CI runs the gates on Windows **and** Linux (containment + installer smoke), and
  the README CI badge reflects live status instead of a hardcoded "passing".
- **Onboarding parity (EN/KO)** — install commands are ZIP-safe (`sh ./install.sh`),
  the Korean README and quickstart carry the same `git clone` + start-command
  steps as English, and the README points to the full prompt's safety clause.
- A cache-stable hot-prefix discipline and a meaning-preserving compression of
  the largest skill keep the per-run token cost down.

### Removed
- Internal application/promotion strategy docs are kept private (not in the public
  tree or its history) — the public repo shows a product, not a prize application.

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
