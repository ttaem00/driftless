---
name: overnight-autonomous-work
description: >
  Overnight autonomous work bundle. Use when the human asks to "run everything
  overnight", "push all remaining tickets while I sleep", "do as much as you
  safely can on your own", "paste one prompt and finish the backlog", or asks
  whether each worker task has to be launched by hand. The human pastes ONE
  parent prompt; the parent agent surveys all open work (issues, PRs, backlog,
  TODOs, failing checks), infers the human's real goal from evidence, fans out
  parallel worker subagents, self-recovers worker failures, re-verifies and
  merges finished work, and escalates ONLY risk / permission / product
  decisions to the human. Tool-agnostic: works with Claude (subagents /
  workflow tool) or Codex (goal mode), with no external spawn launcher.
  Triggers: overnight, run everything, all tickets, autonomous, finish the
  backlog, push all remaining work, parent prompt, parallel workers, while I
  sleep, before bed, as far as you can, one prompt.
---

# Overnight Autonomous Work

This skill fires when the human says something like "do as much as you safely
can overnight" or "push all the remaining work as far as it will go." The output
is **an execution bundle the PARENT agent runs end to end** — not a plan, not a
checklist for a person to follow by hand.

The parent is not a single worker. It plays seven roles at once: **project lead,
work decomposer, worker conductor, failure analyst, priority decider, human
reporter, and risk controller.**

Worker orchestration belongs to the agent's own native mechanism (Claude
subagents / workflow tool, or Codex goal mode). There is **no external spawn
launcher** and **no peer/recursive AI call** — the parent drives its own
workers over this one repository's work. Worktree isolation uses the agent's
worktree tooling (or a `worktrees/` directory).

## Root intent (why this is autonomous)

The human is a **non-developer**. They do not read logs to make decisions. What
they actually want to know is:

- Where is the project stuck right now?
- What is the genuinely important work?
- What can be handled immediately?
- What cannot be done, and why?
- What is the root cause when a worker keeps failing?
- What do *I* (the human) actually have to decide?
- What is the next action that moves things forward?

The parent answers those questions in plain language and **owns the rest of the
technical work itself.** Autonomous, but always **within the gates below** — the
human-escalation guardrail is the load-bearing part of this skill.

## The human contract

The normal path is one paste:

```text
The human pastes ONE parent prompt.
The parent owns: survey, worker dispatch/execution, failure recovery,
verification, PR/merge/issue/board gates, and the final report.
Worker tasks are not chores the human runs by hand — they are the parent's
tool and recovery handle.
```

### Escalate ONLY these to the human (everything else the parent owns)

This is the guardrail. The parent is autonomous **inside** this fence and must
stop and ask a short plain-language question for any of these:

- Product direction, value calls, or priority between competing goals.
- Entering or using credentials / secrets / API keys.
- Spending money, paid credits, or quota.
- Public release or production deployment.
- Destructive or irreversible actions (data delete, migration, mass file
  removal, removing existing features).
- Promoting anything to a host-global / system-wide location.
- Moving or changing user data.
- Force-push or history rewrite.
- A confirmed external / network / account block the agent genuinely cannot
  pass.

If a task is NOT on this list, the parent does it — it does not park the work
and wait for the human.

## Load-bearing gates (absolute rules; violating one voids that work)

Bake these into the parent bundle and into every worker instruction.

### G1 — Evidence honesty (most important)

- A behavioral PASS comes only from **real execution** (build / run / end-to-end).
  Static, parse, JSON, fixture, or unit-only checks are supporting evidence and
  leave behavior `UNVERIFIED`. Never report `UNVERIFIED` as `PASS`.
- Verify gates/scripts **in the environment they actually run in** (for example,
  the CI runner's shell — not only your local shell or language runtime).
- External or borrowed code is not "proven" until built and run here.
- Evidence from one tool / shell / environment / repo is not a PASS for a
  different target.
- Every claim carries exactly one status: `PASS` / `FAIL` / `BLOCKED` /
  `UNVERIFIED` / `PARTIAL`.

### G2 — Containment (load-bearing)

- Never read or write host-global agent homes, `.env` / `.env.*`, `.ssh`,
  `secrets/**`, private keys, browser profiles, or cloud credentials. Forbid the
  same to workers.
- Run the project's containment / safety check and require PASS before Done.

### G2b — Token / context runaway guard (the 1 KB rule)

- Any raw output over roughly **1 KB** (long logs, big JSON, file dumps, large
  search results) does NOT go back into the parent's context. Write it to an
  evidence artifact file and return only a short summary plus that path. Bake
  this into worker instructions too. Never write secrets or host-global paths
  into an artifact either (G2 still applies).
- Reason: accumulated raw output is the most common cause of context (token)
  runaway, which derails long overnight runs.

### G3 — Text safety for scripts

- Keep shell/automation scripts portable and encoding-safe: prefer ASCII in code
  and string literals (no fancy dashes or curly quotes), and write config files
  without a byte-order mark (BOM). On Windows specifically, keep `.ps1`/`.bat`/
  `.cmd` ASCII-only and BOM-free, and use quoted forward-slash absolute paths in
  any hook command.
- Verify in the shell the script actually runs under, not only a convenience one.

### G4 — Ticket / git discipline

- Non-trivial change: open an issue first, register it on the project board,
  branch (for example `agent/issue-<n>-<slug>`), open a PR, get CI green, then
  squash-merge. No direct push to the default branch. No reset / stash / clean /
  force-push / history rewrite.
- Durable state (decisions, evidence, next actions) lives in the **issue/PR
  body** under a dated update section — not in throwaway comments. Keep a small
  decisions table before closing.

### G5 — UI / UX gate

- For any UI / screen / layout / component work, read the project's design
  guidance **first** and record that you applied it. Every interactive component
  needs all five states (loading / empty / error / success / disabled) and a
  recovery path; one primary action per view; no dark patterns; never convey
  meaning by color alone.

### G6 — Human reporting

- Plain language, one of four labels first: `built/inspected` ·
  `tested/evidence` · `human run/paste` · `blocked/unverified`. Raw commands and
  logs go **below** the plain summary, as evidence lines only.

## Phase 0 — Evidence preflight (full survey)

Run against the target repo. Mark any failed command `UNVERIFIED` / `BLOCKED` —
never invent a clean state. Preserve unrelated dirty/untracked work (no reset /
stash / clean).

```text
git rev-parse --show-toplevel
git status --short --branch --untracked-files=all
git branch --show-current
git remote -v
git worktree list
<gh/auth status for the host you use>
list open issues (number, title, labels, updatedAt, body, url, board items)
list open PRs (number, title, head, base, draft, mergeable state, updatedAt)
list recently closed issues (for follow-up context)
```

Scan TODO / backlog / pending signals too, but exclude secrets and host-global
paths from the search (skip `secrets/**`, `.env*`, `.ssh/**`, build output, and
dependency directories).

Check the build environment if the project requires a build (language/runtime
versions, required toolchain present).

## Phase 1 — Infer the human's real goal (evidence-based, not a ticket list)

Write this from Phase 0 evidence. Tie conclusions to observations, not guesses.
Signals to weigh: recurring themes, long-neglected core tickets, where recent
PRs cluster, currently failing CI, high-user-impact bugs, anything blocking a
release, doc/code mismatch, phrasing the human emphasized before (in the repo's
instruction files or issue bodies), and work that keeps getting deferred.

Fixed output shape:

```text
Inferred human goal:
Evidence (cite it):
Confidence (high/medium/low + why):
Work to do first for this goal (in order):
Points that need human confirmation:
```

## Phase 2 — Inventory + classification

List every item one per line (open issues, open PRs, TODO/backlog/local pending,
recently closed issues relevant to follow-ups, dirty/untracked work, worktrees/
branches). Give each a one-line reason from this set:

```text
do-now · delegate-to-worker · depends-on(ticket#) · missing-info(what) ·
human-decision · high-risk · possible-duplicate · already-fixed-not-cleaned-up ·
needs-failure-analysis · split-into-long-term-track
```

Reuse existing issues wherever possible. Create new issues only for clear,
verifiable local work. Do not pre-create speculative follow-ups before evidence
justifies them.

## Phase 3 — Parallel planning (conflict-aware)

Build the lane plan, then fan workers out with the agent's native mechanism:

- Build a dependency graph and a **per-ticket surface conflict matrix**.
- Assign each worker lane an owner-write surface, a read-only surface, and a
  forbidden surface.
- Lanes touching the same file or feature run **sequentially**; independent lanes
  run **in parallel**.
- Lanes that edit existing files in parallel run in **isolated worktrees** (do
  not use the root checkout as a parallel worker's worktree). **But a lane that
  CREATES new files does not run in an isolated worktree** — new files made in a
  throwaway worktree may not collect back into the main checkout and can be lost;
  run those in the same checkout. One branch per lane.
- Default concurrency: a small cap (for example 3 parallel workers), within the
  agent's own concurrency limit.
- **Fan-out belongs to the native subagent / workflow mechanism, never to a giant
  parallel batch of raw shell calls.** A large parallel batch is fragile: one
  erroring call cancels the whole batch, and long sessions corrupt tool I/O. Run
  any mutation (push / merge / PR / comment) and any call whose argument depends
  on a prior result **sequentially**, confirming each result before the next.

If a dedicated parallel-planning skill exists in this profile, delegate the lane
decomposition to it instead of re-implementing it inline; otherwise use the rules
above and note `UNVERIFIED_SKILL_MISSING`.

## What "push everything" actually means (do not misread)

"Push all the tickets you can" does NOT mean blindly editing everything. It means:

1. Finish as much safely-doable work as possible.
2. Investigate fuzzy work until it is in a runnable state.
3. Split large work into smaller tickets.
4. For blocked work, produce a clear cause + next action.
5. Clean up duplicate / dead candidates (propose with evidence on the issue).
6. Re-analyze and retry failed worker tasks (recovery loop below).
7. Report only the work that genuinely needs a human decision.

## Phase 4 — Wave loop (repeat until exhausted)

The parent repeats until the exhaustion condition holds:

1. Refresh repo / issue / PR / worktree / report / status / process evidence.
2. Preserve unrelated dirty/untracked work.
3. Create or confirm per-lane worktrees/branches.
4. Launch verified independent worker lanes up to the concurrency cap (via the
   native subagent / workflow mechanism; no external launcher). Give each worker
   the [worker instruction template].
5. If a worker stalls, do not freeze — the parent handles safe lanes itself,
   one at a time (call this **ParentDirectSerial**), under the same issue /
   worktree / verification / PR gates.
6. **The parent must re-verify every worker output** (re-run the evidence). Never
   trust a worker result without re-checking.
7. Adopt only verified output. Re-run verification / mergeability gates.
8. Merge / close / update the board only when it is routine and safe.
9. Create or reuse the smallest follow-up only when evidence justifies it.
10. Recompute remaining doable tickets, then start the next wave or the next
    ParentDirectSerial lane.

**Exhaustion condition:** no doable tickets remain, and everything left is a
genuine human decision, a confirmed external/auth/network block, or a serialized
dependency wait — **AND** every agent-solvable unfinished item has been through a
bounded finish-to-done attempt and recorded in the exhaustion ledger. If even one
item was deferred without an attempt, you are not exhausted yet.

`PARENT_REVIEW_READY` (needs parent adoption) is **not Done** — keep it
review-ready until adopted, verified, and merged.

## Phase 5 — Worker failure recovery (no repeating the same instruction)

When a worker fails, the parent runs a recovery loop:

1. Collect the failure log (raw output, written to an artifact if large).
2. Classify the failure: code error, test failure, build failure, type error,
   lint error, merge conflict, dependency problem, env-var problem, permission
   problem, external-API problem, unclear spec, misunderstood existing structure,
   or the worker instruction itself was ambiguous.
3. Confirm the reproduction conditions.
4. Form one to three cause hypotheses.
5. Try a first fix.
6. Verify by real execution.
7. If it still fails, revise the hypothesis.
8. Narrow or decompose the scope (sub-ticket).
9. Consider reassigning to a fresh worker (add the missing context to its input).
10. Look for a workaround path.
11. If still blocked, report to the human — but always include candidate next
    actions.

Branching by type: an ambiguous-instruction failure means **rewrite the
instruction more concretely and retry** (not a human report). An
environment/toolchain failure means check versions/paths and optionally split a
small follow-up. A permission / credit / external-account failure means a
one-line human question right away.

**What "finish to done" means here:** not an infinite loop — narrow the cause,
**actually try every path you safely can within scope**, then leave a clear state
(done, or blocked + next action). Do not repeat the identical attempt twice in a
row. **Declaring a clear state WITHOUT trying is not finishing** — the exhaustion
ledger below blocks that structurally.

## Phase 5b — Agent-solvable non-completion (not just "missing data")

A recurring trap: deferring doable work to "next time." Missing data is not the
only kind. The essence is **try everything you safely can within scope.** Example:
writing "feature A needs improvement (A is fast-moving latest tech)" and just
opening/closing a ticket is NOT solving it — you must actually research A's latest
state and attempt to apply it.

When you see signals like `needs improvement`, `needs latest research`,
`needs integration`, `needs validation`, `needs cleanup`, `UI discoverability`
(hard for the human to find / hidden entry point), `data is insufficient`,
`need more samples`, `watch`, `follow-up`, or `deferred`, classify the remaining
work **before the final report**:

- **Agent-solvable (default):** run a bounded finish-to-done attempt in the SAME
  run. Directly try bounded approaches — local commands, code changes, tests,
  **directly fixing failed implementation / integration / validation**,
  **researching the latest technology**, **evaluating open-source tools / data
  sources**, dependency probes, **browser automation** for safe public
  collection/verification, **UI discoverability** (wire a hard-to-find feature to
  a human-visible entry point; apply the UI/UX gate), public-internet / public-
  data / transcript paths, repo tooling, and safe local artifact generation. If
  a worker did not do it, the parent does it via ParentDirectSerial.
- **Human-only:** only the escalation-fence items above → one short plain question.
- **Hard-external:** prove the dependency is genuinely impossible (no account /
  paid / credential) with exact command or source evidence.

**No deferring:** an open ticket, a comment-only state, or "the agent can do this
later" is NOT grounds for `PARENT_REVIEW_READY` / Done / exhaustion while
agent-solvable work remains. Try the bounded finish-to-done path first, and record
each method tried, its output, the limit hit, and the exact next runnable retry
condition.

### Same-run attempt evidence gate

**An old open issue, an old comment, or an old artifact is NOT evidence that THIS
run tried and stopped.** To claim a final report / exhaustion / `PARENT_REVIEW_READY`
/ `PR_READY` / "nothing for the human to do," every remaining lane needs a
**current-run attempt ledger** (in the issue/PR body or a linked run artifact)
that includes:

- run id + lane id;
- issue/PR number + current state;
- the commands/actions tried **in this run**, or an explicit `NOT_RUN` reason;
- output, limits, verification result;
- for a lane not re-run, the stale/serialized claim evidence;
- why the remaining work is human-only / hard-external / serialized-wait /
  unsafe / still agent-solvable;
- the exact next runnable retry condition + owner surface;
- a link to the open, not-Done tracker.

Old comments/artifacts/existing issues may be cited as **context** only; if the
parent does not attach or link a this-run ledger, the gate is not satisfied. If
the issue tracker is unavailable, write the same ledger to a run artifact, mark
the posting `UNVERIFIED`, and block that lane from any Done / exhaustion claim.

### Done-state contradiction + future-flow escape

Structurally block the false-completion where a PR is merged but agent-owned
unfinished lanes are hidden behind `status: done`. Compare the run-state file's
lane fields directly, not the report's prose.

- **Done-state contradiction:** if the run is in a done state but a remaining
  agent-owned lane bucket (`blocked` / `serialized_wait` / `claim_released_ready`
  / `not_started` / `failed` / `review_ready`) is greater than zero, you may
  claim Done only if each such lane is covered by a this-run exhaustion-ledger
  entry classified `human-only` / `hard-external` / `serialized-dependency`. An
  empty `blockers: []` is NOT grounds — count the fields. An `agent-solvable`
  ledger entry does NOT count as cover (no laundering open lanes with empty-attempt
  entries). No ledger + remaining lanes + done = the incident itself.
- **Future-flow escape:** if the final report pushes current-run inventory /
  priority / core issues / claim-released lanes into "future ticket flow" /
  "next overnight" / "follow-up" / "later," it FAILs unless it proves one of:
  (1) a human-only decision, (2) a verified hard-external block, (3) a scope
  boundary agreed before the run, (4) a bounded same-run attempt exhausted with
  command evidence, or (5) an open not-Done tracker + the exact next runnable
  retry condition (the parent's continuation goal). "Hand it to normal future
  ticket flow" is itself a decomposition/exhaustion failure.
- **Claim-released reclassification:** a lane that was serialized only because of
  a claim, once clear to start, is no longer serialized — reclassify it as
  runnable-now (or human-only / hard-external). It cannot be parked under done
  without a same-run attempt.
- **No "human run/paste: none":** while agent-solvable work remains, do not end
  with "nothing for the human." Output a **parent continuation goal** instead (the
  exact next runnable lane / command).

## Exhaustion ledger (structural; deferring without trying FAILs the gate)

Do not leave deferral to human judgment — block it structurally. For every item
this run leaves open / deferred / blocked / review_ready, write an **exhaustion
ledger entry** (a small JSON record per run). A discipline check validates the
rules per classification:

- `classification: agent-solvable` → **requires `attemptedApproaches` (>= 1, each
  with approach + outcome) + `limitHit` + `nextRetryCondition`.** Leaving it open
  with an empty `attemptedApproaches` = "deferred without trying" = FAIL. ("I'll
  do it next overnight" is not an approach.)
- `classification: human-only` → requires a `humanQuestion` (no self-approval).
- `classification: hard-external` → requires `externalEvidence` (proof it is
  impossible + the next retry condition).
- `classification: serialized-dependency` → requires `dependsOn` (the lane/issue
  it waits on).

A final report must not say "nothing for the human to decide" while leaving
agent-solvable work untried. It must say what was tried (`attemptedApproaches`),
what was found, what is still open and why (`limitHit`), and why there is no safer
agent action available now (or the `nextRetryCondition`).

## Phase 6 — Run reconciliation (before Done / report)

Reconcile real artifacts against the report before Done / merge-ready / final
report.

- Read worker statuses/reports, PR/issue states, and the run-state file if one
  exists (it is the source of truth).
- Generate the final report from **real state evidence**, not a stale template.
- Include lane counts: merged/adopted · review-ready · blocked · not-started ·
  failed · skipped. **Count these from the lane state fields, not the report
  prose** — apply the done-state contradiction gate (a done state with a non-zero
  remaining bucket is not Done without ledger cover; an empty `blockers: []` does
  not pass).
- Count ParentDirectSerial lanes and explain them as "worker-execution recovery /
  alternative," not hidden success.
- On a mismatch, write the exact discrepancy into progress, fix the report /
  adoption state, then close.

## Phase 6b — Final artifact-to-claim audit (STOP gate before the final report)

Before the final report / Done / exhaustion / "all safe lanes ran," the parent
runs a **final artifact-to-claim audit**. This is a required STOP gate, not an
optional review. The audit reconciles the human report, parent progress, worker
reports, lane-state JSON, the run-state file, issue/PR comments, and key
artifacts. If any of these agent-solvable contradictions exists, **FAIL** the
report and return to the wave loop or ParentDirectSerial:

- **skipped-stage:** an artifact contains `SKIPPED_NOT_RUN`, `NOT_RUN`,
  `UNVERIFIED`, `PARENT_REVIEW_READY`, `TODO`, `follow-up`, `watch`, or "not run"
  while the final report claims exhaustion / Done / "no work left."
- **stale-input:** an upstream lane expanded its evidence (candidates, sources,
  browser evidence, dependency/tool availability, fixtures) after a downstream
  lane ran, but the downstream propose/verify/match/score/review/prepare lane was
  **not re-run** with the new artifact.
- **downstream-rerun:** a claim of "more input" / "improved coverage" / "new
  artifact exists" without the dependent lane re-running its runnable command path
  (count-only correction).
- **contradiction:** "all safe lanes ran," "nothing for the human," or "complete"
  conflicts with a lane artifact showing a runnable unfinished stage, stale
  evidence, missing verification, or merely-proposed data.
- **review-ready:** `PARENT_REVIEW_READY` is not Done and cannot be hidden as
  complete without parent adoption + gate re-run + merge/close, or an explicit
  not-Done tracker.

If the audit catches an agent-solvable problem, run the smallest bounded retry
**before** reporting: re-run the downstream command with the latest artifact, run
the skipped local test / tool / browser / open-source / dependency / data path,
or, if the checker itself is the blocker, build/repair the missing checker. Only
then report the remaining human-only / hard-external blocks.

**Do not skip the audit because a reconciliation/validator script is missing.** If
the script is absent or cannot run, do a **manual** artifact-to-claim audit and
open the smallest follow-up issue for the missing checker. "No verification tool"
never means "verification optional" (evidence honesty).

Include a compact audit summary in the final report (saves tokens vs pasting raw
logs): `final artifact audit: PASS|FAIL` · `skipped runnable stages: 0/N` ·
`stale downstream lanes: 0/N` · `parent review-ready lanes: 0/N` (review-ready !=
Done) · `retry-before-report run: yes/no`.

## Safety (never without human approval)

Do not delegate these to a worker either. Stop and ask the human a one-line
question (G6 format): production deploy, public release, running a data delete /
migration, changing or moving user data, spending paid credits, large
auth/permission changes, exposing a secret / API key / token, mass file delete,
removing an existing feature, host-global promotion, force-push, or history reset.
And simply do not do these: claim "mergeable" without tests, or report an
unconfirmed guess as fact.

Workers do not call other AIs / agents / bridges. (The parent orchestrating its
own subagents/workflow over this repo's own work is allowed and expected.)

---

## Template 1 — Parent prompt (the single paste the human gives)

> Keep long instructions in this SKILL.md and the bundle files; keep the pasted
> prompt short.

```text
You are the PARENT session for this repo (<TARGET_REPO>). Roles: project lead,
work decomposer, worker conductor, failure analyst, priority decider, human
reporter, risk controller. The human is a non-developer — report in plain
language, covering only: where it is stuck, what is done, and what the human
must decide.

Run Phases 0 to 6b of the overnight-autonomous-work skill exactly:
(0) Full survey of issues / PRs / backlog / TODOs / failing signals / recent
    commits / docs (leave evidence commands).
(1) Infer the human's real goal from evidence (goal / evidence / confidence /
    do-first / needs-confirmation).
(2) Classify every item. (3) Plan parallel lanes: path-disjoint conflict matrix
    + the new-files-do-not-go-in-a-worktree rule.
(4) Fan workers out with your native subagent / workflow mechanism per that plan;
    repeat waves until exhausted. If a worker stalls, handle safe lanes yourself
    via ParentDirectSerial.
(5) Recover worker failures with the recovery loop (no repeating the same
    instruction; narrow the cause and retry).
(5b) Agent-solvable unfinished work (NOT just data collection — latest-tech
    research, open-source evaluation, browser automation, integration,
    validation) is NEVER deferred to "next overnight." Attempt bounded
    finish-to-done in THIS session. Record every open/deferred item in an
    exhaustion ledger with attemptedApproaches + limitHit + nextRetryCondition
    (deferring without trying FAILs the discipline check).
(6) Reconcile report vs reality before Done. (6b) Run the final
    artifact-to-claim audit before reporting (on FAIL, bounded retry then
    re-audit; if no script, audit manually).

Absolute rules: behavioral PASS only from real execution (static = UNVERIFIED).
Verify gates in the shell they actually run under. Containment/safety check PASS
before Done. Keep automation scripts ASCII and BOM-free. Non-trivial change:
issue -> board -> branch -> PR -> CI green -> squash. No direct push to the
default branch. Durable state in the issue/PR body.

You own routine git / host / verification / merge / issue / board work. Escalate
ONLY genuine human decisions: product/priority, credentials, paid credits,
public release, destructive actions, host-global promotion, force-push. Worker
tasks are your tool, not the human's chores.

Start at Phase 0 now and finish with the [final report template].
```

## Template 2 — Worker instruction (sent to each worker)

```text
[worker goal] one sentence, no vague words, a measurable outcome.
[ticket] issue number / branch agent/issue-<n>-<slug> / dependency ticket (if any).
[worktree] isolated absolute path (required when parallel conflict is possible;
  but NOT for a new-file-creating lane).
[inputs] files / docs / prior worker outputs to read + the contract rules that
  apply (which of G1 to G6).
[owner / read-only / forbidden surfaces] what this worker may write / read only /
  must not touch.
[steps] step by step; name the files you will touch.
[done definition] what must be true to be done; require REAL execution evidence
  (build/run/test command + result).
[verification] which command verifies it (in the shell the gate runs under).
[forbidden] the Safety/gate items that bind this task (e.g. no paid call, no
  host-global access, no other-AI call).
[report format] return structured data:
  - what you did / list of changed files
  - verification commands run + raw result summary (PASS/FAIL/UNVERIFIED label)
  - blockers (if any: failure type + reproduction condition)
  - candidate next actions
  - final signal: one of PARENT_REVIEW_READY / PR_READY / BLOCKED_TRUE_HUMAN /
    HARD_EXTERNAL_BLOCKED (a STOP is void without non-agent-solvable evidence).
Your output is data returned to the parent, not a message to a person. The parent
re-verifies it.
```

## Template 3 — Worker re-instruction after failure (no repeating the same task)

```text
[original goal] <unchanged>
[failure type] code / test / build / type / lint / merge-conflict / dependency /
  env-var / permission / external-API / unclear-spec / misunderstood-structure /
  ambiguous-instruction.
[failure evidence] <key raw log>   [reproduction] <which command/input>
[cause hypothesis] 1) ... 2) ...
[change this time] (pick at least one)
  - narrow/decompose scope: <what smaller unit only>
  - add inputs: <missing context/files>
  - workaround: <different implementation / temp stub / reorder>
  - make it concrete: <ambiguous part -> measurable condition>
[this time you must] verify <X> by real execution and attach command + result.
  No repeating the same approach.
[report format] same as Template 2.
```

## Template 4 — Human report (when blocked or a decision is needed; plain language)

```text
blocked/unverified:    (or built/inspected · tested/evidence · human run/paste)
Overall situation: (one or two sentences a non-developer understands)
Done:
In progress:
Blocked:
Why blocked: (in plain words)
What the parent/workers already tried:
Remaining options:
Decision the human must make: (or "none")
Recommended decision: (with a one-line reason, if any)
Risk: low / medium / high (+ why)
-- evidence lines (commands / paths / PR numbers / raw errors) --
<technical logs go only below here; never in the summary above>
```

## Template 5 — Final completion report (end of overnight; parent -> human)

```text
<first-line label: built/inspected | tested/evidence | human run/paste | blocked/unverified>
1) Done (merged/verified): issue/PR numbers + one-line result + evidence status (PASS).
2) Built but unverified (UNVERIFIED): what and why + follow-up issue number.
3) Blocked: item + cause + what was tried + next action / human decision.
4) Duplicate/dead cleanup: which tickets were merged/retired and why.
5) New follow-up / sub-tickets opened (numbers).
6) Lane counts: merged/adopted / review-ready / blocked / not-started / failed /
   skipped. ParentDirectSerial lane count (= worker-execution recovery, not hidden
   success).
7) Host evidence: this verification was on <host> only — other platforms UNVERIFIED.
8) What the human must decide now (compact, numbered): each + risk level.
-- the last line is exactly one of --
MERGED_DONE                 (verified and merged; no human decision pending)
PR_READY                    (PR ready, awaiting human merge approval / gate)
BLOCKED_NEEDS_FOLLOWUP      (blocked; needs follow-up / decision)
```

## Final check before Done (skip it and you may not report Done)

- [ ] Containment / safety check PASS.
- [ ] Any changed automation scripts pass text-safety (ASCII, no BOM).
- [ ] Behavioral claims have real execution evidence (else UNVERIFIED + follow-up).
- [ ] Unverified remainder is filed as follow-up issues (or a one-line human
  question for human-only items).
- [ ] Each ticket's issue/PR **body** has a dated update + a small decisions table.
- [ ] Board updated. No direct push to the default branch. Risk/permission items
  to the human only.

## Self-check (did this skill build a real execution bundle?)

- [ ] An execution bundle, not a plan-only reply.
- [ ] Normal human path = one parent prompt.
- [ ] Worker orchestration via the native subagent / workflow mechanism (no
  external launcher, no peer/recursive AI call).
- [ ] Parallel lanes are conflict-aware; new-file lanes are NOT isolated in a
  worktree (loss prevention); the root checkout is not used as a parallel worker.
- [ ] The parent re-verifies every worker output.
- [ ] Worker failures go through the recovery loop (no repeating the same task).
- [ ] When a worker stalls, ParentDirectSerial runs before any human fallback.
- [ ] Waves repeat until exhausted. PARENT_REVIEW_READY != Done.
- [ ] Agent-solvable unfinished work (not just data collection) was attempted in
  THIS session via bounded finish-to-done, not deferred to "next overnight."
- [ ] Every open/deferred/blocked item has an exhaustion-ledger entry
  (agent-solvable: attemptedApproaches + limitHit + nextRetryCondition) and the
  discipline check passes.
- [ ] Done-state contradiction checked by counting lane fields (not prose); a done
  state with a non-zero remaining bucket is covered by a human-only / hard-external
  / serialized-dependency ledger entry, not an empty `blockers: []`.
- [ ] No future-flow escape: current-run/core work was not handed to "next
  overnight" without proof (human-only / hard-external / scope / exhaustion /
  continuation goal).
- [ ] No "human run/paste: none" while agent-solvable work remains (output a parent
  continuation goal + next lane instead).
- [ ] Run reconciliation detected stale reporting + lane counts (field-based).
- [ ] Final artifact-to-claim audit ran (or was done manually); on FAIL, bounded
  retry then re-audit; compact audit summary included in the report.
- [ ] Only genuine human decisions escalated. Workers do not call other AIs.
- [ ] Dirty/untracked human work preserved. No direct push to the default branch.
- [ ] Evidence-honesty / containment / text-safety / ticket-workflow gates are baked in.
- [ ] Final report is plain language, four labels, with an exact last-line signal.
```
