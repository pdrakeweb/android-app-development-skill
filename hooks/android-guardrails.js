#!/usr/bin/env node
/**
 * android-guardrails — PostToolUse advisory hook.
 *
 * Several of this skill's house rules are *enforcement*, not guidance, and prose
 * the model may or may not honour on turn forty is the wrong shape for them.
 * Hooks fire on the tool call itself and bypass compaction, so they cannot be
 * forgotten mid-session.
 *
 * This hook is deliberately ADVISORY ONLY. It always exits 0 and never blocks a
 * tool call. A guardrail that blocks on a false positive is worse than no
 * guardrail: it trains you to disable it.
 *
 * Reads the PostToolUse payload on stdin, emits additionalContext when a known
 * silent-failure pattern appears.
 */

'use strict';

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => { raw += c; });
process.stdin.on('end', () => {
  let notes = [];
  try {
    notes = inspect(JSON.parse(raw || '{}'));
  } catch {
    // A hook must never be the reason a session breaks. Stay silent on bad input.
    process.exit(0);
  }
  if (notes.length) {
    process.stdout.write(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        additionalContext:
          'android-app-development guardrails:\n' +
          notes.map((n) => `  - ${n}`).join('\n'),
      },
    }));
  }
  process.exit(0);
});

function inspect(payload) {
  const tool = payload.tool_name || '';
  const input = payload.tool_input || {};
  const notes = [];

  if (tool === 'Bash') notes.push(...inspectBash(String(input.command || '')));

  if (tool === 'Edit' || tool === 'Write' || tool === 'MultiEdit') {
    const path = String(input.file_path || '');
    // Only look at text this call is ADDING, so we don't nag about code being removed.
    const added = [input.content, input.new_string]
      .concat((input.edits || []).map((e) => e && e.new_string))
      .filter((s) => typeof s === 'string')
      .join('\n');
    if (added) notes.push(...inspectSource(path, added));
  }

  return notes;
}

function inspectBash(cmd) {
  const notes = [];

  // `adb install` reports failure on stderr and an unasserted pipeline makes a
  // REJECTED install look identical to a good one.
  if (/\badb\b[^|;&]*\binstall\b/.test(cmd) && !/Success|verify-install/.test(cmd)) {
    notes.push(
      '`adb install` without asserting on `Success`: a rejected install looks ' +
      'identical to a good one. Prefer scripts/verify-install.sh, which also ' +
      'confirms the app launched, is alive, and did not crash.'
    );
  }

  // "Every implementation pass ends with a real build and a real test."
  if (/gradlew[^|;&]*\bassemble\w*\b/.test(cmd) && !/test|check|lint/.test(cmd)) {
    notes.push(
      'Built an APK. This pass is not done until it is installed and driven on a ' +
      'device — "should work now" is not a test (scripts/verify-install.sh).'
    );
  }

  // A screenshot proves nothing about which app produced it.
  if (/screencap|exec-out/.test(cmd) && !/topResumedActivity/.test(cmd)) {
    notes.push(
      'Screenshot taken. Confirm which app is actually in front before drawing a ' +
      'conclusion from it (`dumpsys activity activities | grep topResumedActivity`) — ' +
      'a setup wizard or system dialog on top produces confidently wrong results.'
    );
  }

  return notes;
}

const SOURCE_RULES = [
  {
    // Guard that fails open and silently at targetSdk 36.
    test: /\bonBackPressed\s*\(/,
    note:
      'onBackPressed() is NEVER CALLED at targetSdk 36 — predictive back is on by ' +
      'default and KEYCODE_BACK is not dispatched. Any "are you sure?" or unsaved- ' +
      'work guard built on it is silently gone. Use OnBackPressedDispatcher / ' +
      'BackHandler (platform-currency.md §4).',
  },
  {
    test: /fallbackToDestructiveMigration/,
    note:
      'fallbackToDestructiveMigration papers over a bad migration by DELETING the ' +
      "user's data. Once a version has shipped to a real device, a schema change " +
      'needs a real migration (permissions-storage-cloud.md).',
  },
  {
    test: /android:allowBackup\s*=\s*"true"/,
    note:
      'allowBackup="true" makes this app eligible for Google\'s automatic cloud ' +
      'backup and cross-device restore. Decide that deliberately per store — the ' +
      'default has silently synced device identifiers before.',
  },
  {
    test: /android\.enableJetifier/,
    note: 'android.enableJetifier is a BUILD ERROR under AGP 9, not a warning.',
  },
  {
    test: /windowOptOutEdgeToEdgeEnforcement/,
    note:
      'windowOptOutEdgeToEdgeEnforcement is deprecated and disabled at API 36 — ' +
      'edge-to-edge cannot be opted out of. Handle window insets instead.',
  },
  {
    test: /PREFER_ON_DEVICE/,
    note:
      'PREFER_ON_DEVICE is a preference, not a guarantee — it falls back to the ' +
      'cloud. If on-device is a PRIVACY requirement, gate the feature on the model ' +
      'download state and fail loudly instead of degrading silently.',
  },
  {
    test: /\bcatch\s*\([^)]*\)\s*\{\s*\}/,
    note:
      'Empty catch block: a swallowed error is a silent failure, which this ' +
      'corpus treats as the worst failure mode. Fail loudly, or say why not.',
  },
];

function inspectSource(path, added) {
  const notes = [];
  const isSource = /\.(kt|java)$/.test(path);
  const isManifest = /AndroidManifest\.xml$/.test(path);
  const isGradleProps = /gradle\.properties$/.test(path);
  if (!isSource && !isManifest && !isGradleProps) return notes;

  for (const rule of SOURCE_RULES) {
    if (rule.test.test(added)) notes.push(rule.note);
  }
  return notes;
}
