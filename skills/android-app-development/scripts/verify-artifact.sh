#!/usr/bin/env bash
# verify-artifact.sh — inspect a built APK before trusting it.
#
# Exists because a plausible-but-wrong theory about an artifact can eat an
# afternoon. In the corpus a 33 MB debug watch APK would not install on real
# hardware; the ABI and architecture theories were both wrong, and one
# `aapt2 dump badging` would have said so immediately.
#
# Checks: targetSdk/minSdk, shipped ABIs, signature scheme, dex count, size,
# and whether the build looks debuggable.
#
# Usage: verify-artifact.sh <apk> [--expect-abi arm64-v8a] [--expect-target 36] [--release]
#
# Exit codes: 0 pass · 1 usage/env · 2 an expectation was not met

set -uo pipefail

APK=""; EXPECT_ABI=""; EXPECT_TARGET=""; RELEASE=0; FAILED=0

die()  { printf '\033[31mFAIL\033[0m  %s\n' "$*" >&2; exit "${2:-1}"; }
bad()  { printf '\033[31mFAIL\033[0m  %s\n' "$*" >&2; FAILED=1; }
ok()   { printf '\033[32mok\033[0m    %s\n' "$*"; }
info() { printf '      %s\n' "$*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --expect-abi)    EXPECT_ABI="$2"; shift 2 ;;
    --expect-target) EXPECT_TARGET="$2"; shift 2 ;;
    --release)       RELEASE=1; shift ;;
    -h|--help)       sed -n '2,14p' "$0"; exit 0 ;;
    *) [ -z "$APK" ] && { APK="$1"; shift; } || die "unexpected arg: $1" ;;
  esac
done

[ -n "$APK" ] || die "usage: verify-artifact.sh <apk> [--expect-abi ABI] [--expect-target N] [--release]"
[ -f "$APK" ] || die "APK not found: $APK"

# aapt2 and apksigner live in build-tools; find them if not on PATH.
find_tool() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 && { command -v "$name"; return; }
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
  ls -d "$sdk"/build-tools/*/ 2>/dev/null | sort -Vr | while read -r d; do
    for c in "$d$name" "$d$name.exe" "$d$name.bat"; do
      [ -x "$c" ] && { printf '%s' "$c"; return; }
    done
  done
}

AAPT2="$(find_tool aapt2)"
[ -n "$AAPT2" ] || die "aapt2 not found — install build-tools;36.0.0 or put it on PATH"

BADGING="$("$AAPT2" dump badging "$APK" 2>/dev/null)" || die "aapt2 could not read $APK"

PKG="$(printf '%s' "$BADGING"    | sed -n "s/^package: name='\([^']*\)'.*/\1/p")"
VNAME="$(printf '%s' "$BADGING"  | sed -n "s/.*versionName='\([^']*\)'.*/\1/p" | head -1)"
MINSDK="$(printf '%s' "$BADGING" | sed -n "s/^sdkVersion:'\([0-9]*\)'.*/\1/p")"
TGTSDK="$(printf '%s' "$BADGING" | sed -n "s/^targetSdkVersion:'\([0-9]*\)'.*/\1/p")"

printf '\n  %s  %s\n' "$PKG" "${VNAME:-<no versionName>}"
printf '  %s  (%s)\n\n' "$(du -h "$APK" | cut -f1)" "$APK"

info "minSdk $MINSDK · targetSdk $TGTSDK"

# ---- targetSdk ---------------------------------------------------------------
if [ -n "$EXPECT_TARGET" ]; then
  [ "$TGTSDK" = "$EXPECT_TARGET" ] \
    && ok "targetSdk is $TGTSDK as expected" \
    || bad "targetSdk is $TGTSDK, expected $EXPECT_TARGET"
elif [ -n "$TGTSDK" ] && [ "$TGTSDK" -lt 36 ] 2>/dev/null; then
  info "NOTE: targetSdk $TGTSDK is below 36. Play has required 36 for new apps and"
  info "  updates since 2026-08-31 (Wear/Automotive 35, TV/XR 34). See platform-currency.md §5."
fi

# ---- ABIs --------------------------------------------------------------------
ABIS="$(printf '%s' "$BADGING" | sed -n "s/^native-code: //p" | tr -d "'" | tr ' ' '\n' | grep -v '^$' | tr '\n' ' ')"
if [ -z "$ABIS" ]; then
  info "no native code — ABI checks not applicable"
else
  info "ABIs: $ABIS"
  if [ -n "$EXPECT_ABI" ]; then
    printf '%s' "$ABIS" | tr ' ' '\n' | grep -qx "$EXPECT_ABI" \
      && ok "ships $EXPECT_ABI" \
      || bad "does NOT ship $EXPECT_ABI — this APK cannot run on that hardware"
  fi
  # Wear OS: 64-bit required by Play since 2026-09-15 for native code.
  printf '%s' "$ABIS" | grep -q 'arm64-v8a\|x86_64' \
    || info "NOTE: no 64-bit ABI. Wear OS has required 64-bit since 2026-09-15."
fi

# ---- signature ---------------------------------------------------------------
# v1-only fails to install on modern API levels, and a companion (watch) app
# signed with a different key installs fine, runs fine, and cannot talk to its
# phone app with nothing on screen to say why.
APKSIGNER="$(find_tool apksigner)"
if [ -n "$APKSIGNER" ]; then
  SIG="$("$APKSIGNER" verify --print-certs -v "$APK" 2>&1)" || true
  V2="$(printf '%s' "$SIG" | grep -c 'v2 scheme.*true')"
  V3="$(printf '%s' "$SIG" | grep -c 'v3 scheme.*true')"
  if [ "$V2" -gt 0 ] || [ "$V3" -gt 0 ]; then
    ok "signed (v2/v3 present)"
  else
    bad "no v2/v3 signature — v1-only does not install on modern API levels"
  fi
  DIGEST="$(printf '%s' "$SIG" | sed -n 's/.*SHA-256 digest: \(.*\)/\1/p' | head -1)"
  [ -n "$DIGEST" ] && info "cert SHA-256: $DIGEST"
  info "  (a companion app MUST show this same digest, or pairing fails silently)"
else
  info "apksigner not found — signature not verified"
fi

# ---- dex count and debuggability --------------------------------------------
if command -v unzip >/dev/null 2>&1; then
  DEX="$(unzip -l "$APK" 2>/dev/null | grep -c 'classes.*\.dex')"
  info "dex files: $DEX"
fi

DEBUGGABLE="$(printf '%s' "$BADGING" | grep -c "application-debuggable")"
if [ "$RELEASE" -eq 1 ]; then
  [ "$DEBUGGABLE" -eq 0 ] \
    && ok "not debuggable — looks like a release build" \
    || bad "application-debuggable is set — this is a DEBUG build, do not ship it"
elif [ "$DEBUGGABLE" -gt 0 ]; then
  info "debuggable build (expected for debug; never ship one, especially to a watch)"
fi

if [ "$FAILED" -eq 0 ]; then
  printf '\n\033[32mPASS\033[0m  artifact checks passed.\n'
else
  printf '\n\033[31mFAIL\033[0m  one or more artifact checks failed.\n' >&2
  exit 2
fi
