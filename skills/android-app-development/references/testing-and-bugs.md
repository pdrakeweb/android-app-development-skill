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
6. [Verify the artifact, not the exit code](#6-verify-the-artifact-not-the-exit-code) — tools that report success while doing nothing
7. [What's deliberately not in here](#whats-deliberately-not-in-here)

## 1. The adversarial audit prompt

Don't ask for "a code review." Ask for an adversarial audit against a named list of defect classes, with a mandated output format, and an explicit instruction not to skip files that look clean. The categories that recurred across every audit in the corpus:

- **Crash / panic paths** — unchecked nulls, `!!`, unsafe casts without `is` checks, IndexOutOfBounds, unhandled coroutine exceptions, naked `launch{}` swallowing crashes, state observers firing after lifecycle DESTROYED, ConcurrentModificationException.
- **ANR risks** — blocking I/O or DB queries on Main, synchronous `SharedPreferences.commit()`, long computation without yielding.
- **Memory leaks** — Context held in singletons/ViewModels, unregistered listeners/BroadcastReceivers, Handler + anonymous Runnable holding an Activity, unrecycled bitmaps, coroutine scopes outliving their owner.
- **Lifecycle violations** — fragment transactions after `onSaveInstanceState`, ViewModel holding View refs, flows collected outside lifecycle scope.
- **Architecture anti-patterns** — business logic in Activity/Fragment/Composable, God classes (>500 lines), missing loading/error/success states, hardcoded user-facing strings.
- **Security** — secrets logged or hardcoded, cleartext traffic, exported components without permission checks, WebView JS on untrusted URLs, injectable queries (FTS `MATCH` is a common blind spot).
- **Broken functionality** — dead feature flags, race conditions on shared mutable state, infinite retry loops, silently-dropped network errors, missing null checks on backend fields that are sometimes omitted.
- **Dead controls, especially permission-shaped ones** — a control that is hidden, disabled without explanation, or visibly live but does nothing. Denial is the most common way one appears: the control looks fine and the permission behind it is gone. Check every enhancing permission against the four-part degradation contract, and check that an inline retry branches on permanent denial rather than calling `launch()` into a prompt that will never appear (`permissions-storage-cloud.md`). A permission classified essential purely for coding convenience is itself a finding, as is any request that fires at app startup instead of from the feature that needs it.
- **Android API misuse** — deprecated APIs, missing runtime permission requests (declaring a dangerous permission in the manifest has not been enough since **API 23**), missing notification channels, `FileUriExposedException`, wrong `FLAG_ACTIVITY_*` use.
- **Build/dependency issues** — version conflicts, missing R8/ProGuard keep rules for reflection/serialization, debug code leaking into release, wrong minSdk assumptions.
- **Platform-currency breakage** — the API 36 behaviours in `platform-currency.md` §4, which produce defects that look like ordinary bugs: an `onBackPressed()` override that is never called (so an unsaved-work guard is silently gone), content drawing under the system bars because insets aren't handled, a portrait-locked layout handed a landscape tablet window. Treat a surviving `onBackPressed()` at `targetSdk` 36 as **High** — it is a guard that fails open and silently, which is this corpus's defining failure mode.
- **A named fix with nothing behind it** — for every fix, action or next step the app or library names to the person ("sign in again", "set this device up again", "scan this code"): where is the code that performs it, and where is the control? Reviews and simulations do not flag this, because nothing is wrong; something is absent. A library's error type offered a fix for two milestones before any code could perform it. List what was designed and not built, on purpose.
- **Actions that cancel themselves** — work started in a composable's coroutine scope is cancelled when that composable leaves. Ask of every button: can this action make its own screen or form go away, or replace the object the screen is keyed on (`key(engine) { Screen() }`)? If so it belongs to the activity or view model scope. Found twice in one app, both times only when the real button was pressed; tests that drove the app through debug commands passed.
- **Secret fields and restores** — every secret-entry field: can a password manager generate, save and fill it? What happens when the app is restored onto a new phone? (`permissions-storage-cloud.md`.)

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
  part of a review document most often skipped, and the one that stops the same false positive
  being re-filed every audit. Deliberate decisions that
  look like defects — a baked-in credential in a personal build, a hand-rolled parser that exists
  because the library version was wrong, manual entry kept on purpose because it trains a model —
  get "corrected" by the next well-meaning agent unless the review says explicitly that they are
  intended. Every recurring false-positive finding in this corpus traces back to a missing entry
  in this section.

## 3. Structured manual test plans (ADB-based)

**First, check whether this should be a Journey instead.** Google's Journeys format (`*.journey.xml`) expresses the same thing as the Markdown scenarios below — but machine-parseable, CI-reportable, and runnable in both Android Studio and, via `fornewid/journeys-test`, against a local device using Claude Code as the executor. `ecosystem.md` §3 has the wiring.

**Journeys are the default for feature-behaviour scenarios.** The Markdown ADB format below stays the format for what Journeys cannot express — and that list is real, not a hedge:

- **runtime-permission grant/deny states**, because Journeys grant all app permissions by default and silently defeat exactly the test you were writing (`ecosystem.md` §3 states the limit and what to do about it). **A deny-everything scenario is required for any app declaring a runtime permission**, covering all three not-granted states — never-asked, denied-once, permanently-denied — because the gap between the first and the third is where an inline retry becomes a dead control (`permissions-storage-cloud.md`).
- fault injection against an external peer — refuse, hang, starve, disappear;
- LAN rig work, and anything needing a real device on real Wi-Fi (§7 of the toolchain reference);
- ARM-target verification and artifact-shape checks — `${CLAUDE_SKILL_DIR}/scripts/verify-artifact.sh`;
- toolchain and build-config guards;
- soak tests comparing fd/thread/memory before and after.

Both formats feed the same gate: every scenario ends PASS, FAIL, or BLOCKED.

For a device-testing pass that needs to be reproducible by someone else (or by a future subagent),
write it as numbered, independently-runnable files. **The scenario block is defined once, in
`lifecycle.md` Phase 4 — use it verbatim.** It carries a `BLOCKED if` line that this phase's exit
gate and the rig doctrine both depend on; a scenario written without one cannot record the state the
gate asks for.

Practical notes pulled from a working test plan:
- Export the tool paths once at the top of the harness (`ADB=...`, `APK=...`, `PKG=...`) so every step is copy-pasteable without re-deriving paths.
- Distinguish "FAIL" from "BLOCKED" (e.g. a step needing hardware that isn't present) — don't let environment gaps masquerade as app defects.
- A no-crash check is its own explicit test, not an assumption. **Run `${CLAUDE_SKILL_DIR}/scripts/verify-install.sh` rather than re-deriving the sequence by hand** — it exits non-zero on each distinct failure, and `lifecycle.md` Phase 3 describes exactly what it does, including the data wipe it performs by default. Two things worth knowing before hand-rolling any substitute: the crash buffer is system-wide, so an unscoped read fails good builds on someone else's crash, and it must be cleared *before* launch or a previous run's crash reads as this one's.
- **Deriving tap coordinates from a UI dump is the most fragile part of this harness.** Before writing one, consider `android layout` / `android screen resolve` from the Android CLI, or an MCP device-control server — `ecosystem.md` §4 ranks the options.
- For emulator work broadly, the recurring instruction is simply: *"Use the android simulator that we've used for our other android apps to run the apk"* — i.e., standardize on one emulator/AVD across projects rather than reconfiguring per-app, and *"After running all the fixes launch the APK in the emulator... and perform a full functionality test of every feature and function"* as the closing step of every implementation pass.

## 3a. Scripted journeys: launch extras in, one log line out

For a library's sample app, or a feature that is mostly network and state, give the debug build
two things: every setting readable from launch extras, and one content-free result line in logcat
(`RESULT Answer by=remote tookMs=412`: ids, types and timings, never user content). A bash script
then runs `adb shell am start` per scenario, waits for the line and asserts on it. No layout, no
flakiness.

- Pin the device with `ANDROID_SERIAL` (`windows-toolchain-and-emulators.md` §4).
- `adb shell` re-splits arguments: pass the remote command as one quoted string.
- `am force-stop` does **not** cancel `DownloadManager` downloads, so it tests kill-survival.
- Airplane mode (`cmd connectivity airplane-mode enable`) is a real offline state. Restore it in a
  `trap`.
- A scenario sets its own starting state. One journey's leftover download changed another's result.
- To tap, find the control by its text in a `uiautomator dump`, not by coordinates. Press Back to
  hide the keyboard only if `dumpsys input_method` shows `mInputShown=true`; otherwise Back
  closes the app.
- **Press the real control at least once per flow.** A journey that drives setup through launch
  extras never runs the button's code path. Two bugs (above, "actions that cancel themselves")
  lived behind buttons the journey did not press.
- **`uiautomator dump` sees only the top window.** With a system sheet over the app, every check
  on the app's text fails although the app is right; the keyboard's suggestion strip and autofill
  dropdowns are never in it. Screenshot (`adb exec-out screencap -p`) before concluding, and
  dismiss a sheet before asserting.
- **Never tap an unidentified chip on the keyboard strip.** It also offers the clipboard, which
  held an account password the person had just pasted elsewhere.
- **Do not find "the content" by subtracting known labels** from the screen text. Adding one
  button failed six checks against correct data. Mark content with something the app controls.
- **Assert what stays true.** An app that syncs on foreground made "not synced yet" false two
  seconds after launch. Use a longer wait for network storage than for local, and a longer one
  for the first step after `adb install` than between warm steps.
- **Simulate a restored database without root** on a debug build: `am force-stop`, then
  `run-as <pkg> cp databases/app.db* files/bak/`, and copy back later. The `-wal` and `-shm`
  files go with the `.db`, or recent writes are missing.
- **The script prints its own totals and exits non-zero on any failure.** Report those numbers;
  a count given from memory was wrong by two. Commit the output beside the scenario.
- **Rewrite a journey script rather than patch it with layers of `sed`**, and read `git diff`
  before committing any scripted edit: one range delete removed a neighbouring line.

## 3b. Screenshot testing: catching what a log line cannot

The house rule that *a value computed from nothing is never displayed as a finding* is a **visual** invariant, and the ADB harness can only check it indirectly by grepping a UI dump for a string. Golden-image screenshot tests check it directly, and catch the regression the moment it appears.

| Tool | Runs on | Pixel diff | Use when |
|---|---|---|---|
| **Roborazzi** | Host JVM via Robolectric | Yes | **The default for an agent loop.** Works with Hilt and complex components as ordinary JVM unit tests — no emulator, so no flakiness and no device contention |
| **Paparazzi** | Host JVM, no device | Yes | Pure Compose/View rendering, no Android runtime needed |
| Compose preview screenshots on device | Real device/emulator | No built-in diff | You specifically need system bars and true runtime behaviour |

Record with `./gradlew recordRoborazziDebug`, verify with `./gradlew verifyRoborazziDebug`. **For a headless agent session with no display, Roborazzi is the right default** — it is the only option that gives a pixel diff without a device.

Highest-value screens to pin, in order: **every empty/first-run state** (the rule above), the alert/status ladder if colour carries meaning (`DESIGN_TOKENS.md`), and each error state. These are precisely the screens that are hard to reach by hand and easy to break silently.

## 3c. Keep one test against the real thing beside every fake

Three fakes passed in one project where the real thing did not: a fake model file (the real one
verified, then failed to load, because the runtime reads the format from the file extension); a
hand-written streaming server that never streamed (Node's `req.on("close")` fires when the request
body ends; use `res.on("close")`); and a real reasoning model that stayed silent for up to two
minutes, a shape no fake had.

- Every integration point gets an opt-in test against the real service, skipped unless configured.
- One token does not prove streaming. Require several chunks.
- `curl` a fake before blaming the code under test.
- Secrets for those tests live in a git-ignored `.env`, loaded into the test process only, with a
  committed `.env.example`. Make *whether* a value is set a task input, never the value, so it
  cannot reach the build cache. Print names and counts, never values.
- A Drive backend passed 13 tests against a hand-written fake; the first real run then needed
  three fixes, all in the app's use of Google sign-in. Until one run against the real service,
  report "tested against a fake only" in those words.

  ```kotlin
  val dotEnv = rootProject.file(".env").takeIf { it.exists() }?.readLines().orEmpty()
      .mapNotNull { l -> l.trim().takeIf { it.isNotEmpty() && !it.startsWith("#") }?.split("=", limit = 2) }
      .filter { it.size == 2 }.associate { it[0].trim() to it[1].trim() }
  tasks.withType<Test>().configureEach {
      dotEnv.forEach { (k, v) -> if (System.getenv(k) == null) environment(k, v) }
      inputs.property("envKeys", dotEnv.keys.sorted().joinToString(","))
  }
  ```

## 3d. What the JVM can prove, and what needs a device

Robolectric's SQLite is the real engine: triggers, `RAISE(ABORT, ...)`, `julianday('now')`,
foreign keys and `PRAGMA table_info` behaved as on a device (Robolectric 4.17, AGP 9.5.1, JDK 25
host). Write a one-test probe of the thing you depend on before any code that depends on it.

| Robolectric on the JVM is enough | Needs an emulator or phone |
|---|---|
| SQLite behaviour, Room, migrations with table rebuilds | Android Keystore (absent under Robolectric): `androidTest` |
| WorkManager scheduling, with `work-testing` | Storage semantics: app-specific external storage has no hard links |
| Pure logic, simulations | Play services, sign-in, autofill, anything a person sees |

- Robolectric tests are JUnit 4. A contract suite that must run there and under JUnit 5 carries no
  annotations: plain methods that throw `AssertionError`, plus a name-to-check map each framework
  wraps.
- A fallback for a missing file-system feature caught the wrong exception type and was found by
  review, not by a JVM test. Only the emulator exercised that storage.
- **Untested, say so:** Android 8.0 and 8.1 ship an old Bouncy Castle under `org.bouncycastle`.
  Run a bundled crypto provider on the lowest supported API before claiming it.

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

## 6. Verify the artifact, not the exit code

**An exit code is a claim. An artifact is evidence.** Several tools in this exact toolchain report
success while doing nothing, and an agent that trusts the claim reports progress it did not make —
worse than failing, because a failure at least stops. After any step that is supposed to *produce*
something — an installed package, an APK, a generated schema, a registered task, a passing test —
assert on the thing itself.

Every entry below was hit on Windows inside one week on a single project.

| What lied | Observable symptom | The check that catches it |
|---|---|---|
| **SDK CLI exit codes, in both directions** | `sdkmanager --list` and `android --help` return **9 on success**. Worse, `sdkmanager "platforms;android-37.0"` printed *"Package platforms not found. Package android-37.0 not found."* and **exited 0**, having installed nothing | `ls "$ANDROID_HOME/platforms/android-37"` — check the filesystem for the package directory after every SDK install, never the exit code |
| **A build piped through `tail`** | `./gradlew assembleDebug 2>&1 \| tail -120` returns *tail's* status, so a FAILED build reads as exit 0 — and the compiler errors have already scrolled past the window | Redirect to a file, check `$?` on the build itself, then read the file: `./gradlew assembleDebug > build.log 2>&1; rc=$?`. In bash, `set -o pipefail` or `${PIPESTATUS[0]}` also work |
| **A nested block comment in a `.kts`** | Gradle configures without complaint and every task declared below the comment simply does not exist — *"Task 'checkCommentHygiene' not found"*, for a task plainly visible in the file | Assert the task is registered: `./gradlew tasks --all \| grep -q checkCommentHygiene`. A task you cannot see in `tasks --all` is not there, whatever the file says |
| **A Gradle task touching `Project` inside `doLast`** | Passes for days, then fails — it only breaks when the build **stores** a new configuration-cache entry, not when it reuses one | Resolve `Project` values into local `val`s at configuration time and close over those. To test it at all, force a cache miss (`--no-configuration-cache`, or change an input) rather than trusting a green run |
| **A module whose source dir is not picked up** | Compiles **empty** and the build passes. With nothing depending on it yet, there is no error anywhere | An artifact check, not a build check: for a Room module assert the exported schema JSON exists; otherwise assert the expected classes are in the output jar/dex |
| **Counting `<testcase name=` in JUnit XML** | Counts **declared** tests, not passing ones. A failing case has a `<failure>` child and is otherwise identical, so a naive grep prints a clean list of PASS lines for a run that failed | Read the `failures=` and `errors=` attributes on `<testsuite>`, or parse for `<failure>`/`<error>` children |
| **A green build with the build cache on** | `clean build` succeeded in 2 seconds: every test task was restored from cache and none ran | `--rerun-tasks` for any run that counts as proof, then read the counts in the XML |
| **A JUnit test that does not return `Unit`** | `fun x() = runBlocking { … assertIs<T>(…) }` returns a value, so JUnit ignores it without reporting a skip | `= runBlocking<Unit> { … }` or `= runTest { … }`; compare `@Test` count with tests executed |
| **A dependency with native code** | A library module quietly added 23 MB per ABI to every app using it, 50 MB in an unfiltered APK | `unzip -lv app.apk \| sort -n -r \| head` after adding one; `${CLAUDE_SKILL_DIR}/scripts/verify-artifact.sh --expect-abi` on the release build |

Three of these have a documented cause worth knowing:

- **The SDK package syntax changed.** `android sdk install` takes **slash**-separated names —
  `platforms/android-34`, `build-tools/34.0.0`, `system-images/android-35/google_apis/x86_64`
  (<https://developer.android.com/tools/agents/android-cli>). The old `sdkmanager` form is
  semicolon-separated, and the deprecated shim mangles it on the way through. Call
  `android sdk install` directly. The exit-code-9 behaviour is observed on this toolchain; no
  official page documents it.
- **Kotlin nests block comments** — *"Block comments in Kotlin can be nested"*
  (<https://kotlinlang.org/docs/basic-syntax.html>). A glob or a `/*` written inside KDoc opens a
  comment that never closes. In a `.kt` file that usually errors; in `build.gradle.kts` the script
  just ends early and Gradle proceeds with whatever it managed to read.
- **The configuration cache cannot serialize a script object.** Referencing `rootDir`, or anything
  else hanging off `Project`, from inside `doLast` captures one. Gradle documents the execution-time
  restrictions at
  <https://docs.gradle.org/current/userguide/configuration_cache_requirements.html> — that page was
  not reachable to quote from here, so treat the mechanism above as observed behaviour and the page
  as the authority.

### A guard that has never been observed failing is not yet a guard

Two of the six were bugs **inside verification tasks that appeared to be working**. The comment
truncation silently deleted a hygiene check; the configuration-cache bug let a broken check pass for
days. In both cases the tooling reported green and nobody had ever seen it report red.

So before trusting any check you write — a Gradle verification task, a lint rule, a CI step, a
script in `scripts/`:

1. **Plant a violation** the check is supposed to catch.
2. **Confirm it exits non-zero**, and that the message names the file and line.
3. **Remove the violation.**
4. **Confirm it passes.**

**For tests, make it a loop:** commit, plant one violation with `sed`, run, confirm the *named*
test fails, `git checkout -- .`. Seconds each; twenty of them found tests that could not fail.
The usual cause is **an assertion inside code whose exceptions the system under test swallows**
(a callback or hook it wraps in a catch-all). Record a value there and assert outside.

**Green on the first run is a warning, not a result.** Over four milestones of one library, 35
bugs were planted this way after suites passed first time (a 10,000-run simulation among them).
One survived and showed a missing test. If the `sed` change did not apply, say so; do not count
it. A simulator still has blind spots its author cannot see: ask a reviewer for them
(`subagent-delegation.md`, Pattern B2).

A check only ever seen passing is indistinguishable from a check that cannot fail, and the second
kind is worse than none: it is a green light nobody is watching. This is the same discipline the
audit process applies to findings — reproduce it before you believe it — turned on your own tooling.

## What's deliberately not in here

**Out of scope:** techniques for defeating another vendor's licensing, DRM, or pairing checks. That is IP circumvention aimed at someone else's software, not a way to build your own Android app, and nothing here should be read as a template for it. The harness structure above is entirely independent of any of that.
