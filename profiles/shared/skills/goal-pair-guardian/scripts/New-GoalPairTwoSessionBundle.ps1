<#
.SYNOPSIS
  Create manager-friendly paired prompts for a goal session and a goal-pair session.

.DESCRIPTION
  Fallback helper for Codex app environments where thread creation tools are not
  available, or for a durable preflight record before creating threads. It writes
  a compact JSON/Markdown bundle under .runtime/goal-runs/<RunId>/goal-pair/.
  It does not call a model, create threads, read secrets, inspect host-global
  profiles, mutate git, or access the network.
#>
param(
  [string]$TargetRepo = (Get-Location).Path,
  [string]$RunId = '',
  [Parameter(Mandatory = $true)][string]$Goal,
  [string]$SuccessCriteria = '',
  [string]$Scope = '',
  [string]$GoalThreadId = '<fill after goal thread creation>',
  [string]$PairThreadId = '<fill after goal-pair thread creation>'
)

$ErrorActionPreference = 'Stop'

function Test-UnderPath {
  param(
    [string]$Child,
    [string]$Parent
  )
  $childFull = [System.IO.Path]::GetFullPath($Child).TrimEnd([char[]]@('\','/'))
  $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd([char[]]@('\','/'))
  return $childFull.Equals($parentFull, [System.StringComparison]::OrdinalIgnoreCase) -or
    $childFull.StartsWith("$parentFull\", [System.StringComparison]::OrdinalIgnoreCase) -or
    $childFull.StartsWith("$parentFull/", [System.StringComparison]::OrdinalIgnoreCase)
}

$repoFull = [System.IO.Path]::GetFullPath($TargetRepo)
if (-not (Test-Path -LiteralPath $repoFull -PathType Container)) {
  throw "TargetRepo does not exist: $TargetRepo"
}

if ([string]::IsNullOrWhiteSpace($RunId)) {
  $RunId = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-goal-pair'
}

if ($RunId -notmatch '^[A-Za-z0-9._-]+$') {
  throw "RunId may contain only letters, digits, dot, underscore, and dash: $RunId"
}

$bundleRoot = Join-Path (Join-Path (Join-Path $repoFull '.runtime') 'goal-runs') $RunId
$bundleRoot = Join-Path (Join-Path $bundleRoot 'goal-pair') 'two-session'
$bundleFull = [System.IO.Path]::GetFullPath($bundleRoot)
if (-not (Test-UnderPath -Child $bundleFull -Parent $repoFull)) {
  throw "Bundle path escaped TargetRepo."
}

New-Item -ItemType Directory -Path $bundleFull -Force | Out-Null

if ([string]::IsNullOrWhiteSpace($SuccessCriteria)) {
  $SuccessCriteria = 'Codex must restate concrete success criteria before implementation and may not claim Done without command/tool evidence.'
}
if ([string]::IsNullOrWhiteSpace($Scope)) {
  $Scope = 'Repo-local work only. No credentials, paid billing, public release, destructive action, host-global mutation, browser profiles, secrets, or user data transfer without explicit manager approval.'
}

$goalPrompt = @"
/goal $Goal

Use `$goal-pair-guardian.

You are the goal implementation session.
Manager is a non-developer student. Do not push raw git, raw logs, script choices, or developer-only setup decisions to the manager.

Root intent:
$Goal

Success criteria:
$SuccessCriteria

Scope and exclusions:
$Scope

Goal-pair thread:
$PairThreadId

Rules:
- Keep root intent, success criteria, evidence, blockers, and remaining work visible.
- Do not claim Done until every success criterion has command/tool evidence.
- Mark static-only proof as UNVERIFIED when behavior is not proven through the real path.
- Do not hide agent-solvable work behind follow-up, later, pending, or next session.
- If work should be split, use parallel-ticket-planner.
- If work should run while the manager is away, use overnight-all-tickets.
- If a blocker is agent-solvable, use finish-to-done.
- If a repeated problem appears, use learning-loop and the repo's skill/prompt optimization gate.
- PR, merge, issue close, and release claims require the target repo gates and evidence.
- If context becomes unsafe, write a checkpoint and ask the goal-pair thread for START_FRESH_GOAL continuation handling.

Report:
built/inspected:
tested/evidence:
manager run/paste:
blocked/unverified:
guardian decision:
"@

$pairPrompt = @"
Use `$goal-pair-guardian.

You are the goal-pair companion session. Do not implement feature work unless the manager explicitly redirects this session. Your job is to keep the goal session aligned, evidence-based, and honest about completion.

Goal thread:
$GoalThreadId

Root intent:
$Goal

Success criteria:
$SuccessCriteria

Scope and exclusions:
$Scope

Check loop:
- Read the goal thread with app thread tools when available.
- Check root intent, success criteria, scope, evidence, remaining work, blockers, context health, routing, and finish honesty.
- Correct the goal thread with send_message_to_thread when it drifts, stops early, defers agent-solvable work, or reports unverified Done.
- Prefer a heartbeat automation for repeated checks when a long run is expected.
- If direction fixes no longer work, write a checkpoint where safe and produce a paste-ready continuation /goal.
- Improve the system automatically over repeated occurrences: first record a lesson, second create a concrete proposal, third or serious regression implement the smallest repo-local skill/script/hook/doc fix and validate it.
- Score every improvement on tokens, manager intervention, time, money, and recurrence-prevention performance. Do not optimize by deleting safety, trigger phrases, manager-only gates, or validation requirements.

Report:
inspected:
guardian_decision:
corrected_sessions:
fresh_goal_needed:
remaining_risk:
"@

$record = [pscustomobject]@{
  schema_version = 1
  created_utc = (Get-Date).ToUniversalTime().ToString('o')
  target_repo = $repoFull
  run_id = $RunId
  goal = $Goal
  success_criteria = $SuccessCriteria
  scope = $Scope
  goal_thread_id = $GoalThreadId
  pair_thread_id = $PairThreadId
  goal_prompt = $goalPrompt
  pair_prompt = $pairPrompt
}

$jsonPath = Join-Path $bundleFull 'two-session-bundle.json'
$goalPath = Join-Path $bundleFull 'goal-session-prompt.md'
$pairPath = Join-Path $bundleFull 'goal-pair-session-prompt.md'
$readmePath = Join-Path $bundleFull 'README.md'

[System.IO.File]::WriteAllText($jsonPath, ($record | ConvertTo-Json -Depth 6), [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($goalPath, $goalPrompt, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($pairPath, $pairPrompt, [System.Text.UTF8Encoding]::new($false))

$readme = @"
# Goal Pair Two-Session Bundle

- target_repo: $repoFull
- run_id: $RunId
- created_utc: $($record.created_utc)

Use `goal-session-prompt.md` for the implementation goal session.
Use `goal-pair-session-prompt.md` for the companion goal-pair session.

If Codex app thread tools are available, Codex should create both threads and
replace the placeholder thread ids with the real ids. If not, these files are
paste-ready prompts.
"@
[System.IO.File]::WriteAllText($readmePath, $readme, [System.Text.UTF8Encoding]::new($false))

[pscustomobject]@{
  status = 'PASS'
  bundle_root = $bundleFull
  json_path = $jsonPath
  goal_prompt_path = $goalPath
  pair_prompt_path = $pairPath
} | ConvertTo-Json -Depth 4
