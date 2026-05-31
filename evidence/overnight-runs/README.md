# Overnight run artifacts

> The non-developer promise: **paste one prompt before bed, wake up to merged
> pull requests.** This folder defines what an overnight run leaves behind so you
> can check, the next morning, exactly what the agent did — and, just as
> important, what it **refused** to do without you.

An overnight run is one parent session that surveys all remaining work, splits it
into conflict-aware tickets, fans out worker subagents to do the runnable parts,
recovers from worker failures itself, and escalates only the decisions a human
must own (risk, permission, money, anything irreversible). The worker fan-out is
run by the orchestration tool, not by hand.

Each run drops one **dated artifact** here. The shape is fixed so the morning
read is always the same four questions:

1. **What did it survey?** (the issues / PRs / backlog it looked at)
2. **How many workers ran, on what?** (N worker subagents -> their tickets)
3. **What got merged?** (M merged PR numbers — the wake-up payoff)
4. **What did it REFUSE and escalate to me?** (the risk decisions, in plain
   language, waiting for a human)

## Artifact shape (canonical fields)

A run artifact is a single Markdown file named `YYYY-MM-DD-overnight.md` with
these sections. A machine-readable `YYYY-MM-DD-overnight.json` sidecar may
accompany it with the same fields.

```
run_date            ISO date the run started
duration            wall-clock span of the run
surveyed            counts: open issues / open PRs / backlog items considered
workers             list of { ticket, issue, branch, outcome }   (outcome: merged | pr_open | failed_recovered | blocked)
merged_prs          list of merged PR numbers (the payoff)
escalated           list of { what, why_human_owns_it, manager_label }   <- the REFUSED decisions
gates               which gates ran and their result (PASS / FAIL / BLOCKED)
five_axis           per-axis before/after deltas for the night (see ../5-axis-roi/)
next_actions        what the next session should pick up
```

The **escalated** section is the trust anchor. A safe autonomous loop is defined
as much by what it declines to touch as by what it ships. Every item here maps to
a human-only gate: product/priority calls, credentials, billing/quota, public
release, destructive or irreversible actions, host-global promotion, user-data
transfer, force-push, or history reset.

---

## EXAMPLE / TEMPLATE (not a real run)

> The block below is a **hand-authored illustration** of the shape. PR numbers,
> counts, and timings are placeholders, not measured data. It will be replaced by
> real dated artifacts as overnight runs are captured here. Until then, treat
> every number in this example as UNVERIFIED.

```
run_date:  2026-06-01            # EXAMPLE
duration:  6h 12m                # EXAMPLE

surveyed:
  open_issues:   18              # EXAMPLE
  open_prs:       3
  backlog_items:  7

workers:
  - ticket: "containment: own-path exemption for repo-local config home"
    issue:  "#209"
    branch: "agent/issue-209-own-path-exemption"
    outcome: merged
  - ticket: "gate: detect a deleted hot rule before merge"
    issue:  "#212"
    branch: "agent/issue-212-rule-deletion-guard"
    outcome: merged
  - ticket: "skill: compress session-hot instructions, preserve required rules"
    issue:  "#215"
    branch: "agent/issue-215-instruction-compress"
    outcome: pr_open            # raised, awaiting human review of wording
  - ticket: "port codex preflight check to mirror the claude one"
    issue:  "#218"
    branch: "agent/issue-218-codex-preflight"
    outcome: failed_recovered   # first worker hit a parse error; retried, fixed, re-ran the gate

merged_prs: [209, 212]          # EXAMPLE

escalated:                      # the REFUSED decisions — left for the human
  - what: "Promote the skill-sync hook to also touch the host-global ~/.claude home"
    why_human_owns_it: "Host-global promotion is irreversible without rollback; containment forbids it by default."
    manager_label: "needs_decision"
  - what: "Spend API credit to run the Codex goal-mode PR-review half overnight"
    why_human_owns_it: "Billing / quota is a money axis the human owns."
    manager_label: "needs_decision"
  - what: "Force-push to rewrite a tangled feature branch history"
    why_human_owns_it: "History rewrite / force-push is irreversible."
    manager_label: "needs_decision"

gates:
  containment:        PASS
  windows_text_safety: PASS
  profile_mirror_parity: PASS

five_axis:                       # EXAMPLE deltas — see ../5-axis-roi/ for the method
  tokens_per_ticket:        { before: 41000, after: 33500, unit: "tokens",        note: "EXAMPLE" }
  interventions_per_merge:  { before: 1.8,   after: 0.4,   unit: "human touches", note: "EXAMPLE" }
  time_per_merge:           { before: "—",   after: "—",   unit: "minutes",       note: "UNVERIFIED" }
  money:                    { before: "—",   after: "—",   unit: "usage",         note: "UNVERIFIED" }
  performance:              { before: "—",   after: "—",   unit: "gate pass-rate", note: "UNVERIFIED" }

next_actions:
  - "Human: approve wording on PR for #215, then it auto-merges after gates."
  - "Human: decide the two escalated billing/host-global questions above."
```

## Why this shape

- A non-developer reads top to bottom and learns, in one screen, what happened
  while they slept and what still needs them.
- A reviewer can take any `merged_prs` number to the public GitHub graph and
  confirm it merged.
- The `escalated` list proves the loop is **bounded**: it did the safe work and
  stopped at the human-only line, every time.
