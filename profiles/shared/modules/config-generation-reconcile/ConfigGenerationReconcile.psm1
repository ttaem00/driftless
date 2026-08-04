#Requires -Version 7.2

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FileSha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-MergeableTextFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [int64]$MaximumBytes = 2097152
  )

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.LongLength -gt $MaximumBytes -or $bytes.Contains([byte]0)) {
    return $false
  }

  try {
    $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
    [void]$utf8.GetString($bytes)
    return $true
  } catch {
    return $false
  }
}

function Write-ReconcileReceipt {
  param(
    [Parameter(Mandatory = $true)][hashtable]$Receipt,
    [Parameter(Mandatory = $true)][string]$ReceiptPath
  )

  $directory = Split-Path -Parent $ReceiptPath
  if ($directory) {
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
  }
  $json = $Receipt | ConvertTo-Json -Depth 6
  [System.IO.File]::WriteAllText($ReceiptPath, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

function Assert-DistinctReconcilePaths {
  param(
    [Parameter(Mandatory = $true)][string[]]$InputPaths,
    [Parameter(Mandatory = $true)][string[]]$OutputPaths
  )

  $comparison = if ($IsWindows) {
    [StringComparison]::OrdinalIgnoreCase
  } else {
    [StringComparison]::Ordinal
  }
  $inputs = @($InputPaths | ForEach-Object { [System.IO.Path]::GetFullPath($_) })
  $outputs = @($OutputPaths | ForEach-Object { [System.IO.Path]::GetFullPath($_) })
  foreach ($output in $outputs) {
    foreach ($input in $inputs) {
      if ([string]::Equals($output, $input, $comparison)) {
        throw "Reconcile output must not overwrite an input: $output"
      }
    }
  }
  if ([string]::Equals($outputs[0], $outputs[1], $comparison)) {
    throw 'CandidatePath and ReceiptPath must be different.'
  }
}

function Invoke-DriftlessConfigGenerationReconcile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$BasePath,
    [Parameter(Mandatory = $true)][string]$UserPath,
    [Parameter(Mandatory = $true)][string]$TargetPath,
    [Parameter(Mandatory = $true)][string]$CandidatePath,
    [Parameter(Mandatory = $true)][string]$ReceiptPath,
    [Parameter(Mandatory = $true)][string]$GenerationId,
    [string]$RollbackPath = ''
  )

  foreach ($path in @($BasePath, $UserPath, $TargetPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      throw "Required reconcile input is missing: $path"
    }
  }
  Assert-DistinctReconcilePaths -InputPaths @($BasePath, $UserPath, $TargetPath) -OutputPaths @($CandidatePath, $ReceiptPath)

  $candidateDirectory = Split-Path -Parent $CandidatePath
  if ($candidateDirectory) {
    [System.IO.Directory]::CreateDirectory($candidateDirectory) | Out-Null
  }

  if (Test-Path -LiteralPath $CandidatePath) {
    Remove-Item -LiteralPath $CandidatePath -Force
  }

  $baseHash = Get-FileSha256 -Path $BasePath
  $userHash = Get-FileSha256 -Path $UserPath
  $targetHash = Get-FileSha256 -Path $TargetPath
  $status = ''
  $candidateHash = $null
  $mergeExitCode = $null
  $temporaryOutput = $null

  try {
    if ($userHash -eq $baseHash) {
      Copy-Item -LiteralPath $TargetPath -Destination $CandidatePath -Force
      $status = 'TARGET_APPLIED'
    } elseif ($targetHash -eq $baseHash -or $userHash -eq $targetHash) {
      Copy-Item -LiteralPath $UserPath -Destination $CandidatePath -Force
      $status = 'USER_PRESERVED'
    } else {
      $mergeable = (Test-MergeableTextFile -Path $BasePath) -and
        (Test-MergeableTextFile -Path $UserPath) -and
        (Test-MergeableTextFile -Path $TargetPath)

      if (-not $mergeable) {
        $status = 'HELD_BINARY_CONFLICT'
      } else {
        $temporaryOutput = [System.IO.Path]::GetTempFileName()
        $git = Get-Command git -ErrorAction Stop
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $git.Source
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        foreach ($argument in @('merge-file', '--diff3', '--stdout', '--', $UserPath, $BasePath, $TargetPath)) {
          $startInfo.ArgumentList.Add($argument)
        }
        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        [void]$process.Start()
        $errorRead = $process.StandardError.ReadToEndAsync()
        $outputStream = [System.IO.File]::Open($temporaryOutput, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
          $process.StandardOutput.BaseStream.CopyTo($outputStream)
        } finally {
          $outputStream.Dispose()
        }
        $process.WaitForExit()
        $standardError = $errorRead.GetAwaiter().GetResult()
        $mergeExitCode = $process.ExitCode
        $process.Dispose()

        if ($mergeExitCode -eq 0) {
          Move-Item -LiteralPath $temporaryOutput -Destination $CandidatePath -Force
          $temporaryOutput = $null
          $status = 'AUTO_MERGED'
        } elseif ($mergeExitCode -eq 1) {
          $status = 'HELD_CONFLICT'
        } else {
          throw "git merge-file failed with exit code ${mergeExitCode}: $standardError"
        }
      }
    }

    if (Test-Path -LiteralPath $CandidatePath -PathType Leaf) {
      $candidateHash = Get-FileSha256 -Path $CandidatePath
    }

    $receipt = [ordered]@{
      schema = 'driftless.config-generation-reconcile.v1'
      generationId = $GenerationId
      status = $status
      activeMutation = $false
      candidateReady = [bool]$candidateHash
      rollbackPath = $RollbackPath
      mergeExitCode = $mergeExitCode
      inputs = [ordered]@{
        base = [ordered]@{ path = $BasePath; sha256 = $baseHash }
        user = [ordered]@{ path = $UserPath; sha256 = $userHash }
        target = [ordered]@{ path = $TargetPath; sha256 = $targetHash }
      }
      candidate = [ordered]@{ path = $CandidatePath; sha256 = $candidateHash }
      createdAtUtc = [DateTime]::UtcNow.ToString('o')
    }
    Write-ReconcileReceipt -Receipt $receipt -ReceiptPath $ReceiptPath
    return [pscustomobject]$receipt
  } finally {
    if ($temporaryOutput -and (Test-Path -LiteralPath $temporaryOutput)) {
      Remove-Item -LiteralPath $temporaryOutput -Force
    }
  }
}

Export-ModuleMember -Function Invoke-DriftlessConfigGenerationReconcile
