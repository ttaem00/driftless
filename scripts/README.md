# Driftless gates

Two small, self-contained PowerShell gates that prove Driftless is
**containment-first**: the repo never reads or writes a forbidden path, never
leaks a credential, and never ships a Windows-fragile script. They are read-only
(no network, no secrets, no host-global access) and run the same on Windows
PowerShell 5.1 and PowerShell 7.

| Gate | What it proves | FAILs when |
| --- | --- | --- |
| `Test-Containment.ps1` | The code base never touches a forbidden path or leaks a secret. | A scanned file's own path is forbidden, references a forbidden path, or contains a credential token. |
| `Test-WindowsTextSafety.ps1` | Every shippable script parses identically on Windows PowerShell 5.1. | Any `.ps1` / `.bat` / `.cmd` has a non-ASCII byte or a UTF-8 BOM. |
| `Test-AgentRuntimeHealth.ps1` | The agent is not trying to repair the product from a broken Codex runtime. | Repo-local Codex uses elevated Windows sandbox, has sandbox setup errors, or recent Codex 400/self-error markers. |

## Run them

```powershell
# Containment: scan the working-tree diff and untracked files (pre-commit default)
powershell.exe -ExecutionPolicy Bypass -File scripts/Test-Containment.ps1

# Containment: scan every tracked file (full audit)
powershell.exe -ExecutionPolicy Bypass -File scripts/Test-Containment.ps1 -AllFiles

# Containment: prove detection on a single fixture file (no exemptions applied)
powershell.exe -ExecutionPolicy Bypass -File scripts/Test-Containment.ps1 -File path\to\fixture.txt

# Windows text safety: every tracked .ps1 / .bat / .cmd
powershell.exe -ExecutionPolicy Bypass -File scripts/Test-WindowsTextSafety.ps1

# Agent runtime health: stop early if the agent itself is broken
powershell.exe -ExecutionPolicy Bypass -File scripts/Test-AgentRuntimeHealth.ps1
```

Add `-Json` to either gate for a machine-readable summary.

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
   PowerShell 5.1 and `cmd.exe` read a BOM-less UTF-8 file as legacy CP1252, so a
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
