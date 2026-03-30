#!/usr/bin/env bash
# setup.sh — Install the Node.js upgrade skill for your AI coding agent
#
# Usage:
#   bash setup.sh                  # Interactive — asks which agent(s)
#   bash setup.sh --all            # Install for all detected agents
#   bash setup.sh --agent claude   # Install for a specific agent
#
# Supported agents:
#   claude, copilot, cursor, windsurf, codex, gemini, cline, aider, amazonq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
SKILL_FILE="$SKILL_DIR/SKILL.md"
TARGET_DIR="${TARGET_PROJECT:-.}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!!]${NC} $1"; }
header(){ echo -e "\n${CYAN}$1${NC}"; }

# Strip Claude Code frontmatter and return plain markdown
strip_frontmatter() {
  awk 'BEGIN{in_fm=0; seen_fm=0}
    /^---$/ && !seen_fm { in_fm=1; seen_fm=1; next }
    /^---$/ && in_fm    { in_fm=0; next }
    !in_fm { print }' "$SKILL_FILE"
}

# ── Agent installers ────────────────────────────────────────────────

install_claude() {
  local dir="$TARGET_DIR/.claude/skills/nodejs-upgrade-skill"
  mkdir -p "$dir"
  cp "$SKILL_FILE" "$dir/SKILL.md"
  cp -r "$SKILL_DIR/references" "$dir/"
  cp -r "$SKILL_DIR/scripts" "$dir/"
  info "Claude Code: installed to $dir"
}

install_copilot() {
  local dir="$TARGET_DIR/.github/instructions"
  mkdir -p "$dir"
  cat > "$dir/nodejs-upgrade.instructions.md" << 'FRONTMATTER'
---
applyTo: "**"
name: "Node.js Runtime Upgrade"
description: "Trigger when upgrading, migrating, or modernizing Node.js runtime versions"
---

FRONTMATTER
  strip_frontmatter >> "$dir/nodejs-upgrade.instructions.md"
  info "GitHub Copilot: installed to $dir/nodejs-upgrade.instructions.md"
}

install_cursor() {
  local dir="$TARGET_DIR/.cursor/rules"
  mkdir -p "$dir"
  cat > "$dir/nodejs-upgrade.mdc" << 'FRONTMATTER'
---
description: "Node.js runtime upgrade — trigger when upgrading, migrating, or modernizing Node.js versions, fixing EOL warnings, or updating engines field"
globs: ["package.json", ".nvmrc", ".node-version", ".tool-versions", "Dockerfile*", "**/*.yml"]
alwaysApply: false
---

FRONTMATTER
  strip_frontmatter >> "$dir/nodejs-upgrade.mdc"
  info "Cursor: installed to $dir/nodejs-upgrade.mdc"
}

install_windsurf() {
  local dir="$TARGET_DIR/.windsurf/rules"
  mkdir -p "$dir"
  cat > "$dir/nodejs-upgrade.md" << 'FRONTMATTER'
---
trigger: model_decision
description: "Node.js runtime upgrade — trigger when upgrading, migrating, or modernizing Node.js versions, fixing EOL warnings, or updating engines field"
---

FRONTMATTER
  strip_frontmatter >> "$dir/nodejs-upgrade.md"
  info "Windsurf: installed to $dir/nodejs-upgrade.md"
}

install_codex() {
  local file="$TARGET_DIR/AGENTS.md"
  if [ -f "$file" ]; then
    # Append to existing AGENTS.md
    echo "" >> "$file"
    echo "---" >> "$file"
    echo "" >> "$file"
    strip_frontmatter >> "$file"
    info "Codex: appended to $file"
  else
    strip_frontmatter > "$file"
    info "Codex: created $file"
  fi
}

install_gemini() {
  local file="$TARGET_DIR/GEMINI.md"
  if [ -f "$file" ]; then
    echo "" >> "$file"
    echo "---" >> "$file"
    echo "" >> "$file"
    strip_frontmatter >> "$file"
    info "Gemini: appended to $file"
  else
    strip_frontmatter > "$file"
    info "Gemini: created $file"
  fi
}

install_cline() {
  local dir="$TARGET_DIR/.clinerules"
  mkdir -p "$dir"
  strip_frontmatter > "$dir/nodejs-upgrade.md"
  info "Cline: installed to $dir/nodejs-upgrade.md"
}

install_aider() {
  local file="$TARGET_DIR/CONVENTIONS.md"
  if [ -f "$file" ]; then
    echo "" >> "$file"
    echo "---" >> "$file"
    echo "" >> "$file"
    strip_frontmatter >> "$file"
    warn "Aider: appended to $file — make sure .aider.conf.yml has 'read: CONVENTIONS.md'"
  else
    strip_frontmatter > "$file"
    warn "Aider: created $file — add 'read: CONVENTIONS.md' to .aider.conf.yml"
  fi
}

install_amazonq() {
  local dir="$TARGET_DIR/.amazonq/rules"
  mkdir -p "$dir"
  strip_frontmatter > "$dir/nodejs-upgrade.md"
  info "Amazon Q: installed to $dir/nodejs-upgrade.md"
}

# ── Agent detection ─────────────────────────────────────────────────

detect_agents() {
  local found=()
  [ -d "$TARGET_DIR/.claude" ] || [ -f "$TARGET_DIR/CLAUDE.md" ] && found+=(claude)
  [ -d "$TARGET_DIR/.github" ] && found+=(copilot)
  [ -d "$TARGET_DIR/.cursor" ] || [ -f "$TARGET_DIR/.cursorrules" ] && found+=(cursor)
  [ -d "$TARGET_DIR/.windsurf" ] || [ -f "$TARGET_DIR/.windsurfrules" ] && found+=(windsurf)
  [ -f "$TARGET_DIR/AGENTS.md" ] && found+=(codex)
  [ -f "$TARGET_DIR/GEMINI.md" ] || [ -d "$TARGET_DIR/.gemini" ] && found+=(gemini)
  [ -d "$TARGET_DIR/.clinerules" ] || [ -f "$TARGET_DIR/.clinerules" ] && found+=(cline)
  [ -f "$TARGET_DIR/.aider.conf.yml" ] && found+=(aider)
  [ -d "$TARGET_DIR/.amazonq" ] && found+=(amazonq)
  echo "${found[@]}"
}

install_agent() {
  case "$1" in
    claude)   install_claude ;;
    copilot)  install_copilot ;;
    cursor)   install_cursor ;;
    windsurf) install_windsurf ;;
    codex)    install_codex ;;
    gemini)   install_gemini ;;
    cline)    install_cline ;;
    aider)    install_aider ;;
    amazonq)  install_amazonq ;;
    *) warn "Unknown agent: $1" ;;
  esac
}

# ── Main ────────────────────────────────────────────────────────────

header "Node.js Upgrade Skill — Setup"
echo "Skill source: $SKILL_DIR"
echo "Target project: $(cd "$TARGET_DIR" && pwd)"
echo ""

ALL_AGENTS=(claude copilot cursor windsurf codex gemini cline aider amazonq)

if [ "${1:-}" = "--all" ]; then
  for agent in "${ALL_AGENTS[@]}"; do
    install_agent "$agent"
  done
  exit 0
fi

if [ "${1:-}" = "--agent" ] && [ -n "${2:-}" ]; then
  install_agent "$2"
  exit 0
fi

# Interactive mode
detected=($(detect_agents))
if [ ${#detected[@]} -gt 0 ]; then
  header "Detected agents in this project:"
  for a in "${detected[@]}"; do echo "  - $a"; done
  echo ""
fi

header "Available agents:"
for i in "${!ALL_AGENTS[@]}"; do
  echo "  $((i+1))) ${ALL_AGENTS[$i]}"
done
echo "  a) All agents"
echo "  q) Quit"
echo ""

read -rp "Install for which agent(s)? (comma-separated numbers, 'a' for all): " choice

if [ "$choice" = "q" ]; then
  exit 0
fi

if [ "$choice" = "a" ]; then
  for agent in "${ALL_AGENTS[@]}"; do
    install_agent "$agent"
  done
else
  IFS=',' read -ra selections <<< "$choice"
  for sel in "${selections[@]}"; do
    sel=$(echo "$sel" | tr -d ' ')
    idx=$((sel - 1))
    if [ "$idx" -ge 0 ] && [ "$idx" -lt ${#ALL_AGENTS[@]} ]; then
      install_agent "${ALL_AGENTS[$idx]}"
    else
      warn "Invalid selection: $sel"
    fi
  done
fi

echo ""
info "Done! The skill is ready to use."
echo "  Ask your agent: 'Upgrade this project to the latest Node.js LTS'"
