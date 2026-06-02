---
name: safety-guard
description: >
  Use when a task may expose secrets, touch private files, mutate host-global
  agent settings, publish content, spend money, use credentials, or handle user
  data. Trigger: "safety check", "guardrails", "secret check", "security
  boundary", "containment", "before publish", "before merge", "안전 검사",
  "비밀 검사", "보안 경계".
---

# Safety Guard

This shared skill keeps a non-developer manager from judging security logs or
private-file risk. The agent does the safety check, reports only the result, and
asks the manager only for true manager-only gates.

## Use This Skill When

- Work may read, write, copy, publish, or summarize private data.
- A change affects installer behavior, profile homes, hooks, launchers, browser
  automation, credentials, billing, public release, or user data.
- The agent is about to call work done and needs containment evidence.

## Forbidden Surface

Never read, copy, commit, or mutate:

- host-global agent homes such as `~/.claude` or `~/.codex`;
- `.env`, `.env.*`, SSH folders, cloud credentials, private keys, browser
  profiles, token files, password stores, or `secrets/**`;
- auth/session/log/cache state from another runtime.

Use the repo's shared forbidden-path schema and containment gate instead of
manual guesswork.

## Workflow

1. Restate the user-visible goal in one sentence.
2. Classify the work:
   - safe local repo work;
   - needs manager approval;
   - blocked because it would touch the forbidden surface.
3. Run the smallest available safety evidence:
   - `powershell.exe -ExecutionPolicy Bypass -File scripts/Test-Containment.ps1 -AllFiles`
   - plus any repo-specific gate named in the issue or PR.
4. If the task needs credentials, billing, public release, destructive action,
   host-global promotion, or user-data transfer, stop and ask one plain-language
   question.
5. If the risk is agent-solvable, fix it and rerun the gate. Do not hand raw
   logs to the manager.

## Manager Report

Use the four Driftless labels:

- `built/inspected`: what was checked and why it matters.
- `tested/evidence`: gate command and PASS/FAIL/BLOCKED/UNVERIFIED result.
- `manager run/paste`: only login or approval steps the manager must do.
- `blocked/unverified`: exact risk or unverified host.

Do not say "safe" unless a concrete gate or command supports it.
