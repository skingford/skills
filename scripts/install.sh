#!/bin/bash
# Interactive skill installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/skingford/skills/main/scripts/install.sh | bash
#   bash scripts/install.sh
#
# Non-interactive:
#   SKILLS_NONINTERACTIVE=1 bash scripts/install.sh

set -e

REPO="skingford/skills"

# ── Colors ────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
CYAN='\033[36m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

# ── TTY ───────────────────────────────────────────────────────────
if [ -t 0 ]; then
  TTY_IN=/dev/stdin
elif [ -e /dev/tty ]; then
  TTY_IN=/dev/tty
else
  TTY_IN=""
fi

prompt_input() {
  local var="$1" prompt="$2" default="$3"
  if [ -n "$TTY_IN" ]; then
    printf "%b" "$prompt" > /dev/tty
    read -r "$var" < "$TTY_IN"
  fi
  eval ": \"\${$var:=$default}\""
}

# ── Data ──────────────────────────────────────────────────────────
SKILLS=(
  "go-pro|Go best practices — project structure, error handling, concurrency"
  "api-design|RESTful & gRPC API design — naming, versioning, errors"
  "prompt-engineer|Prompt engineering — system prompts, few-shot, CoT"
  "mcp-ops|MCP server development — tool design, resources"
  "git-workflow|Git conventions — branch naming, commits, PRs"
  "git-clean-main|Keep AI files on dev, exclude from main/master"
  "project-bootstrap|Portable skills — auto-restore on new machine"
)

AGENTS=(
  "claude-code|Claude Code"
  "codex|Codex (OpenAI)"
  "cursor|Cursor"
  "windsurf|Windsurf"
  "github-copilot|GitHub Copilot"
)

# ── Banner ────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}"
cat << 'EOF'
  ____  _    _ _ _
 / ___|| | _(_) | |___
 \___ \| |/ / | | / __|
  ___) |   <| | | \__ \
 |____/|_|\_\_|_|_|___/
EOF
echo -e "${RESET}"
echo -e "  ${DIM}github.com/$REPO${RESET}"
echo ""

# ── Check npx ─────────────────────────────────────────────────────
if ! command -v npx &>/dev/null; then
  echo -e "${RED}Error: npx not found. Install Node.js first: https://nodejs.org${RESET}"
  exit 1
fi

# ── Non-interactive fallback ──────────────────────────────────────
if [ -n "${SKILLS_NONINTERACTIVE:-}" ] || [ -z "$TTY_IN" ]; then
  echo -e "${DIM}Non-interactive mode: installing all skills globally${RESET}"
  npx skills add "$REPO" --skill '*' -g -y
  echo -e "\n${GREEN}${BOLD}Done!${RESET}"
  exit 0
fi

# ── Step 1: Select agents ────────────────────────────────────────
echo -e "${BOLD}Available agents:${RESET}"
echo ""
for i in "${!AGENTS[@]}"; do
  IFS='|' read -r id label <<< "${AGENTS[$i]}"
  printf "  ${CYAN}%d${RESET}) %s ${DIM}(%s)${RESET}\n" "$((i + 1))" "$label" "$id"
done
echo ""
echo -e "  ${CYAN}*${RESET}) All agents (40+)"
echo ""
prompt_input agent_input "  ${BOLD}Select agents (e.g. 1,2 or *): ${RESET}" "1"
echo ""

# Parse agent selection
agent_args=()
if [ "$agent_input" = "*" ]; then
  agent_args=("*")
else
  IFS=',' read -ra picks <<< "$agent_input"
  for pick in "${picks[@]}"; do
    pick=$(echo "$pick" | tr -d ' ')
    idx=$((pick - 1))
    if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#AGENTS[@]}" ]; then
      IFS='|' read -r id _ <<< "${AGENTS[$idx]}"
      agent_args+=("$id")
    fi
  done
fi

if [ ${#agent_args[@]} -eq 0 ]; then
  echo -e "${YELLOW}No valid agents selected. Exiting.${RESET}"
  exit 0
fi

# ── Step 2: Select skills ────────────────────────────────────────
echo -e "${BOLD}Available skills:${RESET}"
echo ""
for i in "${!SKILLS[@]}"; do
  IFS='|' read -r id desc <<< "${SKILLS[$i]}"
  printf "  ${CYAN}%d${RESET}) ${BOLD}%s${RESET} — %s\n" "$((i + 1))" "$id" "$desc"
done
echo ""
echo -e "  ${CYAN}*${RESET}) All skills"
echo ""
prompt_input skill_input "  ${BOLD}Select skills (e.g. 1,3,5 or *): ${RESET}" "*"
echo ""

# Parse skill selection
skill_names=()
all_skills=false
if [ "$skill_input" = "*" ]; then
  all_skills=true
else
  IFS=',' read -ra picks <<< "$skill_input"
  for pick in "${picks[@]}"; do
    pick=$(echo "$pick" | tr -d ' ')
    idx=$((pick - 1))
    if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#SKILLS[@]}" ]; then
      IFS='|' read -r id _ <<< "${SKILLS[$idx]}"
      skill_names+=("$id")
    fi
  done
fi

if ! $all_skills && [ ${#skill_names[@]} -eq 0 ]; then
  echo -e "${YELLOW}No valid skills selected. Exiting.${RESET}"
  exit 0
fi

# ── Step 3: Scope ─────────────────────────────────────────────────
prompt_input scope_input "  ${BOLD}Install globally? [Y/n]: ${RESET}" "y"
scope_flag=""
if [[ "$scope_input" =~ ^[Yy]$ ]] || [ -z "$scope_input" ]; then
  scope_flag="-g"
fi
echo ""

# ── Summary ───────────────────────────────────────────────────────
echo -e "${BOLD}─────────────────────────────────────${RESET}"
if [ "${agent_args[0]}" = "*" ]; then
  echo -e "  Agents: ${CYAN}all${RESET}"
else
  echo -e "  Agents: ${CYAN}${agent_args[*]}${RESET}"
fi
if $all_skills; then
  echo -e "  Skills: ${CYAN}all${RESET}"
else
  echo -e "  Skills: ${CYAN}${skill_names[*]}${RESET}"
fi
echo -e "  Scope:  ${CYAN}$([ -n "$scope_flag" ] && echo "global" || echo "project")${RESET}"
echo -e "${BOLD}─────────────────────────────────────${RESET}"
echo ""

# ── Build agent flag ──────────────────────────────────────────────
agent_flag=""
if [ "${agent_args[0]}" = "*" ]; then
  agent_flag="--agent '*'"
else
  agent_flag="--agent ${agent_args[*]}"
fi

# ── Execute ───────────────────────────────────────────────────────
run_install() {
  local skill="$1"
  local cmd="npx skills add $REPO --skill $skill $scope_flag -y $agent_flag"
  echo -e "  ${DIM}> $cmd${RESET}"
  if eval "$cmd"; then
    echo -e "  ${GREEN}✓${RESET} $skill"
  else
    echo -e "  ${RED}✗${RESET} $skill (failed)"
  fi
}

if $all_skills; then
  run_install "'*'"
else
  for skill in "${skill_names[@]}"; do
    run_install "$skill"
  done
fi

echo ""
echo -e "${GREEN}${BOLD}Done!${RESET} Run ${DIM}npx skills list${RESET} to verify."
