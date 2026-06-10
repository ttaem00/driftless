## 2026-06-06 - Improvement principle must be behavior-gated

### Proposal
Strengthen Test-ImprovementPrincipleDiscipline.ps1 to check public behavior-shaping surfaces, add compact Improvement Principle sections to shipped skills, wire the gate into CI, and require PR evidence for rule/skill/prompt/script/hook/doc changes.

### Why Now
The public improvement principle existed in shared guidance, but rule application could still be missed because the gate only checked static pointers and not shipped skills, learning-loop, finish-to-done, CI, or PR review surfaces.

### Placement Decision
1. Intended scope: repo-local
2. Chosen location: `scripts/Test-ImprovementPrincipleDiscipline.ps1`, shipped
   public SKILL.md files, GitHub Actions, and PR template.
3. Why this scope is correct: the root cause is missed behavior enforcement,
   so CI and reusable gates block regressions while skills carry the on-demand
   operating contract.
4. Hot vs on-demand: no new hot text; `AGENTS.md` keeps the existing pointer,
   CI runs automatically, and details stay in skills/scripts/docs.
5. Rejected alternatives: AGENTS.md-only increases hot context and still relies
   on recall. Learning note only does not change future behavior.

### Validation
- Run Test-ImprovementPrincipleDiscipline.ps1 -SelfTest, the strengthened gate,
  Windows text safety, skill audit, work discipline, and CI.

### Next Action
Implemented in this change; keep the strengthened gate in CI and PR review.

### Rollback
Remove or revert the recorded change if it causes over-triggering or false positives.

### Status
implemented

## 2026-06-11 - Public-safe workflows must reserve high-judgment decisions for lead review

### Proposal
Add shared skill guidance and validation: lightweight workers may gather bounded evidence, but high-judgment decisions require lead/coordinator or high-quality synthesis with explicit observed/inferred/unverified boundaries.

### Why Now
Low-model or lightweight worker fallback is useful for bounded evidence recovery, but unsafe as the sole authority for architecture, security, adoption, release, or public-safe propagation decisions. Shared Driftless skills need the public-safe principle so broad system decisions remain with lead/coordinator synthesis.

### Placement Decision
1. Intended scope: repo-local
2. Chosen location: skill workflow
3. Why this scope is correct: The lesson changes conditional agent behavior best loaded only when the skill triggers.
4. Hot vs on-demand: on-demand skill.
5. Rejected alternatives: AGENTS.md: too hot for conditional behavior. Hook: no blocking condition is defined.

### Validation
- Run skill validation and one representative invocation.

### Next Action
Apply the smallest repo-local/current-isolated-profile prevention now, then validate it. If the target is an instruction doc, run caveman-compress.

### Rollback
Remove or revert the recorded change if it causes over-triggering or false positives.

### Status
proposal
