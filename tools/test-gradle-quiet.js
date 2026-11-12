#!/usr/bin/env node
/**
 * test-gradle-quiet: the output filters keep a failure and drop the noise.
 *
 *   node tools/test-gradle-quiet.js
 *
 * Covers hooks/gradle-quiet.js (the plugin hook) and scripts/qrun.js (the wrapper), against
 * Gradle output recorded from a real build with a planted compile error (paths shortened).
 * No Gradle or Android SDK is needed, so CI runs it.
 *
 * A guard that has never been seen failing is not yet a guard, so the last step breaks the hook
 * on purpose (compiler errors treated as noise) and requires this same suite to catch it.
 * Repo-level: not part of the shipped skill.
 */
'use strict';

const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const HOOK = path.join(ROOT, 'hooks', 'gradle-quiet.js');
const QRUN = path.join(ROOT, 'skills', 'android-app-development', 'scripts', 'qrun.js');
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'gradle-quiet-test-'));

const SRC = 'file:///work/app/core/src/main/kotlin/demo/Planted.kt';
const ERRORS = [
  `e: ${SRC}:3:1 Visibility must be specified in explicit API mode.`,
  `e: ${SRC}:3:38 Initializer type mismatch: expected 'Int', actual 'String'.`,
];
const FAILURE = [
  '> Task :core:checkKotlinGradlePluginConfigurationErrors SKIPPED',
  '',
  '> Task :core:compileKotlin FAILED',
  ...ERRORS,
  'w: file:///work/app/core/src/main/kotlin/demo/Old.kt:9:5 This declaration is deprecated.',
  '',
  '[Incubating] Problems report is available at: file:///work/app/build/reports/problems/problems-report.html',
  '',
  'FAILURE: Build failed with an exception.',
  '',
  '* What went wrong:',
  "Execution failed for task ':core:compileKotlin' (registered by plugin 'org.jetbrains.kotlin.jvm').",
  '> A failure occurred while executing org.jetbrains.kotlin.compilerRunner.btapi.BuildToolsApiCompilationWork',
  '   > Kotlin compiler: NO_EXPLICIT_VISIBILITY_IN_API_MODE',
  '         Location: /work/app/core/src/main/kotlin/demo/Planted.kt:3',
  '',
  '* Try:',
  '> Run with --stacktrace option to get the stack trace.',
  '> Run with --info or --debug option to get more log output.',
  '> Get more help at https://help.gradle.org.',
  '',
  'BUILD FAILED in 4s',
  '1 actionable task: 1 executed',
].join('\n');
const TEST_FAILURE = [
  '> Task :core:test FAILED',
  '',
  'LimitGateTest > a load above the cap is refused() FAILED',
  '    org.opentest4j.AssertionFailedError: expected: <Refused> but was: <Allowed>',
  '        at app.demo.LimitGateTest.refuses(LimitGateTest.kt:41)',
  '',
  '14 tests completed, 1 failed',
  '',
  'FAILURE: Build failed with an exception.',
  '',
  '* What went wrong:',
  "Execution failed for task ':core:test'.",
  '> There were failing tests. See the report at: file:///work/app/core/build/reports/tests/test/index.html',
  '',
  'BUILD FAILED in 9s',
].join('\n');
const NOISE = Array.from({ length: 600 }, (_, i) => `> Task :m${i}:compileKotlin UP-TO-DATE`).join('\n');
const PASS = NOISE + '\n\nBUILD SUCCESSFUL in 12s\n640 actionable tasks: 3 executed, 637 up-to-date';

const lineCount = (s) => s.split('\n').length;
const isError = (l) => l.startsWith('e: ') && l.includes('Planted.kt:3:');

function payload(command, stdout, extra = {}) {
  return JSON.stringify({
    hook_event_name: 'PostToolUse',
    tool_name: extra.tool || 'Bash',
    cwd: TMP,
    tool_input: { command },
    tool_response: { stdout, stderr: extra.stderr || '', interrupted: false, isImage: false, ...(extra.response || {}) },
  });
}

function runHook(hook, stdin) {
  const r = spawnSync(process.execPath, [hook], { input: stdin, encoding: 'utf8' });
  let updated = null;
  try { updated = JSON.parse(r.stdout).hookSpecificOutput.updatedToolOutput; } catch { /* not replaced */ }
  return { code: r.status, raw: r.stdout || '', updated, shown: updated ? updated.stdout : '' };
}

/** Runs every hook check against `hook`; returns the names of the checks that failed. */
function hookSuite(hook, report) {
  const failed = [];
  const check = (name, ok, detail) => {
    if (report) console.log(`${ok ? 'ok   ' : 'FAIL '} ${name}${detail ? ': ' + detail : ''}`);
    if (!ok) failed.push(name);
  };

  const long = runHook(hook, payload('./gradlew check', NOISE + '\n' + FAILURE));
  const kept = long.shown.split('\n').filter(isError).length;
  check('compile failure: every compiler error line survives', kept === ERRORS.length, `${kept} of ${ERRORS.length}`);
  check('compile failure: says the build failed', /BUILD FAILED/.test(long.shown) && /FAILED;/.test(long.shown));
  check('compile failure: noise dropped', long.updated !== null && lineCount(long.shown) < 40,
    `${lineCount(NOISE + FAILURE)} -> ${lineCount(long.shown)} lines`);
  check('compile failure: "* Try:" boilerplate dropped', !/--stacktrace/.test(long.shown));
  check('compile failure: warnings counted, not shown', !/^w: /m.test(long.shown) && /1 warning line/.test(long.shown));
  const log = (/full log: (.+)$/m.exec(long.shown) || [])[1] || '';
  check('compile failure: full log saved', fs.existsSync(log) && fs.readFileSync(log, 'utf8').includes(ERRORS[1]));
  if (fs.existsSync(log)) fs.unlinkSync(log);

  const ps = runHook(hook, payload('.\\gradlew.bat check', NOISE + '\n' + FAILURE, { tool: 'PowerShell' }));
  check('PowerShell tool is covered', ps.shown.split('\n').filter(isError).length === ERRORS.length);

  const test = runHook(hook, payload('./gradlew :core:test', NOISE + '\n' + TEST_FAILURE));
  check('test failure: test name, assertion and first frame survive',
    /refused\(\) FAILED/.test(test.shown) && /AssertionFailedError/.test(test.shown) && /LimitGateTest\.kt:41/.test(test.shown));
  check('test failure: the count survives', /14 tests completed, 1 failed/.test(test.shown));

  // Past about 30 KB the harness passes only the head in stdout and a path to all of it.
  const persisted = path.join(TMP, 'persisted.txt');
  fs.writeFileSync(persisted, NOISE + '\n' + FAILURE);
  const big = runHook(hook, payload('./gradlew check', NOISE.slice(0, 3000),
    { response: { persistedOutputPath: persisted, persistedOutputSize: NOISE.length + FAILURE.length } }));
  check('oversized failure: errors read from the saved file',
    big.shown.split('\n').filter(isError).length === ERRORS.length);
  check('oversized failure: head-preview pointer removed',
    big.updated !== null && !('persistedOutputPath' in big.updated));

  const pass = runHook(hook, payload('./gradlew check', PASS));
  check('passing build: cut to a summary', /BUILD SUCCESSFUL/.test(pass.shown) && lineCount(pass.shown) < 10,
    `${lineCount(PASS)} -> ${lineCount(pass.shown)} lines`);
  check('passing build: not reported as failed', pass.updated !== null && !/FAILED/.test(pass.shown));

  const unknown = runHook(hook, payload('./gradlew check', NOISE + '\nsomething nobody has seen before\nit stopped'));
  check('unrecognised failure: raw tail shown, not nothing', /unrecognised failure/.test(unknown.shown) && /it stopped/.test(unknown.shown));

  const plain = Array.from({ length: 500 }, (_, i) => `line ${i}`).join('\n');
  check('short Gradle output untouched', runHook(hook, payload('./gradlew help', 'BUILD SUCCESSFUL in 1s')).raw === '');
  check('non-Gradle command untouched', runHook(hook, payload('git log', plain)).raw === '');
  check('GRADLE_RAW untouched', runHook(hook, payload('GRADLE_RAW=1 ./gradlew check', plain)).raw === '');
  check('qrun-wrapped command untouched', runHook(hook, payload('node tools/qrun.js -- ./gradlew check', plain)).raw === '');
  check('other tools untouched', runHook(hook, payload('./gradlew check', plain, { tool: 'Read' })).raw === '');
  const junk = runHook(hook, 'not json');
  check('malformed input: silent, exit 0', junk.raw === '' && junk.code === 0);
  return failed;
}

function qrunSuite() {
  const failed = [];
  const check = (name, ok, detail) => {
    console.log(`${ok ? 'ok   ' : 'FAIL '} ${name}${detail ? ': ' + detail : ''}`);
    if (!ok) failed.push(name);
  };
  const emit = (name, text, code) => {
    const f = path.join(TMP, name);
    fs.writeFileSync(f, `process.stdout.write(${JSON.stringify(text + '\n')}); process.exit(${code});\n`);
    return f;
  };
  const run = (script) => spawnSync(process.execPath, [QRUN, '--', 'node', script], { cwd: TMP, encoding: 'utf8' });

  const bad = run(emit('fail.js', NOISE + '\n' + FAILURE, 1));
  const kept = bad.stdout.split('\n').filter(isError).length;
  check('qrun failure: every compiler error line survives', kept === ERRORS.length, `${kept} of ${ERRORS.length}`);
  check('qrun failure: exit code is the command\'s', bad.status === 1, `exit ${bad.status}`);
  check('qrun failure: noise dropped', lineCount(bad.stdout) < 40, `${lineCount(NOISE + FAILURE)} -> ${lineCount(bad.stdout)} lines`);

  const test = run(emit('test.js', NOISE + '\n' + TEST_FAILURE, 1));
  check('qrun test failure: test name and assertion survive',
    /refused\(\) FAILED/.test(test.stdout) && /AssertionFailedError/.test(test.stdout));

  const good = run(emit('pass.js', PASS, 0));
  check('qrun pass: summary only, exit 0', good.status === 0 && /BUILD SUCCESSFUL/.test(good.stdout) && lineCount(good.stdout) < 8,
    `${lineCount(PASS)} -> ${lineCount(good.stdout)} lines`);
  const log = (/full log: (.+)$/m.exec(good.stdout) || [])[1] || '';
  check('qrun pass: full log saved', log !== '' && fs.existsSync(path.resolve(TMP, log.trim())));
  return failed;
}

let exitCode = 0;
try {
  console.log('hooks/gradle-quiet.js');
  const hookFailed = hookSuite(HOOK, true);

  console.log('\nscripts/qrun.js');
  const qrunFailed = qrunSuite();

  // The suite itself, shown failing: a hook that treats compiler errors as noise must be caught.
  console.log('\nplanted violation');
  const broken = path.join(TMP, 'gradle-quiet-broken.js');
  const source = fs.readFileSync(HOOK, 'utf8');
  const mutated = source
    .replace('const kept = ok ? filterPass(lines) : filterFail(lines);', 'const kept = filterPass(lines);')
    .replace("'^w: ', // counted, not shown", "'^w: ', '^e: ',");
  let planted = [];
  if (mutated === source) {
    console.log('FAIL  could not plant the violation: the hook no longer contains the lines this test edits');
    planted = null;
  } else {
    fs.writeFileSync(broken, mutated);
    planted = hookSuite(broken, false);
    const caught = planted.includes('compile failure: every compiler error line survives');
    console.log(`${caught ? 'ok   ' : 'FAIL '} a hook that drops compiler errors is caught (${planted.length} check(s) failed on it)`);
    if (!caught) planted = null;
  }

  const total = hookFailed.length + qrunFailed.length + (planted === null ? 1 : 0);
  console.log(total ? `\n${total} check(s) FAILED` : '\nall passed');
  exitCode = total ? 1 : 0;
} finally {
  fs.rmSync(TMP, { recursive: true, force: true });
}
process.exit(exitCode);
