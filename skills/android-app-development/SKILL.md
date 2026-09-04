---
name: android-app-development
version: 0.2.0
description: Guides building native Android apps (Kotlin, Jetpack Compose, Hilt) end to end — a structured intake interview, a spec, a plan approved before any code, an adversarial audit, an agent-executable test suite, and a beta release. Use when starting a new Android app, resuming or reviewing an existing one, setting up an Android toolchain or phone/tablet/Wear OS emulator, auditing before release, writing agent-executable test scenarios, triaging a bug report from real hardware, or specifying permissions, storage, or cloud sync. Do NOT use for iOS, Flutter, React Native or other cross-platform frameworks, for general Kotlin or JVM questions unrelated to an Android app, or for a one-off Android API question that needs an answer rather than a project.
license: Apache-2.0
compatibility: Builds Android apps with the JDK, Android SDK command-line tools and an emulator or device. The bundled scripts are bash and need adb, aapt2 and apksigner on PATH. Android CLI's emulator command does not work on Windows; AVDs are created manually there.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/preflight.sh *), Bash(${CLAUDE_SKILL_DIR}/scripts/verify-install.sh *), Bash(${CLAUDE_SKILL_DIR}/scripts/verify-artifact.sh *)
---

# Android App Development (Claude Code)

This skill encodes the workflow that has actually shipped working Android apps — not generic Android advice. It is opinionated because the source material was opinionated: every pattern here comes from a session that produced a working APK, a merged fix, or a documented finding.

It is a **process spine**, and it is deliberately not an Android API reference. Google ships official, maintained agent skills for the API-level ground truth that goes stale in ninety days — install those and defer to them (`references/ecosystem.md`). When one of them disagrees with something written here, it wins.

### The reference apps

The examples throughout are drawn from real shipped projects, generalized and renamed. Three recur often enough to be worth knowing by name:

| Name | What it is | Why it's cited |
|---|---|---|
| **`vitals-watch`** | Phone + Wear OS health-alert app. All data on device, no account, no telemetry. | Safety-critical invariants, runtime permissions on a watch, release-vs-debug builds, silent-failure discipline |
| **`field-assistant`** | Offline-capable tablet assistant routing between an on-device model and a cloud API. | The audit/fix loop at scale, LLM hardening, a named safety rule enforced by tests, multi-session integration |
| **`panel-remote`** | Phone/tablet remote control for networked equipment over a LAN. | Emulator networking limits, ARM-target verification, the rig model, resilience/fault-injection testing |

Where a lesson came from somewhere else, it's described rather than named.

## Start here: someone asked for an app

**When the request is "build me an Android app" — or anything that amounts to starting a new app — do not scaffold, do not choose dependencies, and do not write code. Run the intake interview first** (`references/intake-interview.md`), then follow the phases in `references/lifecycle.md`.

The interview is ten broad-to-narrow questions asked in batches of 2–4, followed by dynamically generated follow-ups driven by the answers. It exists because every question in it traces back to something that was built wrong, audited as a defect when it was actually a deliberate decision, or discovered halfway through implementation when it should have been decided in the first ten minutes.

The phases, each with an artifact and an exit gate:

| Phase | Artifact | Gate |
|---|---|---|
| 0 · Interview | audience level (Q0) + answered question set | answers played back and confirmed |
| 1 · Spec | `docs/APP_SPEC.md` (+ ADRs, `CLAUDE.md`) | user has read and confirmed it |
| 1b · Design | `docs/DESIGN_TOKENS.md`, mockups, a named design of record | user has seen and confirmed the design |
| 2 · Plan | `docs/IMPLEMENTATION_PLAN.md` | **user approves before any code** |
| 3 · Implement | working code + updated docs | builds, installs, launches, driven by hand |
| 4 · Test scenarios | `*.journey.xml` and/or `tests/NN-*.md` | suite runs end to end, every result PASS/FAIL/BLOCKED |
| 5 · Audit & fix | audit report + scoped fix agents | no unresolved Critical/High |
| 6 · Beta release | signed release build, published | installed and exercised on real hardware |
| 7 · Handoff | `CLAUDE.md`, `EMULATOR.md`, `DEBUGGING.md`, revisions log | a cold session can build and test it |

Phases 3–5 loop. Phases 0–2 (including 1b) happen once; re-opening one later is a deliberate act that gets written down, not a drift.

## Before you scaffold: the version pins

A cold session working from training data will scaffold a project that does not build. **Verified 2026-09-04** — full detail, deadlines and breaking changes in `references/platform-currency.md`:

| | Pin |
|---|---|
| AGP | **9.4.0** |
| Gradle | **9.6.0** (AGP 9.4's minimum — 9.1 is not enough) |
| JDK | **17** |
| SDK Build Tools | **36.0.0** |
| compileSdk / targetSdk | **36 / 36** — *not* 37; API 37 (Android 17) is still beta |
| minSdk | **28** (corpus floor) |
| Wear OS / Automotive targetSdk | **35** · TV / XR: **34** |

**These two numbers are not opposites, and the naming misleads everyone.** `minSdk` is the oldest
Android that can install the app — the compatibility dial. `targetSdk` is which Android's *behaviour
rules* the app follows, and raising it does **not** drop older devices. `targetSdk 36` + `minSdk 28`
is the normal configuration: it follows current rules *and* runs on a 2018 phone. Never ask a user
for either number — ask how old a phone it must work on (`intake-interview.md` Q4) and translate
(`platform-currency.md` §9).

Three consequences that bite immediately, all detailed in `platform-currency.md`:

- **AGP 9 is a hard break, not a bump.** Built-in Kotlin (you no longer apply the Kotlin Android plugin), the old variant API removed, non-final resource IDs by default, `android.enableJetifier` now a build error. Install Google's `agp-9-upgrade` skill rather than hand-writing this.
- **targetSdk 36 has been required by Play since 2026-08-31.** Edge-to-edge can no longer be opted out of, and predictive back is on by default — so `onBackPressed()` is never called, which silently deletes any unsaved-work guard built on it.
- **If this date is more than a month or two old, re-verify before scaffolding.** `platform-currency.md` §2 says how, in three steps.

## When to use which reference

| Situation | Reference |
|---|---|
| **Any conversation with a human at all** — how much to explain, which words to use, how much to decide for them | `references/user-calibration.md` |
| Someone asked for a new app, or a rough idea needs turning into a spec | `references/intake-interview.md` |
| Mocking up screens, choosing a palette, generating a theme, or reviewing how the built app looks | `references/design-phase.md` |
| Running the end-to-end process; what artifact each phase produces and what "done" means | `references/lifecycle.md` |
| Pinning versions, checking a Play deadline, or diagnosing an AGP 9 / API 36 breakage | `references/platform-currency.md` |
| Choosing a Google skill to defer to, using Android CLI, or picking a test/device-control tool | `references/ecosystem.md` |
| Starting a new app, or splitting a sub-project out of a monorepo | `references/bootstrapping.md` |
| Setting up a machine, or creating/booting phone, tablet, or Wear OS emulators | `references/windows-toolchain-and-emulators.md` |
| Auditing an app before release, fixing audit findings, processing a real-hardware bug report, writing a test plan | `references/testing-and-bugs.md` |
| Specifying permissions, local storage, or cloud backup/sync | `references/permissions-storage-cloud.md` |
| Delegating a large review or a research question to a subagent, or fanning out fixes across multiple files safely | `references/subagent-delegation.md` |

## House rules worth stating explicitly

These showed up often enough, across independent projects, that they're clearly deliberate defaults rather than one-off asks:

- **Personal, non-distributed APKs bake in live credentials on purpose.** This is a documented exception, not an oversight an audit should keep re-flagging — but confirm this framing explicitly with whoever's asking before assuming it, since it does NOT apply to anything that will be distributed, shared, or published (see `permissions-storage-cloud.md` for the boundary and what still needs protecting even in a personal build). Note that distribution now also implies a **developer-verification** question — `platform-currency.md` §6.
- **A safety- or correctness-critical invariant, once established, gets checked by name in every subsequent audit prompt.** (Example from `field-assistant`: "emergency content renders verbatim, never through the LLM" appears in nearly every audit and fix-agent prompt for that app, worded identically each time.) If your app has an analogous non-negotiable rule, name it explicitly and repeat it verbatim across prompts rather than trusting it to be inferred.
- **A button, action, or field that does nothing with no explanation is treated as the worst failure mode**, worse than an error message. Every "why didn't this work" bug report in the corpus traces back to a silent no-op somewhere. Default to failing loudly.
- **Fail closed, and never weaken a guard to make something compile.** Every guard in the corpus exists because the alternative failed *open* and silently. When a value can't be computed, say so — never return the safe-looking one.
- **A value computed from nothing is never displayed as a finding.** Empty states say they're empty. An empty first install is the cheapest possible test of this, and it has caught fabricated numbers twice.
- **Every implementation pass ends with a real build and a real test**, not "should work now." "After running all the fixes launch the APK in the emulator... and perform a full functionality test of every feature" is a recurring, explicit instruction — say it every time rather than assuming it's implied. `${CLAUDE_SKILL_DIR}/scripts/verify-install.sh` makes the check deterministic instead of a claim.
- **When a fix needs a judgement rather than a correction, stop and ask.** Several numbers in these codebases look like implementation details and are actually domain judgements; guessing produces a plausible-looking app that is wrong in a way nobody notices for months.
- **Every silent failure that gets fixed gets a regression test.** A silent failure that regresses is invisible again.
- **Match the register to the person, and establish it before anything else.** Ask the audience-level question first (`user-calibration.md`), then tune every question, explanation and error message to the answer. At novice levels *ask fewer questions and decide more*, stating plainly what you picked — asking someone to choose a navigation library when they cannot evaluate the options is abdication, not consultation. Going quiet after a dense message is the clearest comprehension signal there is; treat sudden agreement with something complicated as a failure to land until proven otherwise.
- **Build a working model of the person, then research harder the less they can check you.** The level from Q0 is scaffolding; keep refining it from what they say, skip, and repeat, and never show them the label. At novice levels explain ELI5 — no assumed background, which is not talking down — and for anything expensive to reverse, convene the **`council`** skill if installed rather than picking unilaterally, reporting decision / reason / honest cost / confidence / what would flip it. The inversion is deliberate: an expert can overrule a lazy recommendation, a novice will live with it for the life of the app.
- **Explain, propose, act — never hand someone a download page.** Anything a package manager can install, install: say what it buys them, name the tool, warn that a permission prompt is coming, then run it and verify. `winget install Git.Git` beats "go download Git", and the only genuinely human steps left are approving prompts, elevation, a reboot, physical hardware, and anything spending their money or identity. The explanation compresses with the audience level; the warning that a prompt is coming never drops, and neither does stating what a destructive action costs (`user-calibration.md` §12).
- **A finding cites the page it came from.** An audit finding with a link to an official doc survives disagreement; one without gets argued about, or silently reverted by the next well-meaning agent.

## Deterministic checks

Prose instructions get skipped on turn forty. These do not — run them instead of asserting the outcome:

| Script | Answers |
|---|---|
| `${CLAUDE_SKILL_DIR}/scripts/preflight.sh` | Does this machine's toolchain match the pins above, and what does the project actually declare? |
| `${CLAUDE_SKILL_DIR}/scripts/verify-install.sh` | Did the APK install, launch, reach the foreground, and survive without crashing? |
| `${CLAUDE_SKILL_DIR}/scripts/verify-artifact.sh` | Does the release artifact carry the right ABIs, targetSdk, and a v2+ signature? |
