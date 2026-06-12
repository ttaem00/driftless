# Single source, two profiles: how one edit updates both

Driftless runs **two** AI tools — Claude Code and Codex — but it does **not**
keep two copies of the rules they share. There is one shared source of truth, and
both profiles read it. Change it once and both tools improve at the same moment.
A **mirror-parity gate** turns that promise into a machine check, so the two
profiles can never quietly drift apart.

This is the "Driftless" half of the name applied to the toolchain itself: the two
tool profiles never diverge. (The other half — the agent never wanders off your
goal — is covered in [What is Driftless?](./what-is-driftless.md).)

---

## The shape: shared + tool-specific

A built profile is **shared rules plus only-what-is-different**. Anything that is
identical for both tools lives in `profiles/shared/` exactly once. Each profile
adds only the genuinely tool-specific parts.

```
driftless/
|
|-- profiles/
|   |
|   |-- shared/                         THE ONE SOURCE OF TRUTH
|   |   |-- contract/                     - design contract (vocabulary,
|   |   |     SHARED_DESIGN_CONTRACT.md       evidence statuses, report labels,
|   |   |                                     manager-only gates, isolation rules)
|   |   |-- schemas/                       - forbidden-paths.json (one machine-
|   |   |     forbidden-paths.json            readable safety surface)
|   |   |     mirror-parity-allowlist.json - declares what is shared vs
|   |   |                                     deliberately tool-specific
|   |   |-- skills/                        - tool-agnostic shared skills
|   |
|   |-- claude/   = shared  +  Claude-specific
|   |               (CLAUDE.md hot-rules filename, Claude skill format,
|   |                settings.json hooks, .claude/commands/ slash commands,
|   |                CLAUDE_CONFIG_DIR launcher mechanic, model/effort defaults)
|   |
|   |-- codex/    = shared  +  Codex-specific
|                   (AGENTS.md hot-rules filename, Codex skill format,
|                    prompts/, CODEX_HOME launcher mechanic, model/effort defaults)
|
|-- scripts/
    |-- Test-ProfileMirrorParity.ps1     the gate that enforces no-drift
```

Both profiles consume the shared tier **by relative path** (each profile's
`README.md` points at `../shared/...`). They do not copy it. So there is only one
copy of each shared rule to maintain.

---

## One edit updates BOTH profiles

Because the shared tier is consumed in place, a single edit to a shared file
reaches both tools without any sync step:

```
                          You edit ONCE
                               |
                               v
              +-----------------------------------+
              |   profiles/shared/                |
              |     contract/SHARED_DESIGN_...md  |   <-- the single edit lands here
              |     schemas/forbidden-paths.json  |
              |     skills/<shared skill>/        |
              +-----------------------------------+
                       |                   |
        consumed by    |                   |    consumed by
        relative path  |                   |    relative path
                       v                   v
        +---------------------+   +---------------------+
        |  profiles/claude/   |   |  profiles/codex/    |
        |  (Claude Code)      |   |  (Codex)            |
        |                     |   |                     |
        |  picks up the edit  |   |  picks up the edit  |
        |  automatically      |   |  automatically      |
        +---------------------+   +---------------------+

   Result: ONE edit -> BOTH profiles updated. No second copy. No drift.
```

Contrast that with the way drift normally creeps in: two separate copies of "the
same" rule, edited at different times by different people, slowly disagreeing
until nobody is sure which one is correct. Driftless removes the second copy, so
there is nothing to fall out of sync.

---

## How the gate enforces no-drift

`scripts/Test-ProfileMirrorParity.ps1` reads
`profiles/shared/schemas/mirror-parity-allowlist.json` — the declaration of what
is shared and what is deliberately tool-specific — and runs three complementary
checks. It does **not** diff two copies for byte equality, because there is only
one copy of each shared asset. Instead it proves the single-source shape is
intact:

| Signal | What it checks | FAILs when |
|---|---|---|
| **A. Shared-tier existence** | Every declared shared asset exists under `profiles/shared/` and is marked consumed by **both** profiles. | A shared file is missing, or is consumed by only one profile. |
| **B. Profile-consumer proof** | Each profile still **points at** the shared tier by relative path instead of forking its own copy. | A profile's consumer file stopped referencing the shared tier (it forked). |
| **C. Git one-sidedness** | The committed PR diff (`Base...HEAD`) never edits a profile-local copy of a shared concept while leaving the shared source untouched. | A pull request changes a shared concept in one profile only. |

When a base ref cannot be resolved (offline or a shallow clone), Signal C reports
`UNVERIFIED` — never a silent PASS and never a false FAIL — and Signals A and B
still gate. A missing or unparseable allowlist reports `BLOCKED`, never a vacuous
PASS. The gate is read-only: no network, no secrets, no host-global access. It is
ASCII-only and BOM-free so it passes the Windows text-safety gate (it cannot fail
its own rule on PowerShell 7).

Run it:

```powershell
# Default: structural + consumer signals always gate; git one-sidedness runs
# against origin/main when that base resolves.
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-ProfileMirrorParity.ps1

# Structural-only run (no git history needed):
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-ProfileMirrorParity.ps1 -SkipGitDiff

# Machine-readable summary:
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-ProfileMirrorParity.ps1 -Json
```

Exit codes: `0` = PASS, `1` = FAIL (drift), `2` = BLOCKED (missing or unparseable
allowlist, or nothing to enforce — reported BLOCKED, never a silent PASS).

---

## The 39-vs-34 skill count is INTENTIONAL, not drift

> Counts here are from the **private development runtime** Driftless grew from,
> where the pattern was proven at scale. **This public kit ships 20 profile starter skills**
> (1 Claude-specific, 1 Codex-specific, 18 shared) — `find profiles -name SKILL.md
> | wc -l` confirms. The parity logic below governs both.

In the development runtime the Claude profile carries **39 skills** and the Codex
profile **34 skills**. That five-skill difference looks like drift at a glance. It
is not. It is deliberate tool-specific specialization, and the gate is built to
*not* flag it.

Here is why the counts differ:

- **Claude-only skills** — skills that depend on capabilities only the Claude
  profile has (its Workflow / dynamic-workflow orchestration, Chrome DevTools MCP
  driven browser skills). These belong only in the Claude profile.
- **Codex-only skills** — skills that depend on Codex-specific machinery (its
  `goal` mode, its `openai.yaml` skill registration). These belong only in the
  Codex profile.

The shared design contract states it plainly: launcher mechanics, the hot-rules
filename (`CLAUDE.md` vs `AGENTS.md`), and skill format / model defaults **are
expected to differ** between profiles and do not belong in the shared tier. A
lesson learned for one tool stays in that tool's profile until it is shown to be
genuinely tool-agnostic — only then is it promoted into the shared tier.

So the mirror-parity gate enforces parity on the **shared tier only**. It never
forces the two skill counts to match. Forcing symmetry would be the wrong goal: a
Claude-only browser-automation skill has no meaning in Codex, and a Codex `goal`
release-gate skill has no meaning in Claude. Letting each tool's strengths grow
independently is **ecosystem leverage**, not divergence.

The allowlist records this explicitly so the intent is auditable, not folklore:

```jsonc
// profiles/shared/schemas/mirror-parity-allowlist.json (excerpt)
"toolSpecificExempt": [
  { "name": "claude-only-skills", "side": "claude", "approxCount": 39,
    "why": "Workflow / dynamic-workflow / Chrome DevTools MCP dependent; never required to mirror." },
  { "name": "codex-only-skills",  "side": "codex",  "approxCount": 34,
    "why": "goal-mode / openai.yaml registration dependent; never required to mirror." }
],
"skillCountDelta": {
  "claudeSkills": 39,
  "codexSkills": 34,
  "verdict": "intentional-tool-specific-not-drift"
}
```

**The rule of thumb:** drift is two copies of the *same* thing disagreeing.
Tool-specific skills are *different* things on purpose. The gate guards the first
and stays out of the way of the second.

---

## Where to go next

- **[What is Driftless?](./what-is-driftless.md)** — the full picture, including
  the other half of "driftless" (the agent staying on your goal).
- **[Guardrails](./guardrails.md)** — the safety fences, including the containment
  guard that consumes the same shared `forbidden-paths.json`.
- The gate itself: `scripts/Test-ProfileMirrorParity.ps1`.
- The declaration: `profiles/shared/schemas/mirror-parity-allowlist.json`.
