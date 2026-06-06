---
name: ui-ux-design-guidance
description: >
  UIUX디자인 ui-ux-design-guidance: UI, UX, frontend, website, visual
  design, layout, user-flow 작업 전에 target repo `docs/design/DESIGN.md`
  지침을 우선 읽고, 없으면 installed Driftless default design guide를
  fallback으로 적용한다. Trigger: UI, UX, frontend, 프론트엔드, 웹사이트,
  디자인, 레이아웃, 화면, 사용자 흐름, design.md, DESIGN.md.
---
## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Generalize as principle-based guidance or design principles; avoid spec/case overfitting and special-casing unless evidence proves a bounded exception reduces user effort, maintainer effort, maintenance risk, or safety burden.
# UI/UX Design Guidance

Use this skill whenever work changes or reviews user-visible UI: frontend code,
website pages, layouts, visual styling, design systems, navigation, forms,
states, responsive behavior, accessibility, or user flows.

## Root Intent

The manager may be a non-developer high-school student. They should not need to
remember a design file path, notice design debt, or ask for polish manually.
The agent should load design guidance before UI work, apply it to the actual
screen or workflow, and report missing evidence in plain language.

## Required Input

Resolve the target repository root, then read the first available design guide
in this order:

```text
1. <target repo>\docs\design\DESIGN.md
2. <installed Driftless root>\docs\design\DESIGN.md
```

The canonical design guide path is `docs/design/DESIGN.md`. The target repo
guide is product-specific and wins when present. When the target repo has no
local guide, resolve the installed Driftless root from `DRIFTLESS_REPO_ROOT`,
`CODEX_ISOLATED_REPO_ROOT`, `CODEX_HOME`, `CLAUDE_CONFIG_DIR`, the current
checkout, or the profile/shared skill location, then read
`<installed Driftless root>\docs\design\DESIGN.md`. Do not hard-code a drive
letter or machine-specific absolute path.

## Workflow

1. Read the target repo design guide before proposing, editing, or reviewing
   UI/UX. If it is missing, read the installed Driftless default design guide.
2. Extract only the parts relevant to the current surface: user goal, primary
   action, information hierarchy, accessibility, responsive behavior, and
   loading/empty/error/success/disabled states.
3. Apply active frontend instructions and this design document together. If
   they conflict, keep safety, accessibility, and user clarity first, then
   explain the tradeoff in the manager report.
4. Build or review the actual usable screen/workflow first. Avoid turning UI
   work into a landing page, decorative writeup, hidden route, or raw command.
5. Verify new or changed screens through the real user path when tools allow.
   Prefer DOM, accessibility, log, and assertion evidence first. Use screenshots
   only for visual claims such as layout, overlap, spacing, responsive behavior,
   rendering, or final user-visible proof.
6. Close with the exact guide status:
   - `REPO_DESIGN_GUIDE_USED`: target repo guide was read.
   - `PROFILE_DEFAULT_DESIGN_GUIDE_USED`: target repo guide was missing, so the
     installed Driftless default guide was read.
   - `UNVERIFIED_REPO_DESIGN_GUIDE_MISSING`: repo-specific design compliance is
     unverified because only the fallback guide existed.
   - `UNVERIFIED_DESIGN_GUIDE_MISSING`: neither repo guide nor fallback guide
     was readable.

## Must

- Treat target repo `docs/design/DESIGN.md` as product guidance when present.
- When it is missing, apply the installed Driftless default guide instead of
  leaving the screen with no design baseline.
- Make the first screen the actual usable experience unless the task explicitly
  asks for a landing page.
- Include expected UI states: loading, empty, error, success, disabled, and
  recovery paths when relevant.
- Keep manager-facing language simple, concrete, and jargon-light.
- Preserve fair cancel, decline, undo, delete, and back paths. Do not make the
  user fight the interface.

## Never

- Do not claim target repo DESIGN.md compliance without reading that repo's
  file. If the fallback was used, say so.
- Do not leave manager-visible UI as a hidden route, raw localhost URL, or
  internal command only.
- Do not mutate host-global Claude/Codex profiles to install this rule.
- Do not use a machine-specific absolute path as the default design-guide path.

## Evidence

Use this report shape:

```markdown
built/inspected: read <repo guide or installed Driftless default guide> and applied it to <surface>.
tested/evidence: <browser/test/static command evidence>.
manager run/paste: <where the manager sees the UI, or internal-only reason>.
blocked/unverified: <missing rendered proof, missing repo-specific guide, missing all design guides, or open follow-up>.
```
