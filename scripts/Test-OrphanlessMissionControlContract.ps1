#requires -Version 7.0
#requires -PSEdition Core
[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)
$ErrorActionPreference = 'Stop'
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$skillPath = Join-Path $rootPath 'profiles/shared/skills/mission-control/SKILL.md'
$failures = [System.Collections.Generic.List[string]]::new()
if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
  $failures.Add("missing mission-control skill: $skillPath") | Out-Null
} else {
  $text = Get-Content -LiteralPath $skillPath -Raw -Encoding UTF8
  foreach ($pattern in @(
    '## Orphanless Mission Contract',
    'Decompose atomically',
    'Retrieve existing surfaces first',
    'Compose a role graph',
    'Keep one manager interface',
    'Close through the parent',
    'single user goal -> atomic lanes -> role-aware sessions -> one',
    'manager-visible state surface',
    'work ledger',
    'dashboard',
    'worker/session results roll up',
    'disconnected chats'
  )) {
    if ($text -notmatch [regex]::Escape($pattern)) {
      $failures.Add("mission-control missing Orphanless contract anchor: $pattern") | Out-Null
    }
  }
  foreach ($privatePattern in @('c-c-isolated-runtime','ccisolated','D:\\','C:\\Users\\','orphanless-watch')) {
    if ($text -match $privatePattern) {
      $failures.Add("public mission-control leaks private/internal pattern: $privatePattern") | Out-Null
    }
  }
}
$result = [pscustomobject]@{ check='Test-OrphanlessMissionControlContract'; status=$(if($failures.Count){'FAIL'}else{'PASS'}); file=$skillPath; failures=@($failures) }
if ($Json) { $result | ConvertTo-Json -Depth 6 } else { if($failures.Count){$failures | ForEach-Object { Write-Output "FAIL: $_" }}; Write-Output "RESULT: $($result.status)" }
if ($failures.Count) { exit 1 }
exit 0
