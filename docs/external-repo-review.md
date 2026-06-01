# External repo review

A lean, evidence-honest look at the trendy agent repos most relevant to
Driftless, and a per-repo verdict on whether to adopt anything from them.

**Why this is short on purpose.** Driftless is a small, two-profile
(Claude + Codex) maintainer-automation kit: shared skills, a static 5-axis
skillopt harness, and three gates (containment, mirror-parity, text-safety),
all offline and inside a repo-local isolated home. The point of this review is
to stay that way. For each repo we ask one question: *does it reduce time /
tokens / manager intervention without adding infrastructure, a paid surface, a
recursive-AI loop, or a containment hole?* Most answers are "borrow one idea, or
watch for later" — not "adopt a framework". Keeping Driftless light is the win.

## How to read the verdicts

- **ADOPT** — a small, reversible idea worth folding in now (or already folded in).
- **PILOT_ONLY** — promising, but prove it on one real Driftless flow before keeping it.
- **WATCH_LATER** — good idea, wrong size for day-one Driftless; re-check on a stated trigger.
- **DO_NOT_ADOPT** — conflicts with a Driftless boundary (infra, paid surface, recursion, containment).
- **INSUFFICIENT_EVIDENCE** — not verified deeply enough here to judge; would need a live read.

**Evidence labels.** *Observed* = read directly in Driftless's own files this
session. *Inferred* = reasoned from the candidate list / Driftless's design.
*Unverified* = repo metadata (stars, last commit, license, CI, security policy)
was **not** fetched live in this review, so any such claim stays Unverified until
a real read. We do not inflate.

---

## 1. microsoft/SkillOpt — `ADOPT` (already adapted; keep the lean form)

- **Useful pattern.** Treat a markdown skill file as a tunable artifact: change
  it a little, measure, keep the change only if it scored better. "Skills are
  trainable like parameters." *Inferred from the reference summary; the live
  repo's training loop was Unverified here.*
- **Risk / do-not-adopt.** The original framing implies an *iterative,
  trajectory-and-validation* optimizer — which in a faithful port would mean
  repeated model runs (cost, tokens, possibly a trainer). That violates
  Driftless's "no paid/billed surface, no recursive AI, offline" rule.
- **Lightweight adaptation for Driftless.** Already done, and deliberately
  stripped: `skills/skillopt/SKILL.md` + `scripts/Test-SkillOptValidationHarness.ps1`
  keep *only* the gradient idea as a **static** baseline-vs-candidate scorer on
  five axes (tokens / manager / time / money / perf) with a zero-regression,
  zero-dropped-safety-term gate and three built-in self-test pairs.
  *Observed in Driftless this session.* No model call, no trainer, no network.
- **Cost.** Zero ongoing — it is a PowerShell text scorer; cost is tokens/time, never dollars.
- **Non-developer explanation.** Before keeping any tweak to an instruction file,
  a one-screen score says ACCEPT or REJECT and why. You never have to read code
  to know a change is safe to keep. The expensive "train a model on your skills"
  part is intentionally left out so it never costs money.

## 2. humanlayer/12-factor-agents — `WATCH_LATER` (mine one principle, don't import the doc)

- **Useful pattern.** A checklist of production-agent principles: own your
  prompts, own your context window, small focused agents, explicit
  human-in-the-loop, stateless/reducer control flow. Driftless already lives
  several of these (human-only gates, isolated profiles, skills as owned
  prompts). *Inferred.*
- **Risk / do-not-adopt.** It is a *principles document*, not a tool. Importing
  the whole framing as Driftless docs would bloat the hot context and duplicate
  what `guardrails.md` + the lesson-promotion ladder already say. No code to adopt.
- **Lightweight adaptation for Driftless.** At most, cite it as prior art in one
  line of `docs/en/apply-to-your-agent.md` if a reader asks "is this grounded in
  known practice?" Do not port the document. *Recommendation.*
- **Cost.** Zero (a citation), or net-negative if imported wholesale (context bloat).
- **Non-developer explanation.** A well-known list of "how to build agents that
  don't go off the rails." Driftless already follows most of it; we just point
  to it rather than copying it in.
- **Re-check trigger.** If Driftless ever adds a *runtime* agent loop (not just
  skills + gates), revisit factors 5–8 (state, control flow) as a real design input.

## 3. anthropics/skills — `ADOPT` (format only — already the native format)

- **Useful pattern.** The `SKILL.md` convention itself: a front-matter
  `name` + `description`/trigger, then a procedure body, reusable across Claude
  Code / Claude.ai / API. *Inferred; matches what Driftless ships.*
- **Risk / do-not-adopt.** The *sample skill content* is general-purpose and
  off-domain for a maintainer-automation kit. Bulk-copying example skills would
  add unmaintained surface that the mirror-parity gate would then have to police
  on both profiles for no benefit.
- **Lightweight adaptation for Driftless.** Keep authoring Driftless skills in
  the same `SKILL.md` shape (Driftless already does — `profiles/shared/skills/*`,
  `profiles/claude/skills/*`, `profiles/codex/skills/*`, `skills/*`, all use it).
  *Observed.* Borrow the *format and trigger discipline*, not the example skills.
- **Cost.** Zero — it is the convention Driftless is already built on.
- **Non-developer explanation.** Driftless's "skills" use Anthropic's own
  standard file format, so they work in normal Claude tooling and aren't a
  private invention. We follow the format; we don't copy their example tasks.

## 4. nvidia/skillspector — `ADOPT` (pilot shipped as the in-repo Test-SkillAudit gate)

- **Useful pattern.** Scan an agent skill for malicious patterns / risky
  behaviors *before* you trust it — exactly the question you should ask of any
  third-party Claude/Codex skill. This is the closest external repo to
  Driftless's own containment mindset. *Inferred from the reference summary;
  the scanner's real coverage and rule set were Unverified here.*
- **Risk / do-not-adopt.** Unknown dependency weight, maintenance status, and
  license were **not** verified in this review (Unverified). Pulling in an
  external scanner as a hard gate could add a dependency Driftless currently has
  zero of, and could produce false positives that block good PRs.
- **Lightweight adaptation for Driftless.** Pilot the *idea*, not the tool:
  Driftless's `Test-Containment.ps1` already greps shipped skills for
  forbidden-path references; a tiny additive rule could also flag skills that
  *propose* a host-global write or a paid/recursive call (the skillopt harness's
  `forbidden_hits` check is the same instinct). Try it on the existing skills
  first; only consider the real NVIDIA tool if the in-repo rule proves too thin.
- **Cost.** Pilot = zero (extends an existing PowerShell gate). Adopting the
  external tool later = a new dependency + license review (manager gate).
- **Non-developer explanation.** Before trusting a skill someone else wrote, you
  want a quick safety scan. Driftless already does a small version of this in its
  gates; we'd grow that a little rather than bolt on an outside scanner we'd have
  to maintain.
- **Pilot success/fail.** Success = the extended grep flags a planted bad skill
  and stays clean on the real ones (mirror the containment FAIL/PASS proof).
- **Pilot outcome: ADOPTED.** Shipped as `scripts/Test-SkillAudit.ps1` (a 6th
  gate). It does the skillspector *idea* in the lean in-repo form: it audits
  every shipped `SKILL.md` for structural soundness (name matches its folder, a
  non-empty description with a trigger signal) so a skill cannot land that
  silently never fires. It pairs a `-SelfTest` that FAILs on planted-bad
  fixtures (missing name, name/folder mismatch, empty description, no
  frontmatter) with a clean live PASS on the real skills — exactly the planted-
  FAIL / real-PASS proof the pilot asked for. No new dependency, no external
  scanner; the same gate runs in the claude/codex dev runtime too (mirror).
  Fail = unavoidable false positives → revert, keep the manual review note.

## 5. rohitg00/agentmemory — `WATCH_LATER` (Driftless's memory tier is already the lean answer)

- **Useful pattern.** Persistent memory for a coding agent so project context
  and recurring lessons survive across long sessions. *Inferred.*
- **Risk / do-not-adopt.** Most "agent memory" tools imply a store (vector DB,
  embeddings, or a service) — new infrastructure, possible network/paid surface,
  and a containment question about where memory is written. That is the opposite
  of lean for a day-one kit.
- **Lightweight adaptation for Driftless.** None needed now. Driftless already
  has the *cheap* form of this: a repo-local memory tier plus the enforced
  **lesson-promotion ladder** (memory < skill < hot rule < hook < gate) so a
  recurring lesson climbs to an *enforced* surface instead of living in a fuzzy
  store. *Observed: `docs/en/lesson-promotion-ladder.md`, `evidence/lesson-ladder/`.*
- **Cost.** Adopting a memory backend = new infra + ongoing cost (rejected for now). Watching = zero.
- **Non-developer explanation.** "Remember things across sessions" sounds great,
  but most tools for it add a database the project has to run and pay for.
  Driftless instead writes lessons into plain files and promotes the important
  ones into hard rules — same goal, no server.
- **Re-check trigger.** If the same lost-context mistake recurs **3+ times** that
  the file-based ladder can't catch, re-evaluate a minimal local memory note —
  still offline, still repo-local, no external store.

## 6. ChromeDevTools/chrome-devtools-mcp — `WATCH_LATER` (capability, not a day-one dependency)

- **Useful pattern.** An MCP server that lets an agent drive Chrome DevTools for
  real browser/DOM/network/performance evidence — genuinely useful when a task
  *needs* rendered-page proof. *Inferred; it is a widely-referenced official-ish MCP.*
- **Risk / do-not-adopt.** It is an **MCP server**, i.e. an optional external
  capability. Driftless's whole install promise is "ask before any MCP/plugin/
  dependency, default No." Bundling it as default would break that promise and
  add a moving part most maintainer-automation tasks (git, GitHub, PR review)
  never need.
- **Lightweight adaptation for Driftless.** Keep it exactly where it is: an
  *opt-in* extra the installer offers and the user must say yes to. Document it
  as "available if your work is browser/UI flavored," not as a core piece.
  *Recommendation, consistent with the ask-before-install design Observed in
  `docs/en/apply-to-your-agent.md`.*
- **Cost.** Zero unless a user opts in; then it is their local Chrome + an MCP process.
- **Non-developer explanation.** A tool that lets the agent look at a real web
  page (for UI work). Driftless never installs it on its own — it asks first,
  and the default is no — because most "fix the backlog overnight" work doesn't
  touch a browser.
- **Re-check trigger.** If Driftless gains a UI/frontend skill that needs
  rendered-page evidence, promote it from "offered" to "documented default for
  that one skill."

## Honorable mention — anthropics/knowledge-work-plugins — `DO_NOT_ADOPT` (out of domain)

- **Useful pattern.** Business knowledge-work plugins (sales, support, legal,
  finance). *Inferred.* Good engineering, wrong domain.
- **Risk / do-not-adopt.** Driftless is *developer-maintainer* automation, not
  knowledge-work plugins. Adopting these would dilute the positioning and add
  surface the mirror-parity gate must police on both profiles for no benefit.
- **Cost.** Negative (scope creep + maintenance) if adopted.
- **Non-developer explanation.** These are office-task helpers (sales, legal,
  finance). Useful, but not what Driftless is for, so we leave them out.
- **Re-check trigger.** Only if the product direction ever expands beyond
  developer-maintainer automation (a manager-only product decision).

---

## Bottom line

Driftless's lean core (skills + a static 5-axis gate + containment) already
captures the *cheap, reversible* essence of the best ideas here. The single
clear net-positive action is the **SkillSpector pilot**: extend the existing
containment gate to flag a skill that proposes a host-global / paid / recursive
action — same offline, zero-dependency shape as the skillopt harness. Everything
else is either already native (SkillOpt idea, SKILL.md format) or deliberately
kept at arm's length (12-factor as prior art, agentmemory as the already-leaner
ladder, chrome-devtools-mcp as opt-in only, knowledge-work-plugins as off-domain)
so the kit stays small.

> Repo metadata (stars, last commit, license, CI, SECURITY.md, dependency
> weight) was **not fetched live** in this review and is Unverified. Before any
> verdict above moves to a real ADOPT-with-dependency, do a live read of the
> candidate's maintenance + license + security posture and record it here.

---

## Update — adopted the SkillSpector idea (not the tool) + 12-factor as prior art

*(2026-06-01)* Acted on the Bottom line above. Two verdicts moved from "idea" to
"folded in", both in the lean, zero-dependency, offline form the rest of this
review argued for. Nothing new was installed and no external scanner was vendored.

- **nvidia/skillspector — `ADOPT` (idea only; was `PILOT_ONLY`).** The "scan
  before you trust" instinct is now a real, reusable surface: the shared skill
  `profiles/shared/skills/adopt-external-tool/SKILL.md`. It is a one-screen
  checklist (license / new-infra / host-global+secret paths / inline secrets /
  peer-recursive spawn / ROI / smallest-form) the agent runs **before** applying
  any external repo, tool, third-party skill, or MCP, and closes with one verdict
  (ADOPT_SMALL / PILOT_ONLY / WATCH_LATER / REJECT / UNVERIFIED). No dependency,
  no NVIDIA tool pulled in — same offline shape as the containment + skillopt
  gates. *Observed: skill created this session; registered as a shared asset in
  `mirror-parity-allowlist.json` so one edit reaches both profiles.* The NVIDIA
  scanner itself stays `WATCH_LATER` (a real adopt would need the deferred live
  license + dependency read; that gate is unchanged).
- **humanlayer/12-factor-agents — `ADOPT` (cited as prior art; was `WATCH_LATER`).**
  Mined, not imported. Its principles (own your prompts/context, small focused
  pieces, human-in-the-loop) are cited as grounding in the new principles pages
  `docs/en/adopt-external-tools-safely.md` + `docs/ko/외부도구안전도입.md`,
  adapted to Driftless's non-developer owner + two-profile reality. The document
  is **not** vendored; the hot context stays small.

**Unchanged this round.** `rohitg00/agentmemory` stays `WATCH_LATER` (the
file-based memory tier + lesson-promotion ladder is still the leaner answer; a
memory backend is still rejected as new infra). `ChromeDevTools/chrome-devtools-mcp`
stays `WATCH_LATER` (opt-in, ask-before-install). No paid/recursive/infra surface
was added; the kit stayed lean.
