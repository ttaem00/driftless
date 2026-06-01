# Real-use verification (measured)

A skeptic's question for any "non-developer can use it" tool is: *does the setup
actually work on a clean machine, and how long does it take?* This is a measured
answer, not a claim — re-runnable by anyone.

## What was run (fresh clone, non-developer path)

```
git clone https://github.com/mizan0515/driftless && cd driftless
sh ./install.sh --dry-run --both      # preview the plan, change nothing
sh ./install.sh --both --yes          # materialize the isolated homes
```

## Result (measured)

| Step | Outcome |
|---|---|
| Fresh `git clone` | OK |
| `install.sh --dry-run --both` | OK (exit 0) — prints the plan, changes nothing |
| `install.sh --both --yes` | OK (exit 0) — asks before any MCP/dep/plugin (default no) |
| Isolated homes materialized | `.runtime/claude-home` **and** `.runtime/codex-home` created |
| Host-global config | untouched (the installer only writes under `.runtime/`) |
| Containment gate on the fresh clone | **PASS** (`DRIFTLESS_CONTAINMENT_PASS`) |
| **End-to-end wall-clock** | **~16 seconds** |

## Why this matters (5-axis: time + non-dev access)

The README promises a "60-second proof." Measured, the whole zero-to-isolated-home
path is **~16s** — well inside that, on a clean checkout, for both tools at once.
This is the *time* axis of the five-axis gradient (faster setup = less of the
operator's time) and the credibility check that the non-developer onboarding path
is real, not aspirational.

## Honest limits

- Measured on Windows (the host with PowerShell for the gates). The POSIX
  installer path itself runs on Linux/macOS too (CI proves the Linux installer +
  containment), but a full non-Windows wall-clock is not separately captured here
  — see the [host evidence matrix](../docs/en/host-evidence-matrix.md).
- The number is install + gate setup, not an overnight maintenance run (that
  depends on your repo's backlog size).
- Re-run it yourself; the steps above are the whole test.
