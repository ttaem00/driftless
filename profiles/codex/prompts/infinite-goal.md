# Codex `goal` prompt — infinite maintainer loop (paste-ready)

This is the **Codex** counterpart of the Claude infinite-develop loop. Claude runs
a long task with dynamic workflow orchestration; **Codex runs it as a `goal`** —
you give a long-horizon goal plus verifiable success criteria, and Codex works
autonomously toward it. Paste the block below into Codex (goal mode) from inside
the repo you want maintained.

> The two tools reach the same outcome differently: Claude = workflow/subagents +
> a scheduled re-trigger; Codex = a `goal` with success criteria that keeps it
> working longer. Pick the one you have; the shared rules and gates are identical
> (one source drives both profiles).

---

## Paste this into Codex (goal mode)

```text
GOAL: Keep this repository healthy and moving, autonomously, over a long horizon.
Survey the open issues, split them into conflict-aware tickets, work each on its
own branch, open PRs, and merge only the ones that pass every safety gate. Treat
this as a continuous loop, not a one-shot: when one ticket is done, pick the next
highest-value one and keep going.

SUCCESS CRITERIA (verifiable — keep working until these hold, then loop again):
- Every change merged passed the safety gates (containment, text-safety,
  mirror-parity) with command-proof evidence — no "done" claim without it.
- The main branch is clean and CI is green; no PR left hanging.
- Each cycle improved at least one of: onboarding, trust, Codex/Claude
  applicability, non-developer ease, tokens/time/money/intervention, recurring-
  mistake prevention, security/openness, or community reach.
- A short plain-language progress note is left each cycle (done / needs-your-
  decision / blocked / in-progress) so a fresh session can resume.

RULES:
- Do NOT stop to ask after each unit — keep going. Only pause for a human
  decision on: product/priority, credentials/secrets, spending money/credits,
  public release, destructive/irreversible actions, host-global promotion, moving
  user data, force-push/history rewrite, or a confirmed external block.
- Evidence honesty: a static change is UNVERIFIED until a real run/gate proves it;
  never report UNVERIFIED as PASS; if a tool result is empty/malformed, retry once
  then stop — never act blindly on unseen output.
- Containment: never read or write host-global agent config, secrets, .env, SSH
  keys, or browser profiles. The isolated home stays inside this repo.
- Improve BOTH profiles where the change is shared (one edit -> both, enforced by
  the mirror-parity gate); keep tool-specific work in the right profile.
- Stay lean. Small reversible pieces, not new heavy infrastructure.

WHEN YOU CANNOT CONTINUE: don't declare "done" — leave a resume note plus the next
ticket so the next session (Codex or Claude) picks up exactly where you stopped.
```

---

## Notes

- **No self-restart by itself.** A goal runs long but still ends; to make it truly
  continuous, re-issue this goal on a schedule (your runner's cron / a wrapper),
  or have a human paste it again — same structural point as the Claude side.
- **Audit pass.** For long runs, periodically (e.g. every ~15 min) run a *separate*
  short check that re-reads this goal + the rules and confirms recent work still
  serves the goal and that every claim has evidence — autonomous runs drift when
  context is compacted. See the overnight skill's "audit worker" discipline
  (`skills/overnight-autonomous-work/SKILL.md`).
- This file is the Codex-specific artifact; the Claude-specific artifact is its
  workflow/orchestration setup. The success criteria and gates are shared.
