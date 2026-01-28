#!/bin/bash
# Unpossible - Long-running AI agent loop
# "Me fail English? That's unpossible!" — Ralph Wiggum
# Usage: ./unpossible.sh [--init] [--no-observe] [--tool amp|claude] [max_iterations] [prd1] [prd2] ...

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Display a random Ralph quote
show_quote() {
  if [[ -f "$SCRIPT_DIR/quotes.txt" ]]; then
    local quote
    quote=$(shuf -n 1 "$SCRIPT_DIR/quotes.txt" 2>/dev/null || sort -R "$SCRIPT_DIR/quotes.txt" | head -1)
    echo ""
    echo "  \"$quote\""
    echo "      — Ralph Wiggum"
    echo ""
  fi
}

# Initialize project function
init_project() {
  echo "Initializing Unpossible for project..."

  # Find project root
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  if [[ -z "$PROJECT_ROOT" ]]; then
    echo "Error: Not in a git repository"
    exit 1
  fi

  # Create root CLAUDE.md
  ROOT_CLAUDE="$PROJECT_ROOT/CLAUDE.md"
  if [[ ! -f "$ROOT_CLAUDE" ]]; then
    cat > "$ROOT_CLAUDE" << 'CLAUDE_EOF'
# Project Instructions

This project uses Unpossible, an autonomous AI agent for iterative development.

## For Claude Code

When running as part of Unpossible, follow the instructions in `scripts/unpossible/CLAUDE.md`.

Key files:
- `scripts/unpossible/CLAUDE.md` - Agent instructions
- `scripts/unpossible/.prd-files` - List of PRD files to process
- `scripts/unpossible/patterns.txt` - Codebase patterns (read first)
- `scripts/unpossible/progress.txt` - Run progress log

## Creating PRDs

When asked to create a PRD, read `scripts/unpossible/prd.json.example` for the format, then save the new PRD to `scripts/unpossible/prds/[feature-name].json`.

Guidelines:
- Break features into small stories (one iteration each)
- Use descriptive IDs (AUTH-001, UI-001, API-001)
- Priority 1 = done first, higher numbers = later
- Acceptance criteria should be specific and testable
- Add technicalNotes to guide implementation

## Development

- Follow TDD: Write tests FIRST, then implement
- Run quality checks before committing
- Keep changes focused and minimal
CLAUDE_EOF
    echo "Created: $ROOT_CLAUDE"
  else
    echo "Exists: $ROOT_CLAUDE"
  fi

  # Create patterns.txt
  if [[ ! -f "$SCRIPT_DIR/patterns.txt" ]]; then
    echo "# Codebase Patterns" > "$SCRIPT_DIR/patterns.txt"
    echo "# Add reusable patterns discovered during development" >> "$SCRIPT_DIR/patterns.txt"
    echo "" >> "$SCRIPT_DIR/patterns.txt"
    echo "Created: $SCRIPT_DIR/patterns.txt"
  else
    echo "Exists: $SCRIPT_DIR/patterns.txt"
  fi

  # Create prds directory
  if [[ ! -d "$SCRIPT_DIR/prds" ]]; then
    mkdir -p "$SCRIPT_DIR/prds"
    echo "Created: $SCRIPT_DIR/prds/"
  else
    echo "Exists: $SCRIPT_DIR/prds/"
  fi

  echo ""
  echo "Unpossible initialized. Next steps:"
  echo "  1. Add PRD files to prds/"
  echo "  2. Run: ./unpossible.sh [iterations] [prd-name]"
}

# Check for --init flag
if [[ "$1" == "--init" ]]; then
  init_project
  exit 0
fi

# Check for --no-observe flag
USE_OBSERVER=true
if [[ "$1" == "--no-observe" ]]; then
  USE_OBSERVER=false
  shift
elif [[ "$1" != "--worker" ]]; then
  if command -v node &> /dev/null; then
    exec node "$SCRIPT_DIR/observer/server.js" "$@"
  else
    echo "Warning: Node.js not found, running without observer"
  fi
fi

if [[ "$1" == "--worker" ]]; then
  shift
fi

# Parse arguments
TOOL="claude"
MAX_ITERATIONS=10
PRD_REFS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      else
        PRD_REFS+=("$1")
      fi
      shift
      ;;
  esac
done

# Resolve PRD reference to absolute path
resolve_prd() {
  local ref="$1"
  if [[ "$ref" == /* ]]; then
    echo "$ref"
  elif [[ "$ref" == */* ]] || [[ "$ref" == *.json ]]; then
    echo "$SCRIPT_DIR/$ref"
  else
    echo "$SCRIPT_DIR/prds/${ref}.json"
  fi
}

# Validate PRD file
validate_prd() {
  local prd_path="$1"
  if [[ ! -f "$prd_path" ]]; then
    echo "Error: PRD file not found: $prd_path" >&2
    return 1
  fi
  if ! jq empty "$prd_path" 2>/dev/null; then
    echo "Error: Invalid JSON: $prd_path" >&2
    return 1
  fi
  return 0
}

# Build PRD file list
PRD_FILES=()

if [[ ${#PRD_REFS[@]} -eq 0 ]]; then
  if [[ -f "$SCRIPT_DIR/prd.json" ]]; then
    PRD_FILES=("$SCRIPT_DIR/prd.json")
  else
    echo "Error: No PRD specified and no default prd.json found"
    echo "Usage: ./unpossible.sh [--tool amp|claude] [max_iterations] [prd1] [prd2] ..."
    exit 1
  fi
else
  for ref in "${PRD_REFS[@]}"; do
    resolved=$(resolve_prd "$ref")
    if validate_prd "$resolved"; then
      PRD_FILES+=("$resolved")
    else
      exit 1
    fi
  done
fi

# Write PRD file list for agent to read
printf '%s\n' "${PRD_FILES[@]}" > "$SCRIPT_DIR/.prd-files"

# Extract branch info from first PRD
BRANCH_NAME=$(jq -r '.branchName // empty' "${PRD_FILES[0]}" 2>/dev/null || echo "")
BASE_BRANCH=$(jq -r '.baseBranch // "main"' "${PRD_FILES[0]}" 2>/dev/null || echo "main")

show_quote

echo "Target branch: $BRANCH_NAME"
echo "Base branch: $BASE_BRANCH"
echo "PRD files: ${PRD_FILES[*]}"
echo "Max iterations: $MAX_ITERATIONS"
echo "Tool: $TOOL"
echo ""

# Progress and patterns files
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
PATTERNS_FILE="$SCRIPT_DIR/patterns.txt"

# Initialize patterns.txt if it doesn't exist
if [[ ! -f "$PATTERNS_FILE" ]]; then
  echo "# Codebase Patterns" > "$PATTERNS_FILE"
  echo "# Add reusable patterns discovered during development" >> "$PATTERNS_FILE"
  echo "" >> "$PATTERNS_FILE"
fi

# Ensure root CLAUDE.md exists (silent check, use --init for verbose setup)
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [[ -n "$PROJECT_ROOT" && ! -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
  echo "Run './unpossible.sh --init' first to set up project files"
  exit 1
fi

# Check for uncommitted changes before starting
if [[ -n "$PROJECT_ROOT" ]]; then
  cd "$PROJECT_ROOT"
  if [[ -n $(git status --porcelain) ]]; then
    echo ""
    echo "ERROR: Uncommitted changes detected!"
    echo ""
    git status --short
    echo ""
    echo "Please commit or stash your changes before running Unpossible."
    echo "This prevents losing work when switching branches."
    exit 1
  fi
  cd - > /dev/null
fi

# Main iteration loop
for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Unpossible Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  if [[ "$TOOL" == "amp" ]]; then
    OUTPUT=$(cat "$SCRIPT_DIR/prompt.md" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
  else
    # Run Claude with the CLAUDE.md as input, streaming JSON output for Observer
    TEMP_OUTPUT=$(mktemp)
    echo "$(cat "$SCRIPT_DIR/CLAUDE.md")" | claude --dangerously-skip-permissions --verbose --output-format stream-json 2>&1 | tee "$TEMP_OUTPUT" || true
    OUTPUT=$(cat "$TEMP_OUTPUT")
    rm -f "$TEMP_OUTPUT"
  fi

  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Unpossible completed all tasks at iteration $i!"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Unpossible reached max iterations ($MAX_ITERATIONS). Some tasks may be incomplete."
exit 1
