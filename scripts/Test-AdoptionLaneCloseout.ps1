<#
.SYNOPSIS
  Validate public-safe external adoption lane closeout discipline.

.DESCRIPTION
  A pilot artifact is evidence, not Done. Final closeout requires a post-pilot
  decision and a matching lane state.
#>
[CmdletBinding()]
param(
  [string]$Path = "",
  [switch]$FinalCloseout,
  [switch]$SelfTest,
  [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Failure([System.Collections.Generic.List[string]]$Failures, [string]$Message) {
  $Failures.Add($Message) | Out-Null
}

function Test-LedgerObject([object]$Ledger, [switch]$Final) {
  $failures = [System.Collections.Generic.List[string]]::new()
  if (-not $Ledger.PSObject.Properties.Name.Contains("surfaces") -or -not $Ledger.surfaces) {
    Add-Failure $failures "missing surfaces"
    return @($failures)
  }

  foreach ($surface in @($Ledger.surfaces)) {
    $id = if ($surface.PSObject.Properties.Name.Contains("id")) { [string]$surface.id } else { "<missing-id>" }
    $classification = if ($surface.PSObject.Properties.Name.Contains("classification")) { [string]$surface.classification } else { "" }
    $closeoutState = if ($surface.PSObject.Properties.Name.Contains("closeoutState")) { [string]$surface.closeoutState } else { "" }
    $pilotKind = if ($surface.PSObject.Properties.Name.Contains("pilotKind")) { [string]$surface.pilotKind } else { "none" }
    $hasPostDecision = $surface.PSObject.Properties.Name.Contains("postPilotDecision") -and $surface.postPilotDecision
    $isPilot = ($classification -eq "C") -or ($classification -eq "PILOT_ONLY") -or ($pilotKind -and $pilotKind -ne "none")

    if ($Final -and ($closeoutState -eq "pending" -or $closeoutState -eq "piloted" -or $closeoutState -eq "experimented")) {
      Add-Failure $failures "surface $id final closeout cannot be $closeoutState"
    }

    if ($isPilot) {
      if (-not $hasPostDecision) {
        Add-Failure $failures "pilot surface $id missing postPilotDecision"
        continue
      }
      foreach ($field in @("decision", "evidence", "reason")) {
        if (-not $surface.postPilotDecision.PSObject.Properties.Name.Contains($field) -or -not $surface.postPilotDecision.$field) {
          Add-Failure $failures "pilot surface $id postPilotDecision missing $field"
        }
      }

      $decision = [string]$surface.postPilotDecision.decision
      $expectedCloseout = switch ($decision) {
        "adopt" { "adopted" }
        "scale" { "scaled" }
        "watch" { "watched" }
        "reject" { "rejected" }
        "block" { "blocked" }
        "manager_only" { "blocked" }
        default { "" }
      }
      if (-not $expectedCloseout) {
        Add-Failure $failures "pilot surface $id has invalid postPilotDecision.decision: $decision"
      } elseif ($Final -and $closeoutState -ne $expectedCloseout) {
        Add-Failure $failures "pilot surface $id decision $decision requires closeoutState $expectedCloseout"
      }
      if ($decision -eq "watch") {
        if (-not $surface.postPilotDecision.PSObject.Properties.Name.Contains("nextTrigger") -or -not $surface.postPilotDecision.nextTrigger) {
          Add-Failure $failures "pilot surface $id watch decision missing nextTrigger"
        }
      }
      if ($decision -eq "scale") {
        if (-not $surface.postPilotDecision.PSObject.Properties.Name.Contains("ownerArtifact") -or -not $surface.postPilotDecision.ownerArtifact) {
          Add-Failure $failures "pilot surface $id scale decision missing ownerArtifact"
        }
      }
    }
  }

  return @($failures)
}

function New-SampleLedger([string]$Case) {
  $surface = [pscustomobject]@{
    id = "sample-pilot"
    classification = "PILOT_ONLY"
    closeoutState = "adopted"
    pilotKind = "fixture"
    postPilotDecision = [pscustomobject]@{
      decision = "adopt"
      evidence = "fixture passed"
      reason = "bounded surface adopted"
    }
  }

  switch ($Case) {
    "pending" { $surface.closeoutState = "pending" }
    "piloted" { $surface.closeoutState = "piloted" }
    "missingPostDecision" { $surface.PSObject.Properties.Remove("postPilotDecision") }
    "watchMissingTrigger" {
      $surface.closeoutState = "watched"
      $surface.postPilotDecision.decision = "watch"
    }
    "scale" {
      $surface.closeoutState = "scaled"
      $surface.postPilotDecision.decision = "scale"
      $surface.postPilotDecision | Add-Member -NotePropertyName "ownerArtifact" -NotePropertyValue "https://github.com/example/repo/issues/1"
    }
  }

  [pscustomobject]@{
    surfaces = @($surface)
  }
}

function Invoke-SelfTest {
  $failures = [System.Collections.Generic.List[string]]::new()
  foreach ($case in @("clean", "scale")) {
    $caseFailures = @(Test-LedgerObject (New-SampleLedger $case) -Final)
    if ($caseFailures.Count -ne 0) {
      Add-Failure $failures ("positive fixture failed: " + $case + ": " + ($caseFailures -join "; "))
    }
  }

  foreach ($case in @("pending", "piloted", "missingPostDecision", "watchMissingTrigger")) {
    $caseFailures = @(Test-LedgerObject (New-SampleLedger $case) -Final)
    if ($caseFailures.Count -eq 0) {
      Add-Failure $failures "negative fixture should fail: $case"
    }
  }
  return @($failures)
}

if ($SelfTest -or (-not $Path)) {
  $failures = @(Invoke-SelfTest)
  if ($failures.Count -gt 0) {
    Write-Error ("FAIL Test-AdoptionLaneCloseout self-test:`n" + ($failures -join "`n"))
    exit 1
  }
  Write-Output "PASS Test-AdoptionLaneCloseout self-test"
  exit 0
}

$ledger = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
$failures = @(Test-LedgerObject $ledger -Final:$FinalCloseout)
$result = [pscustomobject]@{
  check = "Test-AdoptionLaneCloseout"
  status = if ($failures.Count -eq 0) { "PASS" } else { "FAIL" }
  failures = $failures
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
}

if ($failures.Count -gt 0) {
  Write-Error ("FAIL Test-AdoptionLaneCloseout:`n" + ($failures -join "`n"))
  exit 1
}

Write-Output "PASS Test-AdoptionLaneCloseout"
exit 0
