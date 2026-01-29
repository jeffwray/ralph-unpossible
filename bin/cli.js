#!/usr/bin/env node
/**
 * Unpossible CLI - Entry point for npx ralph-unpossible
 * Usage:
 *   npx ralph-unpossible --init          # Initialize project
 *   npx ralph-unpossible 5 my-feature    # Run 5 iterations
 */

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { copyFileSync, mkdirSync, existsSync, writeFileSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const packageRoot = join(__dirname, '..');

// Handle --init flag
if (process.argv.includes('--init')) {
  const cwd = process.cwd();

  console.log('Initializing Unpossible for your project...\n');

  // Check if we're in a git repo
  try {
    const { execSync } = await import('child_process');
    execSync('git rev-parse --show-toplevel', { stdio: 'ignore' });
  } catch {
    console.error('Error: Not in a git repository.');
    console.error('Please run this command from within a git repository.');
    process.exit(1);
  }

  // Copy CLAUDE.md to project root
  const claudeMdDest = join(cwd, 'CLAUDE.md');
  if (!existsSync(claudeMdDest)) {
    copyFileSync(
      join(packageRoot, 'templates', 'CLAUDE.md'),
      claudeMdDest
    );
    console.log('  Created: CLAUDE.md');
  } else {
    console.log('  Exists:  CLAUDE.md');
  }

  // Create prds/ directory
  const prdsDir = join(cwd, 'prds');
  mkdirSync(prdsDir, { recursive: true });
  console.log('  Created: prds/');

  // Copy prd.json.example
  const prdExampleDest = join(prdsDir, 'example.json');
  if (!existsSync(prdExampleDest)) {
    copyFileSync(
      join(packageRoot, 'templates', 'prd.json.example'),
      prdExampleDest
    );
    console.log('  Created: prds/example.json');
  } else {
    console.log('  Exists:  prds/example.json');
  }

  // Create patterns.txt if doesn't exist
  const patternsFile = join(cwd, 'patterns.txt');
  if (!existsSync(patternsFile)) {
    copyFileSync(
      join(packageRoot, 'templates', 'patterns.txt'),
      patternsFile
    );
    console.log('  Created: patterns.txt');
  } else {
    console.log('  Exists:  patterns.txt');
  }

  console.log('\nUnpossible initialized! Next steps:');
  console.log('  1. Edit prds/example.json or ask Claude to create a PRD');
  console.log('  2. Run: npx ralph-unpossible 5 example');
  console.log('');
  console.log('Or ask Claude to create a PRD:');
  console.log('  claude "Create a PRD for user authentication"');

  process.exit(0);
}

// Handle --help flag
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  console.log(`
ralph-unpossible - Autonomous AI coding agent

Usage:
  npx ralph-unpossible --init              Initialize project with templates
  npx ralph-unpossible [iterations] [prd]  Run the agent

Options:
  --init         Set up Unpossible in current project
  --no-observe   Run without the web observer UI
  --tool <name>  Use alternative tool (amp|claude)
  --help, -h     Show this help message

Examples:
  npx ralph-unpossible --init          # One-time setup
  npx ralph-unpossible 5 auth          # 5 iterations on auth PRD
  npx ralph-unpossible 20 auth ui api  # 20 iterations on multiple PRDs
  npx ralph-unpossible --no-observe 10 my-feature

Documentation: https://github.com/BIGDEALIO/ralph-unpossible
`);
  process.exit(0);
}

// Run unpossible.sh with UNPOSSIBLE_HOME set
const script = join(packageRoot, 'lib', 'unpossible.sh');
const child = spawn('bash', [script, ...process.argv.slice(2)], {
  stdio: 'inherit',
  env: { ...process.env, UNPOSSIBLE_HOME: packageRoot }
});

child.on('exit', (code) => process.exit(code ?? 0));
child.on('error', (err) => {
  console.error('Failed to start Unpossible:', err.message);
  process.exit(1);
});
