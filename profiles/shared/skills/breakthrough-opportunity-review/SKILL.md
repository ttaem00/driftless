---
name: breakthrough-opportunity-review
description: >
  Breakthrough Opportunity Review: Use when the user asks for hidden,
  game-changing, high-leverage improvement opportunities they have not fully
  specified yet, either for a whole product or for a narrow requested surface
  such as a page, component, feature, tool, workflow, screen, or user moment.
  Assume a powerful hidden improvement definitely exists inside that scope,
  review planning, UX/UI, architecture/code, technology/library adoption, new
  features, and workflow, then produce evidence-labeled candidates.
---

# Breakthrough Opportunity Review

## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Generalize as principle-based guidance or design principles; avoid spec/case overfitting and special-casing unless evidence proves a bounded exception reduces time, tokens, human intervention, usage, or performance burden.

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

## Layer Sweep

Always sweep the layers explicitly, even for a narrow scope. For a page widget,
apply each layer to that widget, not to the whole product:

- Planning/function: what job, user decision, or product loop should change?
- UX/UI: what interaction, information hierarchy, visual evidence, state, or flow would make the opportunity obvious?
- Architecture/code: what data contract, component boundary, rendering path, test, or refactor unlocks it?
- Technology/library: what current tool or library could make it cheaper or sharper, after verification when recency matters?
- New feature: what feature would feel like the missing breakthrough inside the scope?
- Development workflow: what validation or evidence loop would make the improvement repeatable?

## Placement Decision

1. Intended scope: breakthrough-improvement requests for a whole product or a specific page, feature, component, tool, workflow, screen, or user moment.
2. Chosen location: shared on-demand skill `breakthrough-opportunity-review`.
3. Why this scope is correct: scope-locking plus multi-layer opportunity review is too long for hot instructions and too strategic for ordinary code review.
4. Hot vs on-demand: on-demand. Do not add this full process to always-loaded profile guidance.
5. Rejected alternatives: prompt-only optimization focuses on wording; external adoption review only fits when a specific outside candidate is under consideration.

## Workflow

1. Lock the requested scope first.
   - If the user names a page, feature, component, tool, workflow, screen, file, or user moment, treat that as the primary boundary.
   - Do not inflate a narrow request into the full product, pipeline, company strategy, or architecture unless the user asks.
   - Use adjacent systems only for constraints, dependencies, or clearly bounded optional extensions.
   - State the scope in one sentence: `scope lock: <exact surface>`.

2. Activate the hidden-answer frame.
   - Say internally: "A strong hidden improvement exists in this scope; find the best candidate."
   - Avoid weak framing such as "the user may have missed something" as the main posture.
   - Keep evidence honesty: the premise drives search intensity, while proof still requires observed or source evidence.

3. Restate root intent inside that scope.
   - What the user likely wants next.
   - What must become visible, easier, safer, or more trustworthy.
   - What should not remain hidden in raw scripts, fragile setup, closed experiments, or vague automation claims.

4. Build a compact evidence map before ideation.
   - Inspect the locked surface first: relevant docs, UI/screens, code paths, payload contracts, tests, issues/PRs, and recent user corrections when available.
   - For whole-product requests, inspect product docs, README, design docs, issues/PRs, decision records, skills/prompts/hooks, primary workflows, and recent failures when available.
   - For UX/UI/frontend work, use the local design guidance skill or design contract before proposing visual or flow changes.
   - For current technologies, libraries, standards, prices, laws, or public claims, verify with browsing or primary sources before recommending.
   - Label each input as `Observed`, `Inferred`, `Unverified`, or `Blocked`.

5. Reverse-engineer the missing breakthrough inside the scope.
   - Ask: "What would the user or target audience see from real use of this exact surface that the repo, docs, or agent transcript may hide?"
   - For narrow UI/tool requests, prefer feature-level changes: interaction mode, visual evidence, filtering, grouping, defaults, copy/export action, state clarity, empty/error states, or a sharper user decision flow.
   - For broad requests, search for leverage in onboarding collapse, status surfaces, evidence handoff, safer automation, defaults, recovery flows, public/private propagation, lower token use, lower human intervention, and clearer trust signals.
   - Generate 5-9 hypotheses at the same granularity as the scope. Cover the layer sweep before choosing. If the scope is a page widget, do not make the top candidate a whole pipeline unless explicitly marked `adjacent/out-of-scope`.

6. Score candidates with hard filters.
   - Scope fit: does this improve the requested surface directly?
   - Hidden-answer fit: does it feel like the single strong thing the user expected the agent to discover, not just a reasonable improvement?
   - Pain removed: time, setup, tokens, security risk, validation burden, or human intervention.
   - Visibility: would the target user notice and trust the improvement?
   - Feasibility: can it be piloted without credentials, billing, destructive actions, host-global mutation, or recursive/peer AI calls?
   - Evidence: what is observed vs inferred vs unverified?
   - Blast radius: what can break, and what rollback exists?
   - Public-safe reuse: should the idea belong in shared skills, profile-specific guidance, code, docs, tests, or backlog?

7. Select the strongest 1-3 opportunities.
   - Prefer the opportunity that removes repeated user burden or makes hidden state visible.
   - Avoid novelty bias. A small workflow surface can beat a large new feature if it changes real usage.
   - For narrow requests, choose the strongest in-scope idea first; list broader adjacent ideas only after the in-scope answer.
   - If the best idea needs approval, design the smallest contained pilot instead of stopping.

8. Return an action-ready result.
   - Start from the frame: "The hidden-answer candidate is X."
   - Explain why X is the likely breakthrough idea plainly.
   - Separate evidence from hypothesis.
   - Provide the first implementation slice, validation evidence required, and kill/defer criteria.
   - If the user asked for implementation, continue into the work instead of ending at brainstorming.

## Output Shape

Use this structure unless the user asks for a shorter answer:

- `inspected`: sources checked and root intent.
- `scope lock`: exact surface analyzed; mark any adjacent idea as out-of-scope or optional.
- `hidden-answer frame`: the assumed missing breakthrough and why it fits the user's implied expectation.
- `layer sweep`: planning, UX/UI, architecture/code, technology, new feature, and workflow lenses checked.
- `evidence`: observed facts, inferred facts, unverified gaps, and blockers.
- `top opportunity`: the single sharpest hidden improvement and why it could change the product.
- `other strong opportunities`: 2-5 runners-up with tradeoffs.
- `first slice`: the smallest safe implementation or pilot.
- `validation`: what would prove, disprove, or defer the opportunity.

## Guardrails

- Do not claim a breakthrough is proven without behavioral, local, or source evidence.
- Do not water down the task into "possible improvements"; preserve the premise that a powerful hidden opportunity exists, then label proof honestly.
- Do not turn a narrow page/tool/component request into a whole-product or whole-pipeline answer unless the user asks for that expansion.
- Do not read credentials, `.env`, private keys, browser profiles, cookies, session stores, or host-global profile files.
- Do not recommend public release, billing, destructive actions, credential use, host-global mutation, or recursive/peer AI without explicit approval.
- Do not let excitement replace closeout: every candidate ends as implement, pilot, defer, reject, blocked, or unverified.
