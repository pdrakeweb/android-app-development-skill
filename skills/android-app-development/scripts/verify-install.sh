#!/usr/bin/env bash
# verify-install.sh — install an APK and prove it actually runs.
#
# "Every implementation pass ends with a real build and a real test." This script is
# that test, in a form that cannot be claimed without being run.
#
# Exists because `adb install` reports failure on stderr and still exits 0 in some
# pipelines, so an unasserted install makes a REJECTED install look identical to a
# good one — and because `Success` says nothing about whether the app then launched.
#
# Usage:
#   verify-install.sh <apk> <package> [-s <serial>] [--activity <component>] [--keep-data]
#
# Exit codes: 0 pass · 1 usage/env · 2 install failed · 3 launch failed · 4 crashed

set -uo pipefail

ADB="${ADB:-adb}"
SERIAL=""; ACTIVITY=""; KEEP_DATA=0; APK=""; PKG=""

die()  { printf '\033[31mFAIL\033[0m  %s\n' "$*" >&2; exit "${2:-1}"; }
ok()   { printf '\033[32mok\033[0m    %s\n' "$*"; }
info() { printf '      %s\n' "$*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    -s|--serial)   [ $# -ge 2 ] || die "$1 needs a value"; SERIAL="$2"; shift 2 ;;
    --activity)    [ $# -ge 2 ] || die "$1 needs a value"; ACTIVITY="$2"; shift 2 ;;
    --keep-data)   KEEP_DATA=1; shift ;;
    -h|--help)     sed -n '2,14p' "$0"; exit 0 ;;
    *) if [ -z "$APK" ]; then APK="$1"; elif [ -z "$PKG" ]; then PKG="$1"; else die "unexpected arg: $1"; fi; shift ;;
  esac
done

[ -n "$APK" ] && [ -n "$PKG" ] || die "usage: verify-install.sh <apk> <package> [-s serial] [--activity comp]"
[ -f "$APK" ] || die "APK not found: $APK"

# Windows note: adb.exe cannot read an MSYS /c/... path. Convert if we're in Git Bash.
case "$(uname -s 2>/dev/null || echo unknown)" in
  MINGW*|MSYS*|CYGWIN*)
    if command -v cygpath >/dev/null 2>&1; then APK="$(cygpath -m "$APK")"; fi ;;
esac

A=("$ADB"); [ -n "$SERIAL" ] && A+=(-s "$SERIAL")

command -v "$ADB" >/dev/null 2>&1 || die "adb not on PATH (set \$ADB)"

# A device must actually be there. Without -s, adb fails the moment a second one appears.
DEVICES="$("${A[@]}" devices | tr -d '\r' | awk 'NR>1 && $2=="device" {print $1}')"
[ -n "$DEVICES" ] || die "no device in state 'device' — is the emulator booted?"
if [ -z "$SERIAL" ] && [ "$(printf '%s\n' "$DEVICES" | wc -l)" -gt 1 ]; then
  die "more than one device attached; pass -s <serial>. Attached:
$DEVICES"
fi

# ---- reset to first-run state -------------------------------------------------
# An empty first install is the cheapest test of the "no value computed from
# nothing" rule, so it is the default rather than an option.
if [ "$KEEP_DATA" -eq 0 ]; then
  "${A[@]}" shell pm clear "$PKG" >/dev/null 2>&1 || true
  info "cleared existing data for $PKG (pass --keep-data to keep it)"
fi

# ---- install, asserting on Success -------------------------------------------
OUT="$("${A[@]}" install -r -d "$APK" 2>&1)" || true
printf '%s\n' "$OUT" | grep -q '^Success' \
  || die "install did not report Success:
$OUT" 2
ok "installed $(basename "$APK")"

# ---- clear the crash buffer BEFORE launching ---------------------------------
# Otherwise a crash from a previous run reads as this run's failure. Clearing fails
# on some builds; say so rather than silently inheriting stale crashes.
if ! "${A[@]}" logcat -c -b crash >/dev/null 2>&1; then
  info "WARNING: could not clear the crash buffer — a crash below may predate this run."
fi

# ---- launch ------------------------------------------------------------------
# applicationId and the package MainActivity lives in commonly differ in a
# multi-module app, so the shape-independent launcher intent is the default.
if [ -n "$ACTIVITY" ]; then
  LAUNCH="$("${A[@]}" shell am start -W -n "$ACTIVITY" 2>&1)"
else
  LAUNCH="$("${A[@]}" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 2>&1)"
fi
printf '%s\n' "$LAUNCH" | grep -qiE 'error|does not exist|no activities found' \
  && die "launch failed:
$LAUNCH" 3

# Give the process a moment to either come up or die.
sleep 3

# ---- is it alive? ------------------------------------------------------------
PID="$("${A[@]}" shell pidof "$PKG" 2>/dev/null | tr -d '\r')"
[ -n "$PID" ] || die "no process for $PKG after launch — it started and died, or never started" 3
ok "running (pid $PID)"

# ---- is it in front? ---------------------------------------------------------
# "Confirm which app is actually in front before believing a screenshot" — a setup
# wizard or a system dialog on top produces confidently wrong results otherwise.
TOP="$("${A[@]}" shell dumpsys activity activities 2>/dev/null | grep -m1 topResumedActivity | tr -d '\r')"
if printf '%s' "$TOP" | grep -q "$PKG"; then
  ok "foreground: $(printf '%s' "$TOP" | sed 's/.*ActivityRecord{[^ ]* [^ ]* //; s/ .*//')"
else
  info "WARNING: $PKG is running but not the top resumed activity."
  info "  top is: ${TOP:-<none>}"
  info "  On a watch this is often the setup wizard on first boot, not a failure."
fi

# ---- did it crash? -----------------------------------------------------------
# The crash buffer is system-wide, not per-app: an unrelated GMS or vendor crash in
# this window would otherwise fail a perfectly good build. Scope it to our own pid.
CRASH="$("${A[@]}" logcat -d -b crash --pid="$PID" 2>/dev/null | tr -d '\r')"
if [ -z "$(printf '%s' "$CRASH" | tr -d '[:space:]')" ]; then
  # --pid is unsupported on older platform-tools; fall back to matching the package.
  CRASH="$("${A[@]}" logcat -d -b crash 2>/dev/null | tr -d '\r' | grep -F "$PKG" || true)"
fi
if [ -n "$(printf '%s' "$CRASH" | tr -d '[:space:]')" ]; then
  printf '\n%s\n' "$CRASH" | tail -40 >&2
  die "$PKG crashed after launch" 4
fi
ok "no crash from $PKG"

printf '\n\033[32mPASS\033[0m  %s installed, launched, and is alive with no crash.\n' "$PKG"
