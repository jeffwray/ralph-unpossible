#!/usr/bin/env node
/**
 * Unpossible Observer - Browser-based monitoring for Unpossible autonomous agent
 * Usage: node server.js [unpossible args...]
 */

import http from 'http';
import fs from 'fs';
import path from 'path';
import { spawn, exec } from 'child_process';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Resolve paths based on whether running from npm package or directly
const PACKAGE_DIR = process.env.UNPOSSIBLE_HOME || path.resolve(__dirname, '..');
const PROJECT_DIR = process.cwd();
const SCRIPT_DIR = process.env.UNPOSSIBLE_HOME ? path.join(process.env.UNPOSSIBLE_HOME, 'lib') : PACKAGE_DIR;
const PORT = process.env.PORT || 3456;

const clients = new Set();
let unpossibleProcess = null;
let unpossibleState = {
  status: 'idle',
  iteration: 0,
  maxIterations: 10,
  currentStory: null,
  branch: null,
  startTime: null,
  output: []
};

function broadcast(event, data) {
  const message = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
  clients.forEach(client => client.write(message));
}

function parseOutput(text) {
  const iterMatch = text.match(/Unpossible Iteration (\d+) of (\d+)/);
  if (iterMatch) {
    unpossibleState.iteration = parseInt(iterMatch[1]);
    unpossibleState.maxIterations = parseInt(iterMatch[2]);
    unpossibleState.status = 'running';
    broadcast('state', unpossibleState);
  }

  const branchMatch = text.match(/Target branch: (.+)/);
  if (branchMatch) {
    unpossibleState.branch = branchMatch[1];
    broadcast('state', unpossibleState);
  }

  if (text.includes('Unpossible completed all tasks')) {
    unpossibleState.status = 'complete';
    broadcast('state', unpossibleState);
  }

  if (text.includes('reached max iterations')) {
    unpossibleState.status = 'max_iterations';
    broadcast('state', unpossibleState);
  }

  // Parse stream-json events from Claude
  const lines = text.split('\n');
  for (const line of lines) {
    if (!line.trim().startsWith('{')) continue;
    try {
      const event = JSON.parse(line);
      parseClaudeEvent(event);
    } catch (e) {
      // Not JSON, ignore
    }
  }
}

function parseClaudeEvent(event) {
  // Broadcast all events to frontend for detailed display
  broadcast('claude_event', event);

  // Handle different Claude stream-json event types for sidebar status
  if (event.type === 'assistant') {
    if (event.message?.content) {
      for (const block of event.message.content) {
        if (block.type === 'tool_use') {
          unpossibleState.currentAction = {
            type: 'tool',
            tool: block.name,
            input: block.input
          };
          broadcast('action', unpossibleState.currentAction);
        } else if (block.type === 'text') {
          unpossibleState.currentAction = {
            type: 'thinking',
            text: block.text?.substring(0, 200)
          };
          broadcast('action', unpossibleState.currentAction);
        }
      }
    }
  } else if (event.type === 'content_block_start') {
    if (event.content_block?.type === 'tool_use') {
      unpossibleState.currentAction = {
        type: 'tool_start',
        tool: event.content_block.name,
        id: event.content_block.id
      };
      broadcast('action', unpossibleState.currentAction);
    }
  } else if (event.type === 'result') {
    unpossibleState.currentAction = {
      type: 'tool_result',
      subtype: event.subtype,
      tool: event.tool,
      input: event.input,
      result: typeof event.result === 'string' ? event.result?.substring(0, 500) : event.result
    };
    broadcast('action', unpossibleState.currentAction);
  }
}

function startUnpossible(args) {
  if (unpossibleProcess) {
    broadcast('error', { message: 'Unpossible is already running' });
    return;
  }

  unpossibleState = {
    status: 'starting',
    iteration: 0,
    maxIterations: 10,
    currentStory: null,
    branch: null,
    startTime: new Date().toISOString(),
    output: []
  };

  broadcast('state', unpossibleState);

  const unpossibleScript = path.join(SCRIPT_DIR, 'unpossible.sh');
  unpossibleProcess = spawn('bash', [unpossibleScript, '--worker', ...args], {
    cwd: PROJECT_DIR,
    env: { ...process.env, FORCE_COLOR: '1', UNPOSSIBLE_HOME: PACKAGE_DIR }
  });

  unpossibleProcess.stdout.on('data', (data) => {
    const text = data.toString();
    unpossibleState.output.push({ type: 'stdout', text, time: new Date().toISOString() });
    parseOutput(text);
    broadcast('output', { type: 'stdout', text });
  });

  unpossibleProcess.stderr.on('data', (data) => {
    const text = data.toString();
    unpossibleState.output.push({ type: 'stderr', text, time: new Date().toISOString() });
    parseOutput(text);
    broadcast('output', { type: 'stderr', text });
  });

  unpossibleProcess.on('close', (code) => {
    unpossibleState.status = code === 0 ? 'complete' : 'error';
    unpossibleState.exitCode = code;
    broadcast('state', unpossibleState);
    broadcast('exit', { code });
    unpossibleProcess = null;
  });

  unpossibleProcess.on('error', (err) => {
    broadcast('error', { message: err.message });
    unpossibleProcess = null;
  });
}

function stopUnpossible() {
  if (unpossibleProcess) {
    unpossibleProcess.kill('SIGTERM');
    unpossibleState.status = 'stopped';
    broadcast('state', unpossibleState);
  }
}

async function getPRDInfo() {
  const prdFilesPath = path.join(PROJECT_DIR, '.prd-files');
  try {
    const content = fs.readFileSync(prdFilesPath, 'utf-8');
    const files = content.trim().split('\n').filter(Boolean);
    const prds = [];
    for (const file of files) {
      try {
        const prd = JSON.parse(fs.readFileSync(file, 'utf-8'));
        prds.push({ file: path.basename(file), ...prd });
      } catch (e) {}
    }
    return prds;
  } catch (e) {
    return [];
  }
}

function runDemo() {
  unpossibleState = {
    status: 'running',
    iteration: 0,
    maxIterations: 5,
    currentStory: 'P1-001',
    branch: 'unpossible/phase-1-foundation',
    startTime: new Date().toISOString(),
    output: []
  };
  broadcast('state', unpossibleState);

  const demoOutput = [
    '===============================================================',
    '  Unpossible Iteration 1 of 5 (claude)',
    '===============================================================',
    'Target branch: unpossible/phase-1-foundation',
    'Base branch: main',
    'PRD files: prds/01-foundation.json',
    '',
    'Reading patterns.txt...',
    'Reading progress.txt...',
    '',
    'Selected story: P1-001 - Initialize Next.js 14 project',
    'Priority: 1, Status: pending',
    '',
    '> Writing tests first (TDD)...',
    '> Creating test file: __tests__/setup.test.ts',
    '> Running tests... FAIL (expected)',
    '',
    '> Implementing feature...',
    '> npx create-next-app@latest . --typescript --tailwind --eslint',
    '> Installing shadcn/ui...',
    '',
    '> Running tests... PASS',
    '> Running typecheck... PASS',
    '> Running lint... PASS',
    '',
    '> Committing: feat: P1-001 - Initialize Next.js 14 project',
    '> Updating PRD: passes: true',
    '',
    'Iteration 1 complete. Continuing...',
  ];

  let i = 0;
  const interval = setInterval(() => {
    if (i >= demoOutput.length) {
      unpossibleState.iteration = 1;
      unpossibleState.status = 'complete';
      broadcast('state', unpossibleState);
      broadcast('exit', { code: 0 });
      clearInterval(interval);
      return;
    }
    const text = demoOutput[i] + '\n';
    unpossibleState.output.push({ type: 'stdout', text, time: new Date().toISOString() });
    parseOutput(text);
    broadcast('output', { type: 'stdout', text });
    i++;
  }, 300);
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);

  if (url.pathname === '/' || url.pathname === '/index.html') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(fs.readFileSync(path.join(__dirname, 'index.html')));
    return;
  }

  if (url.pathname === '/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*'
    });
    clients.add(res);
    res.write(`event: state\ndata: ${JSON.stringify(unpossibleState)}\n\n`);
    unpossibleState.output.forEach(out => {
      res.write(`event: output\ndata: ${JSON.stringify(out)}\n\n`);
    });
    req.on('close', () => clients.delete(res));
    return;
  }

  if (url.pathname === '/api/start' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const { args = [] } = JSON.parse(body || '{}');
        startUnpossible(args.filter(a => a !== '--worker'));
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  if (url.pathname === '/api/stop' && req.method === 'POST') {
    stopUnpossible();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true }));
    return;
  }

  if (url.pathname === '/api/state') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(unpossibleState));
    return;
  }

  if (url.pathname === '/api/prds') {
    const prds = await getPRDInfo();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(prds));
    return;
  }

  res.writeHead(404);
  res.end('Not Found');
});

function openBrowser(url) {
  const cmd = process.platform === 'darwin' ? 'open' :
              process.platform === 'win32' ? 'start' : 'xdg-open';
  exec(`${cmd} ${url}`);
}

server.listen(PORT, () => {
  const url = `http://localhost:${PORT}`;
  console.log(`Unpossible Observer running at ${url}`);

  const args = process.argv.slice(2);

  if (args.includes('--demo')) {
    console.log('Starting in demo mode...');
    setTimeout(runDemo, 1000);
    openBrowser(url);
    return;
  }

  if (args.length > 0) {
    console.log(`Starting Unpossible with args: ${args.join(' ')}`);
    setTimeout(() => startUnpossible(args), 500);
  }

  openBrowser(url);
});

process.on('SIGINT', () => {
  stopUnpossible();
  process.exit(0);
});
