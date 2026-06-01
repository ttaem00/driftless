# 5-minute quickstart (for non-developers)

You do not need to know how to code. You need a terminal open in this folder and
either **Claude Code** or **OpenAI Codex** installed. If you have neither yet,
install one first (links: [Claude Code](https://docs.anthropic.com/claude-code),
[Codex](https://developers.openai.com/codex)) — Driftless drives them, it does
not replace them.

> The fastest path: if your agent is already running in this folder, just say
> **"apply this repo to me"** and it follows the [apply-driftless](../../profiles/shared/skills/apply-driftless/SKILL.md)
> procedure for you. The manual steps below are the same thing, by hand.

## Step 1 — Get the repo (1 min)

```sh
git clone https://github.com/mizan0515/driftless
cd driftless
```

## Step 2 — Run the installer (1 min)

It builds an isolated agent home **inside this folder** and never touches your
computer's global Claude/Codex settings. It asks before installing anything
extra, and the answer defaults to **no**.

```sh
./install.sh            # macOS / Linux  (asks: Claude, Codex, or both)
```
```powershell
.\install.ps1           # Windows PowerShell
```

Try `./install.sh --dry-run --both` first if you want to see the plan without
changing anything.

## Step 3 — Start your agent against the isolated home (1 min)

Start Claude Code or Codex **from inside this folder** so it uses the isolated
profile the installer just made. (On Windows the launcher script sets this up
for you; on macOS/Linux, point the tool's config at the repo-local home the
installer printed.)

## Step 4 — Paste one prompt (30 sec)

Open an issue or two describing what you want done (in plain words — "fix the
typos in the docs", "add a contributing guide"). Then paste:

> Push every remaining ticket as far as you can. Survey the open issues, split
> them into safe parallel pieces, open PRs, and merge the ones that pass every
> gate. Ask me before anything risky, irreversible, or that costs money.

## Step 5 — Sleep, then read the morning report (next morning)

You wake up to **merged pull requests** and a short plain-language report:
**done / needs your decision / blocked / in progress**. You review results, not
code.

---

## What you should NOT expect (honest limits)

- It will **not** spend money, publish anything public, touch your private
  files, or do anything irreversible without asking you first.
- Windows is the fully-verified path today; macOS/Linux run the installer but
  some gates are PowerShell-only — see the
  [host evidence matrix](./host-evidence-matrix.md). Anything not yet verified on
  your OS is labeled UNVERIFIED, not promised.
- This is **v0.1.0, day one.** It works, and it maintains its own repo in the
  open, but it is new — start with small, low-risk tickets and grow trust.

## If something breaks

Run the safety gates yourself — they tell you, in plain output, what is wrong:

```powershell
.\scripts\Test-Containment.ps1 -Path . -AllFiles
.\scripts\Test-ProfileMirrorParity.ps1 -Path .
```

Then open an issue describing what you did and what happened.
