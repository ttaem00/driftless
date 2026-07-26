# Hermes Aemeth compatibility home

This small adapter gives a Driftless Hermes CLI or Desktop session the same
Aemeth, Stelle, StarrailTopology, and Trailblazer meanings used by the installed
Claude and Codex profiles. It copies only the shared Starrail skill, its contract,
and Hermes-native aliases into `.runtime/hermes-home`.

Install and start it on Windows:

```powershell
pwsh.exe -ExecutionPolicy Bypass -File install.ps1 -Tool hermes
$env:HERMES_HOME="$PWD\.runtime\hermes-home"; hermes
$env:HERMES_HOME="$PWD\.runtime\hermes-home"; hermes desktop --cwd $PWD
```

On macOS or Linux:

```sh
sh ./install.sh --hermes
HERMES_HOME="$PWD/.runtime/hermes-home" hermes
HERMES_HOME="$PWD/.runtime/hermes-home" hermes desktop --cwd "$PWD"
```

The installer does not read or change a host-global Hermes home. Existing
sessions need `/reload-skills` or a restart because Hermes discovers skills at
session start.
