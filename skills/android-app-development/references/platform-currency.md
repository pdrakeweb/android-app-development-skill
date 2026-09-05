# Platform Currency — Pins, Deadlines, and Breaking Changes

Android's toolchain moves fast enough that a cold session working from training data will scaffold a
project that does not build. This file is the antidote: a dated pin table, the platform behaviours
that break a working app, and the Play policy deadlines that decide whether a build is publishable
at all.

**Contents**

- [1 · The pin table](#1--the-pin-table) — verified versions, as of a stated date
- [2 · How to re-verify](#2--how-to-re-verify-when-this-file-is-stale) — when this file goes stale
- [3 · AGP 9 is a hard break](#3--agp-9-is-a-hard-break)
- [4 · API 36 behaviours that break working apps](#4--api-36-behaviours-that-break-working-apps)
- [5 · Play distribution deadlines](#5--play-distribution-deadlines)
- [6 · Developer verification](#6--developer-verification-and-the-personal-apk)
- [7 · Wear OS requirements](#7--wear-os-requirements)
- [8 · Emulator acceleration on Windows](#8--emulator-acceleration-on-windows)
- [9 · Plain English ↔ API levels](#9--plain-english--api-levels) — translating the intake answer

---

## 1 · The pin table

**Verified 2026-09-04 against developer.android.com.** Everything downstream — the scaffold, the
version catalog, the emulator images, the release build — depends on these. Put them in
`gradle/libs.versions.toml` so nothing can drift, and restate the row you relied on in
`docs/APP_SPEC.md` §2.

| Thing | Pin | Why this value |
|---|---|---|
| **AGP** | **9.4.0** (September 2026) | Current stable |
| **Gradle** | **9.6.0** | AGP 9.4's minimum *and* default — 9.1 is not enough |
| **JDK** | **17** | AGP 9.4 minimum and default. Pick a JDK at or above every plugin in the build ([JDK guide](https://developer.android.com/build/jdks)) |
| **SDK Build Tools** | **36.0.0** | AGP 9.4 minimum and default |
| **NDK** (only if native code) | **28.2.13676358** | AGP 9.4 default |
| **compileSdk** | **37** | Android 17 is stable; compile against the newest stable SDK (see below) |
| **targetSdk** | **36** | Required by Play since 2026-08-31 (§5) |
| **minSdk** | **28** | The observed floor across this corpus; raise it, don't lower it, without a reason |
| **Wear OS / Automotive targetSdk** | **35** | Play's form-factor exception (§5) |
| **TV / XR targetSdk** | **34** | Play's form-factor exception (§5) |
| **Max API supported by AGP 9.4** | 37 | Ceiling, not a recommendation |

> **`compileSdk` and `targetSdk` move on different schedules, and that is deliberate.**
> `compileSdk` should track the newest *stable* SDK, because compiling against it surfaces
> deprecations early and costs nothing at runtime — it does not change a single behaviour on a
> device. `targetSdk` is what opts the app into a new release's behaviour changes, so it moves when
> Play requires it and you have tested those changes, not before. Android 17 (API 37) is stable, so
> `compileSdk 37` with `targetSdk 36` is the correct pairing today. Only the QPR releases are in
> beta; never point `compileSdk` at one of those.

**Rule of thumb:** `compileSdk` = newest stable. `targetSdk` = what Play requires and you have
tested. `minSdk` = how old a phone must still run it. Raising `compileSdk` never drops a device.

**Kotlin Gradle Plugin:** AGP 9 introduces built-in Kotlin (§3), which changes how KGP is applied
and pins a minimum. *"Android Gradle plugin 9.0 now has a runtime dependency on Kotlin Gradle plugin
(KGP) **2.2.10**"* — a lower version is silently upgraded to it
(<https://developer.android.com/build/releases/agp-9-0-0-release-notes>). Re-read that page rather
than the migration guide when you need the number; the migration guide does not carry it.

---

## 2 · How to re-verify when this file is stale

This table has a shelf life measured in weeks. **If the date above is more than a month or two old,
re-verify before scaffolding** rather than trusting it. Three sources, in order:

1. `android sdk list` and the AGP release notes at
   <https://developer.android.com/build/releases/gradle-plugin> — the compatibility table near the
   top gives Gradle/JDK/Build-Tools minimums directly.
2. <https://developer.android.com/about/versions> — is the newest API level stable or beta?
3. Google's own `agp-9-upgrade` skill, which is maintained against the toolchain rather than
   written down once (`ecosystem.md`).

**When this file and a Google skill disagree, the Google skill wins.** This one is a snapshot; that
one is maintained. Correct this file when you notice.

---

## 3 · AGP 9 is a hard break

Not a version bump. A project generated from AGP 8-era knowledge will not build, and the errors do
not name the real cause. The changes that bite:

- **Built-in Kotlin.** You no longer apply `org.jetbrains.kotlin.android` — AGP provides Kotlin
  itself. The old plugin is *not compatible* with the new DSL. This is the one that most often
  produces a wall of confusing configuration errors on a scaffold copied from an older template.
- **The old variant API is gone.** AGP 9 uses the new DSL interfaces exclusively. Two
  `gradle.properties` bridges exist — `android.newDsl=false` project-wide, `android.newDsl.optOut=:module`
  per module — and both go away in AGP 10. Treat them as a deadline, not a setting.
- **`kapt` is incompatible with built-in Kotlin.** *"The `org.jetbrains.kotlin.kapt` (or
  `kotlin-kapt`) plugin is incompatible with built-in Kotlin"*
  (<https://developer.android.com/build/migrate-to-built-in-kotlin>). This skill's default stack
  includes Hilt, so a template carrying `kapt` walks straight into it — move to KSP.
- **`android.enableJetifier` is obsolete.** It is off by default and slated for removal in AGP 10; if
  it is in an inherited `gradle.properties`, delete it and move the offending dependency to its
  AndroidX version. AGP 9 does *not* fail the build on it — the two properties it does error on are
  `android.r8.integratedResourceShrinking` and `android.enableNewResourceShrinker.preciseShrinking`
  (<https://developer.android.com/build/releases/agp-9-0-0-release-notes>).
- **KMP modules move to `com.android.kotlin.multiplatform.library`**, off `com.android.library`.

**Do not hand-write an AGP 9 migration from this list.** It is here so you recognise the symptoms.
For the actual work, install Google's `agp-9-upgrade` skill (`ecosystem.md`) — it is maintained
against the toolchain and this list is not.

---

## 4 · API 36 behaviours that break working apps

These fire when `targetSdk` reaches 36, which Play now requires (§5). Each one has shipped as a
"the app worked yesterday" bug report.

- **Edge-to-edge is mandatory and cannot be opted out of.** The
  `windowOptOutEdgeToEdgeEnforcement` flag is deprecated and disabled. Content will draw under the
  status and navigation bars whether the layout handles insets or not. **Any app targeting 36 must
  handle window insets deliberately** — this is now a correctness requirement, not polish, and it
  belongs on the audit checklist (`testing-and-bugs.md`) and in every screenshot review. Google
  ships an `edge-to-edge` skill for the migration.
- **Predictive back is on by default.** `onBackPressed()` is no longer called and
  `KeyEvent.KEYCODE_BACK` is no longer dispatched. An app relying on either for "are you sure?"
  interception, unsaved-draft guards, or custom back handling **loses that behaviour silently** —
  the back gesture simply works, and whatever the override was protecting is gone. This is exactly
  the silent-failure class this skill's house rules are built around. Migrate to
  `OnBackPressedDispatcher` / `BackHandler`. `android:enableOnBackInvokedCallback="false"` on the
  `<application>` or `<activity>` buys time and is a bridge, not a fix
  (<https://developer.android.com/about/versions/16/behavior-changes-16>).
- **Orientation and resizability restrictions are ignored on large screens.** On displays with
  smallest width ≥ 600dp, manifest `screenOrientation`, aspect-ratio and `resizeableActivity`
  restrictions do not apply. A portrait-locked phone layout will be handed a landscape tablet
  window. If the app is a kiosk or a remote-control surface that assumed a locked orientation
  (intake Q2), that assumption is void on tablets — test it there. Two documented escapes exist and
  both expire: the `android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY` manifest property,
  which stops working once `targetSdk` reaches 37, and an exception for apps declaring
  `android:appCategory="game"`
  (<https://developer.android.com/about/versions/16/behavior-changes-16>). Use the property to buy
  migration time, never as the destination.
- **16 KB memory pages.** This one does *not* wait for `targetSdk` 36 — it fires at **35**: *"all
  apps targeting Android 15 (API level 35) and higher must support 16 KB memory page sizes on 64-bit
  devices on Google Play"*, with Play blocking non-compliant updates from **2027-02-01**
  (<https://developer.android.com/guide/practices/page-sizes>). "Uses native code" includes native
  code you never wrote: *"Your app links with any third-party native libraries or dependencies (such
  as SDKs) that use them."* A pure Kotlin app with one analytics or ML SDK is in scope. Prebuilt
  `.so` files must be recompiled and reimported, not just repackaged. `android:pageSizeCompat` is a
  short-term bridge, not a fix.

---

## 5 · Play distribution deadlines

Verified 2026-09-04. **The API 36 requirement is already in force.**

| Requirement | Level | Since |
|---|---|---|
| New apps and updates | **targetSdk 36** | 2026-08-31 |
| Wear OS, Automotive | targetSdk 35 | 2026-08-31 |
| Android TV, XR | targetSdk 34 | 2026-08-31 |
| Existing apps, to stay visible to *new* users on newer devices | targetSdk 35 | — |

An extension to **2026-11-01** can be requested through the Play Console. Missing the deadline does
not remove an app; it blocks *updates*, and drops it out of search for new users on newer devices.

This matters at intake, not at release: if the answer to Q10 is "Play Store", `targetSdk 36` is a
constraint on the spec, and every API-36 behaviour in §4 is in scope from the first commit.

---

## 6 · Developer verification, and the "personal APK"

A new constraint that lands directly on this skill's personal-APK house rule.

- From **2026-09-30**, in **Brazil, Indonesia, Singapore and Thailand**, apps installed from
  participating app stores on certified Android devices must be registered by a verified developer.
  Global rollout follows in **2027**.
- **ADB sideloading remains the escape hatch**, and there is an explicit "advanced flow" for power
  users installing from unverified developers. A build you install on your own device with
  `adb install` is not affected.
- **Limited distribution accounts** exist for hobbyists, students and teachers: no government ID, no
  fee, and sharing with **up to 20 devices**. This is the right answer for most "a handful of named
  people" projects, and it did not exist when the corpus's projects were built.

**What to do with it:** intake Q10 ("who gets the APK, and how?") now has a fourth consequence
beyond credentials, signing, and R8 — *which distribution identity does this need?* Record the
answer in the spec. For a genuinely personal build, write down that ADB install is the distribution
channel, so a future session doesn't panic-register an account it doesn't need.

---

## 7 · Wear OS requirements

- **64-bit support is required from 2026-09-15.** New apps and updates containing native code must
  ship both 32-bit and 64-bit. Play blocks non-compliant uploads after that date, and continues
  delivering 32-bit packages to older watches — so this is an *addition*, not a migration. Pure
  Kotlin/Java Wear apps are unaffected.
- **Watch Face Format is required since January 2026** for installing watch faces on Wear OS
  devices. A watch face built the old way will not install.
- Wear/Automotive `targetSdk` floor is 35, not 36 (§5).

---

## 8 · Emulator acceleration on Windows

**Use Windows Hypervisor Platform (WHPX).** It is Google's recommendation and the emulator's
default on Windows.

- **HAXM is dead.** Intel discontinued it; from emulator **36.2.x.x** the emulator no longer uses it.
- **AEHD (Android Emulator hypervisor driver) is sunset on 2026-12-31.** It still works until then.
  Do not install it on a new machine — you would be adopting something with a known expiry date.

Setup detail is in `windows-toolchain-and-emulators.md` §1.5.

---

## 9 · Plain English ↔ API levels

Nobody outside Android development thinks in API levels, and the intake interview deliberately does
not ask for one (`intake-interview.md` Q4). This is the translation table — the user answers in
phones and years, you write down a number.

Dates below are **platform-stability** dates from
<https://developer.android.com/tools/releases/platforms> — when the SDK froze, which runs ahead of
when phones got the OS. Use them for ordering, not as ship dates.

| Android | API | SDK stable | Roughly |
|---|---|---|---|
| 17 | 37 | 2026 | Current stable — what `compileSdk` tracks |
| 16 | 36 | Mar 2025 | The `targetSdk` Play requires |
| 15 | 35 | Jun 2024 | Last year's phones |
| 14 | 34 | Jun 2023 | |
| 13 | 33 | Jun 2022 | |
| 12 | 31 | Aug 2021 | **"anything from the last ~5 years"** |
| 11 | 30 | Jul 2020 | |
| 10 | 29 | 2019–20 | |
| 9 | 28 | Aug 2018 | **"anything still in real use"** — this corpus's floor |
| 8.0 | 26 | Aug 2017 | Below here, expect real work |
| 7.0 | 24 | Aug 2016 | |

**Mapping the intake answers:**

| They said | Set `minSdk` |
|---|---|
| Just my own device(s) | Whatever that device runs — ask, don't guess |
| Anything from the last ~5 years | **31** (or 28 if it costs nothing) |
| Anything still in real use | **28** |
| A specific old device I own | That device's version — confirm it by name |

Three things to keep straight when using this table:

- **The date is when the SDK stabilized, not how old the phone is.** Phones receive OS updates
  for years, so a 2021 handset may well be running Android 14 today. A device's *current* version
  is what matters for whether the app installs; its shipped version only bounds the worst case.
- **`targetSdk` is not on this table by choice.** It is 36 because Play requires 36 (§5), on every
  row. Lowering `minSdk` does not lower it, and raising it does not raise `minSdk`. See the
  explainer in `intake-interview.md` Q4.
- **Don't quote market-share percentages from memory.** If the decision actually hinges on how many
  devices a floor reaches, read the current distribution numbers in Android Studio's new-project
  dialog or the Play Console rather than inventing a figure — this is exactly the "value computed
  from nothing" the house rules forbid.

**What a lower `minSdk` actually costs**, so the tradeoff can be stated honestly rather than
hand-waved: some newer APIs need a runtime version check and a fallback path; some Jetpack
libraries raise their own floor over time; and every supported version below the test device is a
version nobody has actually run the app on unless you add an emulator for it. None of that is
prohibitive down to 28 — it is why 28 is this corpus's floor rather than something higher.
