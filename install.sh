#!/usr/bin/env bash
# ccbar installer
# Usage:
#   curl -sSfL https://raw.githubusercontent.com/dipenchovatiya/ccbar/main/install.sh | bash
#   bash install.sh --uninstall
#   bash install.sh --uninstall --purge

set -e

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

ok()   { printf "${GREEN}✓${RESET} %s\n" "$*"; }
err()  { printf "${RED}✗${RESET} %s\n" "$*" >&2; }
warn() { printf "${YELLOW}!${RESET} %s\n" "$*"; }
info() { printf "  %s\n" "$*"; }
header() { printf "\n${BOLD}${CYAN}%s${RESET}\n" "$*"; }

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
BASE_URL="https://raw.githubusercontent.com/dipenchovatiya/ccbar/main"
CLAUDE_DIR="$HOME/.claude"
CCBAR_SCRIPT="$CLAUDE_DIR/ccbar.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
SETTINGS_BACKUP="$CLAUDE_DIR/settings.json.ccbar-backup"
CONFIG_DIR="$HOME/.config/ccbar"
CONFIG_FILE="$CONFIG_DIR/config"

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
DO_UNINSTALL=false
DO_PURGE=false

for arg in "$@"; do
  case "$arg" in
    --uninstall) DO_UNINSTALL=true ;;
    --purge)     DO_PURGE=true ;;
  esac
done

# ---------------------------------------------------------------------------
# UNINSTALL
# ---------------------------------------------------------------------------
if $DO_UNINSTALL; then
  header "ccbar uninstaller"

  # Remove script
  if [[ -f "$CCBAR_SCRIPT" ]]; then
    rm -f "$CCBAR_SCRIPT"
    ok "Removed $CCBAR_SCRIPT"
  else
    info "ccbar.sh not found — already removed"
  fi

  # Restore or strip statusLine from settings.json
  if [[ -f "$SETTINGS_FILE" ]]; then
    if [[ -f "$SETTINGS_BACKUP" ]]; then
      # Restore original statusLine value from backup
      ORIGINAL_STATUS_LINE="$(cat "$SETTINGS_BACKUP")"
      # If the backed-up value is null, remove the key entirely
      if [[ "$ORIGINAL_STATUS_LINE" == "null" ]]; then
        jq 'del(.statusLine)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" \
          && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        ok "Removed statusLine from $SETTINGS_FILE (original was unset)"
      else
        jq --argjson sl "$ORIGINAL_STATUS_LINE" '.statusLine = $sl' "$SETTINGS_FILE" \
          > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        ok "Restored original statusLine in $SETTINGS_FILE"
      fi
      rm -f "$SETTINGS_BACKUP"
      ok "Removed backup $SETTINGS_BACKUP"
    else
      jq 'del(.statusLine)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" \
        && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
      ok "Removed statusLine from $SETTINGS_FILE"
    fi
  else
    info "No $SETTINGS_FILE found — nothing to update"
  fi

  # Purge config
  if $DO_PURGE; then
    if [[ -d "$CONFIG_DIR" ]]; then
      rm -rf "$CONFIG_DIR"
      ok "Purged config directory $CONFIG_DIR"
    else
      info "Config directory not found — already removed"
    fi
  else
    info "Config preserved at $CONFIG_FILE (use --purge to remove)"
  fi

  printf "\n${GREEN}${BOLD}ccbar uninstalled.${RESET} Restart Claude Code to apply.\n\n"
  exit 0
fi

# ---------------------------------------------------------------------------
# INSTALL
# ---------------------------------------------------------------------------
header "ccbar installer"

# -- Dependency checks -------------------------------------------------------

# jq: required
if ! command -v jq &>/dev/null; then
  err "jq is required but not found."
  info "Install it with:"
  info "  macOS:  brew install jq"
  info "  Ubuntu: sudo apt install jq"
  info "  Fedora: sudo dnf install jq"
  exit 1
fi
ok "jq found ($(jq --version))"

# git: optional (git widgets won't work without it)
if ! command -v git &>/dev/null; then
  warn "git not found — git widgets (branch, status, worktree) will be disabled"
else
  ok "git found ($(git --version | head -1))"
fi

# -- Download ccbar.sh -------------------------------------------------------

printf "\n"
info "Downloading ccbar.sh..."
mkdir -p "$CLAUDE_DIR"
if ! curl -sSfL "${BASE_URL}/ccbar.sh" -o "$CCBAR_SCRIPT"; then
  err "Failed to download ccbar.sh from ${BASE_URL}/ccbar.sh"
  exit 1
fi
chmod +x "$CCBAR_SCRIPT"
ok "Installed $CCBAR_SCRIPT"

# Grab version string from the script for the summary
CCBAR_VERSION="$("$CCBAR_SCRIPT" --version 2>/dev/null || echo "unknown")"

# -- Download config.default -------------------------------------------------

TMPCONFIG="$(mktemp)"
if ! curl -sSfL "${BASE_URL}/config.default" -o "$TMPCONFIG"; then
  err "Failed to download config.default from ${BASE_URL}/config.default"
  rm -f "$TMPCONFIG"
  exit 1
fi

if [[ -f "$CONFIG_FILE" ]]; then
  ok "Preserving existing config at $CONFIG_FILE"
  rm -f "$TMPCONFIG"
else
  mkdir -p "$CONFIG_DIR"
  mv "$TMPCONFIG" "$CONFIG_FILE"
  ok "Created default config at $CONFIG_FILE"
fi

# -- Update ~/.claude/settings.json -----------------------------------------

printf "\n"
STATUS_LINE_JSON=$(jq -n --arg cmd "$CCBAR_SCRIPT" '{"type":"command","command":$cmd}')

if [[ -f "$SETTINGS_FILE" ]]; then
  # Back up the current statusLine value (may be null if key absent)
  jq '.statusLine // null' "$SETTINGS_FILE" > "$SETTINGS_BACKUP"
  ok "Backed up current statusLine to $SETTINGS_BACKUP"

  # Merge new statusLine in
  jq --argjson sl "$STATUS_LINE_JSON" '.statusLine = $sl' "$SETTINGS_FILE" \
    > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  ok "Updated statusLine in $SETTINGS_FILE"
else
  mkdir -p "$CLAUDE_DIR"
  jq -n --argjson sl "$STATUS_LINE_JSON" '{"statusLine":$sl}' > "$SETTINGS_FILE"
  ok "Created $SETTINGS_FILE with statusLine"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf "\n${GREEN}${BOLD}ccbar installed successfully!${RESET}\n\n"
printf "  ${BOLD}Version:${RESET}  %s\n"              "$CCBAR_VERSION"
printf "  ${BOLD}Script:${RESET}   %s\n"              "$CCBAR_SCRIPT"
printf "  ${BOLD}Config:${RESET}   %s\n"              "$CONFIG_FILE"
printf "  ${BOLD}Settings:${RESET} %s\n"              "$SETTINGS_FILE"
printf "\n  Restart Claude Code to see the statusline.\n"
printf "  Edit %s to customize widgets and colors.\n\n" "$CONFIG_FILE"
