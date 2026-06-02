#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
AGENTS_DIR="$CLAUDE_DIR/agents"
COMMANDS_DIR="$CLAUDE_DIR/commands"
DESIGN_LINK="$CLAUDE_DIR/design"
TEMPLATES_LINK="$CLAUDE_DIR/templates"
NAMESPACE="torch"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}$1${NC}"; }
warn()  { echo -e "${YELLOW}$1${NC}"; }
error() { echo -e "${RED}$1${NC}" >&2; }

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Install or uninstall Claude Code extensions (agents + commands)."
    echo ""
    echo "Options:"
    echo "  --uninstall    Remove symlinks and clean up"
    echo "  --namespace NS Use custom namespace (default: torch)"
    echo "  --check        Verify installation status"
    echo "  -h, --help     Show this help"
}

check_prerequisites() {
    local missing=0

    if ! command -v claude &>/dev/null; then
        warn "Claude Code CLI not found — required for agents and commands to work"
        missing=1
    fi

    if ! command -v gh &>/dev/null; then
        warn "gh CLI not found — needed for PR commands (optional)"
    fi

    if ! command -v acli &>/dev/null; then
        warn "acli not found — needed for Jira workflows (optional)"
    fi

    return $missing
}

check_status() {
    echo -e "${BOLD}Installation status:${NC}"
    echo ""

    local agents_link="$AGENTS_DIR/$NAMESPACE"
    local commands_link="$COMMANDS_DIR/$NAMESPACE"

    if [[ -L "$agents_link" ]]; then
        local target
        target="$(readlink "$agents_link")"
        info "  Agents:   $agents_link -> $target"
    else
        warn "  Agents:   not installed"
    fi

    if [[ -L "$commands_link" ]]; then
        local target
        target="$(readlink "$commands_link")"
        info "  Commands: $commands_link -> $target"
    else
        warn "  Commands: not installed"
    fi

    if [[ -L "$DESIGN_LINK" ]]; then
        info "  Design:   $DESIGN_LINK -> $(readlink "$DESIGN_LINK")"
    else
        warn "  Design:   not installed"
    fi

    if [[ -L "$TEMPLATES_LINK" ]]; then
        info "  Templates: $TEMPLATES_LINK -> $(readlink "$TEMPLATES_LINK")"
    else
        warn "  Templates: not installed"
    fi

    echo ""

    if [[ -L "$agents_link" && -L "$commands_link" ]]; then
        local agent_count command_count
        agent_count=$(find -L "$agents_link" -maxdepth 1 -name '*.md' -not -name 'README*' 2>/dev/null | wc -l | tr -d ' ')
        command_count=$(find -L "$commands_link" -maxdepth 1 -name '*.md' -not -name 'README*' 2>/dev/null | wc -l | tr -d ' ')
        info "  $agent_count agents, $command_count commands available"
    fi
}

install() {
    echo -e "${BOLD}Installing Claude Code extensions...${NC}"
    echo ""

    if ! check_prerequisites; then
        echo ""
        error "Install Claude Code CLI first: https://docs.anthropic.com/en/docs/claude-code"
        exit 1
    fi

    mkdir -p "$AGENTS_DIR" "$COMMANDS_DIR"

    local agents_link="$AGENTS_DIR/$NAMESPACE"
    local commands_link="$COMMANDS_DIR/$NAMESPACE"

    if [[ -L "$agents_link" || -e "$agents_link" ]]; then
        warn "Replacing existing agents link: $agents_link"
        rm -f "$agents_link"
    fi

    if [[ -L "$commands_link" || -e "$commands_link" ]]; then
        warn "Replacing existing commands link: $commands_link"
        rm -f "$commands_link"
    fi

    ln -sf "$REPO_DIR/agents" "$agents_link"
    ln -sf "$REPO_DIR/commands" "$commands_link"

    # Design guidelines and HTML templates are shared (not namespaced) — skills
    # reference them as ~/.claude/design/* and ~/.claude/templates/*.
    if [[ -L "$DESIGN_LINK" || -e "$DESIGN_LINK" ]]; then
        warn "Replacing existing design link: $DESIGN_LINK"
        rm -f "$DESIGN_LINK"
    fi
    if [[ -L "$TEMPLATES_LINK" || -e "$TEMPLATES_LINK" ]]; then
        warn "Replacing existing templates link: $TEMPLATES_LINK"
        rm -f "$TEMPLATES_LINK"
    fi
    ln -sf "$REPO_DIR/design" "$DESIGN_LINK"
    ln -sf "$REPO_DIR/templates" "$TEMPLATES_LINK"

    echo ""
    info "Installed:"
    info "  Agents:    $agents_link -> $REPO_DIR/agents"
    info "  Commands:  $commands_link -> $REPO_DIR/commands"
    info "  Design:    $DESIGN_LINK -> $REPO_DIR/design"
    info "  Templates: $TEMPLATES_LINK -> $REPO_DIR/templates"
    echo ""

    local agent_count command_count
    agent_count=$(find "$REPO_DIR/agents" -name '*.md' -not -name 'README*' 2>/dev/null | wc -l | tr -d ' ')
    command_count=$(find "$REPO_DIR/commands" -name '*.md' -not -name 'README*' 2>/dev/null | wc -l | tr -d ' ')
    info "$agent_count agents and $command_count commands now available in Claude Code."
    echo ""
    echo "Agents are used automatically by Claude Code when relevant."
    echo "Commands available as /torch:<command> (e.g., /torch:pr, /torch:triage)."
}

uninstall() {
    echo -e "${BOLD}Uninstalling Claude Code extensions...${NC}"
    echo ""

    local agents_link="$AGENTS_DIR/$NAMESPACE"
    local commands_link="$COMMANDS_DIR/$NAMESPACE"
    local removed=0

    if [[ -L "$agents_link" ]]; then
        rm "$agents_link"
        info "Removed: $agents_link"
        removed=1
    fi

    if [[ -L "$commands_link" ]]; then
        rm "$commands_link"
        info "Removed: $commands_link"
        removed=1
    fi

    if [[ -L "$DESIGN_LINK" ]]; then
        rm "$DESIGN_LINK"
        info "Removed: $DESIGN_LINK"
        removed=1
    fi

    if [[ -L "$TEMPLATES_LINK" ]]; then
        rm "$TEMPLATES_LINK"
        info "Removed: $TEMPLATES_LINK"
        removed=1
    fi

    if [[ $removed -eq 0 ]]; then
        warn "Nothing to uninstall — no symlinks found for namespace '$NAMESPACE'"
    else
        echo ""
        info "Uninstalled. Agents and commands no longer available in Claude Code."
    fi
}

# Parse args
ACTION="install"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --uninstall) ACTION="uninstall"; shift ;;
        --check)     ACTION="check"; shift ;;
        --namespace) NAMESPACE="$2"; shift 2 ;;
        -h|--help)   usage; exit 0 ;;
        *)           error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

case "$ACTION" in
    install)   install ;;
    uninstall) uninstall ;;
    check)     check_status ;;
esac
