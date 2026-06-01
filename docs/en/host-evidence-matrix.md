# Host Evidence Matrix

Driftless makes a hard rule of itself: **a claim is only as strong as the
evidence from the host it was measured on.** A check that passes on Windows does
*not* prove it passes on macOS or Linux. So instead of a vague "cross-platform"
badge, this page states, per operating system, exactly what has been **verified**
and what is honestly still **UNVERIFIED**.

Honest `UNVERIFIED` labeling is not a weakness — it is the rigor. We would rather
tell you "we have not measured this on your machine yet" than imply a green check
we did not earn.

---

## Evidence vocabulary

| Status | Meaning |
|---|---|
| **PASS** | Ran on this host and produced passing evidence. |
| **UNVERIFIED** | Not yet run on this host. No claim either way. |
| **BLOCKED** | Could not run (missing prerequisite, e.g. not a git repo). |
| **N/A** | Does not apply to this host. |

---

## The matrix

| Capability | Windows | macOS | Linux |
|---|---|---|---|
| **Containment gate** (`Test-Containment.ps1`) | **PASS** — verified on Windows PowerShell 5.1 and PowerShell 7 | UNVERIFIED | **PASS** — runs in CI on an Ubuntu runner (`pwsh`) on every push/PR |
| **Windows text-safety gate** (`Test-WindowsTextSafety.ps1`) | **PASS** — verified on Windows PowerShell 5.1 and PowerShell 7 | UNVERIFIED (the *rule* is Windows-specific, but the gate would still need a run to confirm it executes) | UNVERIFIED |
| **Profile mirror-parity gate** | **PASS** on Windows | UNVERIFIED | UNVERIFIED |
| **Env-var launch** (`CLAUDE_CONFIG_DIR` / `CODEX_HOME` -> isolated home; no `Start-*.ps1` launcher ships) | UNVERIFIED — the installer prints the command (`apply-to-your-agent.md` Step 3); a real session start is not yet e2e-measured | UNVERIFIED — same | UNVERIFIED — same |
| **Cross-platform install path** (`install.sh` / `install.ps1`) | UNVERIFIED — `install.ps1` is the Windows entry point; dry-run works, a full run is not yet measured | UNVERIFIED — intended path, not yet measured | **PASS** — CI runs `install.sh --both --yes` on Ubuntu, asserts the isolated homes materialize under `.runtime/` and host-global `~/.claude` is untouched |

---

## What "Windows PASS" actually means

The Windows column is green because the gates were **run** on a real Windows host
and produced passing evidence — not because the source looks correct. Specifically:

- The gates are authored to parse identically under **Windows PowerShell 5.1**
  (the constrained legacy host that CI uses) **and PowerShell 7**, and were
  verified under both.
- The gate scripts are themselves ASCII-only and BOM-free, so each one passes its
  own text-safety rule.
- The containment gate reports `BLOCKED` (exit 2), never a silent PASS, when the
  target is not a git repository — so an empty or wrong target cannot masquerade
  as success.

A Windows PASS is a statement about Windows only. It carries **no** implication
for macOS or Linux. That is the rule.

---

## Why macOS and Linux are UNVERIFIED (and what would change that)

The two gates are PowerShell. PowerShell *does* run on macOS and Linux via
**PowerShell 7 (`pwsh`)**, and the gates avoid Windows-only constructs, so they
are *expected* to work there. But "expected" is not "verified." Until the gates
are actually executed on a macOS host and a Linux host and produce passing
evidence, those cells stay **UNVERIFIED** — by design, not by oversight.

To promote a cell from UNVERIFIED to PASS, the standard is simple and the same as
everywhere else in Driftless:

1. Run the gate on that host (`pwsh -File scripts/Test-Containment.ps1`, etc.).
2. Capture the real output as evidence.
3. Record it against that host. One host's PASS never back-fills another's.

### The cross-platform install path

For users who are not on Windows, the intended entry point is a POSIX
`install.sh` rather than the PowerShell launcher. This path is **documented but
UNVERIFIED**: it is the planned route for macOS/Linux setup and has not yet been
measured end-to-end on those hosts. We label it honestly so you know it is a
roadmap path, not a tested one. When it is run and produces evidence on a given
host, this matrix is updated for that host — and only that host.

---

## The principle behind this page

This whole document exists because Driftless treats "it works" as a measured
fact, not a hope:

- **Host-specific PASS needs evidence from that host.** A Windows PASS never
  implies a macOS or Linux PASS.
- **Behavioral claims need a real end-to-end run.** A static review of a script
  or a document leaves the *behavior* UNVERIFIED, no matter how correct the text
  looks.
- **UNVERIFIED is a real, honest status** — not a polite way of saying "probably
  fine." It means "no claim has been earned here yet."

If you run a gate on a host we have marked UNVERIFIED and it passes, that is
exactly the evidence needed to upgrade the cell. Contributions of host evidence
are welcome.

Korean: see the guardrails page **[안전장치](../ko/안전장치.md)** for the safety
model these gates enforce.
