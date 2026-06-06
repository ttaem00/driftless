---
name: review-before-done
description: >
  Use before PR_READY, merge, issue close, release, or final Done when changes
  need a last bug/risk review. Trigger: "review before done", "final review",
  "before merge", "before close", "PR_READY", "release check", "끝내기 전 검토",
  "머지 전 검토", "최종 검토".
---
## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Generalize as principle-based guidance or design principles; avoid spec/case overfitting and special-casing unless evidence proves a bounded exception reduces user effort, maintainer effort, maintenance risk, or safety burden.
# Review Before Done

This shared skill prevents a non-developer manager from reading diffs, pull
requests, or raw test logs to decide whether work is ready. The agent reviews
the change, fixes material issues, and reports the evidence.

## Review Focus

Prioritize:

- bugs and behavior regressions;
- security, privacy, containment, or permission mistakes;
- missing verification for the user-visible claim;
- broken installer, launcher, or profile behavior;
- false "done" claims where behavior is only documented or hidden.

Ignore style-only comments unless they hide a real usability or safety issue.

## Workflow

1. Identify the review target:
   - dirty checkout;
   - current branch vs base;
   - pull request;
   - single commit.
2. Read the changed files and the surrounding call path. Do not review from a
   summary alone.
3. Run focused verification based on risk:
   - relevant tests or gates;
   - containment for safety-sensitive changes;
   - installer or fresh-clone smoke when onboarding behavior changed.
4. Classify each finding:
   - `blocker`: directly breaks the goal or safety boundary;
   - `fix-now`: agent-solvable and worth fixing before Done;
   - `backlog`: useful hardening but not needed for this acceptance boundary;
   - `reject`: unsupported, speculative, or outside scope.
5. Fix blocker/fix-now items and rerun verification.

## Done Rule

Do not report Done, PR_READY, or merge-ready while any of these remain:

- failing or unrun required gate;
- unverified user-visible behavior;
- unresolved manager-only decision;
- hidden/internal-only path being presented as a customer feature;
- dirty checkout caused by this task.

## Manager Report

Start with the four Driftless labels. Keep the first sentence plain:

- what changed;
- what was tested;
- what the manager must do, if anything;
- what remains unverified.

Findings should be short and tied to file paths or commands. Do not paste long
logs.
