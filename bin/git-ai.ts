#!/usr/bin/env bun
// git ai - AI-assisted Conventional Commit (Bun + TypeScript).
//
// Generates type/scope/subject/body from the staged diff, then drives the
// repo's *configured* commitizen adapter (cz-conventional-changelog,
// cz-customizable, commitlint's cz, …) with those values prefilled, so you
// press enter through (or edit), then commits. pre-commit still runs.
//
// If the repo has no commitizen installed, it falls back to assembling the
// message itself and opening `git commit -e` with it prefilled in the editor.
//
// Backend is required — a filter that reads the prompt on stdin and prints the
// completion on stdout (no default; aborts if unset):
//   git config --global cz-ai.cmd "cn -p"                      (Continue CLI)
//   git config --global cz-ai.cmd "ollama run qwen2.5-coder:7b"
// Show the model's reasoning live (thinking models):
//   git config --global cz-ai.stream true
// Also dump the raw model output above the parsed suggestion:
//   git config --global cz-ai.verbose true
//
// Alias: [alias] ai = "!~/src/shell-config/bin/git-ai.ts"

import {execSync, spawn, spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

type AiDefaults = {type: string; scope: string; subject: string; body: string};

const gitConfig = (key: string): string => {
  const r = spawnSync('git', ['config', '--get', key], {encoding: 'utf8'});
  return r.status === 0 ? r.stdout.trim() : '';
};

const repoRoot = execSync('git rev-parse --show-toplevel', {encoding: 'utf8'}).trim();
const requireFromRepo = createRequire(path.join(repoRoot, 'node_modules', 'index.js'));

// --- commitizen adapter resolution -----------------------------------------
// commitizen is optional. When present, we drive the repo's *configured*
// adapter (not just cz-conventional-changelog) and prefill the AI's values by
// patching each prompt question's `default`. When absent, main() falls back to
// a plain `git commit -e` with the assembled message. We load the adapter's own
// package entry (not its engine), so it sets its own widths/types — which also
// sidesteps the old "max NaN chars" subject-prompt bug we had to work around.

const readJson = (file: string): {[k: string]: unknown} | null => {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return null;
  }
};

// Where a repo declares its commitizen adapter: package.json
// config.commitizen.path, or a JSON .czrc / .cz.json with a `path`. Empty when
// unconfigured — we then try cz-conventional-changelog by default.
const adapterPathFromConfig = (): string => {
  const pkg = readJson(path.join(repoRoot, 'package.json')) as
    | {config?: {commitizen?: {path?: unknown}}}
    | null;
  if (typeof pkg?.config?.commitizen?.path === 'string') return pkg.config.commitizen.path;
  for (const f of ['.czrc', '.cz.json']) {
    const cfg = readJson(path.join(repoRoot, f)) as {path?: unknown} | null;
    if (typeof cfg?.path === 'string') return cfg.path;
  }
  return '';
};

type Prompter = (cz: unknown, commit: (m: string) => void) => void;

// Resolve and load the adapter's prompter plus the inquirer it expects, both
// from the repo's node_modules. Returns null if no commitizen stack is present.
const loadCommitizen = (): {prompter: Prompter; inquirer: unknown} | null => {
  let inquirer: unknown;
  try {
    inquirer = requireFromRepo('inquirer');
  } catch {
    return null;
  }
  const configured = adapterPathFromConfig();
  const candidates = configured ? [configured] : ['cz-conventional-changelog'];
  for (const id of candidates) {
    // Try as a bare module name, then as a repo-relative path (covers a
    // configured "./node_modules/cz-customizable" or a local adapter file).
    for (const spec of [id, path.resolve(repoRoot, id)]) {
      try {
        const mod = requireFromRepo(spec) as {
          prompter?: Prompter;
          default?: {prompter?: Prompter};
        };
        const prompter = mod?.prompter ?? mod?.default?.prompter;
        if (typeof prompter === 'function') return {prompter, inquirer};
      } catch {
        // not here — try the next candidate/spec
      }
    }
  }
  return null;
};

// Wrap inquirer so the adapter's questions get our AI values as their defaults.
// We never assume a fixed field set: we intercept the questions array the
// adapter passes to .prompt() and patch by question `name`, so custom adapters
// (cz-customizable scopes/types, etc.) prefill too wherever names line up.
const aiInquirer = (inquirer: unknown, ai: AiDefaults): unknown => {
  const defaults: {[name: string]: string} = {
    type: ai.type,
    scope: ai.scope,
    subject: ai.subject,
    body: ai.body,
  };
  return new Proxy(inquirer as object, {
    get(target, prop, recv) {
      if (prop !== 'prompt') return Reflect.get(target, prop, recv);
      return (questions: Array<{name?: string; default?: unknown}>, ...rest: unknown[]) => {
        for (const q of questions ?? []) {
          const v = q?.name ? defaults[q.name] : '';
          if (v) q.default = v;
        }
        return (target as {prompt: (...a: unknown[]) => unknown}).prompt(questions, ...rest);
      };
    },
  });
};

const parseDefaults = (raw: string): AiDefaults => {
  const out: AiDefaults = {type: '', scope: '', subject: '', body: ''};
  const start = raw.indexOf('{');
  const end = raw.lastIndexOf('}');
  if (start === -1 || end === -1) return out;
  try {
    Object.assign(out, JSON.parse(raw.slice(start, end + 1)));
  } catch {
    process.stderr.write('(could not parse AI output; falling back to empty defaults)\n');
  }
  return out;
};

// Minimal ANSI styling — each helper no-ops when stderr isn't a TTY (piped,
// redirected, CI), so we never leak escape codes into captured output.
const sgr = (code: string) => (s: string) => (process.stderr.isTTY ? `\x1b[${code}m${s}\x1b[0m` : s);
const dim = sgr('2');
const bold = sgr('1');
const cyan = sgr('36');
const green = sgr('32');
const magenta = sgr('35');

// Show the AI's parsed choices before the prompter opens, so it's clear what
// the defaults you're about to enter-through actually are. Writes to stderr to
// stay clear of anything that might consume stdout. With verbose on, also dumps
// the raw model output that produced these choices.
const printDecision = (ai: AiDefaults, opts: {verbose: boolean; raw: string}): void => {
  if (opts.verbose) {
    process.stderr.write(dim('\n── raw AI output ──────────────────\n'));
    process.stderr.write(dim(opts.raw.trim() + '\n'));
    process.stderr.write(dim('───────────────────────────────────\n'));
  }
  const scope = ai.scope ? cyan(`(${ai.scope})`) : '';
  const header = `${green(ai.type || '?')}${scope}: ${bold(ai.subject || '(no subject)')}`;
  process.stderr.write(`\n${magenta('AI suggests:')} ${header}\n`);
  if (ai.body) process.stderr.write(`${dim('  body:')} ${ai.body}\n`);
  process.stderr.write('\n');
};

const startSpinner = (label: string, stream: boolean): ((done: string) => void) => {
  if (stream || !process.stderr.isTTY) {
    process.stderr.write(label + '\n');
    return () => {};
  }
  const frames = ['-', '\\', '|', '/'];
  let i = 0;
  const t = setInterval(() => {
    process.stderr.write(`\r${frames[i++ % frames.length]} ${label}`);
  }, 90);
  return (done: string) => {
    clearInterval(t);
    // \x1b[K erases from the cursor to end of line, so a shorter "done" message
    // doesn't leave the tail of the longer spinner line behind.
    process.stderr.write(`\r\x1b[K${done}\n`);
  };
};

const buildPrompt = (diff: string): string =>
  [
    'Generate a Conventional Commit message for the staged git diff below.',
    'Respond with ONLY minified JSON, no prose and no code fences:',
    '{"type":"feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert",' +
      '"scope":"<short area>","subject":"<imperative, <=80 chars, no trailing period>",' +
      '"body":"<optional longer explanation, or empty>"}',
    '',
    'For "scope": pick a short lowercase area/module name derived from the changed' +
      ' files (a directory, package, or feature, e.g. "auth" or "parser"). Only use' +
      ' "" if the change is genuinely repo-wide with no single area.',
    '',
    'Diff:',
    diff,
  ].join('\n');

const runAi = (aiCmd: string, stream: boolean, prompt: string): Promise<string> =>
  new Promise(resolve => {
    const stop = startSpinner('Generating commit message...', stream);
    const child = spawn('/bin/sh', ['-c', aiCmd], {stdio: ['pipe', 'pipe', 'inherit']});
    let out = '';
    child.stdout.on('data', chunk => {
      out += chunk;
      if (stream) process.stderr.write(chunk); // show thinking/output live
    });
    child.on('error', () => {
      stop('[ai failed] using empty defaults');
      resolve('');
    });
    child.on('close', () => {
      stop('Commit message ready.');
      resolve(out);
    });
    child.stdin.write(prompt);
    child.stdin.end();
  });

// Write `message` to a temp file and commit it (pre-commit hooks still run).
// With `edit`, git opens the editor on the message first (the no-commitizen
// path, so you still get a review/edit step). Returns git's exit status.
const writeCommit = (message: string, edit = false): number => {
  const msgFile = path.join(os.tmpdir(), `git-ai-msg-${process.pid}.txt`);
  fs.writeFileSync(msgFile, message);
  const args = ['commit', ...(edit ? ['-e'] : []), '-F', msgFile];
  const r = spawnSync('git', args, {stdio: 'inherit'});
  fs.unlinkSync(msgFile);
  return r.status ?? 0;
};

// Assemble a Conventional-Commit-formatted message from the AI's parsed fields,
// for the no-commitizen path. Falls back to a bare subject if no type was given.
const assembleMessage = (ai: AiDefaults): string => {
  const scope = ai.scope ? `(${ai.scope})` : '';
  const header = ai.type ? `${ai.type}${scope}: ${ai.subject}` : ai.subject;
  return (ai.body ? `${header}\n\n${ai.body}` : header) + '\n';
};

const main = async (): Promise<void> => {
  const diff = execSync('git diff --cached', {encoding: 'utf8', maxBuffer: 64 * 1024 * 1024});
  if (!diff.trim()) {
    console.error('Nothing staged. `git add` something first.');
    process.exit(1);
  }

  const aiCmd = gitConfig('cz-ai.cmd');
  if (!aiCmd) {
    console.error('cz-ai.cmd is not set. Configure a backend command, e.g.:');
    console.error('  git config --global cz-ai.cmd "cn -p"');
    process.exit(1);
  }
  const stream = gitConfig('cz-ai.stream') === 'true';
  const verbose = gitConfig('cz-ai.verbose') === 'true';

  const raw = await runAi(aiCmd, stream, buildPrompt(diff));
  const ai = parseDefaults(raw);
  printDecision(ai, {verbose, raw});

  const cz = loadCommitizen();
  if (!cz) {
    // Generic repo: prefill the assembled message into the editor (git opens
    // $EDITOR; nothing is committed until you save & close).
    process.exit(writeCommit(assembleMessage(ai), true));
  }

  cz.prompter(aiInquirer(cz.inquirer, ai), (message: string) => {
    process.exit(writeCommit(message));
  });
};

if (import.meta.main) {
  await main();
}
