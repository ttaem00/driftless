<!--
Driftless PRs merge only when the safety gates pass (CI runs them on Windows +
Linux). You can run them locally too — they print plain-language reasons.
-->

## What this changes / 무엇을 바꾸나

<!-- One or two plain sentences. Link the issue it closes: "Closes #NN". -->

## Checklist

- [ ] The safety gates pass locally or in CI (containment, text-safety, mirror-parity):
      `./scripts/Test-Containment.ps1 -Path . -AllFiles`,
      `./scripts/Test-WindowsTextSafety.ps1 -Root .`,
      `./scripts/Test-ProfileMirrorParity.ps1 -Path .`
- [ ] If I changed a shared rule/skill, I changed it **once in the shared tier**
      (one edit → both Claude and Codex profiles), not separately per tool.
- [ ] No secrets, no host-global agent config, no machine paths — public-safe.
- [ ] Scripts (`.ps1`/`.bat`/`.cmd`) are ASCII + no BOM.
- [ ] Claims are evidence-backed; anything not run is labeled UNVERIFIED (no
      inflated "done").

## Notes / 비고 (optional)
