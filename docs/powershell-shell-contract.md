# PowerShell Shell Contract

## What This Solves

This repo runs on Windows and uses two different PowerShell families:

- `pwsh.exe`: PowerShell 7+, `PSEdition Core`.
- `powershell.exe`: Windows PowerShell 5.1, `PSEdition Desktop`.

LLMs often switch between them by habit. That causes false validation, broken
scripts, or CI-only failures. The fix is a small repo contract: normal tasks use
PowerShell 7, and Windows PowerShell 5.1 is an explicit compatibility path.

## Default Command

Use this for normal repo tasks:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\task.ps1 <task>
```

Examples:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\task.ps1 doctor
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\task.ps1 lint
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\task.ps1 test
```

## When Windows PowerShell 5.1 Is Allowed

`powershell.exe` is allowed only for documented compatibility checks or legacy
scripts. The default legacy folder is:

```text
scripts/winps51/
```

Smoke-test it through the normal entrypoint:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\task.ps1 legacy-doctor
```

This repo also has existing validation gates that intentionally run under
Windows PowerShell 5.1 to catch compatibility and encoding problems. Those are
compatibility gates, not the default agent task route.

## Adding A PowerShell 7 Script

For a new default script:

1. Put it behind `scripts/task.ps1` when practical.
2. Add `#Requires -Version 7.2`.
3. Check `$PSVersionTable.PSEdition -eq 'Core'`.
4. Use explicit cmdlets and executable names; avoid aliases such as `ls`, `cat`,
   `rm`, `curl`, and `wget`.
5. Do not use Bash heredoc syntax such as `<<EOF` in PowerShell. Use a
   PowerShell here-string or a checked-in script file.
6. Keep `.ps1`, `.bat`, and `.cmd` files ASCII-safe because this repo still
   parses fragile script files with Windows PowerShell 5.1.

## Adding A Windows PowerShell 5.1 Legacy Script

For a Desktop-only script:

1. Put it under `scripts/winps51/` or document another legacy path.
2. Add:

```powershell
#Requires -Version 5.1
#Requires -PSEdition Desktop
```

3. Check `$PSVersionTable.PSEdition -eq 'Desktop'`.
4. Do not call it from normal tasks except through an explicit legacy wrapper.

## Tooling

The optional tool installer verifies or installs these CurrentUser modules:

- `PSScriptAnalyzer`
- `Pester`

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\task.ps1 install-tools
```

If the machine has no gallery/network access, the task prints manual install
instructions instead of weakening machine policy.

## Troubleshooting

### `pwsh not found`

PowerShell 7 is not installed or not on PATH. Install PowerShell 7, then run the
default command again.

### `script requires PowerShell 7`

You started the task with `powershell.exe`. Re-run it with `pwsh`.

### `script requires Windows PowerShell Desktop`

You started a legacy script with `pwsh`. Run it through:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\task.ps1 legacy-doctor
```

### `PSScriptAnalyzer not installed`

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\task.ps1 install-tools
```

### `Pester not installed`

Run the same `install-tools` task. The current shell-contract gate does not
depend on Pester, so missing Pester does not block the lightweight check.

### GitHub Actions Used The Wrong Shell

Workflow PowerShell steps must declare either:

```yaml
shell: pwsh
```

or:

```yaml
shell: powershell
```

Do not rely on the runner default.

### Bash heredoc failed in PowerShell

PowerShell does not accept Bash heredoc syntax such as `<<EOF`. Use a
PowerShell here-string (`@' ... '@` or `@" ... "@`) or put the body in a script
file and run it with `pwsh -File`.

## What Codex Should Do When Shell Errors Happen

Codex should inspect `$PSVersionTable.PSEdition` and `$PSVersionTable.PSVersion`,
then route the command through the contract. It should not try random shell
switches until one happens to work.
