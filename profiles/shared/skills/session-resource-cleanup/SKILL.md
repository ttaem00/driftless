---
name: session-resource-cleanup
description: >
  세션리소스정리 session-resource-cleanup: Use when a maintainer asks to finish,
  close out, clean up, optimize, or reduce lag after Claude/Codex/browser
  automation work; when Playwright, Chrome, Edge, Whale, Browser, Webwright,
  local evidence servers, worker processes, or temporary browser profiles may
  have been opened by the current session; or when desktop input/scrolling feels
  laggy and stale automation resources must be inspected without touching normal
  user browser profiles.
---

## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Generalize as
principle-based guidance or design principles; avoid spec/case overfitting and
special-casing unless evidence proves a bounded exception reduces time, tokens,
manager intervention, money/usage, or performance burden.

# Session Resource Cleanup

Use this skill near session closeout, after browser/UI evidence work, or when
desktop input/scrolling feels delayed. The goal is not global process
optimization. The goal is session-owned cleanup: close or register resources the
current session opened, and leave other sessions and normal user apps alone.

## Principle

The session that opens a resource owns its closeout. A global scheduler cannot
reliably know whether a browser window belongs to this session, another session,
or the user. Prefer owner cleanup over global cleanup.

Never read cookies, local storage, browser profile files, passwords, session
stores, `.env`, `.ssh`, private keys, or `secrets/**`.

## Workflow

1. Restate the closeout boundary: what work/session is being cleaned up, and
   what must not be touched.
2. List likely session-owned resources:
   - Playwright/browser contexts and pages opened by this session.
   - Temporary Chromium/Chrome/Edge/Whale profiles with `codex-*`,
     `puppeteer_dev_*`, `ms-playwright`, or `remote-debugging-port` launch
     markers.
   - Local evidence/dev servers started by the session.
   - Worker `node`, `pwsh`, or browser support processes whose parent or command
     line ties them to the current repo/session.
3. First close resources through the owner API when possible:
   - Playwright: close page/context/browser in `finally`.
   - Browser tools: use the tool's close/release operation if available.
   - Local servers: stop the process you started or record its PID/log owner.
4. Run the bundled stale automation-browser audit in dry-run mode before
   terminating anything:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\profiles\shared\skills\session-resource-cleanup\scripts\Invoke-SessionResourceCleanup.ps1 -StaleMinutes 10
```

5. Apply cleanup only when targets are clearly temporary automation resources,
   stale by age, or orphaned because their parent process is gone:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\profiles\shared\skills\session-resource-cleanup\scripts\Invoke-SessionResourceCleanup.ps1 -Apply -StaleMinutes 10
```

6. Report:
   - `inspected`: how many candidate resources were found.
   - `cleaned`: how many were closed/stopped.
   - `left open`: owner, purpose, and cleanup trigger.
   - `not touched`: normal user browsers/apps and why.

## Desktop Lag Triage

If only the desktop AI app still has slow typing or scrolling after cleanup:

1. Verify stale automation browsers are zero.
2. Avoid per-second global WMI/process polling; it can add UI contention.
3. Keep the visible desktop app responsive; do not lower the app/UI process
   priority as a blanket fix.
4. Treat remaining lag as likely Electron/Chromium renderer pressure or product
   issue. Recommend checkpoint + app restart or performance trace instead of
   killing arbitrary child processes.

## Resources

- `scripts/Invoke-SessionResourceCleanup.ps1`: Windows-safe dry-run/apply helper
  for stale temporary browser automation process trees. It matches launch
  metadata only and never reads browser profile contents.
