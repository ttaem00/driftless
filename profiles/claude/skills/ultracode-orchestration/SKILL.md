---
name: ultracode-orchestration
description: >
  울트라코드 ultracode-orchestration: Claude's headline mode for big or ambiguous
  goals -- maximum (xhigh) reasoning effort plus dynamic multi-agent workflow
  orchestration, where Claude spawns its own subagents/lanes over THIS repo's own
  work inside one harness. The harness owns spawning; risky edits to existing
  files run in isolated worktrees. Use to decide WHEN to escalate to ultracode
  versus run a single-agent low-effort flow, and how to fan out lanes natively
  instead of faking parallelism with raw shell batches. This is the Claude-only
  part; tool-agnostic lane/conflict/evidence rules live in the shared skills.
  Trigger / 트리거: "울트라코드", "ultracode", "xhigh", "high effort",
  "최대 추론", "멀티 에이전트", "multi-agent", "서브에이전트", "subagents",
  "워크플로 오케스트레이션", "workflow orchestration", "lanes 병렬",
  "fan out", "이 큰 작업 한 번에", "복잡한 목표", "ambiguous goal",
  "이거 ultracode로", "오케스트레이션", "병렬 작업 직접".
---

# Ultracode Orchestration (Claude-only headline mode)

Ultracode is Claude's headline operating mode for THIS isolated runtime. It is
two settings turned up at once:

1. **Reasoning effort = xhigh (maximum).** Claude spends more thinking budget per
   step. This is the right default only when the goal is large, ambiguous, or
   high-stakes enough that a wrong cheap pass costs more than the extra thinking.
2. **Dynamic multi-agent workflow orchestration.** Claude does not just answer in
   one thread -- it plans lanes and spawns its OWN subagents/worker lanes over the
   repo's own work, then reviews and adopts their output itself.

This file is the **Claude-specific** part: what ultracode is, when it applies, how
spawning works here, and how it contrasts with Codex. The **tool-agnostic** parts
-- conflict-aware lane decomposition, the owner/read-only/forbidden surface
matrix, the new-file isolation rule, evidence statuses, and the manager report
contract -- live ONCE in the shared skills (parallel lane planning, finish-to-done,
autonomous overnight work). Read those for the lane mechanics; do not restate them
here.

## The spawning model (read this before you orchestrate)

- **The harness owns spawning.** Claude does not shell out to an external launcher
  to start workers. In-session parallel fan-out is done through the native workflow
  / subagent mechanism, which caps concurrency and gives native isolation. This is
  the FIRST CHOICE for any in-harness lane work.
- **Subagents/lanes are Claude working on THIS repo's own work.** They are not peer
  AIs, not other CLIs, not bridges to other models. Self-orchestration over this
  repo is allowed and expected; spawning a peer/recursive external AI is not.
- **Never emulate fan-out with a raw parallel shell batch.** Packing one response
  with a large batch of parallel shell calls is not lane parallelism: one call
  erroring cancels the whole batch, and big batches in long sessions corrupt tool
  I/O. The native workflow tool/subagents cap concurrency; the raw main loop does
  not. Run mutations (push / merge / PR create / issue comment) and any chained
  call whose later argument depends on a prior result sequentially, verifying each
  result before the next.
- **Risky edits to existing files use isolated worktrees.** Lanes that edit the
  SAME existing file are isolated in a per-lane worktree. **Lanes that CREATE new
  files must NOT use a separate worktree** -- new files made in a side worktree do
  not collect back into the main checkout and are silently lost; isolate those by
  disjoint file paths in the shared checkout instead (the shared conflict-matrix
  rule). If a lane both edits a shared file and creates new files, split it or
  serialize it.
- **The parent re-verifies every worker output.** A worker lane ending at
  "review-ready" is not Done. The parent reviews the diff and evidence, runs the
  gates again, and only then adopts / merges / closes. Worker lanes do not
  self-merge, self-close issues, or claim final completion.

## Contrast with Codex goal lanes (one paragraph, do not over-mirror)

Codex parallelizes through an **external launcher** that drives discrete "goal"
lanes -- a separate process model. Claude parallelizes **natively inside one
harness**: it fans out subagents/lanes itself, with built-in concurrency caps and
worktree isolation, and the same Claude session that planned the lanes reviews and
adopts their work. These are different paradigms by design. Do not force a
symmetric port: take the lane-decomposition / conflict-matrix discipline (which is
shared and tool-agnostic) but keep Claude's spawning native and the goal-lane
launcher wrapper out of scope. "Codex did it with an external launcher" is not a
reason to add one here.

## WHEN ultracode applies vs a single low-effort agent (lean gradient)

Ultracode is powerful and expensive. The discipline is **lean gradient**: spend the
least effort that reliably answers the decision in front of you, and escalate only
when the cheap path would likely be wrong or wasteful. Decide BEFORE you start, not
after you have burned the budget.

**Escalate to ultracode (xhigh + orchestration) when most of these hold:**

- The goal is large or ambiguous -- multiple sub-problems, unclear scope, or the
  manager said "do everything / push all of it / figure out what matters."
- The work decomposes into **independent, parallel-safe lanes** with disjoint write
  surfaces (so fan-out actually buys wall-clock and the parent can adopt in waves).
- A wrong first pass is costly -- it touches load-bearing code, release decisions,
  or a long dependency chain where a shallow guess compounds.
- The work spans many tickets/files and benefits from a parent that plans, recovers
  failed lanes, and reconciles before reporting.

**Stay single-agent, low effort, no fan-out when:**

- The task is small, well-specified, and local (one file, one obvious fix, a
  rename, a doc tweak, a single command's output).
- There is no real parallelism -- everything is serially dependent, so lanes would
  just add coordination overhead with no wall-clock gain.
- A quick read or a single gate run answers the question. Do not spin up a parent +
  workers to do what one focused pass does.
- Cost/context is the binding constraint and the cheap pass is very likely correct.

**Lean-gradient rule of thumb:** start at the lowest effort that can plausibly
succeed; escalate one notch (low -> high -> xhigh, single -> orchestrated) only when
evidence shows the cheaper tier is failing or would be wrong. Do not default to
ultracode for everything -- a non-developer manager pays for the runaway in
time/tokens/intervention, and over-orchestration on a tiny task is itself a defect.
When you do escalate, state in one line the decision it answers, the success
evidence, and the follow-through on success or failure (close as adopted, promote to
a scale issue, or reject with evidence) -- don't leave a pilot open-ended.

## Orchestration loop (Claude-specific shape; lane rules are shared)

When ultracode applies, the parent runs a wave loop and owns seven roles at once:
project lead, work decomposer, lane conductor, failure analyst, prioritizer,
manager reporter, risk controller. Concretely:

1. Refresh evidence (repo / issues / PRs / worktrees / failing checks). Preserve
   unrelated dirty/untracked work -- never reset, stash, or clean it away.
2. Delegate lane decomposition and the conflict matrix to the shared parallel-lane
   planner; do not re-implement that inline.
3. Fan out the verified independent lanes natively (workflow tool / subagents) up
   to the concurrency cap. Isolate same-file edits in worktrees; isolate new-file
   lanes by disjoint paths.
4. If a lane blocks, do not stall -- the parent processes a safe lane directly,
   serially, under the same gates.
5. Re-verify every lane's output yourself before adopting. Adopt only verified work.
6. Reconcile reported status against actual artifacts before any Done / merge-ready
   / final report. Count lanes from real state, not from prose.
7. Recover failed lanes by narrowing the cause and changing the instruction --
   never re-send the identical failing instruction. Escalate to the manager only
   the true manager-only decisions; everything agent-solvable stays with Claude and
   is finished this session.

## Boundaries (load-bearing; described in prose, never embed a forbidden token)

- Run Claude against the repo-local config home, never the host-global agent home.
  Do not read or mutate credentials, environment files, key material, browser
  profiles, or any secrets directory. Worker lanes inherit the same boundary.
- Do not spawn peer or recursive external AI calls in the active path. Claude
  orchestrating its OWN subagents over this repo's work is the allowed exception and
  is exactly what ultracode is.
- Behavioral claims need a real end-to-end run; static/parse/fixture checks leave
  behavior UNVERIFIED. Use one status per claim: PASS / FAIL / BLOCKED / UNVERIFIED /
  PARTIAL. Route any large raw output to an evidence artifact and return only a
  summary plus its path -- accumulated raw output is the most common cause of
  context/token runaway.
- Before Done, the containment guard must pass, and any changed shell/script files
  must pass the text-safety gate. Report to the manager in plain Korean, starting
  with one of the four manager labels, with raw command evidence below the summary.

## Self-check (before claiming ultracode was the right mode)

- [ ] Effort tier and orchestration were CHOSEN against the goal, not defaulted.
- [ ] If single-agent low-effort would have answered it, that was used instead.
- [ ] Lanes were spawned natively (harness-owned), never via a raw parallel shell
      batch and never via an external launcher.
- [ ] Same-file edit lanes used worktrees; new-file lanes used disjoint paths, not a
      side worktree.
- [ ] Mutations and chained calls ran sequentially with verified results.
- [ ] Every worker output was parent-re-verified before adoption; review-ready was
      not reported as Done.
- [ ] No peer/recursive external AI was spawned; no forbidden path was read/written.
- [ ] Containment + text-safety gates passed; report is plain-Korean, evidence below.
