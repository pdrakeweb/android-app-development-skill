#!/usr/bin/env bash
# preflight.sh — does this machine's toolchain match the pins, and what does the
# project actually declare?
#
# Run this BEFORE scaffolding or before the first build in a cold session. A
# mismatched JDK or Gradle produces configuration-time errors that never name the
# real cause, and an AGP 8-era scaffold does not build under AGP 9 at all.
#
# Pins verified 2026-09-04 — see references/platform-currency.md. If that date is
# well past, re-verify rather than trusting this script.
#
# Usage: preflight.sh [project-dir]
#
# Exit codes: 0 clean · 1 one or more warnings (the toolchain or project needs
# attention before building). It is a check, so it fails when the check fails.

set -uo pipefail

DIR="${1:-.}"
WARN=0

PIN_AGP="9.4.0"; PIN_GRADLE="9.6.0"; PIN_JDK="17"
PIN_BUILD_TOOLS="36.0.0"; PIN_COMPILE="37"; PIN_TARGET="36"

ok()   { printf '\033[32mok\033[0m    %s\n' "$*"; }
warn() { printf '\033[33mwarn\033[0m  %s\n' "$*"; WARN=1; }
info() { printf '      %s\n' "$*"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# Compare dotted versions: 0 if $1 >= $2.
vge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

head_ "Toolchain"

# ---- JDK ---------------------------------------------------------------------
if command -v java >/dev/null 2>&1; then
  # Not `head -1`: JAVA_TOOL_OPTIONS prints a banner ahead of the version line.
  JV="$(java -version 2>&1 | grep -m1 'version "' | sed -n 's/.*version "1\.\([0-9]*\).*/\1/p;s/.*version "\([0-9]*\).*/\1/p' | head -1)"
  if [ -z "$JV" ]; then warn "could not parse 'java -version' output"
  elif vge "$JV" "$PIN_JDK"; then ok "JDK $JV (minimum $PIN_JDK)"
  else
    warn "JDK $JV — AGP $PIN_AGP needs JDK $PIN_JDK or newer"
    info "too old a JDK fails at Gradle configuration time with an error that"
    info "never names the JDK as the cause"
  fi
else
  warn "java not on PATH — install Eclipse Temurin $PIN_JDK"
fi

# ---- Gradle wrapper ----------------------------------------------------------
WRAP="$DIR/gradle/wrapper/gradle-wrapper.properties"
if [ -f "$WRAP" ]; then
  GV="$(sed -n 's/.*gradle-\([0-9][0-9.]*\)-.*\.zip/\1/p' "$WRAP")"
  if vge "$GV" "$PIN_GRADLE"; then ok "Gradle wrapper $GV"
  else warn "Gradle wrapper $GV — AGP $PIN_AGP requires $PIN_GRADLE or newer"; fi
else
  info "no Gradle wrapper at $WRAP (fine if the project isn't scaffolded yet)"
fi
command -v gradle >/dev/null 2>&1 && \
  info "NOTE: a system gradle is on PATH — always use ./gradlew, never it"

# ---- SDK ---------------------------------------------------------------------
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -n "$SDK" ] && [ -d "$SDK" ]; then
  ok "SDK at $SDK"
  [ -d "$SDK/build-tools/$PIN_BUILD_TOOLS" ] \
    && ok "build-tools $PIN_BUILD_TOOLS" \
    || warn "build-tools $PIN_BUILD_TOOLS not installed (android sdk install, or sdkmanager)"
  [ -d "$SDK/platforms/android-$PIN_COMPILE" ] \
    && ok "platform android-$PIN_COMPILE" \
    || warn "platform android-$PIN_COMPILE not installed"
elif [ -n "$SDK" ]; then
  warn "ANDROID_HOME / ANDROID_SDK_ROOT is set to '$SDK', which is not a directory here"
  info "a native Windows path (C:\\Users\\...) is set but unreadable from this shell —"
  info "set it to the POSIX form (/c/Users/...) for these scripts"
else
  warn "ANDROID_HOME / ANDROID_SDK_ROOT not set"
fi

command -v android >/dev/null 2>&1 \
  && ok "Android CLI present ($(android version 2>/dev/null | head -1))" \
  || info "Android CLI not installed — it is the preferred toolchain path; see ecosystem.md §1"

# ---- what the project declares ----------------------------------------------
head_ "Project declares"

CAT="$DIR/gradle/libs.versions.toml"
if [ -f "$CAT" ]; then
  ok "version catalog present (nothing can drift)"
  AGP_V="$(sed -n 's/^[[:space:]]*\(agp\|androidGradlePlugin\)[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\2/p' "$CAT" | head -1)"
  if [ -n "$AGP_V" ]; then
    case "$AGP_V" in
      9.*) vge "$AGP_V" "$PIN_AGP" && ok "AGP $AGP_V" || info "AGP $AGP_V (current stable is $PIN_AGP)" ;;
      *)   warn "AGP $AGP_V — AGP 9 is a HARD BREAK, not a bump"
           info "built-in Kotlin, old variant API removed, non-final resource IDs,"
           info "and kapt incompatible with built-in Kotlin. See platform-currency.md §3, install"
           info "Google's agp-9-upgrade skill rather than hand-writing the migration." ;;
    esac
  fi
else
  info "no gradle/libs.versions.toml — pin every version in one catalog so the Kotlin"
  info "compiler and its annotation processors cannot drift apart"
fi

BUILDS="$(find "$DIR" -name 'build.gradle*' -not -path '*/build/*' -not -path '*/.git/*' 2>/dev/null)"
if [ -n "$BUILDS" ]; then
  TS="$(printf '%s' "$BUILDS" | tr '\n' '\0' | xargs -0 grep -ho 'targetSdk[ =]*\([0-9]*\)' 2>/dev/null | grep -o '[0-9]*' | sort -u | tr '\n' ' ')"
  CS="$(printf '%s' "$BUILDS" | tr '\n' '\0' | xargs -0 grep -ho 'compileSdk[ =]*\([0-9]*\)' 2>/dev/null | grep -o '[0-9]*' | sort -u | tr '\n' ' ')"
  # The catalog form this script recommends — targetSdk = libs.versions.targetSdk.get()
  # — carries no literal, so fall back to the catalog rather than silently skipping
  # every check below.
  if [ -f "$CAT" ]; then
    [ -z "$TS" ] && TS="$(sed -n 's/^[[:space:]]*targetSdk[[:space:]]*=[[:space:]]*"\([0-9]*\)".*/\1/p' "$CAT" | sort -u | tr '\n' ' ')"
    [ -z "$CS" ] && CS="$(sed -n 's/^[[:space:]]*compileSdk[[:space:]]*=[[:space:]]*"\([0-9]*\)".*/\1/p' "$CAT" | sort -u | tr '\n' ' ')"
  fi
  [ -n "$CS" ] && info "compileSdk: $CS   (pin: $PIN_COMPILE — track the newest stable SDK)"
  [ -n "$TS" ] && info "targetSdk:  $TS   (pin: $PIN_TARGET — Play requirement since 2026-08-31)"

  for t in $TS; do
    if [ "$t" -ge 36 ] 2>/dev/null; then
      info ""
      info "targetSdk $t means these are NOT optional (platform-currency.md §4):"
      printf '%s' "$BUILDS" | tr '\n' '\0' | xargs -0 grep -l 'enableEdgeToEdge' >/dev/null 2>&1 \
        || info "  · edge-to-edge cannot be opted out of — handle window insets deliberately"
      if grep -rql 'onBackPressed()' "$DIR" --include='*.kt' --include='*.java' 2>/dev/null; then
        warn "onBackPressed() found, and targetSdk is $t — not called on Android 16+"
        info "  On a device running Android 16 or newer, any 'are you sure?' or"
        info "  unsaved-work guard built on it is silently gone. It still fires on"
        info "  older devices, so the bug appears only on current hardware."
        info "  Migrate to OnBackPressedDispatcher / BackHandler."
      fi
      break
    fi
  done

  # AGP 9 removed final resource IDs, so a `when` on R.id no longer compiles.
  if grep -rqE 'when[[:space:]]*\([^)]*\.id\)' "$DIR" --include='*.kt' 2>/dev/null; then
    warn "a 'when' over a view id found — non-final resource IDs are AGP 9's default"
    info "  R.id.* is not a compile-time constant; convert to if/else branches"
  fi
fi

if [ -f "$DIR/gradle.properties" ] && grep -q 'android.enableJetifier' "$DIR/gradle.properties" 2>/dev/null; then
  warn "android.enableJetifier is set — obsolete, off by default, and removed in AGP 10"
  info "delete it and move the offending dependency to its AndroidX version"
fi

printf '\n'
if [ "$WARN" -eq 0 ]; then
  printf '\033[32mPASS\033[0m  preflight clean.\n'
else
  printf '\033[33mFAIL\033[0m  review the warnings above before building.\n'
  exit 1
fi
