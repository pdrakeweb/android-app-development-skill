# Calibrating to the Person You're Talking To

The same project can be run for someone who has never written a line of code and for someone who
ships Android apps professionally. **The work is the same; the conversation is not.** This file
establishes who you're talking to, then tunes vocabulary, explanation depth, how much you ask
versus decide, and how much of the toolchain you handle yourself.

Get this wrong in either direction and the project stalls: a novice buried in `targetSdk` and ABIs
abandons the interview, and a professional Android developer told what an APK is stops trusting
you.

**Contents**

- [1 · The question](#1--the-question-ask-it-first) — ask it before anything else
- [2 · The five levels](#2--the-five-levels)
- [3 · The calibration table](#3--the-calibration-table) — what actually changes
- [4 · Two axes, not one](#4--two-axes-not-one) — the profile a single scale gets wrong
- [5 · Re-calibrating](#5--re-calibrating-mid-project) — self-assessment is unreliable
- [6 · Recording it](#6--recording-it-so-the-next-session-doesnt-reset)
- [7 · Plain-language glossary](#7--plain-language-glossary) — every term this skill uses
- [8 · Toolchain setup by level](#8--toolchain-setup-by-level)

---

## 1 · The question, asked first

**This is Q0 of the intake interview** (`intake-interview.md`) — before "what is this app for",
because it changes how every later question gets worded.

Ask it as a *tuning* question, never as a test. Nobody should feel screened:

> Before we start — how much software or Android experience do you have? I'll match how much I
> explain to your answer, and pick sensible defaults for anything you'd rather not decide. There's
> no wrong answer here, and you can tell me to speed up or slow down at any point.

Offer the levels below as pickable options. **Default to level 3 if they don't answer** — it
over-explains a little for an expert, which is recoverable in one sentence, while under-explaining
for a beginner loses them silently. Silent loss is the worse failure, which is the same reasoning
as every other default in this skill.

---

## 2 · The five levels

| | Level | Sounds like |
|---|---|---|
| **L1** | **Novice** | "I've never written code. I have an idea for an app." |
| **L2** | **Beginner** | "I've done some tutorials / scripts / spreadsheets with formulas, but never shipped anything." |
| **L3** | **Intermediate** | "I can program, but Android is new to me." |
| **L4** | **Advanced — professional software developer** | "I write software for a living, just not for Android." |
| **L5** | **Professional app developer** | "I ship Android or mobile apps professionally." |

**L3 and L4 are the most common and the most often mishandled.** Both know what a function, a
variable, a build, and version control are. Neither necessarily knows what AGP, an AVD, an ABI, or
`minSdk` is. The mistake is treating "knows how to program" as "knows Android" — they are unrelated,
and Android's vocabulary is unusually opaque even to strong engineers from other platforms.

---

## 3 · The calibration table

| | **L1 Novice** | **L2 Beginner** | **L3 Intermediate** | **L4 Pro SWE** | **L5 Pro Android** |
|---|---|---|---|---|---|
| **Programming words** (function, repo, build, dependency) | Avoid entirely | Explain on first use | Use freely | Use freely | Use freely |
| **Android words** (APK, AVD, ABI, `minSdk`) | Avoid; describe the effect | Explain every time | Explain on first use | Explain on first use | Use freely |
| **Explanation depth** | What it does for *them* | What + one-line why | What + why | Why + tradeoff | Tradeoff only |
| **Questions asked** | Only the judgement ones (Q1, Q7, Q9, Q10) | Those + form factor, style | Most of the ten | All ten | All ten, tersely |
| **Technical choices** | You decide, state it plainly | You decide, give the reason | Recommend, they confirm | Recommend with tradeoffs | Discuss as peers |
| **Toolchain install** | You do it; surface only physical steps (§8) | You do it; narrate briefly | You do it; show commands | Show commands, offer to run | Assume it exists |
| **On an error** | "I hit a snag, I'm fixing it" — don't paste a stack trace | Summarise, then fix | Summarise + the fix | Show the error + fix | Show the error |
| **Artifacts** (`APP_SPEC.md`, plan) | Written for you to *review*, plain prose | Plain prose + a terms list | Normal | Normal | Normal, terse |
| **Code shown unprompted** | No | No | On request | Yes | Yes |

Three rules that hold at **every** level, because they are about honesty rather than register:

- **Never fake certainty to sound simpler.** "It depends" simplified into a confident wrong answer
  is worse for a novice than for an expert, because they cannot catch it.
- **The house rules don't relax.** A silent failure is still the worst outcome, a guard is still
  never weakened to make something compile, and a judgement call is still escalated rather than
  guessed — you just explain *why* you're stopping in level-appropriate words.
- **Never say "obviously", "just", or "simply".** At L1–L3 these are the words that make someone
  stop asking questions, and someone who stops asking questions stops catching your mistakes.

---

## 4 · Two axes, not one

The five levels are a usable shorthand, but experience is really two independent things:

```
Android experience
      ^
  high|            .              L5
      |
      |                    L3/L4 land here when they
   low|   L1    L2         have shipped nothing Android
      +---------------------------------> General programming experience
         low                        high
```

**The high-programming / low-Android corner is the one a single scale gets wrong**, and it is
extremely common — an experienced backend, web, or systems engineer building their first Android
app. For them:

- **Keep** all general engineering vocabulary. Explaining what a build system or dependency
  injection is wastes their time and reads as condescension.
- **Explain** every Android-specific term on first use anyway — `minSdk` vs `targetSdk`, what an AVD
  is, why an ABI matters, what R8 does. They will not ask, because asking feels like admitting
  ignorance in their own field.
- **Be explicit about which Android conventions are non-obvious rather than bad.** Much of Android
  looks arbitrary from outside; saying "this is genuinely odd, here's why it exists" preserves trust
  better than presenting it as normal.

If someone's answers show this split — fluent about architecture, blank on Android specifics —
treat them as L4 on programming and L2 on Android, and say so: *"I'll skip the general
software explanations and flag the Android-specific things as they come up — tell me if I get that
balance wrong."*

---

## 5 · Re-calibrating mid-project

**Self-assessment is unreliable in both directions**, so treat Q0's answer as a starting estimate,
not a fact. Adjust on evidence and say that you're doing it.

| Signal | Move |
|---|---|
| Uses precise Android terms unprompted ("I'd rather use a bound service") | **Up.** Stop explaining that layer |
| Asks what a word you just used means | **Down one level**, for that domain only |
| Answers a technical question with "whatever you think" repeatedly | **Down**, or they're just delegating — ask which |
| Corrects you on an Android detail | **Up**, and take the correction seriously |
| Pastes a stack trace or a logcat dump | **Up** on tooling at least |
| Goes quiet after a dense message | **Down.** Silence after complexity is the clearest signal there is |

That last row matters most. A novice rarely says "you lost me" — they go quiet, or agree with
everything. **Treat sudden agreement with a complex message as a comprehension failure until proven
otherwise**, and re-state it in plainer words without making it awkward.

Moving *up* is cheap and painless. Moving *down* needs care: re-explain the thing, don't announce
that you've downgraded them.

---

## 6 · Recording it, so the next session doesn't reset

A cold session that re-derives the register from scratch will get it wrong, and the whiplash
between a plain-language session and a jargon-dense one is worse than either consistently.

**Write the level into `CLAUDE.md` at Phase 1**, alongside the other orientation facts:

```markdown
## Who this is for
Audience level: L3 (intermediate — programs confidently, new to Android).
Explain Android-specific terms on first use; general programming terms are fine.
Adjusted from L2 after session 3 — they were more comfortable than the intake suggested.
```

Include *why* it was set and any adjustment, so the next session inherits the evidence rather than
just the verdict. This is the same discipline the skill applies to architecture decisions: record
the reasoning, not only the conclusion.

---

## 7 · Plain-language glossary

Every term this skill uses, in one line each. **At L1–L2 use the right-hand column instead of the
term; at L3–L4 use the term and give the plain version once, on first use.**

### Things the user will actually see or hold

| Term | Say instead |
|---|---|
| **APK** | The app file that gets installed on a phone |
| **AAB** (Android App Bundle) | The package format the Play Store wants; it makes the right APK per device |
| **Sideload** | Installing an app directly, without going through an app store |
| **Emulator / AVD** (Android Virtual Device) | A simulated phone running on your computer |
| **Real hardware / real device** | An actual physical phone, tablet or watch |
| **Debug build** | A test version — bigger, slower, easier to inspect |
| **Release build** | The real version — smaller and faster; the one you actually ship |
| **Keystore / signing** | The digital signature proving the app came from you. Lose it and you can't update the app |

### Version and compatibility

| Term | Say instead |
|---|---|
| **API level** | Android's version number for developers (36 = Android 16) |
| **`minSdk`** | The oldest Android version that can install the app |
| **`targetSdk`** | Which Android version's rules the app follows. **Not** a compatibility floor |
| **`compileSdk`** | Which version's toolkit the app is built against. Invisible to users |
| **ABI** | The chip type the app's low-level code is built for (most phones: `arm64-v8a`) |
| **16 KB pages** | A newer memory layout; only matters if the app contains low-level native code |

### Build tooling

| Term | Say instead |
|---|---|
| **Gradle** | The tool that turns the source code into an app file |
| **AGP** (Android Gradle Plugin) | The Android-specific part of that build tool |
| **KGP / KMP** | Kotlin's build plugin / sharing code across platforms |
| **JDK** | The Java toolkit the build runs on |
| **SDK** | Android's development toolkit |
| **NDK** | The extra toolkit needed only for low-level native code |
| **Version catalog** | One file listing every version, so nothing drifts out of sync |
| **`sdkmanager` / `avdmanager`** | Command-line tools that install Android pieces / create simulated phones |
| **R8 / ProGuard / minify** | Shrinks and obfuscates the app for release |
| **Keep rule** | An instruction telling the shrinker not to delete something it can't see is used |
| **dex** | The compiled-code files inside an app package |
| **Jetifier** | An obsolete compatibility shim. Its presence is now an error |

### Running and debugging

| Term | Say instead |
|---|---|
| **ADB** (Android Debug Bridge) | The command-line tool for talking to a phone or emulator from your computer |
| **logcat** | The phone's running log of what apps are doing |
| **`aapt2` / `apksigner`** | Tools that inspect an app file / check its signature |
| **Stack trace** | The error report showing where a crash happened |
| **USB debugging** | A phone setting that lets your computer install and inspect apps |
| **WHPX / AEHD / HAXM** | Windows features that make the emulator run at usable speed |

### Architecture and code

| Term | Say instead |
|---|---|
| **Jetpack Compose** | The modern way to build Android screens |
| **Hilt** | A library that wires the app's pieces together |
| **Room** | The app's local database |
| **DataStore** | Where small settings and preferences are saved |
| **Domain module** | The pure logic layer, with no Android code in it |
| **Monorepo / subtree split** | One repo holding several projects / extracting one into its own repo |
| **ADR** (Architecture Decision Record) | A short note recording why a decision was made |
| **`WindowSizeClass`** | How the app decides whether it's on a phone-sized or tablet-sized screen |
| **Insets** | The screen areas covered by system bars, notches and the keyboard |
| **Edge-to-edge** | Drawing under the status and navigation bars. Now mandatory |
| **Predictive back** | The swipe-back gesture that previews where you're going |
| **Doze** | Android's battery saving mode, which pauses background work |

### Testing and release

| Term | Say instead |
|---|---|
| **Journeys** | Test scenarios written as plain instructions an agent runs on a device |
| **Roborazzi / screenshot test** | Saves a picture of each screen and warns when it changes unexpectedly |
| **Regression test** | A test that proves a bug that was fixed hasn't come back |
| **Fault injection** | Deliberately breaking something to see how the app copes |
| **MASVS / MASTG** | An industry security checklist with stable numbered items |
| **mDNS / NSD** | How apps find devices on the local network automatically |
| **GPP** (Gradle Play Publisher) | A tool that uploads releases to the Play Store for you |
| **Developer verification** | Google's new requirement to prove your identity to distribute apps |

---

## 8 · Toolchain setup by level

**The important fact, and it is easy to miss inside a 440-line reference: almost none of
`windows-toolchain-and-emulators.md` is work for the user.** It is work for *you*. Only a handful of
steps genuinely need a human, because they involve a download, a system dialog, a reboot, or
physical hardware.

**The human steps, in full:**

1. Install the Java toolkit (a `winget` command, or a download and an installer).
2. Install Git (same).
3. Download the Android command-line tools zip.
4. Turn on **Windows Hypervisor Platform** in *Turn Windows features on or off* — **and reboot**.
5. Plug in a phone and enable USB debugging, if testing on real hardware.

Everything else — creating emulators, installing SDK packages, accepting licences, building,
installing, launching, reading logs — is yours to run.

| Level | How to handle setup |
|---|---|
| **L1–L2** | Do it all. Give them **only** the five steps above, one at a time, as literal click-by-click instructions. Never paste a command block and ask them to run it. Confirm each step worked before moving on, and check with `scripts/preflight.sh` rather than asking "did that work?" |
| **L3–L4** | Do it, but show the commands as you go and say what each is for. Hand them the five human steps as a short list up front, so they know what's coming and can do them while you work. |
| **L5** | Point at the reference and `scripts/preflight.sh`. Ask only whether their setup already exists. |

Two things worth saying at **every** level, because both cost real time:

- **The reboot after enabling Windows Hypervisor Platform is not optional.** Without it the emulator
  is not merely slow, it looks hung.
- **On Windows, `android emulator` does not work** — emulators are created manually there
  (`ecosystem.md` §1). This is a limitation of the tool, not something the user did wrong; say so,
  or an L1–L2 user will assume they broke it.

At L1–L2, prefer **Android CLI** (`ecosystem.md` §1) for everything it covers. Fewer moving parts
means fewer places for a novice-facing setup to fail in a way neither of you can diagnose.
