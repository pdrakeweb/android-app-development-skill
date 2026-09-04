# Auditing, Testing, and Fixing Bugs

This is the highest-value part of the corpus. The pattern — exhaustive categorized audit, then N parallel subagents each scoped to a disjoint file list — is what let a single review pass turn into dozens of correct, non-conflicting fixes in one sitting.

**Contents**

1. [The adversarial audit prompt](#1-the-adversarial-audit-prompt) — defect classes, output format, severity
   - [1b. Borrowed vocabulary](#1b-borrowed-vocabulary-masvs-and-the-quality-guidelines) — MASVS / app-quality IDs
2. [Fixing findings](#2-fixing-findings--the-scoped-parallel-subagent-pattern) — scoped parallel subagents
   - [2b. The review artifact](#2b-the-review-artifact-itself--conventions-that-paid-off)
3. [Structured test plans](#3-structured-manual-test-plans-adb-based) — Journeys and the ADB harness
   - [3b. Screenshot testing](#3b-screenshot-testing-catching-what-a-log-line-cannot)
4. [Real-hardware bug reports](#4-real-hardware-bug-reports)
5. [UI / adaptive-layout review](#5-uiadaptive-layout-review-screenshot-driven)
6. [What's deliberately not in here](#whats-deliberately-not-in-here)

## 1. The adversarial audit prompt

Don't ask for "a code review." Ask for an adversarial audit against a named list of defect classes, with a mandated output format, and an explicit instruction not to skip files that look clean. The categories that recurred across every audit in the corpus:

- **Crash / panic paths** — unchecked nulls, `!!`, unsafe casts without `is` checks, IndexOutOfBounds, unhandled coroutine exceptions, naked `launch{}` swallowing crashes, state observers firing after lifecycle DESTROYED, ConcurrentModificationException.
- **ANR risks** — blocking I/O or DB queries on Main, synchronous `SharedPreferences.commit()`, long computation without yielding.
- **Memory leaks** — Context held in singletons/ViewModels, unregistered listeners/BroadcastReceivers, Handler + anonymous Runnable holding an Activity, unrecycled bitmaps, coroutine scopes outliving their owner.
- **Lifecycle violations** — fragment transactions after `onSaveInstanceState`, ViewModel holding View refs, flows collected outside lifecycle scope.
- **Architecture anti-patterns** — business logic in Activity/Fragment/Composable, God classes (>500 lines), missing loading/error/success states, hardcoded user-facing strings.
- **Security** — secrets logged or hardcoded, cleartext traffic, exported components without permission checks, WebView JS on untrusted URLs, injectable queries (FTS `MATCH` is a common blind spot).
- **Broken functionality** — dead feature flags, race conditions on shared mutable state, infinite retry loops, silently-dropped network errors, missing null checks on backend fields that are sometimes omitted.
- **Android API misuse** — deprecated APIs, missing runtime permission requests (declaring in the manifest is not enough on API 33+), missing notification channels, `FileUriExposedException`, wrong `FLAG_ACTIVITY_*` use.
- **Build/dependency issues** — version conflicts, missing R8/ProGuard keep rules for reflection/serialization, debug code leaking into release, wrong minSdk assumptions.
- **Platform-currency breakage** — the API 36 behaviours in `platform-currency.md` §4, which produce defects that look like ordinary bugs: an `onBackPressed()` override that is never called (so an unsaved-work guard is silently gone), content drawing under the system bars because insets aren't handled, a portrait-locked layout handed a landscape tablet window. Treat a surviving `onBackPressed()` at `targetSdk` 36 as **High** — it is a guard that fails open and silently, which is this corpus's defining failure mode.

Mandate a structured output — either a written report (`audit/AUDIT_REPORT.md`, with Critical/High/Medium/Low counts and one entry per finding: severity, file:line, category, description, reproduction, fix) or, for a more surgical per-tree audit, inline findings in a strict repeating block format:

```
---
SEVERITY: Critical|High|Medium|Low
TITLE: short title
FILE: relative/path.kt:lineNumber
CATEGORY: Crash|ANR|Memory leak|Lifecycle|Architecture|Security|Broken functionality|API misuse|Build
DESCRIPTION: precise explanation and how it manifests/is exploited
REPRODUCTION: how to trigger
FIX: specific fix with code snippet
---
```
...followed by a final `FILES REVIEWED:` list. Explicitly forbid the agent from summarizing code back to you — findings only, in the exact format, or the output balloons and becomes hard to fan out into fix-agents.

**If the app has a named safety/correctness invariant** (see SKILL.md), restate it in the audit prompt verbatim and make it a first-class thing every audit checks — e.g. "is the snippet text rendered EXACTLY, not through any transform that could alter it? Flag any markdown/transform applied to emergency text as Critical."

**Severity calibration that held up across projects:** Critical = crash, security/key leak, or a safety-invariant bypass. High = ANR, broken core feature, swallowed errors, resource leak causing failure. Medium = memory leak, anti-pattern. Low = style, dead code, hardcoded strings.

**Cite the source for every finding.** A finding carrying a link to the official page it came from survives a disagreement; one without it gets argued about, or silently reverted by the next well-meaning agent six weeks later. Add a `REFERENCE:` line to the block format above. This costs one URL per finding and is the cheapest credibility this process has.

## 1b. Borrowed vocabulary: MASVS and the quality guidelines

The house rule is that a named invariant gets repeated **verbatim** across prompts so it can't drift. That pattern already exists, industry-wide, with stable identifiers — use them instead of inventing free-form finding names that vary between sessions.

- **OWASP MASVS / MASTG** for security findings. Controls carry stable IDs (`MASVS-STORAGE-1`, `MASVS-PLATFORM-2`), and the **MAS Checklist** maps every MASVS control to its MASTG test cases. MASTG v2.0.0 is the first stable non-beta release of the modularised framework, with machine-readable components cross-linked across MASVS, MASWE, tests and techniques. Note v2.0.0 **dropped the L1/L2/R verification levels** in favour of MAS Testing Profiles — if you inherit a doc citing "MASVS-L2", it predates that change.
- **Core app quality** and **Wear OS app quality** for everything else. Each requirement has a unique ID (`WO-V1`, `WO-P2`) explicitly intended for team communication, and failing them is a documented cause of Play submission rejection — so these are release-gating, not stylistic.

Why bother: `MASVS-STORAGE-1` means the same thing in every session, to every subagent, forever. "the storage thing we flagged" does not. For an app holding health, financial, or identifying data (intake Q7), run the audit **with the MAS Checklist open** and cite control IDs in the report.

Google's `security/android-intent-security` skill covers the intent surface specifically (`ecosystem.md` §2).

## 2. Fixing findings — the scoped-parallel-subagent pattern

Once you have a finding list, don't fix everything in one linear pass. Partition findings by file/module and dispatch one subagent per partition, each with:

1. **A hard file-scope boundary, stated twice** — once as "Only edit these files" and once as "Do NOT touch [other modules/files], another agent owns them." Repetition isn't redundant here; it's the thing that keeps two agents from racing on the same file.
2. **The exact finding, by ID, file, and line number**, with a specific description of the fix — not "fix the memory leak in X," but the precise restructuring (see example below). The audit report already has this; copy it forward rather than re-deriving it.
3. **"Read the file fully before editing," "apply fixes precisely and minimally, preserving behavior/comments/style."** This keeps a fix-agent from opportunistically refactoring things nobody asked it to touch.
4. **The safety invariant restated**, if the module touches it at all — e.g. "don't weaken any emergency path."
5. **"Report which findings you fixed and any cross-file impact — do not edit outside your file list."** Cross-file impact gets surfaced to you, the coordinating session, rather than acted on unilaterally by a subagent that only has partial context.

Worked example of the level of specificity that makes this work (condensed from an actual fix-agent dispatch):

> CRIT-004: `stream()` (callbackFlow) calls `sessionMutex.lock()` outside the `try`, and the only `unlock()` is inside `awaitClose{}` within `finally`. On error/cancellation paths the global mutex can be held far too long or never released, stalling all inference. Restructure so `unlock()` is in a `finally` that always runs, independent of `awaitClose`. [... exact code skeleton follows ...] Verify the lock is acquired exactly once and released exactly once on every path (normal completion, early return after an error frame, thrown exception, and collector cancellation).

That level of detail — the exact function, the exact bug mechanism, the exact fix shape, and an explicit list of paths to verify — is what lets a subagent get concurrency-critical code right on the first pass without back-and-forth.

After all fix-agents finish: grep for references to anything any agent deleted, confirm no dangling references, and do a final integration build.

## 2b. The review artifact itself — conventions that paid off

The audit/review document is long-lived, not a throwaway. Two conventions from the corpus make it
worth keeping:

- **Mark each finding's status in place as it's resolved** — `✅ Fixed`, `⚠️ Partially fixed`
  (with what remains), or left plain when open. A review where every finding still reads as open
  is one nobody can act on six weeks later, and re-auditing to find out is the expensive path.
- **Include a "what's already done well, so it isn't 'fixed' away later" section.** This is the
  highest-leverage part of a review document and the easiest to skip. Deliberate decisions that
  look like defects — a baked-in credential in a personal build, a hand-rolled parser that exists
  because the library version was wrong, manual entry kept on purpose because it trains a model —
  get "corrected" by the next well-meaning agent unless the review says explicitly that they are
  intended. Every recurring false-positive finding in this corpus traces back to a missing entry
  in this section.

## 3. Structured manual test plans (ADB-based)

**First, check whether this should be a Journey instead.** Google's Journeys format (`*.journey.xml`) expresses the same thing as the Markdown scenarios below — but machine-parseable, CI-reportable, and runnable in both Android Studio and, via `fornewid/journeys-test`, against a local device using Claude Code as the executor. `ecosystem.md` §3 has the wiring.

**Journeys are the default for feature-behaviour scenarios.** The Markdown ADB format below stays the format for what Journeys cannot express — and that list is real, not a hedge:

- **runtime-permission grant/deny states**, because a Journey may auto-grant all app permissions, which silently defeats exactly the test you were writing (see the caveat in `ecosystem.md` §3). Keep these as ADB tests, where `pm revoke` / `pm clear` puts grant state under your control.
- fault injection against an external peer — refuse, hang, starve, disappear;
- LAN rig work, and anything needing a real device on real Wi-Fi (§7 of the toolchain reference);
- ARM-target verification and artifact-shape checks — `scripts/verify-artifact.sh`;
- toolchain and build-config guards;
- soak tests comparing fd/thread/memory before and after.

Both formats feed the same gate: every scenario ends PASS, FAIL, or BLOCKED.

For a device-testing pass that needs to be reproducible by someone else (or by a future subagent), write it as numbered, independently-runnable files, each with this shape:

```
### N.M <short title>
- Preconditions: <what must already be true/done>
- Steps: <numbered shell commands, adb-based>
- Expected: <what should happen, described concretely>
- Verify: <exactly what in the command output/screenshot confirms it>
- Pass/Fail: PASS if <condition>. FAIL if <condition, with likely cause>.
```

Practical notes pulled from a working test plan:
- Export the tool paths once at the top of the harness (`ADB=...`, `APK=...`, `PKG=...`) so every step is copy-pasteable without re-deriving paths.
- Distinguish "FAIL" from "BLOCKED" (e.g. a step needing hardware that isn't present) — don't let environment gaps masquerade as app defects.
- A no-crash check is its own explicit test, not an assumption: `adb logcat -d -v time | grep -iE 'AndroidRuntime|FATAL EXCEPTION|beginning of crash'` should print nothing, and `adb shell pidof <pkg>` should print a PID. **`scripts/verify-install.sh` does all of this** — install asserting on `Success`, clear the crash buffer *before* launching so a previous run's crash can't be misread as this one's, launch, confirm a live PID, check the foreground activity, and assert the crash buffer is empty. Prefer running it to re-deriving the sequence by hand.
- **Deriving tap coordinates from a UI dump is the most fragile part of this harness.** Before writing one, consider `android layout` / `android screen resolve` from the Android CLI, or an MCP device-control server — `ecosystem.md` §4 ranks the options.
- For emulator work broadly, the recurring instruction is simply: *"Use the android simulator that we've used for our other android apps to run the apk"* — i.e., standardize on one emulator/AVD across projects rather than reconfiguring per-app, and *"After running all the fixes launch the APK in the emulator... and perform a full functionality test of every feature and function"* as the closing step of every implementation pass.

## 3b. Screenshot testing: catching what a log line cannot

The house rule that *a value computed from nothing is never displayed as a finding* is a **visual** invariant, and the ADB harness can only check it indirectly by grepping a UI dump for a string. Golden-image screenshot tests check it directly, and catch the regression the moment it appears.

| Tool | Runs on | Pixel diff | Use when |
|---|---|---|---|
| **Roborazzi** | Host JVM via Robolectric | Yes | **The default for an agent loop.** Works with Hilt and complex components as ordinary JVM unit tests — no emulator, so no flakiness and no device contention |
| **Paparazzi** | Host JVM, no device | Yes | Pure Compose/View rendering, no Android runtime needed |
| Compose preview screenshots on device | Real device/emulator | No built-in diff | You specifically need system bars and true runtime behaviour |

Record with `./gradlew recordRoborazziDebug`, verify with `./gradlew verifyRoborazziDebug`. **For a headless agent session with no display, Roborazzi is the right default** — it is the only option that gives a pixel diff without a device.

Highest-value screens to pin, in order: **every empty/first-run state** (the rule above), the alert/status ladder if colour carries meaning (`DESIGN_TOKENS.md`), and each error state. These are precisely the screens that are hard to reach by hand and easy to break silently.

## 4. Real-hardware bug reports

The best bug report in the corpus (paraphrased structure, from a real Wear OS device test) has five parts, in this order:

1. **Context** — what build/version, what hardware, and which docs the assistant should read *before* diagnosing (this front-loads the assistant checking its own work against the spec rather than guessing).
2. **What I observed, in order** — numbered, factual, no diagnosis mixed in yet.
3. **Issues to fix, most severe first** — each one names *which observation(s)* it explains, states *why* it's severe (tying back to a stated design principle — e.g. "a button that does nothing with no explanation is the failure mode this whole project is built to avoid"), and gives a concrete fix direction without over-specifying the implementation.
4. **Diagnostics the reporter can run if useful** — "adb is connected... tell me exactly what to run" hands the assistant a live debugging channel instead of a one-shot report.
5. **A separate section for anything that needs explicit sign-off before touching** — a pre-existing, unrelated defect gets flagged, with the fix direction proposed, but the report explicitly says *"propose it and wait for my answer rather than applying it."* This is worth keeping as a hard boundary: bundling an unrelated, judgment-call fix into a bug-fix pass is exactly how scope creeps.

The corresponding fix instruction, once given, is typically just: *"Implement your recommendations, publish a beta, push all code, ensure that debug commands such as the one given are documented in the appropriate docs folder before pushing everything up."* — implement, release, and document the diagnostic commands used, all in one pass.

## 5. UI/adaptive-layout review (screenshot-driven)

For visual/UX findings specifically, tie every finding to a named screenshot file and a named API/pattern — not "the layout looks cramped" but "phone portrait `07_remote_portrait.png`: landscape-shaped layout crammed into portrait... should the screen lock landscape or use an adaptive stacked layout? (name: `WindowSizeClass`)." Assign a severity (P0 critical / P1 high / P2 medium / P3 polish) per finding, same discipline as the code audit. Cover, at minimum: adaptive layout across orientations, edge-to-edge/insets handling, tablet space usage, Material 3 component fidelity vs. hand-rolled equivalents, dynamic color, predictive-back behavior, and IME insets on any text-entry screen.

Two of those are no longer stylistic at `targetSdk` 36 and should be graded **P0/P1, not polish**:

- **Edge-to-edge / insets.** It cannot be opted out of, so unhandled insets are content hidden under the system bars, not a margin complaint.
- **Orientation on large screens.** Manifest orientation and aspect-ratio restrictions are ignored on displays ≥600dp smallest width, so a portrait-locked layout *will* be handed a landscape tablet window. Screenshot the tablet rig specifically; the phone rig cannot show this.

`hamen/compose_skill` (`ecosystem.md` §5) runs this exact review as a scored audit with every deduction cited to an official page — worth installing for a UI-heavy app rather than reproducing by hand.

## What's deliberately not in here

The ADB test-harness format in section 3 was originally developed on a project that also involved decompiling and modifying a third-party commercial app. Those techniques — defeating another vendor's licensing, DRM, or pairing checks — are **deliberately excluded** from this skill. They are IP circumvention aimed at someone else's software, not a generalizable way to build your own Android app, and nothing here should be read as a template for them. What was worth keeping is the harness structure itself, which is entirely independent of that context.
