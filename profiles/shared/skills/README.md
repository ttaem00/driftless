# Shared skills

These skills are **tool-agnostic**: authored once here, consumed by **both** the
Claude and the Codex profile. The mirror-parity gate enforces that — one edit
improves both profiles, and they cannot silently drift apart. Tool-specific
skills live under each profile (e.g. Claude's `ultracode-orchestration`, Codex's
`goal-mode`).

| Skill | What it does |
|---|---|
| **apply-driftless** | The "apply this repo to my Claude/Codex" procedure: detect the tool, dry-run the installer, ask before any MCP/dependency/plugin (default no), verify the isolated home + gates, report in plain language. Never touches host-global config. |
| **easy-briefing** | Explains status / what to decide / what to test to a non-developer in plain language, outcome-first (no jargon, no raw logs). |
| **finish-to-done** | Investigate → fix → verify → review → done, evidence-based. Doesn't stop at investigation; solves agent-fixable blockers the same session. |
| **root-goal-check** | A gate that judges any new idea/external input against the mission (reduce tokens/intervention/time/money + raise trust/applicability) before adopting it. |
| **ticket-issue** | The issue-before-edit gate: confirm or create an issue (and register it) before non-trivial work. |
| **parallel-ticket-planner** | Splits remaining work into conflict-aware parallel tickets with paste-ready prompts; teaches infinite-mode + a periodic audit lane for long runs. |
| **student-autopilot** | Lets a non-developer student or maintainer ask in one sentence while the agent internally routes ticketing, long-session guardrails, parallel/overnight planning, validation, PR, and merge work. |
| **learning-loop** | Records recurring problems and promotes confirmed lessons up the enforced ladder (memory < skill < hot rule < hook < gate). |
| **goal-pair-guardian** | 목표동행: checks long autonomous goals for drift, early stopping, missing evidence, and continuation/new-session routing. |
| **adopt-external-tool** | Vet an external repo/tool before applying it: trust + maintenance + license + security checks, ADOPT/PILOT/WATCH/DO_NOT verdicts, lean-by-default. |
| **safety-guard** | Checks secret, host-global, credential, billing, public-release, destructive-action, and user-data risk so the manager does not inspect raw security logs. |
| **review-before-done** | Reviews bugs, regressions, safety, and missing evidence before PR_READY, merge, issue close, or release. |
| **work-ledger** | Turns vague work into visible success criteria and evidence rows the manager can understand. |
| **handoff-guard** | Keeps long or overnight runs resumable with compact state, exact evidence, and no raw logs. |

A skill is just a folder with a `SKILL.md` (frontmatter `name` + `description`
with triggers, then the procedure). To add one that both tools should have, put
it here; the mirror-parity gate and the allowlist
(`../schemas/mirror-parity-allowlist.json`) keep both profiles consuming it.
