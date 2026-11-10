#!/bin/sh
# Plan section 5, items 2 to 8 (phases p1 to p3) and the timing runs (p4 to p6) on a physical iPhone,
# driven with xcrun devicectl. Two steps, so the person holding the phone can switch on Airplane Mode
# between them:
#   tools/validate/run-ios-device.sh build <device udid> <team id> <output dir>
#   tools/validate/run-ios-device.sh run   <device udid> <output dir>
# The build step passes IPHONEOS_DEPLOYMENT_TARGET=15.0 on the command line, because Xcode 27.2 accepts
# no lower target. No project or podspec file is changed. The phone must be unlocked.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
bundle="com.michaeldeguzman.offlinebm25.example"
mode="$1"

if [ "$mode" = "build" ]; then
  udid="$2"; team="$3"; out="$4"
  mkdir -p "$out"
  (cd "$root/example" && npm run sync >/dev/null)
  (cd "$root/example/ios/App" && xcodebuild build -workspace App.xcworkspace -scheme App \
    -destination "platform=iOS,id=$udid" -derivedDataPath "$out/derived" -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Automatic IPHONEOS_DEPLOYMENT_TARGET=15.0 >"$out/build.log" 2>&1)
  xcrun devicectl device install app --device "$udid" "$out/derived/Build/Products/Debug-iphoneos/App.app" >"$out/install.log" 2>&1
  echo "built and installed on $udid"
  exit 0
fi

udid="$2"; out="$3"
mkdir -p "$out"
xcrun devicectl device info details --device "$udid" 2>/dev/null | grep -E "Marketing Name|Product Type|OS Version|OS Build" || true
for phase in p1 p2 p3 p4 p5 p6; do
  log="$out/device-$phase.log"
  : >"$log"
  # --terminate-existing kills any running copy first, so every phase starts a new process.
  xcrun devicectl device process launch --device "$udid" --console --terminate-existing "$bundle" -- -validate "$phase" >"$log" 2>&1 &
  launcher=$!
  tries=0
  until grep -q "|PHASE|DONE|$phase" "$log" || [ "$tries" -ge 150 ]; do sleep 2; tries=$((tries + 1)); done
  grep -q "|PHASE|DONE|$phase" "$log" || echo "TIMEOUT waiting for $phase"
  pid=$(grep -o 'App\[[0-9]*' "$log" | head -1 | tr -dc '0-9')
  echo "phase $phase ran in process $pid"
  xcrun devicectl device process terminate --device "$udid" --pid "$pid" >/dev/null 2>&1 || true   # kill
  kill "$launcher" 2>/dev/null || true
  wait "$launcher" 2>/dev/null || true
done
grep -h "\[log\] - OBM25-VALIDATE" "$out"/device-p?.log | sed 's/^.*OBM25-VALIDATE/OBM25-VALIDATE/'
