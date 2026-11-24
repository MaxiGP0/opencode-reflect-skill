#!/usr/bin/env bash
# Install the claude-reflect skill and commands for OpenCode.
#
# Copies the authored OpenCode port from this repository into an OpenCode
# config root. It never downloads the upstream Claude Code plugin and never
# edits AGENTS.md.

set -euo pipefail

CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
FORCE=0

usage() {
    cat <<EOF
Usage: install.sh [options]

Options:
  --config-dir PATH   OpenCode config root (default: ~/.config/opencode)
  --force             Replace the claude-reflect skill and its four commands
  -h, --help          Show this help

Environment:
  OPENCODE_CONFIG_DIR   Same as --config-dir
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config-dir)
            [[ $# -ge 2 ]] || { echo "Missing value for --config-dir" >&2; exit 1; }
            CONFIG_DIR="$2"
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

case "$CONFIG_DIR" in
    "~") CONFIG_DIR="$HOME" ;;
    "~/"*) CONFIG_DIR="$HOME/${CONFIG_DIR#"~/"}" ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SOURCE="$REPO_ROOT/skill/claude-reflect"
COMMANDS_SOURCE="$REPO_ROOT/commands"
COMMAND_NAMES=(
    "reflect.md"
    "reflect-skills.md"
    "skip-reflect.md"
    "view-queue.md"
)

REQUIRED_SOURCE=(
    "$SKILL_SOURCE/SKILL.md"
    "$SKILL_SOURCE/scripts/recent-sessions.mjs"
    "$REPO_ROOT/LICENSE"
    "$REPO_ROOT/NOTICE"
)
for name in "${COMMAND_NAMES[@]}"; do
    REQUIRED_SOURCE+=("$COMMANDS_SOURCE/$name")
done

for path in "${REQUIRED_SOURCE[@]}"; do
    if [[ ! -f "$path" ]]; then
        echo "Error: repository content is incomplete: missing $path" >&2
        exit 1
    fi
done

if ! grep -Eq "^name:[[:space:]]*claude-reflect[[:space:]]*$" "$SKILL_SOURCE/SKILL.md"; then
    echo "Error: skill/claude-reflect/SKILL.md does not declare 'name: claude-reflect'." >&2
    exit 1
fi
if ! grep -Eq "^description:[[:space:]]*[^[:space:]]" "$SKILL_SOURCE/SKILL.md"; then
    echo "Error: skill/claude-reflect/SKILL.md has no description, so OpenCode will not advertise it." >&2
    exit 1
fi

SKILLS_DIR="$CONFIG_DIR/skills"
SKILL_TARGET="$SKILLS_DIR/claude-reflect"
COMMANDS_TARGET="$CONFIG_DIR/commands"
QUEUE_PATH="$CONFIG_DIR/reflect-queue.json"

CONFLICTS=()
if [[ -e "$SKILL_TARGET" ]]; then
    CONFLICTS+=("$SKILL_TARGET")
fi
for name in "${COMMAND_NAMES[@]}"; do
    if [[ -e "$COMMANDS_TARGET/$name" ]]; then
        CONFLICTS+=("$COMMANDS_TARGET/$name")
    fi
done

if [[ ${#CONFLICTS[@]} -gt 0 && "$FORCE" -ne 1 ]]; then
    echo "!!  claude-reflect is already installed, or a target file already exists:" >&2
    for conflict in "${CONFLICTS[@]}"; do
        echo "    $conflict" >&2
    done
    echo "    Re-run with --force to replace the claude-reflect skill and its four commands." >&2
    echo "    Files outside skills/claude-reflect and the four named commands are never touched." >&2
    exit 1
fi

if [[ "$FORCE" -eq 1 && -e "$SKILL_TARGET" ]]; then
    echo "==> Removing the existing skill at $SKILL_TARGET"
    rm -rf -- "$SKILL_TARGET"
fi

echo "==> Installing the skill to $SKILL_TARGET"
mkdir -p -- "$SKILL_TARGET"
cp -- "$SKILL_SOURCE/SKILL.md" "$SKILL_TARGET/SKILL.md"
cp -R -- "$SKILL_SOURCE/scripts" "$SKILL_TARGET/scripts"
cp -- "$REPO_ROOT/LICENSE" "$SKILL_TARGET/LICENSE"
cp -- "$REPO_ROOT/NOTICE" "$SKILL_TARGET/NOTICE"

echo "==> Installing commands to $COMMANDS_TARGET"
mkdir -p -- "$COMMANDS_TARGET"
for name in "${COMMAND_NAMES[@]}"; do
    cp -- "$COMMANDS_SOURCE/$name" "$COMMANDS_TARGET/$name"
done

if [[ -f "$QUEUE_PATH" ]]; then
    echo "    Keeping the existing queue: $QUEUE_PATH"
else
    echo "==> Creating an empty queue at $QUEUE_PATH"
    printf '{\n  "version": 1,\n  "items": []\n}\n' > "$QUEUE_PATH"
fi

for path in \
    "$SKILL_TARGET/SKILL.md" \
    "$SKILL_TARGET/scripts/recent-sessions.mjs" \
    "$SKILL_TARGET/LICENSE" \
    "$SKILL_TARGET/NOTICE" \
    "$COMMANDS_TARGET/reflect.md" \
    "$COMMANDS_TARGET/reflect-skills.md" \
    "$COMMANDS_TARGET/skip-reflect.md" \
    "$COMMANDS_TARGET/view-queue.md"
do
    if [[ ! -f "$path" ]]; then
        echo "Error: installation is incomplete: missing $path" >&2
        exit 1
    fi
done

FILE_COUNT="$(find "$SKILL_TARGET" -type f | wc -l | tr -d ' ')"
echo "OK  Installed the claude-reflect skill ($FILE_COUNT files) and 4 commands."
cat <<EOF

Start a new OpenCode session, then:
  - say "remember: use pnpm, not npm" or correct the agent during work
  - run /view-queue to inspect the queue
  - run /reflect --dry-run to preview, then /reflect to apply

Learnings are written to a marked section of AGENTS.md.
Queue: $QUEUE_PATH
Upstream inspiration and license: https://github.com/BayramAnnakov/claude-reflect
EOF
