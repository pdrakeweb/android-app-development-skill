# Target-SDK Gotchas — What Breaks When You Raise `targetSdk`

Every time an app raises `targetSdk` (the Android version whose rules it agrees to follow), it
opts into that version's new rules. Most are harmless. A few make a working app crash, stop doing
something without telling anyone, or look wrong. This appendix lists the ones a typical app is
likely to hit, oldest first, in plain words: **what changes, what you will actually see, and what
to do.**

`platform-currency.md` §4 covers the Android 16 (API 36) changes in more depth, because Play
requires that target today. This file is the wider map.

**How to use it.**

- **Raising `targetSdk` by several versions at once?** Walk every row between the old target and
  the new one. The rules stack.
- **"What you'll see" matters most.** The worst rows are the silent ones: nothing crashes, a
  feature just stops working. Each of those needs a check that would notice (a test, a scenario,
  an assertion on the result) — the same "verify the artifact" discipline as `testing-and-bugs.md`
  §6.
- **Sources are Google's behaviour-change pages**, checked 2026-11-11. Each version has two
  pages: changes for apps *targeting* that version, and changes for *all* apps running on it. When
  this file and those pages disagree, the pages win.

Glossary for this file: **`targetSdk`** — the Android version whose rules the app follows (not
the oldest it runs on; that is `minSdk`). **Foreground service** — background work the user can
see, shown by an ongoing notification. **`PendingIntent`** — a "do this later on my behalf" token
handed to the system (notifications, alarms, widgets). **Exported** — whether other apps are
allowed to start a component.

---

## API 31 · Android 12

| What changes | What you'll see | What to do |
|---|---|---|
| Every activity, service or receiver with an intent filter must say whether other apps may start it (`android:exported`) | Build fails at manifest merge, or the APK refuses to install | Set `android:exported` on every component that has an intent filter: `true` only for the launcher activity and anything another app must reach |
| Every `PendingIntent` must say whether it can be changed later | Crash when the `PendingIntent` is created (lint warns first) | Add `FLAG_IMMUTABLE` unless the system genuinely needs to fill something in (some notification replies, bubbles), then `FLAG_MUTABLE` |
| Starting a foreground service while the app is in the background is blocked | Crash (`ForegroundServiceStartNotAllowedException`) — often only on real phones, after the app has been backgrounded | Start foreground services only from something the user just did; use WorkManager "expedited" work for the rest |
| Exact alarms need special permission | Alarms are not exact, or never set | Declare `SCHEDULE_EXACT_ALARM`, check `canScheduleExactAlarms()` before every exact alarm, fall back to an inexact one (see API 33/34 rows — it gets stricter) |
| Tapping a notification can no longer bounce through a service or receiver to open a screen ("trampoline") | Tap does nothing; logcat says *"Indirect notification activity start (trampoline)"* | Point the notification's `PendingIntent` straight at the activity |
| New Bluetooth permissions | Scanning or connecting fails | Request `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` / `BLUETOOTH_ADVERTISE` instead of the old location-based set |
| Backup rules moved to a new file format | Your include/exclude rules are ignored for device-to-device transfers | Write `data_extraction_rules.xml` with separate `<cloud-backup>` and `<device-transfer>` sections and point `android:dataExtractionRules` at it |
| Users can grant only approximate location | You get a coarse location when you asked for a precise one | Handle coarse fixes; ask for precise only from the feature that needs it |

## API 33 · Android 13

| What changes | What you'll see | What to do |
|---|---|---|
| Notifications need a runtime permission (`POST_NOTIFICATIONS`) | Notifications silently never appear, including the notice for a running foreground service | Ask from the feature that sends the first notification; treat denial as "feature degraded", never as a dead button |
| Reading other apps' photos, video or audio needs new, separate permissions | Media access denied | Use the system photo picker where you can (no permission at all); otherwise `READ_MEDIA_IMAGES` / `_VIDEO` / `_AUDIO` |
| Wi-Fi features (Wi-Fi Direct, local hotspot, nearby device discovery) get their own permission | Wi-Fi operations blocked | Request `NEARBY_WIFI_DEVICES`, with `neverForLocation` if you don't derive location from it |
| Background body-sensor access needs a second permission | Heart-rate or other sensor reads fail in the background | Declare `BODY_SENSORS_BACKGROUND` too (replaced again at API 36 — see that row) |
| If the user puts the app in the "restricted" battery state, boot broadcasts are held back | Start-up work after a reboot (re-scheduling reminders, for example) silently never runs | Re-schedule on the next app launch as well as on boot |
| `setForceDark()` in WebView stops working | Web content switches light/dark unexpectedly | Remove it; use `setAlgorithmicDarkeningAllowed()` |
| Apps using the advertising ID must declare `AD_ID` | The ID silently becomes all zeros | Declare the permission, or confirm an SDK's manifest already does |

## API 34 · Android 14

| What changes | What you'll see | What to do |
|---|---|---|
| **Every foreground service must declare a type**, and hold the matching `FOREGROUND_SERVICE_<TYPE>` permission | Crash when the service starts | Pick the type that matches what the service does (`health`, `dataSync`, `mediaPlayback`…). Some types need another permission granted first — check before starting |
| Exact alarms are **not granted by default** to new installs (this applies to all apps targeting 33+ on Android 14) | Reminders and timers drift or never fire, with no error | Check `canScheduleExactAlarms()`; if false, either send the user to the system setting with an explanation or accept an approximate time and say so in the UI |
| Implicit intents can't reach your own unexported components | `ActivityNotFoundException`, or a broadcast that never arrives | Use explicit intents (set the package or class) inside your own app |
| Receivers registered in code must say whether other apps can send to them | Crash at registration | Pass `RECEIVER_EXPORTED` or `RECEIVER_NOT_EXPORTED` |
| Starting an activity from the background through a `PendingIntent` needs an explicit opt-in | The screen silently doesn't open | Use the `ActivityOptions` background-start opt-in only where it is genuinely the user's intent |
| `JobScheduler` jobs with network constraints need `ACCESS_NETWORK_STATE` | `SecurityException` | Declare the permission (WorkManager users usually get it through the library) |
| Zip entries with `..` or a leading `/` are rejected | `ZipException` while unzipping | Sanitize entry names; never disable the check |
| Users can grant access to only *some* photos | Your gallery shows fewer items than expected | Use the photo picker, or handle partial access with `READ_MEDIA_VISUAL_USER_SELECTED` |
| Full-screen notifications (`USE_FULL_SCREEN_INTENT`) limited to calling and alarm apps | Heads-up shows instead of the full-screen screen | Check `canUseFullScreenIntent()`; don't build on it unless you are an alarm or calling app |

On Android 14 regardless of target: broadcasts registered in code are **queued while the app is
in the background** and may be merged, and system font scaling goes up to 200% — test layouts at
200%.

## API 35 · Android 15

| What changes | What you'll see | What to do |
|---|---|---|
| **Edge-to-edge is enforced**: the app draws behind the status and navigation bars | Top bars, buttons and list items hidden under system bars; status-bar colour calls do nothing | Handle window insets (Material 3 components and `Scaffold` padding do most of it). The theme opt-out stops working at API 36, so don't rely on it |
| `dataSync` and `mediaProcessing` foreground services get a **6-hour-per-day budget** | Crash if the service doesn't stop when told; refusal to start once the budget is spent | Implement `onTimeout()` and call `stopSelf()`; move long transfers to WorkManager |
| Boot receivers can't start several foreground-service types (`dataSync`, `camera`, `mediaPlayback`, `microphone`, …) | Crash at boot | Defer the work to WorkManager or to the next time the user opens the app |
| Kotlin's `removeFirst()` / `removeLast()` now resolve to a new Java method when you compile against API 35 | **Crash on Android 14 and older** (`NoSuchMethodError`), even though it compiled fine | Use `removeAt(0)` / `removeAt(list.lastIndex)`; never suppress the `NewApi` lint warning that flags it |
| TLS 1.0 and 1.1 are refused | Network calls to old servers fail | Fix the server, or the library negotiating the connection |
| Screen-size values in `Configuration` now include the system bars | Layout maths is off by the bar height | Use window metrics or insets, not `Configuration` sizes, for layout |
| Apps can only take audio focus when visible or running a foreground service | `requestAudioFocus()` quietly fails | Request focus from the visible app or a foreground service, and handle the failure |
| 16 KB memory pages (Play requirement for apps targeting 35+, with native code — including inside SDKs you use) | Play blocks the update; crashes on 16 KB devices | See `platform-currency.md` §4 |

## API 36 · Android 16

Full detail in `platform-currency.md` §4. In short:

| What changes | What you'll see | What to do |
|---|---|---|
| Edge-to-edge opt-out removed | Content under system bars, with no way to switch it off | Handle insets |
| Predictive back is on: `onBackPressed()` is no longer called | Unsaved-work guards and "are you sure?" checks silently stop working | Use `OnBackPressedDispatcher` / Compose `BackHandler` |
| Orientation and aspect-ratio locks ignored on tablets and foldables | A portrait-only layout gets stretched into a landscape tablet window; rotation recreates screens and drops unsaved state | Make layouts adaptive; save UI state across recreation |
| `BODY_SENSORS` replaced by Health Connect-style health permissions | Heart-rate and similar sensor reads fail | Request `READ_HEART_RATE` (etc.) and `READ_HEALTH_DATA_IN_BACKGROUND`; on phones, declare an activity that shows your privacy policy or the permission is revoked |
| `elegantTextHeight` ignored | Text in some scripts (Arabic, Thai, Tamil, …) renders taller and may clip | Test those languages; don't fix heights in pixels |
| `scheduleAtFixedRate` no longer replays every missed run | A periodic task runs fewer times than it used to after the app was paused | Don't depend on catch-up bursts |
| Local network access becomes a permission (opt-in testing now) | Connections to LAN devices fail with `EPERM` once enforced | Prepare for API 37's `ACCESS_LOCAL_NETWORK` |

## API 37 · Android 17

| What changes | What you'll see | What to do |
|---|---|---|
| **Talking to devices on the local network needs `ACCESS_LOCAL_NETWORK`** (a runtime permission in the Nearby devices group) | Connections to home servers, printers, cameras, casting targets, or a LAN AI server fail | Use a system device picker where one exists (no permission needed), or request the permission from the feature that uses the LAN. DNS to a local resolver is exempt. Below 37 the permission is implicitly granted, so the break appears only when you raise the target |
| The tablet orientation opt-out from API 36 stops working | Portrait-only layouts are stretched on tablets, with no escape hatch left | Adaptive layouts, tested on a tablet |
| Writing to `static final` fields by reflection or JNI is blocked | `IllegalAccessException` or a native crash | Stop doing it (often an old library or test helper) |
| Background activity-start rules tightened further, including `IntentSender` | Screens silently don't open | Replace the blanket "allowed" mode with a narrower one, e.g. "allow if visible" |
| Certificate Transparency is on by default | HTTPS fails against servers using private or internal certificates | Check your endpoints; configure in the network security config if you must |
| Native libraries loaded at run time must be read-only | `UnsatisfiedLinkError` | Mark the file read-only before loading; avoid dynamic code loading |
| Background audio is restricted | Playback, focus or volume changes from the background are blocked | Run a foreground service while working with audio |
| Widget bitmaps have a memory limit | Widget updates throw `IllegalArgumentException` | Downsample images to the widget's size |
| `setContentCaptureEnabled(false)` is ignored | Screen content is still captured | Use `FLAG_SECURE` on windows that must not be captured |

---

## What no `targetSdk` warns you about

These come from manufacturers and real-world use rather than from Google's tables, and they
cause the same "it worked yesterday" reports:

- **Manufacturer battery managers.** Samsung, Xiaomi, OPPO, OnePlus and others add their own
  background limits on top of Android's. An app unused for a couple of weeks can be moved into a
  "deep sleep" state where alarms, WorkManager jobs and boot receivers are throttled or skipped,
  with no error anywhere.
- **System updates resetting exemptions.** An over-the-air update can silently undo "don't
  optimize battery" or "allow autostart" settings the user granted.
- **Doze on an idle phone** delays alarms and jobs for hours at a time.

What helps: re-schedule important work whenever the app is opened (not only on boot); show the
user the app's real status ("last reminder fired 08:00") so silent failure becomes visible; and
test on a real device left untouched for days, not only on an emulator.

Sources: Google's behaviour-change pages for each version —
<https://developer.android.com/about/versions/12/behavior-changes-12>,
<https://developer.android.com/about/versions/13/behavior-changes-13>,
<https://developer.android.com/about/versions/14/behavior-changes-14>,
<https://developer.android.com/about/versions/14/behavior-changes-all>,
<https://developer.android.com/about/versions/15/behavior-changes-15>,
<https://developer.android.com/about/versions/16/behavior-changes-16>,
<https://developer.android.com/about/versions/17/behavior-changes-17> — and one production
write-up of manufacturer battery behaviour
(<https://dev.to/stoyan_minchev/i-pushed-my-android-app-to-production-then-android-and-the-oems-spent-two-weeks-tearing-it-apart-1e70>).
All checked 2026-11-11.
