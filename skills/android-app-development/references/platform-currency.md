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
| **JDK** | **17** | AGP 9.4 minimum and default. A newer JDK is not a drop-in substitute |
| **SDK Build Tools** | **36.0.0** | AGP 9.4 minimum and default |
| **NDK** (only if native code) | **28.2.13676358** | AGP 9.4 default |
| **compileSdk** | **36** | See the warning below — **not** 37 |
| **targetSdk** | **36** | Required by Play since 2026-08-31 (§5) |
| **minSdk** | **28** | The observed floor across this corpus; raise it, don't lower it, without a reason |
| **Wear OS / Automotive targetSdk** | **35** | Play's form-factor exception (§5) |
| **TV / XR targetSdk** | **34** | Play's form-factor exception (§5) |
| **Max API supported by AGP 9.4** | 37 | Ceiling, not a recommendation |

> **compileSdk 36, not 37.** AGP 9.4 *supports* API 37, and it is tempting to reach for the highest
> number the toolchain accepts. **Android 17 (API 37) is still in beta** as of this file's
> verification date — it ships as QPR betas with API-diff pages against API 36. Compiling a
> first project against a beta SDK buys nothing and costs a class of failures that are
> indistinguishable from your own bugs. Use 36 until Android 17 goes stable, then move
> `compileSdk` first and `targetSdk` only when Play requires it.

**Kotlin Gradle Plugin:** AGP 9 introduces built-in Kotlin (§3), which changes how KGP is applied
and pins a minimum version. That minimum was **not verified first-hand** for this file — do not
copy a number from memory into a version catalog. Read
<https://developer.android.com/build/migrate-to-built-in-kotlin> or install Google's
`agp-9-upgrade` skill (see `ecosystem.md`) and take the value from there.

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
- **The old variant API is gone.** AGP 9 uses the new DSL interfaces exclusively. A
  `gradle.properties` opt-out (`android.newDsl.optOut=:module`) exists as a migration bridge and
  becomes unavailable in AGP 10 — treat it as a deadline, not a setting.
- **Non-final resource IDs are the default.** `when (view.id) { R.id.x -> ... }` no longer compiles,
  because a `when` on a non-constant needs `if/else` branches. Mechanical to fix, baffling if you
  don't know why.
- **`android.enableJetifier` now throws a build error** rather than warning. If it's in an inherited
  `gradle.properties`, delete it and deal with whatever support-library dependency put it there.
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
  `OnBackPressedDispatcher` / `BackHandler`.
- **Orientation and resizability restrictions are ignored on large screens.** On displays with
  smallest width ≥ 600dp, manifest `screenOrientation`, aspect-ratio and `resizeableActivity`
  restrictions do not apply. A portrait-locked phone layout will be handed a landscape tablet
  window. If the app is a kiosk or a remote-control surface that assumed a locked orientation
  (intake Q2), that assumption is void on tablets — test it there.
- **16 KB memory pages** for any native `.so`. Only relevant with native code or a vendor SDK.
  `android:pageSizeCompat` is a short-term bridge, not a fix.

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
