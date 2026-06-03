param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Add-Result {
  param(
    [System.Collections.Generic.List[object]]$Results,
    [string]$Check,
    [string]$Status,
    [string]$Evidence,
    [string]$NextAction = ''
  )

  $Results.Add([pscustomobject]@{
    check = $Check
    status = $Status
    evidence = $Evidence
    next_action = $NextAction
  }) | Out-Null
}

function Get-PassFail {
  param([bool]$Condition)
  if ($Condition) { return 'PASS' }
  return 'FAIL'
}

$repo = (Resolve-Path -LiteralPath $Root).Path
$results = [System.Collections.Generic.List[object]]::new()
$skill = Join-Path $repo 'profiles\shared\skills\mission-control\SKILL.md'
$allowlist = Join-Path $repo 'profiles\shared\schemas\mirror-parity-allowlist.json'
$sharedReadme = Join-Path $repo 'profiles\shared\README.md'
$claudeReadme = Join-Path $repo 'profiles\claude\README.md'
$codexReadme = Join-Path $repo 'profiles\codex\README.md'

foreach ($path in @($skill, $allowlist, $sharedReadme, $claudeReadme, $codexReadme)) {
  Add-Result -Results $results -Check "mission-control surface present: $([System.IO.Path]::GetFileName($path))" -Status (Get-PassFail (Test-Path -LiteralPath $path -PathType Leaf)) -Evidence $path -NextAction 'Restore the shared mission-control surface.'
}

$skillText = if (Test-Path -LiteralPath $skill -PathType Leaf) { [System.IO.File]::ReadAllText($skill) } else { '' }
$requiredTerms = @(
  'name: mission-control',
  'Control Tower Loop',
  'Worker Contract',
  'Evidence Quality',
  'Gradient Closeout',
  'goal-pair-guardian',
  'learning-loop',
  'manager-only'
)

foreach ($term in $requiredTerms) {
  Add-Result -Results $results -Check "mission-control contract includes: $term" -Status (Get-PassFail ($skillText.Contains($term))) -Evidence $skill -NextAction "Restore the mission-control contract term: $term"
}

$oldId = 'student' + '-autopilot'
$oldTitle = 'Student ' + 'Autopilot'
$trackedRaw = & git -C $repo ls-files profiles scripts .github 2>$null
$trackedFiles = @($trackedRaw | Where-Object { $_ })
$hits = [System.Collections.Generic.List[object]]::new()
foreach ($relative in $trackedFiles) {
  $full = Join-Path $repo $relative
  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
  $text = [System.IO.File]::ReadAllText($full)
  foreach ($term in @($oldId, $oldTitle)) {
    if ($text.Contains($term)) {
      $hits.Add([pscustomobject]@{ file = $relative; term = $term }) | Out-Null
    }
  }
}

Add-Result -Results $results -Check 'no old autopilot name in public surfaces' -Status (Get-PassFail ($hits.Count -eq 0)) -Evidence (($hits | ConvertTo-Json -Depth 4) -join '') -NextAction 'Replace old autopilot naming with mission-control.'

$failed = @($results | Where-Object { $_.status -eq 'FAIL' })
Write-Output '== Driftless mission-control UX gate =='
foreach ($result in $results) {
  Write-Output ("[{0}] {1} - {2}" -f $result.status, $result.check, $result.evidence)
}
Write-Output '---'
Write-Output ("PASS={0} FAIL={1}" -f @($results | Where-Object { $_.status -eq 'PASS' }).Count, $failed.Count)

if ($failed.Count -gt 0) {
  exit 1
}
