# Windows PowerShell 5.1 Legacy Path

This folder is the documented exception path for Windows PowerShell
5.1/Desktop-only work.

Normal repo tasks use:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\task.ps1 <task>
```

Use `powershell.exe` only when a script here, or another explicitly documented
compatibility gate, requires Windows PowerShell 5.1.
