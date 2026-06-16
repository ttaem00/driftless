<!--
Driftless PRs merge only when the repo-local safety gates pass. Run them before
ready/merge; they print plain-language reasons.
-->

## What this changes / 무엇을 바꾸나

<!-- One or two plain sentences. Link the issue it closes: "Closes #NN". -->

## Checklist

- [ ] The aggregate local PR gate passes:
      `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-PrValidationGate.ps1`
- [ ] If I changed a shared rule/skill, I changed it **once in the shared tier**
      (one edit → both Claude and Codex profiles), not separately per tool.
- [ ] No secrets, no host-global agent config, no machine paths — public-safe.
- [ ] Scripts (`.ps1`/`.bat`/`.cmd`) are ASCII + no BOM.
- [ ] Claims are evidence-backed; anything not run is labeled UNVERIFIED (no
      inflated "done").
- [ ] If I changed rules, skills, prompts, scripts, hooks, or docs, I used
      root-cause analysis and principle-based guidance; I avoided spec/case
      overfitting and special-casing unless the PR explains the bounded reason.

## Notes / 비고 (optional)
