#!/usr/bin/env bash
# Check that the claude-reflect OpenCode port is installed correctly.

set -euo pipefail

CONFIG_DIR="${1:-${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}}"

case "$CONFIG_DIR" in
    "~") CONFIG_DIR="$HOME" ;;
    "~/"*) CONFIG_DIR="$HOME/${CONFIG_DIR#"~/"}" ;;
esac

SKILL_TARGET="$CONFIG_DIR/skills/claude-reflect"
COMMANDS_TARGET="$CONFIG_DIR/commands"
QUEUE_PATH="$CONFIG_DIR/reflect-queue.json"
COMMAND_NAMES=(
    "reflect.md"
    "reflect-skills.md"
    "skip-reflect.md"
    "view-queue.md"
)

fail() {
    echo "FAIL  $1" >&2
    exit 1
}

REQUIRED=("$SKILL_TARGET/SKILL.md")
for name in "${COMMAND_NAMES[@]}"; do
    REQUIRED+=("$COMMANDS_TARGET/$name")
done

MISSING=()
for path in "${REQUIRED[@]}"; do
    if [[ ! -f "$path" ]]; then
        MISSING+=("$path")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "FAIL  The installation is incomplete. Missing:" >&2
    for path in "${MISSING[@]}"; do
        echo "      - $path" >&2
    done
    echo "      Run install.sh first, or install.sh --force to repair." >&2
    exit 1
fi

SKILL_PATH="$SKILL_TARGET/SKILL.md"

if ! grep -Eq "^name:[[:space:]]*claude-reflect[[:space:]]*$" "$SKILL_PATH"; then
    fail "SKILL.md does not declare 'name: claude-reflect'."
fi
if ! grep -Eq "^description:[[:space:]]*[^[:space:]]" "$SKILL_PATH"; then
    fail "SKILL.md has no description, so OpenCode will not advertise the skill."
fi
for name in "${COMMAND_NAMES[@]}"; do
    if ! grep -Eq "^description:[[:space:]]*[^[:space:]]" "$COMMANDS_TARGET/$name"; then
        fail "$name has no 'description' frontmatter."
    fi
done

CHECK_FILES=("$SKILL_PATH")
for extra in \
    "$SKILL_TARGET/LICENSE" \
    "$SKILL_TARGET/NOTICE" \
    "$SKILL_TARGET/scripts/recent-sessions.mjs"
do
    if [[ -f "$extra" ]]; then
        CHECK_FILES+=("$extra")
    fi
done
for name in "${COMMAND_NAMES[@]}"; do
    CHECK_FILES+=("$COMMANDS_TARGET/$name")
done

for file in "${CHECK_FILES[@]}"; do
    for needle in "~/.claude" "CLAUDE.md" "hooks.json"; do
        if grep -Fiq -- "$needle" "$file"; then
            fail "Forbidden reference '$needle' found in $file"
        fi
    done
done

if ! grep -Fq "reflect-queue.json" "$SKILL_PATH"; then
    fail "SKILL.md does not document the queue path (reflect-queue.json)."
fi
if ! grep -Fq "reflect-queue.json" "$COMMANDS_TARGET/reflect.md"; then
    fail "commands/reflect.md does not document the queue path (reflect-queue.json)."
fi

for marker in "claude-reflect:start" "claude-reflect:end"; do
    if ! grep -Fq "$marker" "$SKILL_PATH"; then
        fail "SKILL.md does not document the AGENTS.md marker '$marker'."
    fi
    if ! grep -Fq "$marker" "$COMMANDS_TARGET/reflect.md"; then
        fail "commands/reflect.md does not document the AGENTS.md marker '$marker'."
    fi
done

if [[ -f "$QUEUE_PATH" ]]; then
    if ! grep -Fq '"version"' "$QUEUE_PATH" || ! grep -Fq '"items"' "$QUEUE_PATH"; then
        fail "The queue file does not match schema version 1: $QUEUE_PATH"
    fi
else
    echo "Note: no queue file yet at $QUEUE_PATH. Installer normally creates it."
fi

FILE_COUNT="$(find "$SKILL_TARGET" -type f | wc -l | tr -d ' ')"
echo "OK  claude-reflect is installed at $SKILL_TARGET ($FILE_COUNT skill files, 4 commands)."
echo "    Queue: $QUEUE_PATH"
echo "    AGENTS.md markers: <!-- claude-reflect:start --> / <!-- claude-reflect:end -->"
