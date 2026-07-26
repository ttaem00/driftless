# Driftless Hermes Aemeth adapter

This is a bounded, repo-local compatibility home for the Driftless Aemeth sprint
language. It is not a full third Driftless profile.

When the manager says `Aemeth` / `에이메스`, `Stelle` / `스텔레`,
`StarrailTopology` / `스타레일 토폴로지` / `스타레일`, or `Trailblazer` /
`개척자` / `개척자Trailblazer`, load `skills/starrail-sprint/SKILL.md` and use
`shared/contract/STARRAIL_SPRINT_CONTRACT.json` as the one meaning.

The protected runtime names are `AemethExecutionLanguage`,
`StelleStepContract`, `StarrailTopologyGraph`, and `TrailblazerExecutor`. The
protected function names are `New-AemethSprint`, `New-StelleStep`,
`New-StarrailTopology`, and `Invoke-Trailblazer` (Python uses the same names
without hyphens).

Keep reads and generated receipts inside this repository. Never read or change a
host-global Hermes home, credentials, secrets, browser profiles, or user data.
A failed verification is `BLOCKED`, never PASS.

Hermes loads skills when a session starts. After installing into an already-open
Hermes session, use `/reload-skills` when available or restart that session with
this repo-local `HERMES_HOME`.
