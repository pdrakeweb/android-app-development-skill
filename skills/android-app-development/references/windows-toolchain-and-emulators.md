# Windows Toolchain and Emulator Setup

How to go from a **fresh Windows machine with nothing installed** to phone, tablet, and Wear OS
emulators all booting and running an APK — without Android Studio. Every command here was actually
run, across the `vitals-watch`, `field-assistant`, and `panel-remote` projects; the gotchas are the
ones that cost real time, not theoretical ones.

Paths below use Git Bash (`/c/...`). In PowerShell the same paths are `C:\...`. Windows binaries
(`adb.exe`, `emulator.exe`, `aapt2.exe`, `gh.exe`) never understand an MSYS-style `/c/...` path —
see §6.

**Contents:** [§0 Android CLI first](#0--try-android-cli-first) · [§1 Install](#1--install-the-toolchain) ·
[§2 Project setup](#2--project-level-setup) · [§3 AVDs](#3--avds-for-phone-tablet-and-wear-os) ·
[§4 Boot/install/launch](#4--booting-installing-and-launching) · [§5 Verify](#5--verify-its-actually-running) ·
[§6 Windows path traps](#6--windows-specific-path-and-shell-gotchas) ·
[§7 Emulator networking limits](#7--emulator-networking-limitations-know-these-before-you-debug-the-wrong-thing) ·
[§8 Shutdown](#8--shutting-down) · [§9 Scope](#9--scope-of-this-document)

---

## 0 · Try Android CLI first

Most of §1 is now automatable. Google's **Android CLI** installs the SDK component-by-component,
scaffolds projects, deploys, and manages AVDs — see `ecosystem.md` §1.

```bash
android sdk install
android create
android run
```

**On Windows there is a verified, load-bearing exception: `android emulator` is disabled, and
downloading the CLI from PowerShell is not supported.** So on Windows the split is:

| Job | Use |
|---|---|
| SDK install, scaffolding, deploy, docs, skills | **Android CLI** (§0) |
| **Creating and booting AVDs** | **The manual path below** (§3–§4) |

On macOS and Linux, `android emulator` covers the AVD half too and §3 becomes a fallback.

**Everything below therefore remains current on Windows.** It is not legacy — it is the supported
path for the emulator half of the job, and the §6–§7 gotchas apply no matter which tool created
the AVD.

---

## 1 · Install the toolchain

Nothing here needs Android Studio. The full toolchain is four downloads and one Windows feature.

### 1.1 JDK 17

Modern Android Gradle builds (AGP 8.x, `jvmToolchain(17)`) pin JDK 17. A newer JDK is **not** a
drop-in substitute — it fails at Gradle configuration time, often with an error that never names
the JDK as the cause.

```bash
java -version        # want 17.x
```

Install **Eclipse Temurin 17**: <https://adoptium.net/temurin/releases/?version=17> (Windows x64
`.msi`), or:

```powershell
winget install EclipseAdoptium.Temurin.17.JDK
```

Known good: 17.0.19.

### 1.2 Git for Windows

Supplies Git Bash, which every command in this document assumes.
<https://git-scm.com/download/win>, or `winget install Git.Git`.

### 1.3 Android SDK command-line tools

Download the Windows **command line tools only** package from
<https://developer.android.com/studio#command-line-tools-only>, then:

```bash
SDK=/c/Users/$USER/AppData/Local/Android/Sdk

# The nesting matters: cmdline-tools/latest/bin/sdkmanager.bat, not cmdline-tools/bin/.
mkdir -p "$SDK/cmdline-tools"
unzip commandlinetools-win-*.zip -d "$SDK/cmdline-tools"
mv "$SDK/cmdline-tools/cmdline-tools" "$SDK/cmdline-tools/latest"
```

If `sdkmanager` complains it can't find itself, this nesting is almost always why — it must sit at
`cmdline-tools/latest/bin/`.

### 1.4 Core SDK packages

```bash
SDKM="$SDK/cmdline-tools/latest/bin/sdkmanager.bat"

"$SDKM" --licenses          # accept all; the build refuses without this

yes | "$SDKM" \
  "platform-tools" \
  "emulator" \
  "platforms;android-36" \
  "build-tools;36.0.0"
```

`platform-tools` gives you `adb`; `build-tools` gives you `aapt2` (inspect APK badging/manifest)
and `apksigner` (verify signatures). Bump `android-36` / `36.0.0` to whatever `compileSdk` the
project actually declares — check `gradle/libs.versions.toml` first rather than assuming.

### 1.5 Hardware acceleration — use WHPX

```bash
"$SDK/emulator/emulator.exe" -accel-check
```

If it fails, enable **Windows Hypervisor Platform** in *Turn Windows features on or off*, then
reboot. Without it the emulator is not "a bit sluggish" — it is unusably slow, to the point of
looking hung.

**WHPX is the right answer, and the only one with a future.** Two dead ends to avoid:

- **HAXM is deprecated** (Intel discontinued it). From emulator **36.2.x.x** the emulator no longer
  uses it at all.
- **AEHD — the Android Emulator hypervisor driver — is sunset on 2026-12-31.** It still works until
  then. Do not install it on a new machine; you would be adopting something with a published expiry
  date. If an older setup guide tells you to install AEHD, that guide is stale.

### 1.6 GitHub CLI — only if you'll publish releases

<https://cli.github.com/>, or `winget install GitHub.cli`, then `gh auth login`.

### 1.7 Gradle — nothing to install

The wrapper is committed to every project in this corpus. Use `./gradlew`, never a system Gradle —
a mismatched system Gradle is a common source of "works on one machine" build failures.

### Set once per shell

```bash
SDK=/c/Users/$USER/AppData/Local/Android/Sdk
ADB="$SDK/platform-tools/adb.exe"
SDKM="$SDK/cmdline-tools/latest/bin/sdkmanager.bat"
AVDM="$SDK/cmdline-tools/latest/bin/avdmanager.bat"
EMU="$SDK/emulator/emulator.exe"
```

Known-good baseline on the machine this was written from: adb 1.0.41, emulator 36.5.11.0,
JDK 17.0.19. **Gradle and AGP are not pinned here** — they belong to the project's version catalog,
and the current values live in `platform-currency.md` §1 (as of 2026-09-04: AGP 9.4.0 on Gradle
9.6.0). `scripts/preflight.sh` checks this machine against them.

---

## 2 · Project-level setup

### `local.properties`

Not committed (and must not be — it's machine-specific). Create it in the repo root:

```bash
echo "sdk.dir=C:/Users/$USER/AppData/Local/Android/Sdk" > local.properties
```

> **Forward slashes, always.** A Java `.properties` file treats `\` as an escape character, so a
> Windows path written with single backslashes decodes to nonsense and the build fails with
> `java.io.IOException: The filename, directory name, or volume label syntax is incorrect` —
> which names neither the file nor the SDK, and can eat half an hour before you think to check
> this specific file.

---

## 3 · AVDs for phone, tablet, and Wear OS

### General rules, true across every AVD you create

- **Prefer a Google Play / Google APIs image over bare AOSP**, unless you have a specific reason
  not to. Anything that touches Play Services (Wearable Data Layer, Play Store–gated APIs) fails
  silently — or fails loudly in a way that looks like your bug — on an AOSP image. Check
  `tag.id` in `~/.android/avd/<name>.avd/config.ini`: it must read `google_apis` or
  `google_apis_playstore`.
- **Match the image ABI to the host CPU.** `abi.type` must be `x86_64` on an Intel/AMD machine.
  An `arm64-v8a` image on an x86_64 host is software-emulated and effectively unusable — this is
  a different problem from ARM *app* translation (next point).
- **If the APK ships only `arm64-v8a` native libraries** (common for anything wrapping a
  vendor SDK or loading native code from a `static {}` block), you need a system image with ARM
  translation built in — the `google_apis_playstore` x86_64 images at **API 35/36** have this.
  Older or non-Playstore images will crash the app at launch with no useful log line the first
  time you hit a native call. **Always confirm the app actually launches on a new AVD before
  trusting any other result from it.**
- `avdmanager create avd` sometimes omits CPU keys a working AVD created through Android Studio's
  Device Manager has. If a manually-created x86_64 AVD behaves oddly (won't boot, or boots but
  is unusably slow), append these to its `config.ini`:
  ```bash
  printf 'hw.cpu.arch=x86_64\nhw.cpu.ncore=4\n' >> ~/.android/avd/<name>.avd/config.ini
  ```

### 3.1 Phone

```bash
yes | "$SDKM" "system-images;android-36;google_apis_playstore;x86_64"

echo no | "$AVDM" create avd \
  -n Pixel10Test \
  -k "system-images;android-36;google_apis_playstore;x86_64" \
  -d pixel_9_pro
```

`pixel_9_pro` (1280×2856 @ density 480) is dimensionally identical to a Pixel 10 Pro, so it's the
standard phone stand-in with no skin or density tuning needed.

**Stress-testing display-size settings** (a user raising the OS "display size" slider effectively
raises density and shrinks available dp) without creating more AVDs:

```bash
adb -s <avd-serial> shell wm density 540    # then 600 to go further; `wm density reset` to restore
```

Restart the activity after changing density so the layout re-inflates.

### 3.2 Tablet

```bash
yes | "$SDKM" "system-images;android-36-ext19;google_apis_playstore;x86_64"

echo no | "$AVDM" create avd \
  -n MyAppTab \
  -k "system-images;android-36-ext19;google_apis_playstore;x86_64" \
  -d pixel_tablet
```

`pixel_tablet` (2560×1600 @ density 320) is the standard large-screen stand-in — use it to exercise
`isScreenLarge()` / `WindowSizeClass`-driven layout branches, tablet-specific navigation, and
multi-pane UI.

### 3.3 Wear OS watch, at each API level that matters

Test at every Wear OS version the target watch actually runs, not just the newest — watch hardware
gets OS updates slowly and users are commonly a version or two behind `targetSdk`.

```bash
yes | "$SDKM" \
  "system-images;android-33;android-wear;x86_64" \
  "system-images;android-34;android-wear;x86_64" \
  "system-images;android-36;android-wear-signed;x86_64"

echo no | "$AVDM" create avd -n Wear33 -d wearos_small_round \
  -k "system-images;android-33;android-wear;x86_64"
echo no | "$AVDM" create avd -n Wear34 -d wearos_small_round \
  -k "system-images;android-34;android-wear;x86_64"
echo no | "$AVDM" create avd -n Wear36 -d wearos_small_round \
  -k "system-images;android-36;android-wear-signed;x86_64"
```

> **The package name changes across releases: don't assume it.** It's `android-wear` at API 33
> and 34, but **`android-wear-signed`** at API 36. Run
> `"$SDKM" --list | grep android-wear` to find the current name rather than copying an old one
> forward.

`wearos_small_round` is 384×384 — smaller than most current round watches (commonly 432×432 or
480×480), which makes it a *harsher* layout test than the hardware. That's the right direction:
it catches content the bezel would clip on a real device before you ever see it on one. Each image
is roughly 1–1.5 GB.

---

## 4 · Booting, installing, and launching

### Boot

Start emulators **detached** — they don't exit on their own, so never run one in the foreground of
a script that needs to keep going:

```bash
nohup "$EMU" -avd Pixel10Test -no-boot-anim -no-audio >/dev/null 2>&1 &
nohup "$EMU" -avd Wear34 -no-boot-anim -no-audio -port 5558 >/dev/null 2>&1 &
```

Start `adb start-server` **before** launching an emulator. One started while the adb daemon is
down logs `Unable to connect to adb daemon on port: 5037` and never registers — `adb devices`
stays empty while the process runs happily in the background, which looks like a hang.

Ports are assigned in even pairs from 5554 upward in **boot order, not per-AVD** — the first
emulator to finish booting is always `emulator-5554`, whichever AVD it was. Pin one explicitly
with `-port` once you're running more than one at a time, and before doing anything destructive to
a specific instance, confirm which AVD it actually is:

```bash
adb -s emulator-5554 emu avd name
```

### Wait for boot — on the property, never on a guessed sleep

A device (especially a watch) can sit in `adb devices` as `offline` for a long stretch before it's
actually usable, so waiting for it to merely *appear* isn't enough:

```bash
until [ "$("$ADB" -s emulator-5558 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
  sleep 5
done
"$ADB" devices -l
```

First boot of a cold AVD is a few minutes; later boots resume from a snapshot in seconds.

### Multiple devices need `-s`

```bash
E="-s emulator-5558"
"$ADB" $E shell getprop ro.build.version.sdk      # confirm which API you're actually talking to
```

Every `adb` command without `-s` fails with *"more than one device/emulator"* the moment a second
one is running.

### Install and launch

```bash
"$ADB" $E install -r path/to/app-debug.apk
"$ADB" $E shell am start -n com.example.app/com.example.app.MainActivity
```

> **The component name is not always what you'd guess.** `applicationId` and the Kotlin package
> the activity actually lives in can differ (a multi-module app is a common case: `applicationId`
> is the root ID, but `MainActivity` lives in a `.app` or `.wear` sub-package). The obvious
> `com.example.app/.MainActivity` fails with `Error type 3 … Activity class does not exist`
> **after** install already reported `Success` — which reads exactly like a launch crash when the
> app never started at all. If unsure, use the shape-independent launcher-intent form instead:
> ```bash
> "$ADB" $E shell monkey -p com.example.app -c android.intent.category.LAUNCHER 1
> ```

Grant a runtime permission directly instead of hunting for the system dialog in a script:

```bash
"$ADB" $E shell pm grant com.example.app android.permission.POST_NOTIFICATIONS
```

Do **not** dismiss a permission dialog with `input keyevent 4` (back) if you do need to interact
with it — back can exit the whole app to the launcher instead of just the dialog.

---

## 5 · Verify it's actually running

`Success` from `install` says nothing about whether the app runs.

```bash
"$ADB" $E shell ps -A | grep example                                   # alive?
"$ADB" $E shell dumpsys activity activities | grep topResumedActivity  # foreground?
"$ADB" $E logcat -d -b crash | tail -30                                # empty is the pass
"$ADB" $E exec-out screencap -p > screen.png                           # what it looks like
```

Watch-specific false alarms:
- **First boot lands on the Wear setup wizard** ("Hello"), and a screenshot taken right after
  `am start` may show that instead of your app. Check `topResumedActivity` before concluding
  anything — the app can already be the resumed activity, underneath the wizard.
- **"Waiting for your settings from the phone"** (or equivalent) is the *correct* state on an
  unpaired watch emulator if the app depends on a paired phone for config. Pairing is a separate
  manual step through the Wear companion app flow, not something a script can trigger.

---

## 6 · Windows-specific path and shell gotchas

- **Windows binaries can't read Git Bash (MSYS) paths.** `adb.exe`, `gh.exe`, `aapt2.exe` are
  native Windows executables — an MSYS-style `/c/Users/...` path means nothing to them.
  ```bash
  "$ADB" install /c/Users/me/out.apk     # fails: "No such file or directory"
  "$ADB" install "C:/Users/me/out.apk"   # works
  ```
  Always hand these tools a `C:/...`-style path (quoted, so any space survives).

- **Git Bash rewrites device-side paths that look like Unix absolute paths.** A command like
  `adb shell uiautomator dump /sdcard/ui.xml` gets its `/sdcard/...` argument silently rewritten to
  a Windows path before it ever reaches the emulator, and the failure doesn't look path-related.
  Prefix the command with `MSYS_NO_PATHCONV=1`, or quote the entire remote command as one argument
  passed to `adb shell`.

- **`adb shell run-as cat <file>` corrupts binary files** through CRLF translation on the way back
  to a Windows shell. Use `adb exec-out` instead for anything binary (a database file, an image).

- **A release build is not debuggable.** `adb shell run-as` and pulling app data don't work against
  a release APK at all. Verify a release build through the UI/logcat, and switch to a debug build
  when you need to inspect on-device files directly.

---

## 7 · Emulator networking limitations (know these before you debug the wrong thing)

The standard Android emulator's networking is **SLIRP NAT**, and it has two limits that show up as
mysterious app bugs if you don't know them going in:

- **No inbound UDP without an existing outbound mapping.** Anything that depends on a server
  *pushing* UDP packets at the emulator unprompted (raw RTP media, some device-discovery replies)
  will see the guest receive nothing, ever — not intermittently, categorically. This is a property
  of the emulator's NAT, not a bug in whatever app or server you're testing. The fix is a real
  device on real Wi-Fi (no NAT in the way), or a bridged-network Android VM (e.g. Genymotion) —
  never "keep debugging the standard AVD," which cannot succeed no matter what changes.
- **No multicast, so no mDNS/NSD discovery either.** The standard AVD's NAT doesn't bridge
  multicast traffic, so `_something._tcp`/`_something._udp` service discovery (Network Service
  Discovery, Bonjour/mDNS-style protocols) never reaches the guest and never leaves it. If a
  feature is supposed to auto-discover something on the LAN, test it on a real device on the same
  network, or inject the target address manually as a fallback path for emulator testing.

On the **host** side, on Windows specifically:
- **The Wi-Fi network profile must be Private, not Public**, for mDNS/multicast traffic to work at
  all — Windows blocks it outright on a Public profile, and the symptom looks exactly like an app
  discovery bug.
- **Windows Firewall needs explicit inbound allow rules** for whatever ports/protocols a local
  test server uses (a companion emulator, a mock server, a real accessory on the LAN) — allow the
  actual process (Python interpreter, your server binary) through, not just the port.
- **Port 8554 is generally unusable for a local server you want an AVD to reach**, because the
  Android Emulator's own QEMU process binds `127.0.0.1:8554` for its internal gRPC console
  service and pre-empts that exact port on the emulator's own host-loopback NAT — a client on the
  guest gets an instant EOF that looks like the server never even started. Pick a different port
  for anything you stand up locally for the emulator to talk to.

Reach a host-side local server from inside the emulator via the emulator's host alias, no
`adb reverse` needed: `http://10.0.2.2:<port>/...`.

---

## 8 · Shutting down

```bash
"$ADB" -s emulator-5554 emu kill
```

Leaving emulators running between sessions is fine and often faster — they snapshot on exit, and
the next boot resumes from the snapshot instead of a cold boot.

---

## 9 · Scope of this document

This covers **toolchain installation and emulator mechanics only**. For the audit/fix/test
workflow that runs on top of a working emulator, see `testing-and-bugs.md`; for what a
device-specific system image can and can't prove about real hardware, treat any AVD result as
provisional until confirmed on the real device it stands in for — see `bootstrapping.md` for why
real-hardware testing is a required, not optional, late step.
