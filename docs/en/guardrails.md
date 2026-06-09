# Guardrails

Driftless is **autonomous within gates**. That phrase is the whole safety model:
the AI maintainer is free to do real work on its own — read, branch, fix, open
pull requests, merge passing ones — but it operates inside fences that it cannot
cross. The fences are not advice the AI is asked to follow; the load-bearing ones
are **machine-enforced gates that mechanically fail the work** if a boundary is
broken.

This page describes the four main guardrails in plain language, then names the
exact checks behind each one.

> **Autonomous within gates:** the AI is trusted to *act*, never trusted to
> *decide* who it can act against. The fences decide that, and a human decides
> anything irreversible.

---

## 1. The containment guard — never touches your private files

**Plain version.** The maintainer works only inside your project folder. It never
reaches into your machine's private corners: your global Claude or Codex settings,
your passwords, your SSH keys, your browser data, your `.env` secrets. A guard
scans every change before it can be called done, and if any change reaches for one
of those places, the guard **FAILs** and the work stops.

**What is forbidden.** The forbidden surface is a single, machine-readable rule
set (`forbidden-paths.json`) shared by both tool profiles. It blocks:

- `.env` / `.env.*` environment-secret files
- `.ssh` directories (private SSH material)
- `secrets/` directories
- private keys (`*.pem` / `*.key`)
- browser profiles and credential stores (`Login Data`, `Cookies`, `chrome-profile`)
- the **host-global** agent homes `~/.claude` and `~/.codex` (the maintainer uses
  a *repo-local* isolated home instead — see below)
- leaked credential tokens in any file: GitHub (`ghp_`...), Anthropic
  (`sk-ant-`...), OpenAI-style (`sk-`...), AWS (`AKIA`...), and inline
  `PRIVATE KEY` blocks

**Three kinds of finding.** The guard reports each problem as one of:

- `forbidden_path` — the changed file's **own** path is a forbidden location.
- `forbidden_reference` — a file's text reads or writes a forbidden path.
- `forbidden_secret` — a file's text contains a credential token.

**The containment invariant.** The guard **never opens a secret or forbidden
file.** A file whose own path is forbidden is flagged purely by its path — its
contents are never read. So the guard cannot itself become a way to leak the very
things it protects.

**Honest fairness (why your docs do not falsely fail).** Documentation and the
guard's own infrastructure (`*.md` files, the gate scripts, the schema folder,
`.gitignore`) are *allowed to name* a forbidden path in order to describe or
enforce the boundary — this very page names `~/.claude`. So a `path`-rule
*reference* is not flagged in those files. But the **own-path check and every
secret rule are never exempted**, so a real leaked credential is caught even
inside a doc.

**Isolation, not deletion.** The maintainer runs against a **repo-local isolated
home**, not your global one. For Claude that means `CLAUDE_CONFIG_DIR` points at a
folder inside the repo's runtime area; for Codex it is `CODEX_HOME`. Your machine's
global `~/.claude` and `~/.codex` are left completely untouched. A repo-local
`.claude/` or `.codex/` work folder is part of the project and is exempt from the
own-path check — but a *content reference* to the host-global `~/.claude` still
FAILs, so the isolation can never be quietly bypassed.

---

## 2. The Windows text-safety gate — never ships a script that breaks on Windows

**Plain version.** A single wrong character in a script can silently break it on
Windows. The maintainer is not allowed to ship one. A gate checks every script
and FAILs if it finds a character that Windows can misread.

**Why this matters.** PowerShell 7 and `cmd.exe` read a BOM-less UTF-8
file as the legacy CP1252 codepage. A stray em dash, a curly quote, or any
non-Latin character corrupts the bytes and breaks the parse — and the failure
only shows up later, on someone else's machine. The gate catches it up front. It
enforces three things on every tracked `.ps1` / `.bat` / `.cmd`:

1. **ASCII-only + no UTF-8 BOM.** No em dashes, curly quotes, or non-Latin
   characters in code or string literals; no leading BOM.
2. **No PowerShell-5.1-fragile cmdlets.** A live use of a cmdlet that can be
   absent on the constrained 5.1 host (for example `Get-FileHash`) is flagged
   before it can fail only at runtime.
3. **Forward-slash hook paths.** Any tracked `settings.json` must declare hook
   `command` paths with forward slashes — backslash paths collapse on Windows and
   can freeze the desktop agent host.

(These rules apply to scripts. Documentation files like this one are free to use
Korean, em dashes, and rich punctuation — they are not parsed by a shell.)

---

## 3. Ask before install / before anything that changes your machine

**Plain version.** The maintainer does not silently install software, change
your global settings, or reach outside the project. Anything that would alter your
machine or pull in an outside tool is treated as a request you approve, not a
thing it does on its own.

In practice:

- **Repo-local by default.** Config, runtime state, and work folders stay inside
  the project. "Global" defaults to *repo-wide here*, never *host-global*, unless
  you explicitly approve a host-global promotion.
- **No surprise peers.** The maintainer does not spawn extra AI tools, bridges, or
  recursive agents in the working path unless a current, approved task authorizes
  it. (It *is* allowed to orchestrate its own helper sessions over your repo's own
  work — that is the overnight loop itself.)
- **Outside tools are a decision, not a default.** Adopting an external library,
  installing a dependency, or enabling a new integration is surfaced to you with
  evidence, not assumed.

---

## 3b. The work-discipline gate — no unfinished stub ships as a real rule

**Plain version.** Two habits keep the maintainer honest: a rule must be *real*
before it ships (no "I'll fill this in later" left inside an authoritative file),
and non-trivial work runs on a branch tied to a tracked issue. Both used to live
only as written advice. The work-discipline gate turns the first one into a
mechanical check and surfaces the second as an advisory.

**What it enforces (blocking).** The gate scans every tracked `.md` and `.ps1`
for an *unresolved placeholder* — a leftover stub marker introducing unfinished
content. The genuine-stub signal is narrow on purpose, so prose that merely
*names* the word in passing is not flagged:

- A marker in **stub form** (`TODO:` / `FIXME:` / `XXX:` / `TBD:`, or `FIXME(`)
  introducing leftover content, or a marker that is the **first token** of a line
  or list item.
- An **angle-bracket template token** — an unfilled slot such as `<PLACEHOLDER>`,
  `<FILL-IN>`, `<TBD>`, or `<REPLACE-ME>`.

If a tracked rule file ships one of these, the gate **FAILs** with the exact
`file:line`, so the stub is resolved before the change is called done. A token
cited inside a code span (`` `TODO` ``) is treated as a deliberate mention and is
*not* a hit — the same fairness the containment and text-safety gates give to
docs that name the thing they guard. This very document, which describes the
work-discipline gate and names those markers, is exempt for that reason.

**Proven to have teeth.** A built-in negative self-test plants a placeholder in
an in-memory rule fixture and asserts the detector FAILs on it, then asserts a
clean fixture PASSes — no temp files, no git mutation:

```powershell
.\scripts\Test-WorkDiscipline.ps1 -SelfTest
```

**What it advises (non-blocking).** The gate also reports whether the current
working branch follows `agent/issue-<n>-<slug>` (or the tool-specific
`claude/issue-...` / `codex/issue-...` forms), tying non-trivial work to a
tracked issue. This is an **advisory** only: a detached HEAD or the default
branch is skipped, never failed — a clean release cut should not break the gate.

---

## 4. Human-only escalation — some decisions never become the AI's to make

**Plain version.** A short list of decisions is *always* yours. When the
maintainer hits one of these, it stops and asks you a short question in your own
language instead of guessing. It will not do these on its own no matter how
"obviously right" they look.

**The human-only gates:**

- **Product and priority** — what the project should become, and what matters most.
- **Credentials** — anything involving logins, keys, or secrets.
- **Billing and quota** — spending money or consuming paid quota.
- **Public release** — publishing anything to the world.
- **Destructive or irreversible actions** — deletes and operations that cannot be
  undone.
- **Host-global promotion** — touching your machine's global settings.
- **User-data transfer** — moving your data somewhere new.
- **Force-push and history reset** — rewriting the shared project history.

Everything *outside* this list — the routine GitHub, git, validation, and safety
mechanics — the maintainer is expected to handle on its own, so you are only ever
asked about things that genuinely need a human.

---

## How "autonomous within gates" actually finishes a job

A guarded autonomy is only safe if the AI cannot quietly skip a fence and call
the job done. Driftless closes that loophole:

- **No false "done."** A job is not done while hidden, unverified, or risky work
  is still pending. Unverified or partial results must be labeled as such and
  tracked as follow-ups, not buried under unrelated successes.
- **Solve-or-escalate.** If a blocker is something the AI can fix this session, it
  fixes it, retries the gate, and reports the retry as evidence. If the blocker is
  one of the human-only gates above, it asks you instead.
- **Evidence over claims.** No "it passed" without a real run that produced the
  evidence. A static check of a document proves the document, not the behavior.

---

## Run the gates yourself

The two load-bearing gates are small, read-only PowerShell scripts — no network,
no secrets, no host-global access — and they run the same on Windows PowerShell
5.1 and PowerShell 7.

```powershell
# Containment: scan the working-tree diff and untracked files (the pre-commit default)
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-Containment.ps1

# Containment: scan every tracked file (full audit)
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-Containment.ps1 -AllFiles

# Windows text safety: every tracked .ps1 / .bat / .cmd
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-WindowsTextSafety.ps1

# Work discipline: no unresolved placeholder ships inside a tracked rule file
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-WorkDiscipline.ps1
```

Add `-Json` to either gate for a machine-readable summary. Exit codes: `0` = PASS,
`1` = FAIL, `2` = BLOCKED (containment gate only, when the target is not a git
repository — reported BLOCKED, never a silent PASS).

For which operating systems these gates are *verified* on, see the
[Host Evidence Matrix](./host-evidence-matrix.md). Korean version of this page:
**[안전장치](../ko/안전장치.md)**.
