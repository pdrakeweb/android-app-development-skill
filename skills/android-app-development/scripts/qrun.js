#!/usr/bin/env node
/**
 * qrun — run a noisy command, keep the full log on disk, print only what matters.
 *
 *   node tools/qrun.js [--max N] [--tail N] [--label name] -- <command...>
 *   node tools/qrun.js -- ./gradlew :app:testDebugUnitTest
 *
 * Why: a raw Gradle/adb/test run dumps hundreds to thousands of lines into the model's
 * context, and every later turn pays to re-read them. This prints one summary line on
 * success and only the failure blocks on failure. The full output is always saved, so
 * nothing is lost: grep the log path it prints instead of re-running the build.
 *
 * Exit code is the wrapped command's exit code. Zero dependencies (Node only), so it
 * works the same under Git Bash, PowerShell and Linux.
 */
'use strict';

const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

// ---- args ---------------------------------------------------------------------------
const argv = process.argv.slice(2);
const sep = argv.indexOf('--');
if (sep === -1 || sep === argv.length - 1) {
  console.error('usage: qrun.js [--max N] [--tail N] [--label name] -- <command...>');
  process.exit(2);
}
const opts = { max: 60, tail: 25, label: '' };
for (let i = 0; i < sep; i++) {
  const k = argv[i];
  if (k === '--max') opts.max = parseInt(argv[++i], 10) || opts.max;
  else if (k === '--tail') opts.tail = parseInt(argv[++i], 10) || opts.tail;
  else if (k === '--label') opts.label = String(argv[++i] || '');
}
let cmdArgs = argv.slice(sep + 1);

// Gradle's rich console redraws lines with control codes; plain output is smaller and parseable.
const isGradle = /(^|[\\/])gradlew(\.bat)?$|^gradle$/.test(cmdArgs[0] || '');
if (isGradle && !cmdArgs.some((a) => a.startsWith('--console'))) cmdArgs.push('--console=plain');

const quote = (a) => (/[\s"'&|<>()]/.test(a) ? `"${a.replace(/"/g, '\\"')}"` : a);
const cmdline = cmdArgs.map(quote).join(' ');

// ---- log file -----------------------------------------------------------------------
function logDir() {
  for (const d of [path.join(process.cwd(), 'build', 'qrun'), path.join(os.tmpdir(), 'qrun')]) {
    try { fs.mkdirSync(d, { recursive: true }); return d; } catch { /* try next */ }
  }
  return os.tmpdir();
}
const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..*/, '');
const slug = (opts.label || cmdArgs.join('_')).replace(/[^A-Za-z0-9._-]+/g, '-').slice(0, 40);
const logPath = path.join(logDir(), `${stamp}-${slug}.log`);
const out = fs.createWriteStream(logPath);

// ---- run ----------------------------------------------------------------------------
const started = Date.now();
const child = spawn(cmdline, { shell: true, stdio: ['inherit', 'pipe', 'pipe'] });
child.stdout.pipe(out, { end: false });
child.stderr.pipe(out, { end: false });
child.on('error', (e) => { console.error(`qrun: failed to start: ${e.message}`); process.exit(127); });
child.on('close', (code) => {
  out.end(() => finish(code === null ? 1 : code));
});

// ---- summarise ----------------------------------------------------------------------
const ANSI = /\x1b\[[0-9;?]*[A-Za-z]/g;

function finish(code) {
  const secs = ((Date.now() - started) / 1000).toFixed(1);
  const lines = fs.readFileSync(logPath, 'utf8').replace(ANSI, '').split(/\r?\n/);
  const n = lines.length;
  const header = `qrun: exit ${code} in ${secs}s | ${n} lines | ${cmdline.slice(0, 100)}`;
  const footer = `full log: ${path.relative(process.cwd(), logPath) || logPath}`;
  const warnings = lines.filter((l) => /^w: |warning:/i.test(l)).length;

  if (code === 0) {
    const facts = lines.filter((l) =>
      /^BUILD SUCCESSFUL/.test(l) ||
      /\d+ tests? completed/.test(l) ||
      /^Tests run:|^OK \(\d+ tests?\)/.test(l) ||
      /^\s*Success\s*$/.test(l)
    );
    const parts = [header];
    if (facts.length) parts.push(unique(facts).slice(0, 5).join('\n'));
    if (warnings) parts.push(`${warnings} warning line(s) (see log)`);
    parts.push(footer);
    console.log(parts.join('\n'));
    process.exit(0);
  }

  const picked = failureBlocks(lines);
  let body;
  if (picked.length) {
    const shown = picked.slice(0, opts.max);
    body = shown.join('\n');
    if (picked.length > shown.length) body += `\n... ${picked.length - shown.length} more failure line(s) in log`;
  } else {
    // Unknown tool or format: the tail is where a failure message almost always lives.
    body = `(no known error pattern; last ${opts.tail} lines)\n` + lines.filter(Boolean).slice(-opts.tail).join('\n');
  }
  console.log([header, body, footer].join('\n'));
  process.exit(code);
}

function unique(a) { return [...new Set(a)]; }

function failureBlocks(lines) {
  const keep = new Set();
  const add = (i) => { if (i >= 0 && i < lines.length && lines[i].trim()) keep.add(i); };
  for (let i = 0; i < lines.length; i++) {
    const l = lines[i];
    if (/^e: |^error: |^Error: |: error: |^FAILURE: |^\* What went wrong:|^Execution failed for task|^> Task \S+ FAILED|^Lint found|^FAILED$/.test(l)) {
      add(i);
      // What went wrong: keep the explanatory lines that follow until the next section.
      if (/^\* What went wrong:/.test(l)) {
        for (let j = i + 1; j < lines.length && j < i + 12 && !/^\* (Try|Exception|Get more)/.test(lines[j]) && lines[j].trim(); j++) add(j);
      }
    } else if (/ FAILED$/.test(l) && /^\S.*>/.test(l)) {
      // JUnit via Gradle: "ClassName > testName FAILED" then the assertion and first frames.
      add(i);
      for (let j = i + 1; j < lines.length && j < i + 7; j++) {
        if (!/^\s/.test(lines[j]) && lines[j].trim()) break;
        add(j);
      }
    } else if (/^\d+ tests? completed, \d+ failed|^Tests run:.*Failures: [1-9]/.test(l)) {
      add(i);
    } else if (/INSTALL_FAILED|INSTRUMENTATION_FAILED|FATAL EXCEPTION|AndroidRuntime: |Exception in thread/.test(l)) {
      add(i);
      add(i + 1);
    }
  }
  return unique([...keep].sort((a, b) => a - b).map((i) => lines[i].replace(/\s+$/, '')));
}
