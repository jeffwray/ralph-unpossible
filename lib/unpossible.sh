#!/bin/bash
# Unpossible - Long-running AI agent loop
# "Me fail English? That's unpossible!" — Ralph Wiggum
# Usage: unpossible [--init] [--no-observe] [--tool amp|claude] [max_iterations] [prd1] [prd2] ...

set -e

# Resolve paths based on whether running from npm package or directly
if [ -n "$UNPOSSIBLE_HOME" ]; then
  # Running from npm package
  PACKAGE_DIR="$UNPOSSIBLE_HOME"
  SCRIPT_DIR="$UNPOSSIBLE_HOME/lib"
  OBSERVER_DIR="$UNPOSSIBLE_HOME/observer"
  QUOTES_FILE="$UNPOSSIBLE_HOME/lib/quotes.txt"
  TEMPLATES_DIR="$UNPOSSIBLE_HOME/templates"
else
  # Running directly from repo (for development)
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PACKAGE_DIR="$SCRIPT_DIR"
  OBSERVER_DIR="$SCRIPT_DIR/observer"
  QUOTES_FILE="$SCRIPT_DIR/quotes.txt"
  TEMPLATES_DIR="$SCRIPT_DIR/templates"

  # Check if we're in the lib/ subdirectory
  if [[ "$SCRIPT_DIR" == */lib ]]; then
    PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
    OBSERVER_DIR="$PACKAGE_DIR/observer"
    QUOTES_FILE="$SCRIPT_DIR/quotes.txt"
    TEMPLATES_DIR="$PACKAGE_DIR/templates"
  fi
fi

# Project-local files stay in current directory
PROJECT_DIR="$(pwd)"
PRDS_DIR="$PROJECT_DIR/prds"
PATTERNS_FILE="$PROJECT_DIR/patterns.txt"
PROGRESS_FILE="$PROJECT_DIR/progress.txt"
PRD_FILES_LIST="$PROJECT_DIR/.prd-files"
CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"

# Display a random Ralph quote
show_quote() {
  if [[ -f "$QUOTES_FILE" ]]; then
    local quote
    quote=$(shuf -n 1 "$QUOTES_FILE" 2>/dev/null || sort -R "$QUOTES_FILE" | head -1)
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

  # Create root CLAUDE.md from template or default
  ROOT_CLAUDE="$PROJECT_ROOT/CLAUDE.md"
  if [[ ! -f "$ROOT_CLAUDE" ]]; then
    if [[ -f "$TEMPLATES_DIR/CLAUDE.md" ]]; then
      cp "$TEMPLATES_DIR/CLAUDE.md" "$ROOT_CLAUDE"
    else
      cat > "$ROOT_CLAUDE" << 'CLAUDE_EOF'
# Project Instructions

This project uses Unpossible, an autonomous AI agent for iterative development.

## Creating PRDs

When asked to create a PRD, read `prds/example.json` for the format, then save new PRDs to `prds/[feature-name].json`.

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

## Running Unpossible

```bash
npx ralph-unpossible 5 my-feature
```
CLAUDE_EOF
    fi
    echo "Created: $ROOT_CLAUDE"
  else
    echo "Exists: $ROOT_CLAUDE"
  fi

  # Create patterns.txt from template or default
  PATTERNS="$PROJECT_ROOT/patterns.txt"
  if [[ ! -f "$PATTERNS" ]]; then
    if [[ -f "$TEMPLATES_DIR/patterns.txt" ]]; then
      cp "$TEMPLATES_DIR/patterns.txt" "$PATTERNS"
    else
      echo "# Codebase Patterns" > "$PATTERNS"
      echo "# Add reusable patterns discovered during development" >> "$PATTERNS"
      echo "" >> "$PATTERNS"
    fi
    echo "Created: $PATTERNS"
  else
    echo "Exists: $PATTERNS"
  fi

  # Create prds directory
  PRDS="$PROJECT_ROOT/prds"
  if [[ ! -d "$PRDS" ]]; then
    mkdir -p "$PRDS"
    echo "Created: $PRDS/"
  else
    echo "Exists: $PRDS/"
  fi

  # Copy example PRD
  EXAMPLE_PRD="$PRDS/example.json"
  if [[ ! -f "$EXAMPLE_PRD" ]]; then
    if [[ -f "$TEMPLATES_DIR/prd.json.example" ]]; then
      cp "$TEMPLATES_DIR/prd.json.example" "$EXAMPLE_PRD"
    fi
    echo "Created: $EXAMPLE_PRD"
  else
    echo "Exists: $EXAMPLE_PRD"
  fi

  echo ""
  echo "Unpossible initialized. Next steps:"
  echo "  1. Edit prds/example.json or ask Claude to create a PRD"
  echo "  2. Run: npx ralph-unpossible 5 example"
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
    exec node "$OBSERVER_DIR/server.js" "$@"
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
    echo "$PROJECT_DIR/$ref"
  else
    echo "$PRDS_DIR/${ref}.json"
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
  if [[ -f "$PROJECT_DIR/prd.json" ]]; then
    PRD_FILES=("$PROJECT_DIR/prd.json")
  else
    echo "Error: No PRD specified and no default prd.json found"
    echo "Usage: unpossible [--tool amp|claude] [max_iterations] [prd1] [prd2] ..."
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
printf '%s\n' "${PRD_FILES[@]}" > "$PRD_FILES_LIST"

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

# Initialize patterns.txt if it doesn't exist
if [[ ! -f "$PATTERNS_FILE" ]]; then
  echo "# Codebase Patterns" > "$PATTERNS_FILE"
  echo "# Add reusable patterns discovered during development" >> "$PATTERNS_FILE"
  echo "" >> "$PATTERNS_FILE"
fi

# Ensure CLAUDE.md exists
if [[ ! -f "$CLAUDE_MD" ]]; then
  echo "Run 'npx ralph-unpossible --init' first to set up project files"
  exit 1
fi

# Check for uncommitted changes before starting
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
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
    OUTPUT=$(cat "$CLAUDE_MD" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
  else
    # Run Claude with the CLAUDE.md as input, streaming JSON output for Observer
    TEMP_OUTPUT=$(mktemp)
    echo "$(cat "$CLAUDE_MD")" | claude --dangerously-skip-permissions --verbose --output-format stream-json 2>&1 | tee "$TEMP_OUTPUT" || true
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
