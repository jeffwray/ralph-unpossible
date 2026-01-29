# Unpossible Agent Instructions

You are an autonomous coding agent working on a software project.

## Creating PRDs

When asked to create a PRD, read `prds/example.json` for the format, then save the new PRD to `prds/[feature-name].json`.

Guidelines:
- Break features into small stories (completable in ~15-30 min of AI work)
- Use descriptive IDs (AUTH-001, UI-001, API-001, DB-001)
- Priority 1 = most important/foundational (done first)
- Acceptance criteria must be specific and testable
- Add technicalNotes to guide implementation approach
- Include testStrategy to define how to verify the story

---

## Autonomous Mode Instructions

When running in autonomous mode (via `npx ralph-unpossible`), follow these instructions:

## Pre-Flight Check

**BEFORE doing anything else, run `git status` to check for uncommitted changes.**

If there are ANY uncommitted changes (staged or unstaged):
1. **DO NOT proceed** with branch switching or any other work
2. Report the uncommitted files to the user
3. End your response with: `<promise>UNCOMMITTED_CHANGES</promise>`

This prevents losing work when switching branches. Only proceed if the working directory is clean.

## Your Task

1. Read the PRD file list from `.prd-files` (one path per line)
2. Load ALL PRD files and combine their `userStories` arrays
3. Read `patterns.txt` first (global codebase patterns)
4. Read `progress.txt` for current run context
5. **Branch Setup**:
   - **FIRST: Check for uncommitted changes** with `git status`
   - If there are uncommitted changes, **STOP and report the issue** - do not switch branches
   - Get `branchName` and `baseBranch` from first PRD
   - If `baseBranch` is set, create/checkout `branchName` from `baseBranch`
   - If no `baseBranch`, create/checkout `branchName` from `main`
6. Pick the **highest priority** user story (across ALL PRDs) where `passes: false`
7. Implement that single user story
8. Run quality checks (e.g., typecheck, lint, test - use whatever your project requires)
9. If checks pass, commit ALL changes with message: `feat: [Story ID] - [Story Title]`
10. **Update progress at all three levels** (see below)

## Test-Driven Development (TDD)

**You MUST follow TDD for all implementation work:**

1. **Write tests FIRST** - Before writing any implementation code, write failing tests that define the expected behavior
2. **Run tests to confirm they fail** - Verify tests fail for the right reason (not syntax errors)
3. **Write minimal implementation** - Write just enough code to make tests pass
4. **Refactor** - Clean up code while keeping tests green
5. **Commit** - Tests and implementation together

### TDD Workflow Per Story

```
1. Read story acceptance criteria
2. Write test file(s) that verify each criterion
3. Run tests - confirm they FAIL
4. Implement the feature
5. Run tests - confirm they PASS
6. Refactor if needed
7. Run full test suite
8. Commit with tests included
```

### Test Requirements

- **API routes**: Test request/response, error cases, auth
- **Database functions**: Test CRUD operations, edge cases
- **UI components**: Test rendering, interactions, states
- **Utility functions**: Test inputs/outputs, edge cases
- **No implementation without tests** - If you can't test it, don't build it

### Test Commands

```bash
npm run test          # Run all tests
npm run test:watch    # Watch mode during development
npm run test:coverage # Coverage report
```

## Three-Level Progress System

### 1. Global Patterns (`patterns.txt`)
**Persists forever, never archived.** Contains reusable codebase patterns.

When you discover a pattern future iterations should know:
```
## Patterns
- Use `sql<number>` template for aggregations
- Always use `IF NOT EXISTS` for migrations
- Export types from actions.ts for UI components
```

Only add **general, reusable** patterns - not story-specific details.

### 2. Shared Progress (`progress.txt`)
**Per-run log, archived when branch changes.** Contains run-specific progress.

APPEND to progress.txt after each story:
```
## [Date/Time] - [Story ID]
- What was implemented
- Key decisions made
- Blockers or issues encountered
---
```

### 3. PRD-Level Progress (in PRD JSON)
**Story-specific, travels with the PRD.** Update the story's `progress` field.

When completing a story, update the **source PRD file**:
```json
{
  "id": "US-001",
  "passes": true,
  "progress": {
    "completedAt": "2024-01-28T10:30:00Z",
    "filesChanged": ["src/auth.ts", "prisma/schema.prisma"],
    "summary": "Added auth middleware with session validation",
    "learnings": "Used existing session pattern from utils"
  }
}
```

## Branch Inheritance

The PRD can specify where to branch from:

```json
{
  "branchName": "unpossible/phase2",
  "baseBranch": "unpossible/phase1"
}
```

- If `baseBranch` exists: `git checkout -b branchName baseBranch`
- If no `baseBranch`: `git checkout -b branchName main`
- If `branchName` already exists: just checkout and continue

## Forbidden Actions

**NEVER execute these commands or actions:**

- `terraform apply`, `terraform destroy`, or any Terraform commands that modify infrastructure
- `pulumi up`, `pulumi destroy`, or any Pulumi commands
- `aws` CLI commands that create, modify, or delete resources
- `kubectl apply`, `kubectl delete`, or commands that modify Kubernetes clusters
- Any IaC (Infrastructure as Code) execution commands
- Database migrations against production databases
- Deployment scripts (`infra-apply.sh`, etc.)

**You MAY:**
- Create/edit Terraform, Pulumi, or IaC configuration files
- Create deployment scripts (but not run them)
- Run `terraform fmt`, `terraform validate` for syntax checking
- Run local Docker commands (`docker-compose up`, etc.)
- Run database migrations against LOCAL development databases only

When working on IaC stories, your job is to **write the code**, not execute it. Infrastructure provisioning is done manually by humans.

## Quality Requirements

- ALL commits must pass your project's quality checks (typecheck, lint, test)
- ALL commits must include tests for new functionality
- Do NOT commit broken code
- Do NOT commit code without corresponding tests
- Keep changes focused and minimal
- Follow existing code patterns

## Stop Condition

After completing a user story, check if ALL stories (across ALL PRD files) have `passes: true`.

If ALL stories are complete and passing, reply with:
<promise>COMPLETE</promise>

If there are still stories with `passes: false`, end your response normally (another iteration will pick up the next story).

## Important

- Work on ONE story per iteration
- Commit frequently
- Keep CI green
- Read `patterns.txt` before starting each iteration
