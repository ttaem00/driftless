#!/usr/bin/env sh
# Driftless installer (POSIX shell).
#
# What this does, in plain language:
#   You cloned or downloaded Driftless. Run this once. It sets up an isolated
#   home for Claude, Codex, or both -- a config folder that lives INSIDE this
#   repository, so the agent never touches your machine's global Claude or Codex
#   settings. It does NOT install Claude, Codex, any MCP server, any plugin, or
#   any dependency without asking you first (and the answer defaults to "no").
#
# Usage:
#   ./install.sh                 # interactive: asks which tool(s) to set up
#   ./install.sh --claude        # set up the Claude profile only
#   ./install.sh --codex         # set up the Codex profile only
#   ./install.sh --both          # set up both profiles
#   ./install.sh --dry-run       # print the plan; change nothing
#   ./install.sh --yes           # accept the default tool choice (both) noninteractively
#   ./install.sh --help          # show this help
#
# This script is idempotent: running it again re-uses the existing isolated home
# and only fills in what is missing. It never writes outside this repository.

set -eu

# ---------------------------------------------------------------------------
# Resolve the repo root from THIS script's own location, never from the current
# directory. That keeps the isolated home under this repo no matter where you
# run the command from.
# ---------------------------------------------------------------------------
SCRIPT_PATH=$0
case "$SCRIPT_PATH" in
  /*) : ;;
  *)  SCRIPT_PATH="$(pwd)/$SCRIPT_PATH" ;;
esac
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)

REPO_ROOT=$SCRIPT_DIR
if command -v git >/dev/null 2>&1; then
  _top=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "${_top:-}" ]; then
    REPO_ROOT=$_top
  fi
fi

RUNTIME_DIR="$REPO_ROOT/.runtime"
PROFILES_DIR="$REPO_ROOT/profiles"

# ---------------------------------------------------------------------------
# Argument parsing.
# ---------------------------------------------------------------------------
TOOL=""
DRY_RUN=0
ASSUME_YES=0

print_help() {
  sed -n '2,30p' "$SCRIPT_PATH" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --claude) TOOL="claude" ;;
    --codex)  TOOL="codex" ;;
    --both)   TOOL="both" ;;
    --dry-run) DRY_RUN=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    -h|--help) print_help; exit 0 ;;
    *)
      printf '%s\n' "Unknown option: $1"
      printf '%s\n' "Run with --help to see the options."
      exit 2
      ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Small output helpers (plain language, no jargon).
# ---------------------------------------------------------------------------
say()  { printf '%s\n' "$1"; }
step() { printf '  %s\n' "$1"; }
rule() { printf '%s\n' "--------------------------------------------------------"; }

# ask_yes_no PROMPT  -> returns 0 for yes, 1 for no. DEFAULT IS NO.
# In --dry-run or non-interactive mode the answer is the default (no), and we
# say so, so nothing is ever installed behind your back.
ask_yes_no() {
  _prompt=$1
  if [ "$DRY_RUN" -eq 1 ]; then
    step "[dry-run] would ask: $_prompt -> defaulting to NO"
    return 1
  fi
  if [ ! -t 0 ]; then
    step "(no interactive terminal) -> defaulting to NO: $_prompt"
    return 1
  fi
  printf '  %s [y/N]: ' "$_prompt"
  read -r _ans || _ans=""
  case "$_ans" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

# run_or_plan DESCRIPTION COMMAND...  -> run the command, or in --dry-run just
# print what it would do. Used so the dry-run output mirrors the real run.
run_or_plan() {
  _desc=$1
  shift
  if [ "$DRY_RUN" -eq 1 ]; then
    step "[dry-run] would: $_desc"
    return 0
  fi
  "$@"
}

# ---------------------------------------------------------------------------
# Tool selection (interactive when not given on the command line).
# ---------------------------------------------------------------------------
choose_tool() {
  if [ -n "$TOOL" ]; then
    return 0
  fi
  if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
    TOOL="both"
    return 0
  fi
  say "Which agent do you want to set up an isolated home for?"
  step "1) Claude"
  step "2) Codex"
  step "3) Both  (default)"
  printf '  Choose 1, 2, or 3 [3]: '
  read -r _c || _c=""
  case "$_c" in
    1) TOOL="claude" ;;
    2) TOOL="codex" ;;
    *) TOOL="both" ;;
  esac
}

# ---------------------------------------------------------------------------
# Detect whether a CLI is installed (report only; we never auto-install it).
# ---------------------------------------------------------------------------
cli_state() {
  if command -v "$1" >/dev/null 2>&1; then
    printf '%s' "installed"
  else
    printf '%s' "not installed"
  fi
}

# ---------------------------------------------------------------------------
# Materialize one isolated home under .runtime, from the matching profile.
#   NAME        human label (Claude / Codex)
#   PROFILE     source folder name under profiles/
#   HOME_DIR    target isolated home under .runtime/
#   ENV_VAR     the environment variable the launcher exports to isolate the CLI
# The isolated home is a COPY of the profile tree placed under .runtime, which is
# gitignored. It is created only inside this repo; the host-global config home is
# never read or written.
# ---------------------------------------------------------------------------
materialize_home() {
  NAME=$1
  PROFILE=$2
  HOME_DIR=$3
  ENV_VAR=$4

  _src="$PROFILES_DIR/$PROFILE"
  _shared="$PROFILES_DIR/shared"

  if [ ! -d "$_src" ]; then
    step "$NAME profile folder is missing ($_src); skipping."
    return 0
  fi

  if [ -d "$HOME_DIR" ]; then
    step "$NAME isolated home already exists -- re-using it (idempotent): $HOME_DIR"
  else
    step "$NAME isolated home will be created at: $HOME_DIR"
  fi

  # Copy the tool profile and the shared tier into the isolated home. Copying is
  # idempotent: existing files are refreshed, nothing outside .runtime is touched.
  run_or_plan "create $HOME_DIR" mkdir -p "$HOME_DIR"
  run_or_plan "copy the $NAME profile into the isolated home" sh -c "cp -R \"$_src/.\" \"$HOME_DIR/\""
  if [ -d "$_shared" ]; then
    run_or_plan "copy the shared tier (contract + safety schemas + shared skills) into the isolated home" \
      sh -c "mkdir -p \"$HOME_DIR/shared\" && cp -R \"$_shared/.\" \"$HOME_DIR/shared/\""
  fi

  step "$NAME isolation: starting the agent with $ENV_VAR set to this repo-local home (the command printed at the end) keeps the host-global config untouched."
}

# ---------------------------------------------------------------------------
# Ask-before-install: optional extras (MCP servers, plugins, dependencies).
# DEFAULT IS NO for every one of these. We print the prompt and only act on an
# explicit "yes". This is the load-bearing promise of the installer.
# ---------------------------------------------------------------------------
offer_optional_extras() {
  rule
  say "Optional extras (all default to NO):"
  step "Driftless runs without any of these. They are offered, never assumed."
  say ""

  if ask_yes_no "Install optional MCP server(s) for richer tool access?"; then
    step "You said yes. Driftless does not bundle an MCP server installer in this"
    step "minimal kit, so nothing was installed. Add the server yourself only if"
    step "you trust it; the agent reads MCP definitions from the repo-local home."
  else
    step "Skipped MCP servers. (You can add one later by hand.)"
  fi

  if ask_yes_no "Install optional plugins into the isolated home?"; then
    step "You said yes. No plugin is bundled in this minimal kit, so nothing was"
    step "installed. Drop a vetted plugin into the profile and re-run to pick it up."
  else
    step "Skipped plugins."
  fi

  if ask_yes_no "Install optional dependencies (extra command-line tools)?"; then
    step "You said yes. This kit installs no system packages for you; install any"
    step "tool you want through your own package manager."
  else
    step "Skipped dependencies. The two safety gates need only PowerShell or a"
    step "POSIX shell, both of which you already have."
  fi
}

# ---------------------------------------------------------------------------
# Main flow.
# ---------------------------------------------------------------------------
rule
say "Driftless installer"
rule
step "Repo:    $REPO_ROOT"
step "Profiles: $PROFILES_DIR"
step "Isolated homes go under: $RUNTIME_DIR  (gitignored; never committed)"
if [ "$DRY_RUN" -eq 1 ]; then
  step "Mode:    DRY RUN -- nothing will be created or changed."
fi
say ""

choose_tool
say "Setting up: $TOOL"
say ""

# Report CLI presence (we never install the CLI itself).
step "Claude CLI: $(cli_state claude)"
step "Codex CLI : $(cli_state codex)"
say ""

case "$TOOL" in
  claude)
    materialize_home "Claude" "claude" "$RUNTIME_DIR/claude-home" "CLAUDE_CONFIG_DIR"
    ;;
  codex)
    materialize_home "Codex" "codex" "$RUNTIME_DIR/codex-home" "CODEX_HOME"
    ;;
  both)
    materialize_home "Claude" "claude" "$RUNTIME_DIR/claude-home" "CLAUDE_CONFIG_DIR"
    say ""
    materialize_home "Codex" "codex" "$RUNTIME_DIR/codex-home" "CODEX_HOME"
    ;;
esac

offer_optional_extras

rule
if [ "$DRY_RUN" -eq 1 ]; then
  say "Dry run complete. No files were created or changed."
  say "Re-run without --dry-run to apply this plan."
else
  say "Setup complete."
  step "Your isolated home(s) live under .runtime and are contained to this repo."
  step "The host-global Claude/Codex config was never read or changed."
  say "To start now, run from this folder (the env var points the agent at the isolated home):"
  if [ "$TOOL" = "claude" ] || [ "$TOOL" = "both" ]; then
    step "Claude:  CLAUDE_CONFIG_DIR=\"$(pwd)/.runtime/claude-home\" claude"
  fi
  if [ "$TOOL" = "codex" ] || [ "$TOOL" = "both" ]; then
    step "Codex:   CODEX_HOME=\"$(pwd)/.runtime/codex-home\" codex"
  fi
  step "Details + the Windows (PowerShell) form: docs/en/apply-to-your-agent.md (Step 3)."
fi
rule
