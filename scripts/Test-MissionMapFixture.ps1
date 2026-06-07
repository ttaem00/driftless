param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function New-Result {
  param(
    [string]$Name,
    [string]$Status,
    [string]$Detail
  )
  [pscustomobject]@{
    name = $Name
    status = $Status
    detail = $Detail
  }
}

$results = New-Object System.Collections.Generic.List[object]
$fixturePath = Join-Path $Root 'examples\mission-map-state.json'
$docPath = Join-Path $Root 'docs\en\mission-map.md'

if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
  $results.Add((New-Result 'Mission Map fixture exists' 'FAIL' 'examples/mission-map-state.json is missing'))
} else {
  $results.Add((New-Result 'Mission Map fixture exists' 'PASS' 'fixture found'))
}

if (-not (Test-Path -LiteralPath $docPath -PathType Leaf)) {
  $results.Add((New-Result 'Mission Map doc exists' 'FAIL' 'docs/en/mission-map.md is missing'))
} else {
  $doc = Get-Content -LiteralPath $docPath -Raw
  if ($doc -match 'do(es)? not prove a real\s+runtime' -and $doc -match 'private state files') {
    $results.Add((New-Result 'Mission Map doc caveat' 'PASS' 'doc separates fixture proof from runtime behavior'))
  } else {
    $results.Add((New-Result 'Mission Map doc caveat' 'FAIL' 'doc must state fixture/static proof does not prove runtime behavior and private adapters stay private'))
  }
}

if (Test-Path -LiteralPath $fixturePath -PathType Leaf) {
  try {
    $fixture = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
    $required = @(
      'activeGoal',
      'guardian',
      'pr',
      'checks',
      'blockers',
      'evidence',
      'nextAction'
    )
    $missing = @()
    foreach ($field in $required) {
      if (-not ($fixture.PSObject.Properties.Name -contains $field)) {
        $missing += $field
      }
    }
    if ($missing.Count -eq 0) {
      $results.Add((New-Result 'Mission Map required fields' 'PASS' ('fields=' + ($required -join ','))))
    } else {
      $results.Add((New-Result 'Mission Map required fields' 'FAIL' ('missing=' + ($missing -join ','))))
    }

    $states = @(
      [string]$fixture.pr.state,
      [string]$fixture.checks.state,
      [string]$fixture.evidence[0].status
    )
    $allowed = @('PASS', 'FAIL', 'BLOCKED', 'UNVERIFIED', 'PARTIAL')
    $badStates = @($states | Where-Object { $allowed -notcontains $_ })
    if ($badStates.Count -eq 0) {
      $results.Add((New-Result 'Mission Map state labels' 'PASS' ('states=' + ($states -join ','))))
    } else {
      $results.Add((New-Result 'Mission Map state labels' 'FAIL' ('unsupported states=' + ($badStates -join ','))))
    }

    $raw = Get-Content -LiteralPath $fixturePath -Raw
    $dot = [string][char]46
    $privateMarkers = @(
      'D:\\',
      'C:\\Users\\',
      ($dot + 'runtime\\codex-home'),
      ($dot + 'runtime\\claude-home'),
      'thread:',
      'cookie',
      'credential',
      'secret',
      ($dot + 'env'),
      ($dot + 'ssh')
    )
    $hits = @($privateMarkers | Where-Object { $raw.IndexOf($_, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 })
    if ($hits.Count -eq 0) {
      $results.Add((New-Result 'Mission Map public-safe fixture' 'PASS' 'no private path/session/credential markers'))
    } else {
      $results.Add((New-Result 'Mission Map public-safe fixture' 'FAIL' ('private markers=' + ($hits -join ','))))
    }
  } catch {
    $results.Add((New-Result 'Mission Map fixture parses' 'FAIL' $_.Exception.Message))
  }
}

$failed = @($results | Where-Object { $_.status -ne 'PASS' })
$overall = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }

if ($Json) {
  [pscustomobject]@{
    gate = 'Mission Map fixture'
    overall = $overall
    checks = $results
  } | ConvertTo-Json -Depth 5
} else {
  Write-Output '== Mission Map fixture gate =='
  foreach ($r in $results) {
    Write-Output ('[' + $r.status + '] ' + $r.name + ' - ' + $r.detail)
  }
  Write-Output ('RESULT: ' + $overall)
}

if ($overall -ne 'PASS') {
  exit 1
}
