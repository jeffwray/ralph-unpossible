# ralph-unpossible

> "Me fail English? That's unpossible!" — Ralph Wiggum

An autonomous AI agent loop for iterative, PRD-driven development. Spawns fresh AI coding instances to implement user stories one at a time until completion.

![Unpossible Observer](docs/observer-screenshot.png)

*The Unpossible Observer showing real-time AI activity as it autonomously implements user stories*

---

**Don't know who Ralph is?** You're missing out on one of television's greatest philosophical minds. Witness the moment that inspired this project's name:

[![Watch: "That's Unpossible!"](https://img.youtube.com/vi/JXFGy10b7Js/0.jpg)](https://www.youtube.com/watch?v=JXFGy10b7Js)

*Click to watch the 10-second clip that launched a thousand memes*

---

## Installation

### Option 1: Clone into your project

```bash
cd your-project
git clone https://github.com/jeffwray/ralph-unpossible.git scripts/unpossible
rm -rf scripts/unpossible/.git
```

### Option 2: Add as a git submodule

```bash
cd your-project
git submodule add https://github.com/jeffwray/ralph-unpossible.git scripts/unpossible
```

### Option 3: Download directly

```bash
cd your-project
mkdir -p scripts/unpossible
curl -L https://github.com/jeffwray/ralph-unpossible/archive/main.tar.gz | tar xz --strip-components=1 -C scripts/unpossible
```

## Setup

```bash
# Make the script executable
chmod +x scripts/unpossible/unpossible.sh

# Initialize (creates CLAUDE.md in project root, patterns.txt, prds/ folder)
./scripts/unpossible/unpossible.sh --init
```

This creates:
- `CLAUDE.md` in your project root (tells Claude about Unpossible)
- `scripts/unpossible/patterns.txt` for codebase patterns
- `scripts/unpossible/prds/` folder for your PRD files

## Creating PRDs

After running `--init`, Claude already knows the PRD format. Just ask:

```bash
claude "Create a PRD for user authentication with OAuth"
```

Or from an existing spec:

```bash
claude "Create a PRD from docs/my-feature.md"
```

Or with more detail:

```bash
claude "Create a PRD for:
- Dark mode toggle in settings
- Persist preference to localStorage
- Respect system preference by default
- All components support both themes"
```

Claude will automatically create the JSON file in `scripts/unpossible/prds/`.

## Running

```bash
# Run with default 10 iterations on a PRD
./scripts/unpossible/unpossible.sh my-feature

# Run with 50 iterations
./scripts/unpossible/unpossible.sh 50 my-feature

# Run multiple PRDs (stories are combined and prioritized)
./scripts/unpossible/unpossible.sh 30 auth dashboard settings

# Run without the web observer
./scripts/unpossible/unpossible.sh --no-observe 20 my-feature

# Use Amp instead of Claude
./scripts/unpossible/unpossible.sh --tool amp 20 my-feature
```

## How It Works

1. Define user stories in a PRD JSON file
2. Run `./unpossible.sh [iterations] [prd-name]`
3. Each iteration:
   - Picks the highest priority incomplete story
   - Writes tests first (TDD)
   - Implements the feature
   - Runs quality checks
   - Commits on success
   - Updates progress
4. Repeats until all stories pass or max iterations reached

## PRD Format

```json
{
  "project": "MyProject",
  "branchName": "unpossible/feature-name",
  "baseBranch": "main",
  "description": "High-level description of this PRD's goals",
  "userStories": [
    {
      "id": "US-001",
      "title": "Add user authentication",
      "priority": 1,
      "passes": false,
      "acceptanceCriteria": [
        "Users can sign up with email and password",
        "Users can log in with existing credentials",
        "Sessions persist across page refreshes",
        "Invalid credentials show appropriate error messages"
      ],
      "technicalNotes": "Use NextAuth.js with credentials provider",
      "testStrategy": "Integration tests for auth flow, unit tests for validation"
    }
  ]
}
```

### PRD Fields

| Field | Required | Description |
|-------|----------|-------------|
| `project` | Yes | Project name |
| `branchName` | Yes | Git branch to create/use |
| `baseBranch` | No | Branch to create from (default: main) |
| `description` | No | High-level PRD description |
| `userStories` | Yes | Array of user stories |

### User Story Fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique story ID (e.g., US-001, AUTH-01) |
| `title` | Yes | Short descriptive title |
| `priority` | Yes | Number (1 = highest priority) |
| `passes` | Yes | Boolean - set to `false` initially |
| `acceptanceCriteria` | Yes | Array of specific, testable criteria |
| `technicalNotes` | No | Implementation hints for the agent |
| `testStrategy` | No | How this story should be tested |
| `progress` | No | Filled in by agent when complete |

## Features

- **PRD-Driven**: Define work as structured user stories with acceptance criteria
- **TDD Enforced**: Write tests first, then implement
- **Branch Management**: Auto-creates feature branches, supports branch inheritance
- **Three-Level Progress**: Global patterns, run progress, and story-level tracking
- **Web Observer**: Real-time browser UI to monitor agent progress
- **Multi-PRD Support**: Work across multiple PRD files simultaneously
- **Tool Agnostic**: Works with Claude Code or Amp

## Observer UI

The web observer launches automatically at `http://localhost:3456` and provides:
- Real-time terminal output
- Current iteration progress
- Story status tracking
- Tool usage visualization

Run without observer: `./unpossible.sh --no-observe [args]`

## Files

| File | Purpose |
|------|---------|
| `unpossible.sh` | Main runner script |
| `CLAUDE.md` | Agent instructions |
| `patterns.txt` | Persistent codebase patterns |
| `quotes.txt` | Ralph Wiggum quotes (displayed on startup) |
| `progress.txt` | Per-run progress log (created during runs) |
| `prds/` | PRD files directory |
| `observer/` | Web UI for monitoring |

## Tips

### Writing Good PRDs

1. **Small stories**: Each story should be completable in one iteration
2. **Specific criteria**: Acceptance criteria should be testable
3. **Priority matters**: Lower number = higher priority = done first
4. **Technical hints**: Add `technicalNotes` to guide implementation
5. **One concern per story**: Don't mix unrelated changes

### Chaining PRDs

Use `baseBranch` to build features incrementally:

```json
// prds/01-foundation.json
{ "branchName": "unpossible/foundation", "baseBranch": "main" }

// prds/02-auth.json
{ "branchName": "unpossible/auth", "baseBranch": "unpossible/foundation" }

// prds/03-dashboard.json
{ "branchName": "unpossible/dashboard", "baseBranch": "unpossible/auth" }
```

Then run in order:
```bash
./unpossible.sh 20 01-foundation
./unpossible.sh 30 02-auth
./unpossible.sh 40 03-dashboard
```

## Testing

### Unit Tests

Run the test suite (no API calls):

```bash
./test/run-tests.sh
```

Tests verify (47 tests):
- Quote file and random selection
- PRD example structure and validation
- CLAUDE.md instructions
- Shell script structure
- Observer server setup
- Full PRD workflow (create, validate, mark complete)

### End-to-End Test

Run a real loop with Claude (uses API credits):

```bash
./test/e2e-test.sh
```

This test:
1. Creates a temporary project
2. Initializes Unpossible
3. Creates a simple PRD (create a text file)
4. Runs one iteration with Claude
5. Verifies the task was completed

## Hat Tip

Inspired by [snarktank/ralph](https://github.com/snarktank/ralph) and the Ralph pattern for autonomous AI development loops.

## License

MIT

---

<p align="center">
<img src="https://upload.wikimedia.org/wikipedia/en/thumb/a/aa/TheSimpsons-Ralph_Wiggum.png/220px-TheSimpsons-Ralph_Wiggum.png" width="80" alt="Definitely Not Ralph">
</p>

<p align="center"><sub>
<b>DISCLAIMER:</b> All characters, quotes, color schemes, and references in this project are entirely coincidental and bear absolutely no resemblance to any animated television series that may or may not have been on the air since 1989. The yellow color palette was chosen because it pairs well with terminal backgrounds. Any similarity to residents of a certain nuclear-powered town in an unspecified state is purely a statistical anomaly. The phrase "That's unpossible" is a completely original grammatical innovation. We have never heard of "The Simpsons" and if we had, our lawyers would like to remind you that parody is protected speech. Me fail copyright? That's unpossible!
<br><br>
<b>META DISCLAIMER:</b> This entire project—including the totally original yellow color scheme, this disclaimer, and everything else—was built autonomously by the AI agent technology contained herein. The AI made all creative decisions independently. No human told it to use these specific colors or make these specific references. If you have concerns about any aspect of this project, please direct them to the AI by opening a GitHub issue or submitting a pull request. Good luck.
</sub></p>
