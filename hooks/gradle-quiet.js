#!/usr/bin/env node
// gradle-quiet: a Claude Code PostToolUse hook that shrinks Gradle output before
// the model sees it. The full output is saved to a log file whose path is printed
// on the last line, so nothing is lost.
//
// - Build passed: the summary lines (result, task counts, warning count). Output
//   that is not Gradle noise (e.g. from `dependencies` or `tasks`) is kept, capped
//   head and tail.
// - Build failed: every failed task's whole output, every error line elsewhere, and
//   the failure report. If a failed build has no recognisable shape, the raw tail is
//   shown instead.
// - Fails open: short output, a non-Gradle command, an unexpected payload or any
//   error in this script leaves the original output untouched.
//
// Put GRADLE_RAW anywhere in the command (e.g. `GRADLE_RAW=1 ./gradlew ...` or a
// trailing `# GRADLE_RAW`) to see the output unfiltered.
//
// `node gradle-quiet.js --filter-log <file>` filters a saved log to stdout
// (used by tools/test-gradle-quiet.js).

'use strict';

const { mkdirSync, readdirSync, readFileSync, statSync, unlinkSync, writeFileSync } = require('fs');
const { tmpdir } = require('os');
const { basename, join, resolve } = require('path');

const MIN_LINES = 40; // output at or under this is never touched
const MAX_OK_LINES = 40; // kept non-noise lines on a passing build
const MAX_FAIL_LINES = 250; // kept lines on a failing build
const FALLBACK_TAIL = 80; // raw tail when a failure has no recognisable shape
const KEEP_LOGS = 20;

const TASK_HEADER = /^> Task (\S+)(?: (.*))?$/;
const WARNING_LINE = /^w: |^warning: /;
const ERROR_LINE = new RegExp(
  [
    '^e: ', // Kotlin compiler
    '^\\S.*\\berror: ', // javac, KSP, AAPT
    '\\bFAILED\\s*$', // tasks and tests
    '^\\S+ > .+ FAILED', // JUnit: Class > test FAILED
    '^FAILURE: ',
    '^BUILD FAILED',
    '^\\* What went wrong',
    '^(Caused by|Exception in thread)\\b',
    '\\b\\w+(Exception|Error)\\b:',
    'Lint found .*error',
    '\\.(kt|kts|java|xml|toml):\\d+', // any file:line reference
  ].join('|'),
);
const NOISE = new RegExp(
  [
    '^\\s*$',
    '^> Task ',
    '^> Configure project ',
    '^(Starting a|Daemon will be stopped|To honour the JVM settings)',
    '^Download(ing)? ',
    '^(Calculating task graph|Reusing configuration cache|Configuration cache entry)',
    '^Deprecated Gradle features were used',
    '^You can use .--warning-mode',
    '^For more on this, please refer to',
    '^(Publishing build scan|https://(gradle\\.com|scans\\.gradle\\.com))',
    '^\\[Incubating\\]',
    '^See the profiling report',
    '^Consider enabling configuration cache',
    '^w: ', // counted, not shown
    '^warning: ',
  ].join('|'),
);
const SUMMARY = /^(BUILD (SUCCESSFUL|FAILED)|\d+ actionable tasks?:|\d+ tests? completed)/;
const TRY_BLOCK = /^\* Try:/;
const SECTION = /^\* /;

function filterLog(text, ok) {
  const lines = text.replace(/\r\n/g, '\n').split('\n');
  const warnings = lines.filter((l) => WARNING_LINE.test(l)).length;
  const kept = ok ? filterPass(lines) : filterFail(lines);
  if (warnings > 0) kept.push(`[gradle-quiet] ${warnings} warning line(s) not shown`);
  return { kept, total: lines.length };
}

function filterPass(lines) {
  const summary = lines.filter((l) => SUMMARY.test(l));
  const body = lines.filter((l) => !NOISE.test(l) && !SUMMARY.test(l));
  let shown = body;
  if (body.length > MAX_OK_LINES) {
    const head = Math.floor(MAX_OK_LINES / 3);
    const tail = MAX_OK_LINES - head;
    shown = [
      ...body.slice(0, head),
      `[gradle-quiet] ... ${body.length - MAX_OK_LINES} line(s) omitted ...`,
      ...body.slice(-tail),
    ];
  }
  return [...shown, ...summary];
}

function filterFail(lines) {
  const keep = new Array(lines.length).fill(false);

  // 1. The whole output of every failed task.
  let failureAt = lines.findIndex((l) => /^FAILURE: /.test(l));
  if (failureAt < 0) failureAt = lines.length;
  let segStart = -1;
  let segFailed = false;
  const closeSegment = (end) => {
    if (segStart >= 0 && segFailed) for (let i = segStart; i < end; i++) keep[i] = true;
  };
  for (let i = 0; i < failureAt; i++) {
    const m = TASK_HEADER.exec(lines[i]);
    if (m) {
      closeSegment(i);
      segStart = i;
      segFailed = /\bFAILED\b/.test(m[2] ?? '');
    }
  }
  closeSegment(failureAt);

  // 2. Error lines anywhere, each with a little context after it (assertion text,
  //    the first stack frames).
  for (let i = 0; i < failureAt; i++) {
    if (ERROR_LINE.test(lines[i]) && !WARNING_LINE.test(lines[i])) {
      for (let j = i; j < Math.min(i + 4, failureAt); j++) keep[j] = true;
    }
  }

  // 3. The failure report, minus the "* Try:" boilerplate.
  let inTry = false;
  for (let i = failureAt; i < lines.length; i++) {
    if (TRY_BLOCK.test(lines[i])) inTry = true;
    else if (SECTION.test(lines[i]) || SUMMARY.test(lines[i])) inTry = false;
    if (!inTry) keep[i] = true;
  }

  let out = [];
  let gap = false;
  for (let i = 0; i < lines.length; i++) {
    if (keep[i] && lines[i].trim() !== '' && !WARNING_LINE.test(lines[i])) {
      if (gap && out.length) out.push('  ...');
      out.push(lines[i]);
      gap = false;
    } else if (!keep[i]) gap = true;
  }

  // A failed build that matched nothing recognisable shows its raw tail.
  const recognised = out.some((l) => ERROR_LINE.test(l));
  if (!recognised) {
    const tail = lines.filter((l) => l.trim() !== '').slice(-FALLBACK_TAIL);
    return [`[gradle-quiet] unrecognised failure; raw tail (${tail.length} lines):`, ...tail];
  }

  if (out.length > MAX_FAIL_LINES) {
    const head = Math.floor(MAX_FAIL_LINES * 0.6);
    const tail = MAX_FAIL_LINES - head;
    out = [
      ...out.slice(0, head),
      `[gradle-quiet] ... ${out.length - MAX_FAIL_LINES} failure line(s) omitted, see the full log ...`,
      ...out.slice(-tail),
    ];
  }
  return out;
}

function passed(text) {
  return /^BUILD SUCCESSFUL/m.test(text) && !/^(BUILD FAILED|FAILURE: )/m.test(text);
}

function saveLog(text, cwd) {
  const dir = join(tmpdir(), 'claude-gradle');
  mkdirSync(dir, { recursive: true });
  try {
    const old = readdirSync(dir)
      .filter((f) => f.endsWith('.log'))
      .map((f) => ({ f, t: statSync(join(dir, f)).mtimeMs }))
      .sort((a, b) => b.t - a.t)
      .slice(KEEP_LOGS - 1);
    for (const { f } of old) unlinkSync(join(dir, f));
  } catch {
    /* pruning is best effort */
  }
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const file = join(dir, `${basename(cwd || process.cwd())}-${stamp}.log`);
  writeFileSync(file, text);
  return file;
}

function render(text, file) {
  const ok = passed(text);
  const { kept, total } = filterLog(text, ok);
  const note = `[gradle-quiet] ${ok ? 'passed' : 'FAILED'}; showing ${kept.length} of ${total} lines; full log: ${file}`;
  return { kept, total, out: kept.join('\n') + '\n' + note };
}

function hook(payload) {
  const tool = payload.tool_name;
  const command = payload.tool_input?.command ?? '';
  if (tool !== 'Bash' && tool !== 'PowerShell') return null;
  if (!/(^|[\s\\/;&|(])gradlew?(\.bat)?(\s|$)/.test(command)) return null;
  if (/GRADLE_RAW/.test(command)) return null;
  if (/qrun/.test(command)) return null; // already summarised by scripts/qrun.js

  const resp = payload.tool_response;
  let text;
  let rebuild;
  let file;
  if (typeof resp === 'string') {
    text = resp;
    rebuild = (s) => s;
  } else if (resp && typeof resp.stdout === 'string') {
    const err = typeof resp.stderr === 'string' ? resp.stderr : '';
    text = err ? resp.stdout + '\n' + err : resp.stdout;
    // Past about 30 KB Claude Code keeps only the head of the output in `stdout`
    // and saves all of it to a file. The end of a build is where the failure is,
    // so filter the saved file, and drop the pointer so the filtered text is
    // shown rather than a preview of the head.
    const { persistedOutputPath, persistedOutputSize, ...rest } = resp;
    if (typeof persistedOutputPath === 'string') {
      text = readFileSync(persistedOutputPath, 'utf8');
      file = persistedOutputPath;
    }
    rebuild = (s) => ({ ...rest, stdout: s, stderr: '' });
  } else {
    return null;
  }

  if (text.split('\n').length <= MIN_LINES) return null;
  file ??= saveLog(text, payload.cwd);
  const { kept, total, out } = render(text, file);
  if (kept.length >= total) return null;
  return {
    hookSpecificOutput: { hookEventName: 'PostToolUse', updatedToolOutput: rebuild(out) },
  };
}

function main() {
  const argv = process.argv.slice(2);
  if (argv[0] === '--filter-log') {
    const file = resolve(argv[1]);
    process.stdout.write(render(readFileSync(file, 'utf8'), file).out + '\n');
    return;
  }
  try {
    const result = hook(JSON.parse(readFileSync(0, 'utf8')));
    if (result) process.stdout.write(JSON.stringify(result));
  } catch {
    /* fail open: say nothing, the original output stands */
  }
}

main();
