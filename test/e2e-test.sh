#!/bin/bash
# End-to-end test for Unpossible
# Usage: ./test/e2e-test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$SCRIPT_DIR/e2e-project"
OBSERVER_PORT=3457

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }

echo ""
echo -e "${CYAN}========================================"
echo "  Unpossible E2E Test"
echo -e "========================================${NC}"
echo ""

# Check prerequisites
command -v claude &> /dev/null || { echo -e "${RED}Error: claude CLI not found${NC}"; exit 1; }
command -v node &> /dev/null || { echo -e "${RED}Error: node not found${NC}"; exit 1; }
command -v jq &> /dev/null || { echo -e "${RED}Error: jq not found${NC}"; exit 1; }

# Cleanup
cleanup() {
  [[ -n "$OBSERVER_PID" ]] && kill $OBSERVER_PID 2>/dev/null
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# === Setup: Create test project and start Observer ===
echo -e "${CYAN}[Setup] Creating test project and starting Observer...${NC}"

rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR/scripts"
rsync -a --exclude='.git' --exclude='test' "$ROOT_DIR/" "$TEST_DIR/scripts/unpossible/"

cd "$TEST_DIR"
git init -q
git config user.email "test@test.com"
git config user.name "Test"

# Start Observer - it stays running throughout all tests
PORT=$OBSERVER_PORT node scripts/unpossible/observer/server.js &
OBSERVER_PID=$!
sleep 2

echo -e "${GREEN}Observer running at http://localhost:$OBSERVER_PORT${NC}"
echo ""

# === Test 1: Init ===
echo -e "${CYAN}[1/3] Testing --init...${NC}"

scripts/unpossible/unpossible.sh --init > /dev/null 2>&1
[[ -f "CLAUDE.md" ]] && pass "--init creates CLAUDE.md" || fail "--init creates CLAUDE.md"
[[ -d "scripts/unpossible/prds" ]] && pass "--init creates prds/" || fail "--init creates prds/"

# === Test 2: Claude executes simple task ===
echo ""
echo -e "${CYAN}[2/3] Testing Claude execution (simple task)...${NC}"

# Create minimal PRD
cat > scripts/unpossible/prds/test.json << 'EOF'
{
  "project": "Test",
  "branchName": "unpossible/test",
  "userStories": [{
    "id": "T-001",
    "title": "Create hello.txt",
    "priority": 1,
    "passes": false,
    "acceptanceCriteria": ["Create hello.txt with 'Hello from Unpossible!'"]
  }]
}
EOF

git add -A && git commit -q -m "Initial commit"

# Run Claude directly (faster than full unpossible loop for testing)
echo "Testing Claude can execute tasks..."
echo "Create a file called hello.txt containing 'Hello from Unpossible!' in the current directory" | claude --dangerously-skip-permissions > /dev/null 2>&1

[[ -f "hello.txt" ]] && pass "Claude created hello.txt" || fail "Claude created hello.txt"
grep -q "Hello from Unpossible" hello.txt 2>/dev/null && pass "hello.txt has correct content" || fail "hello.txt content"

# === Test 3: Full loop with Observer ===
echo ""
echo -e "${CYAN}[3/3] Testing full Unpossible loop (watch the Observer!)...${NC}"

rm -f hello.txt
git checkout . 2>/dev/null

# Create a fresh PRD
cat > scripts/unpossible/prds/loop-test.json << 'EOF'
{
  "project": "LoopTest",
  "branchName": "unpossible/loop-test",
  "userStories": [{
    "id": "L-001",
    "title": "Create goodbye.txt",
    "priority": 1,
    "passes": false,
    "acceptanceCriteria": ["Create goodbye.txt containing 'Goodbye!'"]
  }]
}
EOF

# Note: .prd-files is created automatically by unpossible.sh when it resolves PRD paths

git add -A && git commit -q -m "Add loop test PRD"

# Run via Observer API so it tracks and displays the progress
echo "Running unpossible loop (this may take 30-60 seconds)..."
echo -e "${YELLOW}Watch the Observer at http://localhost:$OBSERVER_PORT${NC}"

# Trigger run via Observer's API
curl -s -X POST "http://localhost:$OBSERVER_PORT/api/start" \
  -H "Content-Type: application/json" \
  -d '{"args": ["1", "loop-test"]}' > /dev/null

# Wait for completion (poll status)
echo "Waiting for completion..."
for attempt in $(seq 1 120); do
  STATUS=$(curl -s "http://localhost:$OBSERVER_PORT/api/state" | jq -r '.status' 2>/dev/null || echo "unknown")
  if [[ "$STATUS" == "complete" || "$STATUS" == "error" || "$STATUS" == "max_iterations" ]]; then
    break
  fi
  sleep 2
done

[[ -f "goodbye.txt" ]] && pass "Loop created goodbye.txt" || fail "Loop created goodbye.txt"

# Check if PRD was updated
PRD_PASSES=$(jq -r '.userStories[0].passes' scripts/unpossible/prds/loop-test.json 2>/dev/null)
[[ "$PRD_PASSES" == "true" ]] && pass "PRD marked as passing" || echo -e "${YELLOW}⚠${NC} PRD not marked (may need more iterations)"

# Summary
echo ""
echo -e "${CYAN}========================================"
echo -e "  Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo -e "========================================${NC}"

[[ $FAIL -gt 0 ]] && exit 1 || exit 0
