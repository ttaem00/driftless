# Apply Driftless to your agent

This page shows two ways to set Driftless up. Pick the one that fits you. Both
do the exact same thing, and both **ask before installing anything** (MCP
servers, plugins, or extra tools) — the default answer is always **No**.

You do not need to write any code.

---

## The magic path: say one sentence to your agent

If you already have Claude Code or Codex running in this folder, you do not have
to run anything yourself. Just tell the agent, in plain words:

> **"Apply this repo to me."**

Other sentences that work just as well:

- "Set me up with the Driftless isolated profile."
- "Install this repo's isolated home for yourself, ask before any extras."
- "이 저장소를 나한테 적용해줘." (Korean)
- "드리프트리스 격리 프로필로 나를 설정해줘." (Korean)

The agent reads this page, figures out whether it is Claude or Codex, and runs
the installer below for you. It will **stop and ask you** before installing any
MCP server, plugin, or dependency. If you do not answer, the answer is No, and
nothing extra is installed.

### What the agent will do for you

1. Find this repository's root (it does not matter which sub-folder you are in).
2. Create an **isolated home** for the agent under `./.runtime/` — a private
   config folder that lives **inside this repo**.
3. Point the agent at that isolated home so it never touches your machine's
   global config:
   - Claude is pointed at the isolated home via `CLAUDE_CONFIG_DIR`, instead of
     the host-global `~/.claude`.
   - Codex is pointed at the isolated home via `CODEX_HOME`, instead of the
     host-global `~/.codex`.
4. Tell you which CLIs are installed and what to do next.

The host-global `~/.claude` and `~/.codex` are **never read and never changed**.
Everything stays inside this repository, under `./.runtime/`, which is
git-ignored and never committed.

---

## The manual path: one command

Prefer to do it yourself? Open a terminal in this folder and run one command.

### macOS / Linux (or any POSIX shell)

```sh
# See the plan first (changes nothing):
./install.sh --dry-run

# Set up both profiles:
./install.sh --both

# Or just one:
./install.sh --claude
./install.sh --codex

# Interactive (it asks which tool):
./install.sh
```

### Windows (PowerShell)

```powershell
# See the plan first (changes nothing):
powershell.exe -ExecutionPolicy Bypass -File install.ps1 -DryRun

# Set up both profiles:
powershell.exe -ExecutionPolicy Bypass -File install.ps1 -Tool both

# Or just one:
powershell.exe -ExecutionPolicy Bypass -File install.ps1 -Tool claude
powershell.exe -ExecutionPolicy Bypass -File install.ps1 -Tool codex

# Interactive (it asks which tool):
powershell.exe -ExecutionPolicy Bypass -File install.ps1
```

That is the whole install. Run it again any time — it is **idempotent**: it
re-uses the isolated home you already have and only fills in what is missing.

---

## It ASKS before installing MCP / plugins / dependencies

This is the part that keeps Driftless safe and lean. After it sets up the
isolated home, the installer prints three questions, one at a time:

```
Install optional MCP server(s) for richer tool access? [y/N]:
Install optional plugins into the isolated home?       [y/N]:
Install optional dependencies (extra command-line tools)? [y/N]:
```

- The default for every one of these is **No** (the capital `N`).
- If you just press Enter, or you are running with `--dry-run`, or there is no
  interactive terminal, the answer is **No** and **nothing extra is installed**.
- Driftless works fully without any of these extras. They are offered, never
  assumed.

So you are never surprised by an MCP server, a plugin, or a system package
appearing on your machine. You decide, every time.

---

## Korean / 한국어 요약

코드를 한 줄도 쓸 필요가 없습니다. 방법은 두 가지입니다.

**1) 에이전트에게 한 문장 말하기 (가장 쉬움).**
이 폴더에서 Claude나 Codex가 이미 돌고 있다면, 그냥 이렇게 말하세요.

> "이 저장소를 나한테 적용해줘."

에이전트가 이 문서를 읽고, 자신이 Claude인지 Codex인지 판단해서 아래 설치
스크립트를 대신 실행합니다. **MCP 서버, 플러그인, 추가 도구를 설치하기 전에는
반드시 먼저 물어보고, 기본 답은 항상 "아니오"**입니다. 대답하지 않으면 아무것도
추가로 설치되지 않습니다.

**2) 직접 한 줄 실행하기.**
이 폴더에서 터미널을 열고 아래 한 줄만 실행하세요.

- macOS / Linux: `./install.sh --both`
- Windows: `powershell.exe -ExecutionPolicy Bypass -File install.ps1 -Tool both`
- 먼저 계획만 보고 싶다면 끝에 `--dry-run`(Windows는 `-DryRun`)을 붙이세요.

두 방법 모두 **격리 홈**을 이 저장소 안 `./.runtime/` 폴더에만 만듭니다.
- Claude는 호스트 전역 `~/.claude` 대신 `CLAUDE_CONFIG_DIR`로 격리 홈을 봅니다.
- Codex는 호스트 전역 `~/.codex` 대신 `CODEX_HOME`으로 격리 홈을 봅니다.

즉, 컴퓨터의 전역 설정(`~/.claude`, `~/.codex`)은 **절대 읽거나 바꾸지
않습니다.** 모든 것은 이 저장소 안에만 남습니다. 같은 명령을 다시 실행해도
안전합니다(idempotent) — 이미 만든 격리 홈을 재사용하고 빠진 부분만 채웁니다.

설치 마지막에 MCP 서버 / 플러그인 / 추가 의존성을 설치할지 **세 번 따로 물어보며,
모두 기본값이 "아니오"**입니다. 그냥 Enter만 눌러도 아무것도 설치되지 않습니다.

---

## After it runs

### Step 3 — start the agent against the isolated home

Run from this repo folder. The environment variable is the whole trick: it points
the CLI at the repo-local isolated home, so your host-global config is untouched.
The installer prints exactly these lines for the tool(s) you chose.

macOS / Linux:

```bash
# Claude
CLAUDE_CONFIG_DIR="$(pwd)/.runtime/claude-home" claude
# Codex
CODEX_HOME="$(pwd)/.runtime/codex-home" codex
```

Windows (PowerShell):

```powershell
# Claude
$env:CLAUDE_CONFIG_DIR="$PWD\.runtime\claude-home"; claude
# Codex
$env:CODEX_HOME="$PWD\.runtime\codex-home"; codex
```

That is the launch step — there is no separate launcher script to install; the env
var IS the isolation. Then:

- Your isolated home(s) are under `./.runtime/` (for example
  `./.runtime/claude-home` and `./.runtime/codex-home`). That folder is
  git-ignored, so it is never committed and never shared.
- To confirm the repo never touches a forbidden path or leaks a secret, run the
  containment gate:

  ```powershell
  powershell.exe -ExecutionPolicy Bypass -File scripts/Test-Containment.ps1
  ```

- To confirm every shipped script is Windows-safe (ASCII, no BOM), run:

  ```powershell
  powershell.exe -ExecutionPolicy Bypass -File scripts/Test-WindowsTextSafety.ps1
  ```

Both gates are read-only: no network, no secrets, no host-global access.


## For the agent: the apply-driftless skill

The procedure the agent follows when you say "apply this repo to me" is the
shared **apply-driftless** skill (`profiles/shared/skills/apply-driftless/SKILL.md`),
consumed identically by both the Claude and Codex profiles: detect the tool, dry-run
the installer, ask before any MCP/dependency/plugin (default no), verify the isolated
home materialized and the gates pass, then report in plain language. It never touches
your host-global config.
