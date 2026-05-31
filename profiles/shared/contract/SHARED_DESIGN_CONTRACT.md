# Shared Design Contract

**Purpose.** Driftless is one repository with two isolated profiles side by side:
a Claude profile and a Codex profile. Both wrap a different AI tool in the same
isolated, evidence-first, manager-safe runtime. This contract is the single set
of rules that keeps the two profiles interoperable: one shared vocabulary, one
set of safety rules, one report format. Both profiles consume it by repo-relative
path.

> **Change rule.** Anything in this file is shared. Change it here once; both
> profiles pick it up. No copying, no mirroring, no external sync step.

---

## 1. Evidence statuses

Every claim carries exactly one status:

| Status | Meaning |
|---|---|
| `PASS` | Verified by a real run or command on the target. |
| `FAIL` | Verified to be broken by a real run or command. |
| `BLOCKED` | Cannot proceed; a dependency or permission is missing. |
| `UNVERIFIED` | Not yet checked by a real run. The default for any unproven claim. |
| `PARTIAL` | Some of the claim is verified; the rest is not. |

A behavioral `PASS` requires a real end-to-end run. A static check of docs,
schemas, or fixtures leaves behavior `UNVERIFIED`. Host-specific results are
host-specific: a `PASS` on Windows never implies a `PASS` on macOS or Linux. Keep
a host evidence note when it matters.

---

## 2. Manager report labels

The manager is a non-developer. Every report begins in plain language with one of
exactly four labels:

| Label | Use when |
|---|---|
| `built/inspected` | Something was created or read; behavior not yet run. |
| `tested/evidence` | A real run produced the evidence cited. |
| `manager run/paste` | The manager must run or paste something to proceed. |
| `blocked/unverified` | Work is stuck, or a claim is unproven. |

Raw commands, paths, and logs come *after* the plain summary, as evidence lines —
never as the headline.

---

## 3. Manager-only gates

The agent never acts on these by itself. Each requires an explicit manager
decision first:

- **product / value / priority** — what to build and in what order.
- **credentials** — any login, token, or key.
- **billing / quota** — anything that spends money or consumes a paid quota.
- **public release** — publishing, announcing, or making something public.
- **destructive / irreversible actions** — deleting, force-pushing, history reset,
  user-data transfer.
- **host-global promotion** — touching host-global config outside the isolated
  per-repo home (see §5).

Everything else — routine git, GitHub, validation, and safety mechanics — the
agent owns when tools allow. Agent-solvable blockers are solved in the same
session; only the gates above are escalated to the manager.

---

## 4. Run-status enum

A run moves through exactly these states:

```
empty -> preflight -> running -> needs_decision -> blocked -> review_ready -> done -> error
```

`review_ready` and `blocked` are **never** reported as `done`. A run reaches
`done` only after its evidence is `PASS`.

---

## 5. Isolation boundary

Each profile uses only its own repo-local isolated config home and never the
host-global config of either tool.

| Concept | Claude profile | Codex profile |
|---|---|---|
| Repo-local agent home | `CLAUDE_CONFIG_DIR` -> isolated per-repo home | `CODEX_HOME` -> isolated per-repo home |
| Host-global surface to protect | `~/.claude` (and `~/.codex`) | `~/.codex` (and `~/.claude`) |
| Hot-rules file | `CLAUDE.md` | `AGENTS.md` |

**Invariant in both directions.** A Claude-profile run never writes host-global
`~/.claude` or `~/.codex`; a Codex-profile run never writes host-global `~/.codex`
or `~/.claude`. The canonical machine-readable forbidden set lives in
`../schemas/forbidden-paths.json` and is consumed by both profiles' containment
guards. Touching any host-global config is a §3 manager-only gate.

---

## 6. One AI per profile

Each profile is driven by a single AI: Claude in the Claude profile, Codex in the
Codex profile. Peer or recursive AI calls between the two profiles are off by
default. A tool orchestrating its own subagents over its own profile's work is
allowed — that is the tool doing its own job, not a cross-profile peer call.

---

## 7. What is intentionally tool-specific

These may differ between profiles and do **not** belong in the shared tier:

- Launcher mechanics (`CLAUDE_CONFIG_DIR` vs `CODEX_HOME`).
- The hot-rules filename (`CLAUDE.md` vs `AGENTS.md`).
- Skill format, model defaults, and effort levels.

A lesson learned for one tool stays in that tool's profile until it is shown to be
genuinely tool-agnostic; only then is it promoted into this shared contract.
