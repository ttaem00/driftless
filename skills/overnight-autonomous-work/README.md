# Overnight Autonomous Work

**Paste one prompt before bed. Wake up to merged pull requests.**
You never have to write code.

This is the core skill of Driftless. It turns your AI agent into an overnight
maintainer: you give it one instruction, and it works through your whole backlog
on its own — *but only within a fence you control.* It does the routine work
itself and asks you only about the things that genuinely need a human:
money, permissions, public releases, and product decisions.

Works with Claude (subagents) **and** Codex (goal mode). Same skill, both tools —
that is the "driftless" part: your two profiles never drift apart.

---

## What you get (in plain words)

You are not a developer. You do not read logs. Here is what this skill actually
does for you while you sleep:

1. **Looks at everything.** It surveys all your open issues, pull requests,
   backlog notes, TODOs, and anything that is currently failing.
2. **Figures out what you really want.** Instead of just listing tickets, it
   reads the evidence and infers your real goal — and tells you, in plain
   language, how confident it is and why.
3. **Does the work in parallel.** It splits the work into lanes that won't step
   on each other and runs several worker agents at once.
4. **Fixes its own mistakes.** When a worker fails, it diagnoses the cause and
   retries a *different* way — it does not just repeat the same failing attempt.
5. **Checks its own work.** Nothing counts as "done" on a worker's say-so. The
   parent re-verifies every result by actually running it.
6. **Merges what is finished.** When something is verified and safe, it opens the
   pull request and merges it.
7. **Asks you only what matters.** It escalates exactly one short question at a
   time, only for real decisions (below). Everything else, it handles.

In the morning you get a plain-language report: what got done, what is still
stuck and why, and a short numbered list of anything you need to decide.

---

## The guardrail (autonomous, but only inside the fence)

This is the important part. The agent is free to act on its own — **except** for
these, where it stops and asks you a short, plain question:

- Product direction or priority calls.
- Entering or using passwords, secrets, or API keys.
- Spending money, paid credits, or quota.
- Publishing or releasing anything publicly.
- Anything destructive or irreversible (deleting data, removing a feature).
- Changing settings on your whole computer (not just this project).
- Moving or changing your personal data.

If it is not on that list, the agent does it for you. It will not park the work
and wait — and it will not pretend something is finished when it is not. It is
built to never report "done" without real proof that the thing actually works.

---

## The one prompt you paste

Open your agent in your project folder and paste this. Replace `<TARGET_REPO>`
with your project (or just say "this repo").

```text
You are the PARENT session for this repo (<TARGET_REPO>). I am a non-developer —
report to me in plain language: what is stuck, what is done, and what I need to
decide. Nothing else.

Run the overnight-autonomous-work skill end to end:
- Survey all open issues, PRs, backlog, TODOs, and failing checks.
- Infer my real goal from the evidence (and tell me how confident you are).
- Split the work into conflict-free parallel lanes and run worker agents on them.
- When a worker fails, diagnose and retry a DIFFERENT way; never repeat the same
  failing attempt.
- Re-verify every worker result yourself by actually running it.
- Merge work that is verified and safe.
- Do NOT defer doable work to "next time" — finish what you safely can THIS run,
  and for anything left open, record what you tried, the limit you hit, and the
  exact condition to retry.
- Before you tell me you are done, audit your own report against the real state.

You own all the routine git / verification / merge / issue work. Ask me ONLY
about: product or priority calls, passwords or credentials, spending money,
public releases, destructive actions, whole-computer changes, or moving my data.

Start now, and end with a plain-language report plus a numbered list of anything
I must decide.
```

That is the whole interface. One paste, then sleep.

---

## What it will NOT do (so you can trust it overnight)

- It will not spend money or use credits without asking.
- It will not publish or deploy anything without asking.
- It will not touch your secrets, passwords, or anything outside this project.
- It will not delete data or remove features without asking.
- It will not claim something works without actually running it.
- It will not push directly to your main branch or rewrite history.

---

## The files in this folder

- `SKILL.md` — the full execution bundle the agent follows (the detailed version
  of everything above: the phases, the safety gates, and the templates).
- `README.md` — this page.

You only ever need the one prompt above. The `SKILL.md` is what makes the agent
behave the way this page promises.
