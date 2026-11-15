#!/bin/sh
# Compares the character rules of the Swift port (macOS host) and the Kotlin port (JVM and
# Android emulator) with .NET for all 65,536 UTF-16 code units.
# Writes docs/charclass-comparison.md. Needs dotnet, swiftc, and the Android setup that
# android/ needs (JDK 17 for Gradle, ANDROID_HOME, an AVD). If no emulator is running, this
# script boots the AVD named by $AVD (default: the first one listed) and shuts it down after.
#
# Environment variables:
#   SKIP_SWIFT=1   leave out the Swift leg, which needs macOS and swiftc
#   SKIP_JVM=1     leave out the Kotlin JVM leg
#   SKIP_DEVICE=1  leave out the Kotlin emulator leg, which needs an AVD
#   OUT=<path>     where to write the report. The default is docs/charclass-comparison.md.
#                  A relative path is relative to the folder you run the script from.
#   AVD            the emulator to boot when none is running
#   ANDROID_HOME   the Android SDK, default $HOME/Library/Android/sdk
# A skipped leg is left out of the report. dotnet is always needed, because every leg reads
# the .NET data file.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
out="${OUT:-$root/docs/charclass-comparison.md}"
skip_swift="${SKIP_SWIFT:-}"
skip_jvm="${SKIP_JVM:-}"
skip_device="${SKIP_DEVICE:-}"
if [ -n "$skip_swift" ] && [ -n "$skip_jvm" ] && [ -n "$skip_device" ]; then
  echo "run.sh: SKIP_SWIFT, SKIP_JVM and SKIP_DEVICE are all set, so nothing would run" >&2
  exit 1
fi
work="$(mktemp -d)"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
adb="$ANDROID_HOME/platform-tools/adb"
started_emulator=""
cleanup() {
  [ -n "$started_emulator" ] && "$adb" emu kill >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

dotnet run --project "$here/dotnet" -- "$work/dotnet.txt"

# Swift
if [ -z "$skip_swift" ]; then
  swiftc -O "$here/swift/main.swift" \
    "$root/ios/Plugin/Tokenizer.swift" "$root/ios/Plugin/PorterStemmer.swift" \
    "$root/ios/Plugin/StopWords.swift" -o "$work/charclass"
  "$work/charclass" "$work/dotnet.txt" "$(swiftc --version 2>/dev/null | head -1)" > "$work/swift.md"
fi

# Both Kotlin legs read the data file from android/build/charclass-assets.
if [ -z "$skip_jvm" ] || [ -z "$skip_device" ]; then
  mkdir -p "$root/android/build/charclass-assets"
  cp "$work/dotnet.txt" "$root/android/build/charclass-assets/dotnet.txt"
fi

# Kotlin on the JVM
if [ -z "$skip_jvm" ]; then
  (cd "$root/android" && ./gradlew testDebugUnitTest --tests '*CharClassComparisonTest' -i) > "$work/jvm.log" 2>&1
  python3 -I "$here/kotlin_report.py" "Kotlin on the JVM" "$work/jvm.log" > "$work/jvm.md"
fi

# Kotlin on the emulator
if [ -z "$skip_device" ]; then
  if ! "$adb" devices | grep -q '^emulator-.*device$'; then
    avd="${AVD:-$("$ANDROID_HOME/emulator/emulator" -list-avds | head -1)}"
    "$ANDROID_HOME/emulator/emulator" -avd "$avd" -no-window -no-audio -no-snapshot -no-boot-anim >"$work/emulator.log" 2>&1 &
    started_emulator=1
    "$adb" wait-for-device
    until [ "$("$adb" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 3; done
  fi
  "$adb" logcat -c
  (cd "$root/android" && ./gradlew connectedDebugAndroidTest \
    -Pandroid.testInstrumentationRunnerArguments.class=com.michaeldeguzman.plugins.offlinebm25.CharClassComparisonTest) > "$work/device.log" 2>&1
  "$adb" logcat -d > "$work/logcat.txt"
  python3 -I "$here/kotlin_report.py" "Kotlin on the Android emulator" "$work/logcat.txt" > "$work/device.md"
fi

{
  echo "# Character classes: Swift and Kotlin ports vs .NET"
  echo
  echo "Evidence for the README section \"Parity and known differences\". This is not a test fixture."
  echo "Regenerate with \`tools/charclass/run.sh\`."
  echo
  if [ -z "$skip_swift" ]; then
    cat "$work/swift.md"
    echo
  fi
  if [ -z "$skip_jvm" ]; then cat "$work/jvm.md"; fi
  if [ -z "$skip_device" ]; then cat "$work/device.md"; fi
  cat "$here/rerun-note.md"
} > "$out"
echo "wrote $out"
