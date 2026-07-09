---
name: breakthrough-opportunity-review
description: >
  Breakthrough Opportunity Review: Use when the user asks for hidden,
  game-changing, high-leverage improvement opportunities they have not fully
  specified yet, either for a whole product or for a narrow requested surface
  such as a page, component, feature, tool, workflow, screen, dashboard, prompt,
  skill, or user moment. Also use when the user asks for a "clear opportunity",
  "big shift", "breakthrough", or dated report such as
  docs/breakthrough-opportunity-YYYY-MM-DD.md. Lock the scope, inspect current
  project/ticket/session evidence plus public sources when relevant, run a
  multi-layer opportunity sweep, separate evidence from hypothesis, and route
  implementation through tickets/parallel lanes when requested.
---

# Breakthrough Opportunity Review

## Purpose

Find the sharpest hidden improvement without turning the answer into generic ideation. The scope can be a whole product or a narrow feature surface. Preserve the pressure frame: a strong hidden answer exists, and the agent must hunt for it. Start from current source evidence, infer what the user or maintainer may be seeing from real use that the repo has not made obvious yet, and close with a small proof path inside the requested boundary.

This is the public-safe Driftless counterpart of private "big shift" opportunity workflows. It must not include private repository paths, campaign notes, credentials, account details, or internal positioning. Shared, tool-agnostic opportunity discovery belongs here; tool-specific mechanics stay in `profiles/claude/` or `profiles/codex/`.

## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Generalize as principle-based guidance or design principles. Avoid spec/case overfitting, special-casing, and exception growth unless evidence shows a bounded exception lowers user effort, maintainer effort, time, tokens, cost, recurrence risk, maintenance risk, or safety burden.

## Public-Safe Transfer Learning Frame

Use this skill to transform a hidden opportunity from a single surface into a portable improvement principle without copying private runtime details. The review should preserve these public-safe learning concepts when they fit the scope: Principle-based Learning, Far Transfer, Analogical Transfer, Relational Thinking, Structural Analogical Learning, Cross-domain Principle Extraction, Structural Mapping, Generative Learning, Schema Induction, and Conceptual Blending.

Apply the frame as a practical checklist:

1. **Principle-based Learning:** name the invariant rule that would make similar work cheaper, safer, or easier next time.
2. **Structural Mapping:** map source case -> target case by roles, constraints, feedback loops, risks, and success criteria, not by file names, issue numbers, or tool labels alone.
3. **Far Transfer:** ask whether the same relationship appears in another profile, workflow, user flow, or maintainer routine before adding a new one-off rule.
4. **Schema Induction:** compress repeated examples into a reusable trigger/root cause/decision rule/placement/validation/rollback schema.
5. **Generative Learning:** produce at least one reusable artifact candidate, such as a skill patch, gate, script, template, checklist, report, or issue.
6. **Conceptual Blending:** combine the user's real goal, the non-developer UX, and proven workflow practice into the smallest safe first slice.
7. **Anti-overfitting guard:** reject changes that only satisfy the latest example unless the bounded exception demonstrably lowers user effort, maintainer effort, time, cost, safety risk, recurrence risk, or maintenance burden.
8. **Executable verification:** prefer a deterministic gate, fixture, harness, local run, or checklist over prose-only confidence when recurrence is likely.

Keep the transfer public-safe: do not include private paths, private ticket numbers, credentials, account details, browser/session/auth state, host-global instructions, or internal project wording. If an idea came from a private runtime lesson, carry forward only the reusable structure and record any skipped private detail as an exclusion.

## Core Prompt Frame

Preserve the original forcing function:

> The user has not told us yet, but a powerful game-changing improvement is definitely hidden inside the requested scope. Do not merely list possible improvements; hunt as if there is a real answer to uncover.

This is a **search posture**, not permission to invent facts. Hunt as if the answer exists; report with evidence labels. The final answer can say "the strongest candidate is X" while still marking proof gaps as `UNVERIFIED`.

## Source Research Anchors

When public or current best practice matters, verify with public/primary sources before recommending. Useful analogues:

- Opportunity Solution Tree: connect outcomes, opportunities, solutions, and experiments rather than jumping from idea to implementation.
- Service blueprint / journey mapping: expose backstage processes, support systems, and failure points invisible in the UI.
- Business Model Canvas / strategy canvas: separate value, channel, resources, costs, and differentiator assumptions.
- Product discovery practice: turn candidate opportunities into smallest experiments with kill/defer criteria.

Do not cite these methods as proof about the local project. Use them as analogical lenses, then verify current repo/project/session evidence separately.

## Scope Lock

1. If the user names a page, feature, component, tool, workflow, screen, file, dashboard card, skill, prompt, or user moment, that exact surface is the primary boundary.
2. If the user says "this system" or asks for `docs/breakthrough-opportunity-YYYY-MM-DD.md`, treat the active project as the scope unless repo evidence shows a narrower product root.
3. Do not inflate a narrow request into the full product, pipeline, organization strategy, or architecture unless the user asks. Adjacent ideas must be labeled `adjacent/out-of-scope`.
4. State one line before analysis: `scope lock: <exact surface>`.

## Evidence Map Before Ideation

Before choosing opportunities, inspect enough current truth to avoid stale strategy:

- Local source: `AGENTS.md`, profile hot-rules, `profiles/shared/contract/SHARED_DESIGN_CONTRACT.md`, relevant skills/prompts/hooks/scripts, README/docs, and the live code/docs of the locked surface.
- Current work state: git status/branch, GitHub issue/PR bodies/comments when available, local session claims, mission-control artifacts, ticket lists, and recent handoff evidence when accessible.
- Project/product state: remaining tickets, current development map, manager/maintainer-visible dashboards, launchers, validation gates, and stale/deprecated docs that can mislead execution.
- Public research: primary docs or reputable references for current external technologies, UX patterns, product discovery, libraries, prices, policy, or standards.
- Safety: never read or print `.env`, cookies, browser profiles, local storage, passwords, tokens, private keys, auth/session stores, or host-global profile homes.

Mark each input as `PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED`, or `PARTIAL` when reporting, matching `profiles/shared/contract/SHARED_DESIGN_CONTRACT.md`.

## Layer Sweep

Run each axis explicitly, even for a narrow scope:

- Root product/user outcome: what user job or decision improves?
- Planning/function: what roadmap, priority, or capability boundary changes?
- UX/UI/design: what interaction, hierarchy, status, empty/error state, or trust signal becomes obvious?
- GUI/dashboard/status UX: what non-developer status/control surface should replace raw scripts or hidden state?
- Architecture/data contract: what reusable boundary, schema, state machine, or artifact spine unlocks it?
- Code/script/prompt/skill shape: what small skill, script gate, prompt, schema, or template prevents recurrence?
- Credential/security/private-public boundary: what login, billing, public release, secret, destructive, or host-global risk needs safer staging?
- Multi-worker/process model: what owner, heartbeat, ticket, parallel lane, adoption step, or cleanup gate reduces human intervention?
- Fixture/benchmark/real-use proof: what test, replay, harness, browser evidence, or live run would prove it?
- Runtime dependency: what local tool, version, profile, launcher, active home, or materialization path enables or blocks it?
- Technology/library: what current library or external pattern could make it cheaper or sharper after verification?
- Public-safe propagation: should the lesson go to shared tier, a tool-specific profile, docs, tests, or be skipped as private/unsafe?

## Ticket / Parallel Execution Add-on

Use this section when the opportunity requires implementation, tickets, parallel work, or full closeout.

1. **Ticket first when nontrivial.** Create/reuse the smallest GitHub issue with root cause, scope, acceptance criteria, validation, user-only gates, and no secrets.
2. **Register ownership.** Use the repo's session-claim, mission-control, or Kanban/control-plane equivalent where available. Creation is not completion.
3. **Split into parallel-safe lanes.** For each lane record: owner mode, write surface, read-only dependencies, forbidden/private surfaces, validation command, rollback path, and `parallel_safe` state.
4. **Blocker fission.** A blocker should become a smaller owned lane or issue when it is agent-solvable; do not leave it as prose. Escalate only credentials, billing/quota, public release, destructive/irreversible action, host-global promotion, user-data transfer, force-push/history rewrite, or product/value judgments.
5. **Parent adoption.** Worker/child output is not Done until the parent reads it, verifies evidence, updates the control surface, and reruns the original gate.

## Placement Decision

Before adding or changing a rule, choose the smallest durable surface:

- Tool-agnostic, public-safe principle -> `profiles/shared/`.
- Claude-specific mechanics -> `profiles/claude/`.
- Codex-specific mechanics -> `profiles/codex/`.
- Repeated/verifiable stateful action -> script/gate/schema/test instead of prose-only guidance.
- Stable public procedure -> skill; current task progress -> issue/session evidence, not hot context.
- Private, account-specific, path-specific, campaign, credential, billing, or internal material -> do not copy; write a sanitized skip reason or public-safe abstraction.

## Transfer Learning Lens

When the opportunity becomes a learning-loop update, preserve these concept names and perform the transformation:

- **Principle-based Learning:** name the invariant rule that would prevent the failure class.
- **Far Transfer:** identify where the same structure appears outside the current surface, including Claude, Codex, shared tier, launchers, dashboards, validation gates, and public docs.
- **Analogical Transfer / Structural Analogical Learning:** map source case -> target case by roles, constraints, feedback loops, risks, and success criteria, not by string matching.
- **Relational Thinking / Structural Mapping:** compare relationships such as user burden, hidden state, proof gap, owner/readback loop, and rollback path rather than files alone.
- **Cross-domain Principle Extraction:** convert a private or local incident into a public-safe or tool-agnostic principle when possible.
- **Generative Learning / Schema Induction:** write `trigger -> root_cause_class -> decision_rule -> placement -> validation -> rollback`.
- **Conceptual Blending:** combine user root goal, non-developer UX, public best practice, and repo constraints into the smallest safe implementation.

## Workflow

1. Lock the requested scope first.
   - If the user names a page, feature, component, tool, workflow, screen, file, or user moment, treat that as the primary boundary.
   - If the user says "this system" or asks for `docs/breakthrough-opportunity-YYYY-MM-DD.md`, treat the active project as the scope unless repo evidence shows a narrower product root.
   - Do not inflate a narrow request into the full product, pipeline, company strategy, or architecture unless the user asks.
   - Use adjacent systems only for constraints, dependencies, or clearly bounded optional extensions.
   - State the scope in one sentence: `scope lock: <exact surface>`.

2. Define the root-intent gate before gathering evidence.
   - State the root goal, the root cause of the request, and the reusable criteria that should apply to similar future cases.
   - If the project vision or user directive is not explicit, infer from `AGENTS.md`, product docs, decision docs, issues, and recent user instructions; mark the inference.
   - Prefer visible workflow, one-click action, guided UI, clear status, and agent-owned validation over raw scripts or developer setup for non-developer users.

3. Activate the hidden-answer frame.
   - Say internally: "A strong hidden improvement exists in this scope; find the best candidate."
   - For system-level reports, use the exact mission: "A clear opportunity exists that this system needs for its root goal but has not yet recognized."
   - Keep evidence honesty: the premise drives search intensity, while proof still requires observed or source evidence.

4. Build a compact evidence map before ideation.
   - Inspect the locked surface first: relevant docs, UI/screens, code paths, payload contracts, tests, issues/PRs, and recent user corrections when available.
   - For whole-product or system reports, inspect `AGENTS.md`, product docs, README, design docs, issues/PRs/tickets/comments, decision records, skills/prompts/hooks, primary workflows, and recent failures when available.
   - For current technologies, libraries, standards, prices, laws, or public claims, verify with browsing or primary sources before recommending.
   - Label each input as `PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED`, or `PARTIAL`.

5. Run axis-by-axis investigation, not a blended skim.
   - Cover every Layer Sweep axis with at least one evidence label or an explicit `UNVERIFIED`/`BLOCKED` reason.
   - If native worker/session tools and user authorization exist for a large investigation, coordinate through `mission-control` and keep parent synthesis evidence-labeled.
   - If worker tools are unavailable or recursive/peer AI is disallowed, run the axes serially in the current session. Do not call another AI bridge to satisfy "dispatch".
   - Every opportunity candidate needs evidence labels such as code path, doc path, issue/PR number, command output, browser evidence, or source URL.

6. Reverse-engineer the missing breakthrough inside the scope.
   - Ask: "What would the user or target audience see from real use of this exact surface that the repo, docs, or agent transcript may hide?"
   - For narrow UI/tool requests, prefer feature-level changes: interaction mode, visual evidence, filtering, grouping, defaults, copy/export action, state clarity, empty/error states, or a sharper user decision flow.
   - For broad requests, search for leverage in onboarding collapse, status surfaces, evidence handoff, safer automation, defaults, recovery flows, public/private propagation, lower token use, lower human intervention, and clearer trust signals.
   - Generate 5-9 hypotheses at the same granularity as the scope.

7. Score candidates with hard filters.
   - Scope fit, hidden-answer fit, pain removed, visibility, feasibility, evidence strength, blast radius, rollback, and public-safe propagation.

8. Choose the public-safe propagation shape.
   - If the strongest candidate is a transferable lesson, state the structural analogy and which public surface should receive it: existing shared skill, shared contract, script gate, fixture, checklist, report, or issue.
   - If the candidate needs ticket/parallel planning, reuse existing open issues first and name owner surface, write surface, read-only surfaces, conflict risks, validation command, rollback path, and parallel_safe status.
   - If a private or tool-specific detail inspired the idea, explicitly exclude the private detail and keep only the public-safe reusable relation.

9. Select the strongest 1-3 opportunities.
   - Prefer the opportunity that removes repeated user burden or makes hidden state visible.
   - Avoid novelty bias. A small workflow surface can beat a large new feature if it changes real usage.
   - If the best idea needs approval, design the smallest contained pilot instead of stopping.

10. Return an action-ready result or report.
   - Start from the frame: "The hidden-answer candidate is X."
   - Explain why X is the likely breakthrough idea plainly.
   - Separate evidence from hypothesis.
   - Provide the first implementation slice, validation evidence required, and kill/defer criteria.
   - For report mode, write `docs/breakthrough-opportunity-YYYY-MM-DD.md` and include the mandatory report sections below.
   - After a report is confirmed and follow-up work is in scope, route open work through ticket review and parallel planning, reusing existing open issues before proposing new ones.
   - If the user asked for implementation, continue into the work instead of ending at brainstorming.
   - If follow-up remains, every `BLOCKED`, `UNVERIFIED`, `PARTIAL`, `watch`, `follow-up`, or `later` item needs an open issue/lane or a concrete `not needed` reason.

## Report Contract

For `docs/breakthrough-opportunity-YYYY-MM-DD.md`, include:

1. `Root Goal Summary`: user goal, assumptions, and evidence locations.
2. `Preparation Evidence`: local source, issue/PR/ticket/session evidence, public research, and stale-file interference notes.
3. `Axis Review`: every Layer Sweep axis with `PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED`, or `PARTIAL`.
4. `Clear Opportunities Not Yet Recognized`: description, root-goal contribution, evidence, expected leverage, risk, confidence, and first proof slice.
5. `Priority`: why the top item is the strongest hidden-answer candidate.
6. `Epic/Ticket Structure`: reuse open issues first; new issues need purpose, done criteria, validation, owner surface, stop/resume instructions, and user-only gates.
7. `Parallel vs Serial`: conflict surfaces, dependencies, parallel-safe lanes, serialized lanes.
8. `Control / Adoption Plan`: owner modes, session/control-plane/Kanban/heartbeat/readback when applicable.
9. `Risks And Follow-Up`: every unresolved term has an issue/lane/reason.
10. `Resume Instructions`: exact file paths, commands, evidence, and next action.

## Output Shape

Use the manager/maintainer labels from the shared contract:

- `built/inspected`: sources checked, root intent, scope lock.
- `hidden-answer frame`: the strongest hidden opportunity candidate.
- `layer sweep`: planning/UX/UI/architecture/code/technology/security/workflow/public-safe propagation.
- `tested/evidence`: command/source/browser/session evidence with PASS/FAIL/BLOCKED/UNVERIFIED/PARTIAL.
- `ticket/parallel plan`: issue reuse/new issue, lanes, serial dependencies.
- `top opportunity`: why it can change the product/system.
- `first slice`: the smallest safe implementation or pilot.
- `validation`: what would prove, disprove, or defer the opportunity.

## Guardrails

- Do not claim a breakthrough is proven without behavioral, local, or source evidence.
- Do not water down the task into "possible improvements"; preserve the premise that a powerful hidden opportunity exists, then label proof honestly.
- Do not turn a narrow page/tool/component request into a whole-product or whole-pipeline answer unless the user asks for that expansion.
- Do not read credentials, `.env`, private keys, browser profiles, cookies, local storage, session stores, or host-global profile files.
- Do not recommend public release, billing, destructive actions, credential use, host-global mutation, force-push/history rewrite, or recursive/peer AI without explicit approval.
- Do not let excitement replace closeout: every candidate ends as implement, pilot, defer, reject, blocked, or unverified.
