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
highest-value one and keep going. If a registered skill matches the task, invoke
it (e.g. `$skill-name`) before doing the work ad-hoc, rather than reimplementing it.

SUCCESS CRITERIA (verifiable — keep working until these hold, then loop again):
- Every change merged passed the safety gates (containment, text-safety,
  mirror-parity) with command-proof evidence — no "done" claim without it.
- The main branch is clean, local safety gates are green, and no PR is left hanging.
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

## Scoped goal examples (review-and-release side)

The loop above is the long-horizon goal. But goal mode also shines on **short,
well-scoped** maintainer work, where the "done" signal is concrete — exactly the
PR-review / release-gating / triage tasks
[the Codex profile is built for](../../../docs/en/codex-and-claude.md). Each block
below is paste-ready and reuses the **same RULES and gates** as the loop above;
only the GOAL and SUCCESS CRITERIA change. Drop in the PR number / version as noted.

**Review one pull request:**

```text
GOAL: Review pull request #<N> in this repository and report whether it is safe
to merge. Read the diff, run the safety gates against the branch, and check it
against the linked issue's intent. Do not merge — leave a verdict.

SUCCESS CRITERIA:
- Verdict is one of: MERGEABLE (gates green, no risk gate, matches the issue) /
  CHANGES-NEEDED (specific, file:line) / BLOCKED (needs a human decision).
- Every claim cites command-proof evidence (gate output, check status); no
  "looks fine" without a run.
- A plain-language summary names the one thing a non-developer should know.
```

**Gate a release:**

```text
GOAL: Verify this repository is ready to cut release <version>. Check the
release conditions that are written down (CHANGELOG entry present, all gates
green on main, version strings consistent, no unresolved placeholder in a
shipped rule) and report PASS/FAIL per condition. Do not tag or publish.

SUCCESS CRITERIA:
- One line per condition with PASS/FAIL and its command-proof evidence.
- If any condition FAILs, the smallest fix is named; tagging/publishing is left
  to the human (release is a manager-only gate).
```

**Triage the open issues:**

```text
GOAL: Work down the open issues. Classify each as runnable-now (safe to do
alone), needs-a-human-decision, or blocked, and act on the runnable ones one at
a time through the normal branch -> PR -> gate -> merge flow.

SUCCESS CRITERIA:
- Every open issue ends in exactly one bucket with a one-line reason.
- Runnable issues are carried to a merged PR (gates green) or, if larger than
  one safe step, split into conflict-aware tickets first.
- Manager-only items are surfaced as short questions, not acted on.
```

---

## Notes

- **Re-trigger on FINISH, not on a clock.** A goal runs long but still ends. Make
  the *next* goal start the moment the current one finishes — wire your runner so a
  goal's completion immediately re-issues the next gap (a finish hook / wrapper that
  loops while there is real work), rather than waiting a fixed interval. "One task
  ends → next starts now." A timed re-issue is only a backup for a fully-closed
  session. (Claude's equivalent is a Stop hook; Codex's is the runner's finish
  hook — same principle, tool-shaped differently.)
- **Audit pass.** For long runs, run a *separate* short check — driven by the same
  finish hook (e.g. every Nth goal) or a low-frequency backup — that re-reads this
  goal + the rules and confirms recent work still serves the goal and that every
  claim has evidence — autonomous runs drift when context is compacted. See the
  overnight skill's "audit worker" discipline (`skills/overnight-autonomous-work/SKILL.md`).
- This file is the Codex-specific artifact; the Claude-specific artifact is its
  workflow/orchestration setup. The success criteria and gates are shared.
