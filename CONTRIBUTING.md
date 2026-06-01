# Contributing to Driftless

Driftless is a small, lean kit you own — not a heavy framework. Contributions
that keep it lean, safe, and non-developer-friendly are welcome.

## The one rule that matters

**Every change passes the safety gates before it merges.** They are the same
gates CI runs, and you can run them locally:

```powershell
# Windows PowerShell
.\scripts\Test-Containment.ps1 -Path . -AllFiles      # never touches forbidden paths / no leaked secret
.\scripts\Test-WindowsTextSafety.ps1 -Root .          # .ps1/.bat/.cmd stay ASCII + no BOM
.\scripts\Test-ProfileMirrorParity.ps1 -Path .        # the two profiles never drift
.\scripts\Test-SkillOptValidationHarness.ps1          # skill changes do not regress the 5 axes
.\scripts\Test-WorkDiscipline.ps1 -Root .             # no unresolved placeholder ships as a rule
.\scripts\Test-SkillAudit.ps1 -Root .                 # every shipped SKILL.md is structurally sound
```

```sh
# macOS / Linux: the installer path runs without PowerShell
sh ./install.sh --dry-run --both
```

If a gate FAILs, fix the cause — do not weaken the gate. Gates are proven in both
directions (they must still FAIL on a planted violation), so disabling a check is
itself caught.

## How the loop maintains this repo

Most of this repo's own work is done by the overnight autonomous loop it ships:

1. A goal is given in plain language.
2. The agent surveys open issues, splits them into conflict-aware tickets, and
   works each on its own `feat/issue-<n>-<slug>` branch.
3. Each change runs the gates, becomes a pull request linked to its issue, and
   merges only when the gates are green.
4. Risk, permission, billing, public-release, and destructive actions are
   escalated to the human maintainer — never decided by the agent.

You can contribute the same way by hand: open an issue, branch from it, keep the
change small and gate-green, and open a PR that links the issue.

## Conventions

- **Scripts** (`.ps1` / `.bat` / `.cmd`) must be **ASCII + no BOM** so Windows
  PowerShell 5.1 parses them. Put non-ASCII prose in Markdown, not scripts.
- **Shared before tool-specific.** If a skill or rule applies to both Claude and
  Codex, put it once under `profiles/shared/` so one edit improves both profiles.
  Tool-specific work goes under the owning profile.
- **Evidence-first.** No "PASS"/"done" claim without command proof. Label
  anything unrun `UNVERIFIED` rather than claiming it.
- **Honest status.** Keep the `UNVERIFIED` / "day one" / host-evidence caveats
  accurate. Do not inflate them into stronger-sounding claims.

## Reporting problems

Open an issue describing what you did, what you expected, and what happened. If
it is a safety/containment concern, see [SECURITY.md](./SECURITY.md) if present,
or mark the issue clearly so a maintainer triages it first.
