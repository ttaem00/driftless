---
name: breakthrough-opportunity-review
description: >
  Breakthrough Opportunity Review: Use when the user asks for hidden,
  game-changing, high-leverage improvement opportunities they have not fully
  specified yet, either for a whole product or for a narrow requested surface
  such as a page, component, feature, tool, workflow, screen, or user moment.
  Also use when the user asks for a "clear opportunity" the system needs for
  its root goal but has not recognized yet, or asks for a dated report such as
  docs/breakthrough-opportunity-YYYY-MM-DD.md. Assume a powerful hidden
  improvement definitely exists inside that scope, review planning, UX/UI,
  architecture/code, technology/library adoption, new features, security,
  process, runtime dependencies, public-safe propagation, and workflow, then
  produce evidence-labeled candidates.
---

# Breakthrough Opportunity Review

## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Generalize as principle-based guidance or design principles; avoid spec/case overfitting and special-casing unless evidence proves a bounded exception reduces time, tokens, human intervention, usage, or performance burden.

## Public-Safe Transfer Learning Frame

Use this skill to transform a hidden opportunity from a single surface into a
portable improvement principle without copying private runtime details. The
review should preserve these public-safe learning concepts when they fit the
scope: Principle-based Learning, Far Transfer, Analogical Transfer, Relational
Thinking, Structural Analogical Learning, Cross-domain Principle Extraction,
Structural Mapping, Generative Learning, Schema Induction, and Conceptual
Blending.

Apply the frame as a practical checklist:

1. **Principle-based Learning:** name the invariant rule that would make similar
   work cheaper, safer, or easier next time.
2. **Structural Mapping:** map source case -> target case by roles,
   constraints, feedback loops, risks, and success criteria, not by file names,
   issue numbers, or tool labels alone.
3. **Far Transfer:** ask whether the same relationship appears in another
   profile, workflow, user flow, or maintainer routine before adding a new
   one-off rule.
4. **Schema Induction:** compress repeated examples into a reusable trigger/root cause/decision rule/placement/validation/rollback schema.
5. **Generative Learning:** produce at least one reusable artifact candidate,
   such as a skill patch, gate, script, template, checklist, report, or issue.
6. **Conceptual Blending:** combine the user's real goal, the non-developer UX,
   and proven workflow practice into the smallest safe first slice.
7. **Anti-overfitting guard:** reject changes that only satisfy the latest
   example unless the bounded exception demonstrably lowers user effort,
   maintainer effort, time, cost, safety risk, recurrence risk, or maintenance
   burden.
8. **Executable verification:** prefer a deterministic gate, fixture, harness,
   local run, or checklist over prose-only confidence when recurrence is likely.

Keep the transfer public-safe: do not include private paths, private ticket
numbers, credentials, account details, browser/session/auth state, host-global
instructions, or internal project wording. If an idea came from a private runtime
lesson, carry forward only the reusable structure and record any skipped private
detail as an exclusion.

Find the sharpest hidden improvement without turning the answer into generic
ideation. The scope can be a whole product or a narrow feature surface. Preserve
the pressure frame: a strong hidden answer exists, and the agent must hunt for
it. Start from source evidence, infer what the user may be seeing from real use
that the agent has not noticed yet, and close with a small proof path inside the
requested boundary.

## Core Prompt Frame

Preserve the original forcing function:

> The user has not told us yet, but a powerful game-changing improvement is definitely hidden inside the requested scope. Do not merely list possible improvements; hunt as if there is a real answer to uncover.

This is a **search posture**, not permission to invent facts. Hunt as if the
answer exists; report with evidence labels. The final answer can say "the
strongest candidate is X" while still marking proof gaps as `Unverified`.

## Report Mission Frame

When the user asks for a system-level opportunity report, preserve this mission:

> A clear opportunity exists that this system needs for its root goal but has not yet recognized. Find it and write a report.

Default report path: `docs/breakthrough-opportunity-YYYY-MM-DD.md`, using the
current local date unless the user gives another path. The report must be
resumable from the file alone: root goal, evidence, opportunities, priorities,
ticket structure, parallel/serial split, risks, and follow-ups must all be
present.

Before investigating, define:

- root intent: what the non-developer user or maintainer ultimately wants and
  why it matters.
- root cause: why this request exists and what must not recur.
- reusable criteria: which judgment principles apply to similar future cases.

Treat user examples as evidence, not the answer key. Prefer principle-based
guidance, design principles, and UX heuristics over case-specific exceptions.
Avoid spec/case overfitting, special-casing, and growing exception lists unless
the exception is bounded, evidenced, and reduces user effort, maintainer effort,
time, tokens, recurrence risk, maintenance risk, or safety burden.

## Layer Sweep

Always sweep the layers explicitly, even for a narrow scope. For a page widget,
apply each layer to that widget, not to the whole product:

- Architecture pattern: reusable boundaries, contracts, and ownership shape.
- Code/script shape: scripts, commands, hooks, prompts, rules, skills, and
  repeatable automation surfaces.
- Individual features: specific user-visible capability gaps.
- Planning/function: what job, user decision, or product loop should change?
- UX/UI: what interaction, information hierarchy, visual evidence, state, or flow would make the opportunity obvious?
- GUI/dashboard/status UX: what non-developer status, progress, or control
  surface should exist instead of raw scripts or hidden state?
- Architecture/code: what data contract, component boundary, rendering path, test, or refactor unlocks it?
- Credential/security boundary: what login, secret, API, public/private,
  billing, release, or destructive-action boundary needs a safer shape?
- Multi-worker/process model: what orchestration, worker contract, heartbeat, or
  cleanup gate would reduce user or maintainer intervention?
- Fixture/benchmark method: what test data, real-use proof, benchmark, or
  fixture strategy would make the opportunity measurable?
- Docs/skill template: what reusable prompt, template, skill, or documentation
  would make the improvement repeatable?
- Runtime dependency: what local dependency, installed tool, version, or
  platform boundary enables or blocks the opportunity?
- Technology/library: what current tool or library could make it cheaper or sharper, after verification when recency matters?
- New feature: what feature would feel like the missing breakthrough inside the scope?
- Development workflow: what validation or evidence loop would make the improvement repeatable?
- Public-safe propagation: what should be shared, made profile-specific, or
  explicitly skipped as private/unsafe?

## Placement Decision

1. Intended scope: breakthrough-improvement requests for a whole product or a specific page, feature, component, tool, workflow, screen, or user moment.
2. Chosen location: shared on-demand skill `breakthrough-opportunity-review`.
3. Why this scope is correct: scope-locking plus multi-layer opportunity review is too long for hot instructions and too strategic for ordinary code review.
4. Hot vs on-demand: on-demand. Do not add this full process to always-loaded profile guidance.
5. Rejected alternatives: prompt-only optimization focuses on wording; external adoption review only fits when a specific outside candidate is under consideration.
6. Existing skill reuse check: UI-only depth can route to `ui-ux-design-guidance`; external candidates can route to `adopt-external-tool`; large coordinated work can route through `mission-control`; ticket decomposition can route to `parallel-ticket-planner`; repeated prevention can route to `learning-loop`; final readiness can route to `review-before-done`.
7. Consolidation decision: keep this as the shared wrapper-style opportunity discovery skill. It owns the hidden-answer frame, report contract, evidence labels, and opportunity synthesis.

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
   - Avoid weak framing such as "the user may have missed something" as the main posture.
   - Keep evidence honesty: the premise drives search intensity, while proof still requires observed or source evidence.

4. Restate root intent inside that scope.
   - What the user likely wants next.
   - What must become visible, easier, safer, or more trustworthy.
   - What should not remain hidden in raw scripts, fragile setup, closed experiments, or vague automation claims.

5. Build a compact evidence map before ideation.
   - Inspect the locked surface first: relevant docs, UI/screens, code paths, payload contracts, tests, issues/PRs, and recent user corrections when available.
   - For whole-product or system reports, inspect `AGENTS.md`, product docs, README, design docs, issues/PRs/tickets/comments, decision records, skills/prompts/hooks, primary workflows, and recent failures when available.
   - Inspect old code/docs/temp files only to classify whether they block the root goal. Do not delete or rewrite them without a separate authorized implementation scope; record evidence and impact only.
   - For UX/UI/frontend work, use the local design guidance skill or design contract before proposing visual or flow changes.
   - For current technologies, libraries, standards, prices, laws, or public claims, verify with browsing or primary sources before recommending.
   - Label each input as `Observed`, `Inferred`, `Unverified`, or `Blocked`.

6. Run axis-by-axis investigation, not a blended skim.
   - Cover every Layer Sweep axis with at least one evidence label or an explicit `Unverified`/`Blocked` reason.
   - If native worker/session tools and user authorization exist for a large investigation, coordinate through `mission-control` and keep parent synthesis evidence-labeled.
   - If worker tools are unavailable or recursive/peer AI is disallowed, run the axes serially in the current session. Do not call another AI bridge to satisfy "dispatch".
   - Every opportunity candidate needs evidence labels such as code path, doc path, issue/PR number, command output, browser evidence, or source URL.

7. Reverse-engineer the missing breakthrough inside the scope.
   - Ask: "What would the user or target audience see from real use of this exact surface that the repo, docs, or agent transcript may hide?"
   - For narrow UI/tool requests, prefer feature-level changes: interaction mode, visual evidence, filtering, grouping, defaults, copy/export action, state clarity, empty/error states, or a sharper user decision flow.
   - For broad requests, search for leverage in onboarding collapse, status surfaces, evidence handoff, safer automation, defaults, recovery flows, public/private propagation, lower token use, lower human intervention, and clearer trust signals.
   - Generate 5-9 hypotheses at the same granularity as the scope. Cover the layer sweep before choosing. If the scope is a page widget, do not make the top candidate a whole pipeline unless explicitly marked `adjacent/out-of-scope`.

8. Score candidates with hard filters.
   - Scope fit: does this improve the requested surface directly?
   - Hidden-answer fit: does it feel like the single strong thing the user expected the agent to discover, not just a reasonable improvement?
   - Pain removed: time, setup, tokens, security risk, validation burden, or human intervention.
   - Visibility: would the target user notice and trust the improvement?
   - Feasibility: can it be piloted without credentials, billing, destructive actions, host-global mutation, or recursive/peer AI calls?
   - Evidence: what is observed vs inferred vs unverified?
   - Blast radius: what can break, and what rollback exists?
   - Public-safe reuse: should the idea belong in shared skills, profile-specific guidance, code, docs, tests, or backlog?

8a. Choose the public-safe propagation shape.
   - If the strongest candidate is a transferable lesson, state the structural
     analogy and which public surface should receive it: existing shared skill,
     shared contract, script gate, fixture, checklist, report, or issue.
   - If the candidate needs ticket/parallel planning, reuse existing open issues
     first and name owner surface, write surface, read-only surfaces, conflict
     risks, validation command, rollback path, and parallel_safe status.
   - If a private or tool-specific detail inspired the idea, explicitly exclude
     the private detail and keep only the public-safe reusable relation.

9. Select the strongest 1-3 opportunities.
   - Prefer the opportunity that removes repeated user burden or makes hidden state visible.
   - Avoid novelty bias. A small workflow surface can beat a large new feature if it changes real usage.
   - For narrow requests, choose the strongest in-scope idea first; list broader adjacent ideas only after the in-scope answer.
   - If the best idea needs approval, design the smallest contained pilot instead of stopping.

10. Return an action-ready result or report.
   - Start from the frame: "The hidden-answer candidate is X."
   - Explain why X is the likely breakthrough idea plainly.
   - Separate evidence from hypothesis.
   - Provide the first implementation slice, validation evidence required, and kill/defer criteria.
   - For report mode, write `docs/breakthrough-opportunity-YYYY-MM-DD.md` and include the mandatory report sections below.
   - After a report is confirmed and follow-up work is in scope, route open work through ticket review and parallel planning, reusing existing open issues before proposing new ones.
   - If the user asked for implementation, continue into the work instead of ending at brainstorming.

## Report Contract

For `docs/breakthrough-opportunity-YYYY-MM-DD.md`, include:

1. `Root Goal Summary`: project vision/user directive, assumptions, and evidence locations.
2. `Preparation Evidence`: `AGENTS.md`, related docs, issue/PR/ticket/comment evidence, and old-file interference notes.
3. `Axis Review`: every Layer Sweep axis with `Observed`, `Inferred`, `Unverified`, or `Blocked`.
4. `Clear Opportunities Not Yet Recognized`: each with description, root-goal contribution, evidence, expected leverage, risk, confidence, and first proof slice.
5. `Priority`: rank opportunities and explain why the top item is the best hidden-answer candidate.
6. `Epic/Ticket Structure`: reuse existing open issues first. New tickets need purpose, done criteria, validation method, owner surface, stop/resume instructions, and user-only gates.
7. `Parallel vs Serial`: conflict surfaces, dependencies, and which lanes can safely run in parallel.
8. `Risks And Follow-Up`: every `Blocked`, `Unverified`, `Partial`, `watch`, `follow-up`, or `later` item needs an existing/new issue number or a clear reason no issue is needed.
9. `Resume Instructions`: exact file paths, commands, evidence, and next action so another session can continue without this chat.

## Missing-Risk Checklist

Confirm these in the report rather than leaving them implicit:

- Hidden user burden: raw scripts, unclear git/GitHub state, invisible status, or developer-only setup.
- Evidence gap: fixture/schema/unit/static proof being mistaken for behavioral proof.
- Credential/security boundary: secret, `.env`, browser profile, account, billing, public release, destructive, or host-global risks.
- Runtime/workflow dependency: local tool versions, generated profile surfaces, hooks, skills, commands, and validation gates.
- Multi-worker/process gap: stale workers, missing heartbeat/status board, no cleanup gate, or user paste burden.
- Public/private propagation: what is public-safe, profile-specific, shared, or skipped with a private/unsafe reason.
- Old artifact interference: retired docs, temporary files, stale compatibility shims, or archived routes that could mislead current goals.

## Output Shape

Use this structure unless the user asks for a shorter answer:

- `inspected`: sources checked and root intent.
- `scope lock`: exact surface analyzed; mark any adjacent idea as out-of-scope or optional.
- `hidden-answer frame`: the assumed missing breakthrough and why it fits the user's implied expectation.
- `layer sweep`: planning, UX/UI, architecture/code, technology, new feature, and workflow lenses checked.
- `evidence`: observed facts, inferred facts, unverified gaps, and blockers.
- `top opportunity`: the single sharpest hidden improvement and why it could change the product.
- `other strong opportunities`: 2-5 runners-up with tradeoffs.
- `report path`: created report path when report mode is requested.
- `ticket/parallel plan`: issue reuse/new-ticket structure and parallel vs serial lanes when requested.
- `first slice`: the smallest safe implementation or pilot.
- `validation`: what would prove, disprove, or defer the opportunity.

## Guardrails

- Do not claim a breakthrough is proven without behavioral, local, or source evidence.
- Do not water down the task into "possible improvements"; preserve the premise that a powerful hidden opportunity exists, then label proof honestly.
- Do not turn a narrow page/tool/component request into a whole-product or whole-pipeline answer unless the user asks for that expansion.
- Do not read credentials, `.env`, private keys, browser profiles, cookies, session stores, or host-global profile files.
- Do not recommend public release, billing, destructive actions, credential use, host-global mutation, or recursive/peer AI without explicit approval.
- Do not let excitement replace closeout: every candidate ends as implement, pilot, defer, reject, blocked, or unverified.
