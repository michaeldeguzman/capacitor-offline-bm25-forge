#!/bin/sh
# Plan section 5, items 2 to 8 (phases p1 to p3) and the timing runs (p4 to p6), on the Android emulator, in airplane mode. Runs the example app in
# validation mode, one launch per phase, with a force-stop between launches. Results are read
# from logcat. Needs ANDROID_HOME and a JDK 17 for Gradle (org.gradle.java.home).
# Usage: tools/validate/run-android.sh <output dir>
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
out="$1"
mkdir -p "$out"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
adb="$ANDROID_HOME/platform-tools/adb"
pkg="com.michaeldeguzman.offlinebm25.example"
started_emulator=""

cleanup() {
  "$adb" shell cmd connectivity airplane-mode disable >/dev/null 2>&1 || true
  [ -n "$started_emulator" ] && "$adb" emu kill >/dev/null 2>&1 || true
}
trap cleanup EXIT

if ! "$adb" devices | grep -q '^emulator-.*device$'; then
  avd="${AVD:-$("$ANDROID_HOME/emulator/emulator" -list-avds | head -1)}"
  "$ANDROID_HOME/emulator/emulator" -avd "$avd" -no-window -no-audio -no-snapshot -no-boot-anim >"$out/emulator.log" 2>&1 &
  started_emulator=1
  "$adb" wait-for-device
  until [ "$("$adb" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 3; done
fi
echo "device: $("$adb" shell getprop ro.product.model | tr -d '\r'), API $("$adb" shell getprop ro.build.version.sdk | tr -d '\r')"

(cd "$root/example" && npm run sync >/dev/null)
(cd "$root/example/android" && ./gradlew assembleDebug >"$out/build.log" 2>&1)
"$adb" install -r "$root/example/android/app/build/outputs/apk/debug/app-debug.apk" >/dev/null
"$adb" shell pm clear "$pkg" >/dev/null   # empty app storage

# Airplane mode on, and proof that the network is gone.
"$adb" shell cmd connectivity airplane-mode enable
sleep 5
echo "airplane_mode_on=$("$adb" shell settings get global airplane_mode_on | tr -d '\r')"
if "$adb" shell ping -c 1 -W 3 8.8.8.8 >"$out/ping.log" 2>&1; then echo "ping 8.8.8.8: REACHABLE"; else echo "ping 8.8.8.8: unreachable ($(tail -1 "$out/ping.log" | tr -d '\r'))"; fi

for phase in p1 p2 p3 p4 p5 p6; do
  "$adb" shell am force-stop "$pkg"          # kill
  "$adb" logcat -c
  "$adb" shell am start -n "$pkg/.MainActivity" --es validate "$phase" >/dev/null
  tries=0
  until "$adb" logcat -d | grep -q "|PHASE|DONE|$phase" || [ "$tries" -ge 100 ]; do sleep 2; tries=$((tries + 1)); done
  "$adb" logcat -d >"$out/android-$phase.log"
  grep -q "|PHASE|DONE|$phase" "$out/android-$phase.log" || echo "TIMEOUT waiting for $phase"
  echo "phase $phase ran in process $("$adb" shell pidof "$pkg" | tr -d '\r')"
  "$adb" shell am force-stop "$pkg"
done
grep -h "OBM25-VALIDATE" "$out"/android-p1.log "$out"/android-p2.log "$out"/android-p3.log "$out"/android-p4.log "$out"/android-p5.log "$out"/android-p6.log | sed 's/^.*Msg: //; s/^.*\(OBM25-VALIDATE\)/\1/' | awk '!seen[$0]++'
