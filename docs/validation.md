# Validation

A summary of the runs on the iOS Simulator, an Android emulator and a physical iPhone. The unit tests also run on the JVM. Simulator and emulator numbers are not device numbers. Every build was a Debug build.

## Setup

| | iOS Simulator | Android emulator | iPhone |
|---|---|---|---|
| Target | iPhone 17 Simulator, iOS 27.0, Xcode 27.2 | API 32 (Android 12) arm64 emulator, Google APIs image | iPhone 17 Pro Max, iOS 27.2, connected by USB |
| Network | online | Airplane Mode | Airplane Mode, with Wi-Fi and Bluetooth off |
| Deployment target | 15.0 on the command line | minSdk 22, compileSdk 33 | 15.0 on the command line |

The plugin declares iOS 14.0. Xcode 27.2 accepts deployment targets from 15.0 only, so I passed `IPHONEOS_DEPLOYMENT_TARGET=15.0` on the command line and changed no project file. Nothing here validates iOS 14 to 26. There was no physical Android device, and I have not built the plugin with MABS.

## How the runs work

Each example app has a validation mode that a launch flag starts: `-validate <phase>` on iOS, a `validate` intent extra on Android. The app runs the steps itself and logs one line per result: `OBM25-VALIDATE|<platform>|<item>|<PASS|FAIL|INFO>|<detail>`. A script kills the app between phases and starts it again, so the persistence check runs in a new process. The scripts are in `tools/validate`. The expected rankings and scores come from `tests/fixtures/scores.json`.

The comparison for all 20 queries checks the result count, each score within 1e-6 at every rank, the same ids inside each group of tied scores, and ids ascending inside each group.

## Results

| Item | iOS Simulator | Android emulator | iPhone |
|---|---|---|---|
| `upsertMany` with 50 items: count 50, none skipped | pass | pass | pass |
| Kill and relaunch: `getCollectionInfo` still shows 50, and the 20 queries still match | pass | pass | pass |
| "pump seal" returns p14 first, and all 20 rankings match `scores.json` | pass | pass | pass |
| Re-upsert p14 with new text: count stays 50, results follow the new text | pass | pass | pass |
| Remove 2 ids gives 48, then clear: the collection is gone | pass | pass | pass |
| Bad input (empty or unknown collection, item without an id, missing items): readable message, no crash | pass, 10 checks | pass, 10 checks | pass, 10 checks |
| 2,000 items import and search | pass | pass | pass |

The iOS Simulator ran online. The Android emulator and the iPhone ran in Airplane Mode, so the item 3 and item 4 results there come from a device with no network. I also searched the iOS and Android plugin sources for network calls. They import only `Foundation` and `Capacitor` on iOS, and `java.io`, `java.util.concurrent`, `org.json`, `kotlin.math` and `com.getcapacitor` on Android. The Android plugin manifest declares no permission.

## Timings

Times are in milliseconds and include the Capacitor bridge. The items are generated from 50 seed procedures: item `k` takes the text of procedure `k mod 50` plus 3 extra words from a fixed linear congruential generator. The unique-words run adds 3 synthetic consonant-only words per item that appear in no other item, so the term list has 6,359 terms instead of 359. The iOS WebView rounds times to whole milliseconds.

| Measure | iOS Simulator | Android emulator | iPhone 17 Pro Max |
|---|---|---|---|
| Import, 50 items | 6 | 18 | 45 |
| Import, 2,000 items | 155 | 196 | 237 |
| Import, 2,000 items with 6,000 unique words | 209 | 185 | 307 |
| Cold first `getCollectionInfo`, 50 items | 1.0 | 10.3 | 3.0 |
| Cold first `getCollectionInfo`, 2,000 items | 32.0 | 83.9 | 53.0 |
| Cold first `getCollectionInfo`, unique-words run | 43.0 | 106.7 | 50.0 |
| Cold first search with the load included, 2,000 items | 34.0 | 68.6 | 51.0 |
| Cold first search with the load included, unique-words run | 43.0 | 50.9 | 52.0 |
| Warm search median / p95, 2,000 items | 1.0 / 4.0 | 1.0 / 3.5 | 1.0 / 5.0 |
| Warm search median / p95, unique-words run | 1.0 / 3.0 | 0.7 / 2.0 | 1.0 / 5.0 |

Cold means the first call after the app was killed and started again. The `getCollectionInfo` call loads and decodes the collection file.

| Collection | Terms | File size |
|---|---|---|
| 50 items | 359 | 12,985 bytes |
| 2,000 items | 359 | 474,285 bytes |
| 2,000 items with 6,000 unique words | 6,359 | 623,156 bytes |

The file sizes are identical on iOS and Android.

## Unit tests

| Platform | Tests |
|---|---|
| iOS, XCTest on the Simulator | 31, all pass |
| Android, JUnit on the JVM | 33, all pass |
| Android, instrumented on the emulator | 33, all pass |

They cover the parity fixtures (stemmer, tokenizer, scores), the index against `scores.json`, persistence in a fresh instance, replace, remove, clear, skipped ids, defaults, tie order, bad input, collection names, canonical equivalence of terms, ids and names, and corrupt or stale files.

## One iOS log line

Every iOS launch logs `JS Eval error A JavaScript exception occurred` once. It comes from Capacitor 5.7.8: at launch it evaluates `window.Capacitor.triggerEvent('resume', 'document')` before the page has defined `window.Capacitor`. The plugin and the example are not involved, and nothing fails because of it.

## Not validated

- A physical Android device.
- iOS 14 to 26, and any Release build.
- An ODC library and demo built with MABS.
