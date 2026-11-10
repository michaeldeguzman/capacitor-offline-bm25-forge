#!/bin/sh
# Plan section 5, items 2 to 8 (phases p1 to p3) and the timing runs (p4 to p6), on the iOS Simulator. Runs the example app in validation mode,
# one launch per phase, with a kill between launches. Results are read from the app's console,
# which --console-pty makes line buffered. A plain --stdout file stays empty until the app exits.
# Usage: tools/validate/run-ios.sh <simulator udid> <output dir>
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
device="$1"
out="$2"
bundle="com.michaeldeguzman.offlinebm25.example"
mkdir -p "$out"

(cd "$root/example" && npm run sync >/dev/null)
# IPHONEOS_DEPLOYMENT_TARGET=15.0: Xcode 27 simulators start at iOS 15. The project stays at 14.0.
(cd "$root/example/ios/App" && xcodebuild build -workspace App.xcworkspace -scheme App \
  -destination "platform=iOS Simulator,id=$device" IPHONEOS_DEPLOYMENT_TARGET=15.0 \
  -derivedDataPath "$out/derived" CODE_SIGNING_ALLOWED=NO >"$out/build.log" 2>&1)
app="$out/derived/Build/Products/Debug-iphonesimulator/App.app"

xcrun simctl bootstatus "$device" -b >/dev/null
xcrun simctl terminate "$device" "$bundle" >/dev/null 2>&1 || true
xcrun simctl uninstall "$device" "$bundle" >/dev/null 2>&1 || true
xcrun simctl install "$device" "$app"

for phase in p1 p2 p3 p4 p5 p6; do
  xcrun simctl terminate "$device" "$bundle" >/dev/null 2>&1 || true   # kill
  log="$out/ios-$phase.log"
  : > "$log"
  xcrun simctl launch --console-pty "$device" "$bundle" -validate "$phase" >"$log" 2>&1 &
  launcher=$!
  tries=0
  until grep -q "|PHASE|DONE|$phase" "$log" || [ "$tries" -ge 150 ]; do sleep 2; tries=$((tries + 1)); done
  grep -q "|PHASE|DONE|$phase" "$log" || echo "TIMEOUT waiting for $phase"
  alive=$(xcrun simctl spawn "$device" launchctl list | grep -c "$bundle" || true)
  echo "phase $phase ran in process $(grep -o 'App\[[0-9]*' "$log" | head -1); app still running at the end: $([ "$alive" -gt 0 ] && echo yes || echo no)"
  xcrun simctl terminate "$device" "$bundle" >/dev/null 2>&1 || true
  kill "$launcher" 2>/dev/null || true
  wait "$launcher" 2>/dev/null || true
done
xcrun simctl terminate "$device" "$bundle" >/dev/null 2>&1 || true
grep -h "\[log\] - OBM25-VALIDATE" "$out"/ios-p1.log "$out"/ios-p2.log "$out"/ios-p3.log "$out"/ios-p4.log "$out"/ios-p5.log "$out"/ios-p6.log | sed 's/^.*OBM25-VALIDATE/OBM25-VALIDATE/'
