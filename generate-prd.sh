#!/bin/bash
# Generate a PRD from a feature description using Claude
# Usage: ./generate-prd.sh "feature description" [output-name]
# Usage: ./generate-prd.sh path/to/spec.md [output-name]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "$1" ]]; then
  echo "Usage: ./generate-prd.sh \"feature description\" [output-name]"
  echo "       ./generate-prd.sh path/to/spec.md [output-name]"
  echo ""
  echo "Examples:"
  echo "  ./generate-prd.sh \"Add user authentication with OAuth\" auth"
  echo "  ./generate-prd.sh docs/dark-mode-spec.md dark-mode"
  exit 1
fi

INPUT="$1"
OUTPUT_NAME="${2:-feature}"

# Check if input is a file
if [[ -f "$INPUT" ]]; then
  SPEC_CONTENT=$(cat "$INPUT")
  PROMPT_TYPE="markdown spec file"
else
  SPEC_CONTENT="$INPUT"
  PROMPT_TYPE="feature description"
fi

# Create the prompt
PROMPT=$(cat << 'PROMPT_EOF'
You are helping create a PRD (Product Requirements Document) for an autonomous AI coding agent.

Read the example PRD format:

PROMPT_EOF
)

PROMPT+=$(cat "$SCRIPT_DIR/prd.json.example")

PROMPT+=$(cat << 'PROMPT_EOF'


Now create a PRD based on the following input. Guidelines:

1. **Break down into small stories**: Each story should be completable in ~15-30 minutes of AI work
2. **Specific acceptance criteria**: Each criterion should be testable and unambiguous
3. **Logical priority order**: Dependencies should have lower priority numbers (done first)
4. **Include technical notes**: Help the AI understand HOW to implement, not just WHAT
5. **Test strategy**: Describe what tests should verify the feature works

Format rules:
- Story IDs should be descriptive (e.g., AUTH-001, UI-001, API-001)
- Acceptance criteria should start with action verbs
- Priority 1 = most important/foundational, higher numbers = less critical
- Branch names should be descriptive: unpossible/feature-name

PROMPT_EOF
)

PROMPT+="

Input ($PROMPT_TYPE):

$SPEC_CONTENT

Generate a complete, well-structured PRD JSON file. Output ONLY the JSON, no markdown code blocks or explanations."

# Generate the PRD using Claude
echo "Generating PRD from $PROMPT_TYPE..."
echo ""

OUTPUT_FILE="$SCRIPT_DIR/prds/${OUTPUT_NAME}.json"

# Use Claude to generate
RESULT=$(echo "$PROMPT" | claude --print)

# Try to extract JSON if wrapped in code blocks
CLEAN_RESULT=$(echo "$RESULT" | sed -n '/^{/,/^}/p')
if [[ -z "$CLEAN_RESULT" ]]; then
  CLEAN_RESULT=$(echo "$RESULT" | sed -n '/```json/,/```/p' | sed '1d;$d')
fi
if [[ -z "$CLEAN_RESULT" ]]; then
  CLEAN_RESULT="$RESULT"
fi

# Validate JSON
if ! echo "$CLEAN_RESULT" | jq empty 2>/dev/null; then
  echo "Warning: Generated content may not be valid JSON"
  echo "Raw output:"
  echo "$RESULT"
  exit 1
fi

# Pretty print and save
echo "$CLEAN_RESULT" | jq '.' > "$OUTPUT_FILE"

echo "PRD generated successfully!"
echo ""
echo "File: $OUTPUT_FILE"
echo ""
echo "Stories created:"
jq -r '.userStories[] | "  [\(.id)] \(.title) (priority: \(.priority))"' "$OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "  1. Review and edit: $OUTPUT_FILE"
echo "  2. Run: ./unpossible.sh $OUTPUT_NAME"
