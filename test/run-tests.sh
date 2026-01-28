#!/bin/bash
# Test suite for Unpossible
# Usage: ./test/run-tests.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_TMP="$SCRIPT_DIR/tmp"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test helpers
setup() {
  rm -rf "$TEST_TMP"
  mkdir -p "$TEST_TMP"
}

teardown() {
  rm -rf "$TEST_TMP"
}

pass() {
  echo -e "${GREEN}✓${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  echo "  Expected: $2"
  echo "  Got: $3"
  FAIL=$((FAIL + 1))
}

assert_file_exists() {
  if [[ -f "$1" ]]; then
    pass "$2"
  else
    fail "$2" "file exists" "file not found: $1"
  fi
}

assert_file_contains() {
  if grep -q "$2" "$1" 2>/dev/null; then
    pass "$3"
  else
    fail "$3" "file contains '$2'" "pattern not found in $1"
  fi
}

assert_equals() {
  if [[ "$1" == "$2" ]]; then
    pass "$3"
  else
    fail "$3" "$2" "$1"
  fi
}

assert_not_empty() {
  if [[ -n "$1" ]]; then
    pass "$2"
  else
    fail "$2" "non-empty value" "empty"
  fi
}

assert_exit_code() {
  if [[ "$1" -eq "$2" ]]; then
    pass "$3"
  else
    fail "$3" "exit code $2" "exit code $1"
  fi
}

# ============================================
# Tests
# ============================================

echo ""
echo "========================================"
echo "  Unpossible Test Suite"
echo "========================================"
echo ""

# --- quotes.txt tests ---
echo "--- quotes.txt ---"

test_quotes_file_exists() {
  assert_file_exists "$ROOT_DIR/quotes.txt" "quotes.txt exists"
}

test_quotes_not_empty() {
  local count=$(wc -l < "$ROOT_DIR/quotes.txt" | tr -d ' ')
  if [[ "$count" -gt 10 ]]; then
    pass "quotes.txt has $count quotes"
  else
    fail "quotes.txt has enough quotes" ">10 quotes" "$count quotes"
  fi
}

test_quotes_random() {
  # Get 5 random quotes and check they're not all the same
  local q1=$(shuf -n 1 "$ROOT_DIR/quotes.txt" 2>/dev/null || sort -R "$ROOT_DIR/quotes.txt" | head -1)
  local q2=$(shuf -n 1 "$ROOT_DIR/quotes.txt" 2>/dev/null || sort -R "$ROOT_DIR/quotes.txt" | head -1)
  local q3=$(shuf -n 1 "$ROOT_DIR/quotes.txt" 2>/dev/null || sort -R "$ROOT_DIR/quotes.txt" | head -1)

  # At least one should be different (statistically almost certain with 25 quotes)
  if [[ "$q1" != "$q2" ]] || [[ "$q2" != "$q3" ]]; then
    pass "random quote selection works"
  else
    fail "random quote selection" "different quotes" "all same: $q1"
  fi
}

test_quotes_file_exists
test_quotes_not_empty
test_quotes_random

# --- prd.json.example tests ---
echo ""
echo "--- prd.json.example ---"

test_example_valid_json() {
  if jq empty "$ROOT_DIR/prd.json.example" 2>/dev/null; then
    pass "prd.json.example is valid JSON"
  else
    fail "prd.json.example valid JSON" "valid JSON" "invalid JSON"
  fi
}

test_example_has_required_fields() {
  local has_project=$(jq -r '.project' "$ROOT_DIR/prd.json.example")
  local has_branch=$(jq -r '.branchName' "$ROOT_DIR/prd.json.example")
  local has_stories=$(jq -r '.userStories | length' "$ROOT_DIR/prd.json.example")

  assert_not_empty "$has_project" "example has project field"
  assert_not_empty "$has_branch" "example has branchName field"

  if [[ "$has_stories" -gt 0 ]]; then
    pass "example has userStories array"
  else
    fail "example has userStories" ">0 stories" "$has_stories"
  fi
}

test_example_story_structure() {
  local story=$(jq '.userStories[0]' "$ROOT_DIR/prd.json.example")
  local has_id=$(echo "$story" | jq -r '.id')
  local has_title=$(echo "$story" | jq -r '.title')
  local has_priority=$(echo "$story" | jq -r '.priority')
  local has_passes=$(echo "$story" | jq -r '.passes')
  local has_criteria=$(echo "$story" | jq -r '.acceptanceCriteria | length')

  assert_not_empty "$has_id" "story has id"
  assert_not_empty "$has_title" "story has title"
  assert_not_empty "$has_priority" "story has priority"
  assert_equals "$has_passes" "false" "story passes is false"

  if [[ "$has_criteria" -gt 0 ]]; then
    pass "story has acceptanceCriteria"
  else
    fail "story has acceptanceCriteria" ">0 criteria" "$has_criteria"
  fi
}

test_example_valid_json
test_example_has_required_fields
test_example_story_structure

# --- PRD validation tests ---
echo ""
echo "--- PRD validation ---"

test_valid_prd_accepted() {
  setup
  cat > "$TEST_TMP/valid.json" << 'EOF'
{
  "project": "Test",
  "branchName": "test/branch",
  "userStories": [
    {"id": "T-001", "title": "Test", "priority": 1, "passes": false, "acceptanceCriteria": ["test"]}
  ]
}
EOF

  if jq empty "$TEST_TMP/valid.json" 2>/dev/null; then
    pass "valid PRD accepted"
  else
    fail "valid PRD accepted" "valid" "invalid"
  fi
  teardown
}

test_invalid_json_rejected() {
  setup
  echo "{ invalid json }" > "$TEST_TMP/invalid.json"

  if ! jq empty "$TEST_TMP/invalid.json" 2>/dev/null; then
    pass "invalid JSON rejected"
  else
    fail "invalid JSON rejected" "rejected" "accepted"
  fi
  teardown
}

test_valid_prd_accepted
test_invalid_json_rejected

# --- CLAUDE.md tests ---
echo ""
echo "--- CLAUDE.md ---"

test_claude_md_exists() {
  assert_file_exists "$ROOT_DIR/CLAUDE.md" "CLAUDE.md exists"
}

test_claude_md_has_prd_instructions() {
  assert_file_contains "$ROOT_DIR/CLAUDE.md" "Creating PRDs" "CLAUDE.md has PRD creation section"
  assert_file_contains "$ROOT_DIR/CLAUDE.md" "prd.json.example" "CLAUDE.md references example file"
}

test_claude_md_has_tdd_instructions() {
  assert_file_contains "$ROOT_DIR/CLAUDE.md" "TDD" "CLAUDE.md has TDD section"
  assert_file_contains "$ROOT_DIR/CLAUDE.md" "Write tests FIRST" "CLAUDE.md emphasizes tests first"
}

test_claude_md_exists
test_claude_md_has_prd_instructions
test_claude_md_has_tdd_instructions

# --- unpossible.sh tests ---
echo ""
echo "--- unpossible.sh ---"

test_script_executable() {
  if [[ -x "$ROOT_DIR/unpossible.sh" ]]; then
    pass "unpossible.sh is executable"
  else
    fail "unpossible.sh executable" "executable" "not executable"
  fi
}

test_script_has_shebang() {
  local first_line=$(head -1 "$ROOT_DIR/unpossible.sh")
  assert_equals "$first_line" "#!/bin/bash" "unpossible.sh has bash shebang"
}

test_script_has_quote_function() {
  assert_file_contains "$ROOT_DIR/unpossible.sh" "show_quote" "unpossible.sh has show_quote function"
}

test_script_executable
test_script_has_shebang
test_script_has_quote_function

# --- observer tests ---
echo ""
echo "--- observer ---"

test_observer_server_exists() {
  assert_file_exists "$ROOT_DIR/observer/server.js" "observer/server.js exists"
}

test_observer_html_exists() {
  assert_file_exists "$ROOT_DIR/observer/index.html" "observer/index.html exists"
}

test_observer_package_json() {
  assert_file_exists "$ROOT_DIR/observer/package.json" "observer/package.json exists"

  local type=$(jq -r '.type' "$ROOT_DIR/observer/package.json")
  assert_equals "$type" "module" "observer uses ES modules"
}

test_observer_has_sse_endpoint() {
  assert_file_contains "$ROOT_DIR/observer/server.js" "/events" "observer has SSE /events endpoint"
  assert_file_contains "$ROOT_DIR/observer/server.js" "text/event-stream" "observer sends event-stream content type"
}

test_observer_server_exists
test_observer_html_exists
test_observer_package_json
test_observer_has_sse_endpoint

# --- Integration test ---
echo ""
echo "--- Integration ---"

test_init_creates_files() {
  setup
  cd "$TEST_TMP"
  git init -q

  # Run --init
  "$ROOT_DIR/unpossible.sh" --init > /dev/null 2>&1 || true

  assert_file_exists "$TEST_TMP/CLAUDE.md" "--init creates root CLAUDE.md"

  cd - > /dev/null
  teardown
}

test_init_creates_files

# --- Full workflow test ---
echo ""
echo "--- Full Workflow ---"

test_create_example_prd() {
  setup

  # Create a test PRD
  mkdir -p "$TEST_TMP/prds"
  cat > "$TEST_TMP/prds/test-feature.json" << 'EOF'
{
  "project": "TestProject",
  "branchName": "unpossible/test-feature",
  "baseBranch": "main",
  "description": "Test PRD for validation",
  "userStories": [
    {
      "id": "TEST-001",
      "title": "Add hello world endpoint",
      "priority": 1,
      "passes": false,
      "acceptanceCriteria": [
        "GET /api/hello returns 200",
        "Response body contains greeting message",
        "Endpoint is documented"
      ],
      "technicalNotes": "Use Next.js API routes",
      "testStrategy": "Integration test with supertest",
      "progress": {
        "completedAt": null,
        "filesChanged": [],
        "summary": "",
        "learnings": ""
      }
    },
    {
      "id": "TEST-002",
      "title": "Add personalized greeting",
      "priority": 2,
      "passes": false,
      "acceptanceCriteria": [
        "GET /api/hello?name=John returns personalized greeting",
        "Missing name parameter uses default greeting",
        "Name is sanitized for XSS"
      ],
      "technicalNotes": "Build on TEST-001",
      "testStrategy": "Unit tests for sanitization, integration for endpoint",
      "progress": {
        "completedAt": null,
        "filesChanged": [],
        "summary": "",
        "learnings": ""
      }
    }
  ]
}
EOF

  # Validate the created PRD
  if jq empty "$TEST_TMP/prds/test-feature.json" 2>/dev/null; then
    pass "created test PRD is valid JSON"
  else
    fail "created test PRD valid" "valid JSON" "invalid JSON"
  fi

  teardown
}

test_prd_has_all_required_fields() {
  setup

  mkdir -p "$TEST_TMP/prds"
  cat > "$TEST_TMP/prds/test-feature.json" << 'EOF'
{
  "project": "TestProject",
  "branchName": "unpossible/test-feature",
  "baseBranch": "main",
  "description": "Test PRD for validation",
  "userStories": [
    {
      "id": "TEST-001",
      "title": "Add hello world endpoint",
      "priority": 1,
      "passes": false,
      "acceptanceCriteria": ["GET /api/hello returns 200"],
      "technicalNotes": "Use Next.js API routes",
      "testStrategy": "Integration test"
    }
  ]
}
EOF

  local prd="$TEST_TMP/prds/test-feature.json"

  # Check top-level fields
  local project=$(jq -r '.project' "$prd")
  local branch=$(jq -r '.branchName' "$prd")
  local base=$(jq -r '.baseBranch' "$prd")
  local desc=$(jq -r '.description' "$prd")

  assert_equals "$project" "TestProject" "PRD has project name"
  assert_equals "$branch" "unpossible/test-feature" "PRD has branch name"
  assert_equals "$base" "main" "PRD has base branch"
  assert_not_empty "$desc" "PRD has description"

  teardown
}

test_prd_stories_structure() {
  setup

  mkdir -p "$TEST_TMP/prds"
  cat > "$TEST_TMP/prds/test-feature.json" << 'EOF'
{
  "project": "TestProject",
  "branchName": "unpossible/test-feature",
  "userStories": [
    {
      "id": "TEST-001",
      "title": "First story",
      "priority": 1,
      "passes": false,
      "acceptanceCriteria": ["Criterion 1", "Criterion 2"],
      "technicalNotes": "Some notes",
      "testStrategy": "Some strategy"
    },
    {
      "id": "TEST-002",
      "title": "Second story",
      "priority": 2,
      "passes": false,
      "acceptanceCriteria": ["Criterion A"]
    }
  ]
}
EOF

  local prd="$TEST_TMP/prds/test-feature.json"

  # Check story count
  local count=$(jq '.userStories | length' "$prd")
  assert_equals "$count" "2" "PRD has 2 stories"

  # Check first story
  local s1_id=$(jq -r '.userStories[0].id' "$prd")
  local s1_priority=$(jq -r '.userStories[0].priority' "$prd")
  local s1_passes=$(jq -r '.userStories[0].passes' "$prd")
  local s1_criteria=$(jq '.userStories[0].acceptanceCriteria | length' "$prd")

  assert_equals "$s1_id" "TEST-001" "first story has correct ID"
  assert_equals "$s1_priority" "1" "first story has priority 1"
  assert_equals "$s1_passes" "false" "first story passes is false"
  assert_equals "$s1_criteria" "2" "first story has 2 criteria"

  # Check second story
  local s2_id=$(jq -r '.userStories[1].id' "$prd")
  local s2_priority=$(jq -r '.userStories[1].priority' "$prd")

  assert_equals "$s2_id" "TEST-002" "second story has correct ID"
  assert_equals "$s2_priority" "2" "second story has priority 2"

  teardown
}

test_prd_priority_ordering() {
  setup

  mkdir -p "$TEST_TMP/prds"
  cat > "$TEST_TMP/prds/test-feature.json" << 'EOF'
{
  "project": "TestProject",
  "branchName": "unpossible/test",
  "userStories": [
    {"id": "C", "title": "Third", "priority": 3, "passes": false, "acceptanceCriteria": ["x"]},
    {"id": "A", "title": "First", "priority": 1, "passes": false, "acceptanceCriteria": ["x"]},
    {"id": "B", "title": "Second", "priority": 2, "passes": false, "acceptanceCriteria": ["x"]}
  ]
}
EOF

  local prd="$TEST_TMP/prds/test-feature.json"

  # Get highest priority (lowest number) story
  local first=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | .[0].id' "$prd")
  assert_equals "$first" "A" "highest priority story selected first"

  teardown
}

test_prd_mark_complete() {
  setup

  mkdir -p "$TEST_TMP/prds"
  cat > "$TEST_TMP/prds/test-feature.json" << 'EOF'
{
  "project": "TestProject",
  "branchName": "unpossible/test",
  "userStories": [
    {"id": "A", "title": "First", "priority": 1, "passes": false, "acceptanceCriteria": ["x"]},
    {"id": "B", "title": "Second", "priority": 2, "passes": false, "acceptanceCriteria": ["x"]}
  ]
}
EOF

  local prd="$TEST_TMP/prds/test-feature.json"

  # Simulate marking first story complete
  jq '.userStories[0].passes = true | .userStories[0].progress = {"completedAt": "2025-01-28T12:00:00Z", "summary": "Done"}' "$prd" > "$TEST_TMP/updated.json"
  mv "$TEST_TMP/updated.json" "$prd"

  # Verify update
  local a_passes=$(jq -r '.userStories[0].passes' "$prd")
  local a_completed=$(jq -r '.userStories[0].progress.completedAt' "$prd")

  assert_equals "$a_passes" "true" "story A marked as passing"
  assert_not_empty "$a_completed" "story A has completedAt timestamp"

  # Verify next story is B
  local next=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | .[0].id' "$prd")
  assert_equals "$next" "B" "next incomplete story is B"

  teardown
}

test_prd_all_complete_detection() {
  setup

  mkdir -p "$TEST_TMP/prds"
  cat > "$TEST_TMP/prds/test-feature.json" << 'EOF'
{
  "project": "TestProject",
  "branchName": "unpossible/test",
  "userStories": [
    {"id": "A", "title": "First", "priority": 1, "passes": true, "acceptanceCriteria": ["x"]},
    {"id": "B", "title": "Second", "priority": 2, "passes": true, "acceptanceCriteria": ["x"]}
  ]
}
EOF

  local prd="$TEST_TMP/prds/test-feature.json"

  # Check if all stories pass
  local incomplete=$(jq '[.userStories[] | select(.passes == false)] | length' "$prd")

  if [[ "$incomplete" -eq 0 ]]; then
    pass "all stories complete detected"
  else
    fail "all stories complete" "0 incomplete" "$incomplete incomplete"
  fi

  teardown
}

test_script_shows_quote_on_run() {
  setup
  cd "$TEST_TMP"
  git init -q

  # Copy unpossible to simulate installation
  mkdir -p scripts
  cp -r "$ROOT_DIR" scripts/unpossible

  # Run init
  scripts/unpossible/unpossible.sh --init > /dev/null 2>&1 || true

  # Create a test PRD in the right place
  cat > scripts/unpossible/prds/test.json << 'EOF'
{"project":"T","branchName":"t/t","userStories":[{"id":"T","title":"T","priority":1,"passes":false,"acceptanceCriteria":["x"]}]}
EOF

  # Run and capture output (will fail since no claude, but should show quote)
  local output=$(scripts/unpossible/unpossible.sh --no-observe 1 test 2>&1 || true)

  if echo "$output" | grep -q "Ralph Wiggum"; then
    pass "script shows Ralph quote on startup"
  else
    fail "script shows quote" "contains 'Ralph Wiggum'" "quote not found in: $output"
  fi

  cd - > /dev/null
  teardown
}

test_create_example_prd
test_prd_has_all_required_fields
test_prd_stories_structure
test_prd_priority_ordering
test_prd_mark_complete
test_prd_all_complete_detection
test_script_shows_quote_on_run

# ============================================
# Summary
# ============================================

echo ""
echo "========================================"
TOTAL=$((PASS + FAIL))
echo -e "  Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC} ($TOTAL total)"
echo "========================================"
echo ""

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
