# Validation

A summary of the runs on the iOS Simulator, an Android emulator and a physical iPhone. The unit tests also run on the JVM. Simulator and emulator numbers are not device numbers. Every build was a Debug build.

## Setup

| | iOS Simulator | Android emulator | iPhone |
|---|---|---|---|
| Target | iPhone 17 Simulator, iOS 27.0, Xcode 27.2 | API 32 (Android 12) arm64 emulator, Google APIs image | iPhone 17 Pro Max, iOS 27.2, connected by USB |
| Network | online | Airplane Mode | Airplane Mode, with Wi-Fi and Bluetooth off |
| Deployment target | 15.0 on the command line | minSdk 22, compileSdk 33 | 15.0 on the command line |

The plugin declares iOS 14.0. Xcode 27.2 accepts deployment targets from 15.0 only, so I passed `IPHONEOS_DEPLOYMENT_TARGET=15.0` on the command line and changed no project file. Nothing here validates iOS 14 to 26. There was no physical Android device. The MABS builds are in the README status.

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
- The ODC demo built with MABS on Android. The iPhone run is in the README status.

## Raw iPhone output

The per-phase .log files were not kept. This block is the console output the script printed during the run.

```
• Marketing Name: iPhone 17 Pro Max
• Product Type: iPhone18,2
• Thinning Product Type: iPhone18,2
• OS Build Update: 24B119
• OS Version: 27.2
phase p1 ran in process 4024
phase p2 ran in process 4029
phase p3 ran in process 4033
phase p4 ran in process 4037
phase p5 ran in process 4041
phase p6 ran in process 4045
OBM25-VALIDATE|ios|PHASE|INFO|p1 begin; navigator.onLine=false
OBM25-VALIDATE|ios|SETUP|INFO|collection cleared
OBM25-VALIDATE|ios|ITEM2|PASS|count=50; skipped=0; 41 ms
OBM25-VALIDATE|ios|ITEM4-pump-seal|PASS|top=p14; results=p14,p40,p11,p43,p23; navigator.onLine=false
OBM25-VALIDATE|ios|ITEM4-all-queries|PASS|20 queries; 0 problems 
OBM25-VALIDATE|ios|PHASE|DONE|p1
OBM25-VALIDATE|ios|PHASE|INFO|p2 begin; navigator.onLine=false
OBM25-VALIDATE|ios|ITEM3|PASS|exists=true; count=50; uniqueTerms=359; tokenizerVersion=2
OBM25-VALIDATE|ios|ITEM3-queries-after-relaunch|PASS|20 queries; 0 problems
OBM25-VALIDATE|ios|PHASE|DONE|p2
OBM25-VALIDATE|ios|PHASE|INFO|p3 begin; navigator.onLine=false
OBM25-VALIDATE|ios|ITEM5|PASS|upsert.count=1; info.count=50; 'gasket' top=p14; 'seal' before has p14=true; 'seal' after has p14=false; 'pump seal' top=p11
OBM25-VALIDATE|ios|ITEM6|PASS|removed=2; count after remove=48; exists after clear=false; search after clear: collection 'manual' does not exist
OBM25-VALIDATE|ios|ITEM7-empty-collection|PASS|message=collection is required and must not be empty
OBM25-VALIDATE|ios|ITEM7-whitespace-collection|PASS|message=collection is required and must not be empty
OBM25-VALIDATE|ios|ITEM7-empty-collection-info|PASS|message=collection is required and must not be empty
OBM25-VALIDATE|ios|ITEM7-unknown-collection-search|PASS|message=collection 'nope' does not exist
OBM25-VALIDATE|ios|ITEM7-unknown-collection-remove|PASS|message=collection 'nope' does not exist
OBM25-VALIDATE|ios|ITEM7-item-without-id|PASS|message=items[0] needs a non-empty string id and a string text
OBM25-VALIDATE|ios|ITEM7-missing-items|PASS|message=items is required
OBM25-VALIDATE|ios|ITEM7-unknown-info|PASS|exists=false; count=0; currentTokenizerVersion=2
OBM25-VALIDATE|ios|ITEM7-rejected-call-wrote-nothing|PASS|bad exists=false
OBM25-VALIDATE|ios|ITEM7-alive|PASS|the app is still running after every rejection
OBM25-VALIDATE|ios|ITEM8|PASS|import_ms=231; count=2000; skipped=0; uniqueTerms=359; avgLength=14.61; searches=100; search_median_ms=1.0; search_p95_ms=5.0; search_max_ms=12.0
OBM25-VALIDATE|ios|SETUP|INFO|bench collection cleared
OBM25-VALIDATE|ios|PHASE|DONE|p3
OBM25-VALIDATE|ios|PHASE|INFO|p4 begin; navigator.onLine=false
OBM25-VALIDATE|ios|TIMING-IMPORT-manual|PASS|50 items; import_ms=45; count=50; skipped=0; uniqueTerms=359; avgLength=11.90
OBM25-VALIDATE|ios|TIMING-IMPORT-bench2k|PASS|2000 items; import_ms=237; count=2000; skipped=0; uniqueTerms=359; avgLength=14.61
OBM25-VALIDATE|ios|TIMING-IMPORT-bench2kU|PASS|2000 items, 6000 unique words; import_ms=307; count=2000; skipped=0; uniqueTerms=6359; avgLength=17.61
OBM25-VALIDATE|ios|TIMING-FILESIZE|INFO|bench2k%55.bm25.json; bytes=623156
OBM25-VALIDATE|ios|TIMING-FILESIZE|INFO|bench2k.bm25.json; bytes=474285
OBM25-VALIDATE|ios|TIMING-FILESIZE|INFO|manual.bm25.json; bytes=12985
OBM25-VALIDATE|ios|PHASE|DONE|p4
OBM25-VALIDATE|ios|PHASE|INFO|p5 begin; navigator.onLine=false
OBM25-VALIDATE|ios|TIMING-BRIDGE|INFO|first_call_ms=1.0
OBM25-VALIDATE|ios|TIMING-COLD-manual|PASS|50 items; first_getCollectionInfo_ms=3.0; count=50; first_search_ms=1.0; results=7; searches=100; warm_median_ms=0.0; warm_p95_ms=1.0; warm_max_ms=31.0
OBM25-VALIDATE|ios|TIMING-COLD-bench2k|PASS|2000 items; first_getCollectionInfo_ms=53.0; count=2000; first_search_ms=3.0; results=10; searches=100; warm_median_ms=1.0; warm_p95_ms=5.0; warm_max_ms=5.0
OBM25-VALIDATE|ios|TIMING-COLD-bench2kU|PASS|2000 items, 6000 unique words; first_getCollectionInfo_ms=50.0; count=2000; first_search_ms=3.0; results=10; searches=100; warm_median_ms=1.0; warm_p95_ms=5.0; warm_max_ms=10.0
OBM25-VALIDATE|ios|PHASE|DONE|p5
OBM25-VALIDATE|ios|PHASE|INFO|p6 begin; navigator.onLine=false
OBM25-VALIDATE|ios|TIMING-BRIDGE|INFO|first_call_ms=1.0
OBM25-VALIDATE|ios|TIMING-COLD-manual|PASS|50 items; first_search_ms=5.0; results=7; then_getCollectionInfo_ms=0.0; count=50; searches=100; warm_median_ms=0.0; warm_p95_ms=1.0; warm_max_ms=30.0
OBM25-VALIDATE|ios|TIMING-COLD-bench2k|PASS|2000 items; first_search_ms=51.0; results=10; then_getCollectionInfo_ms=0.0; count=2000; searches=100; warm_median_ms=1.0; warm_p95_ms=4.0; warm_max_ms=5.0
OBM25-VALIDATE|ios|TIMING-COLD-bench2kU|PASS|2000 items, 6000 unique words; first_search_ms=52.0; results=10; then_getCollectionInfo_ms=0.0; count=2000; searches=100; warm_median_ms=1.0; warm_p95_ms=5.0; warm_max_ms=8.0
OBM25-VALIDATE|ios|PHASE|DONE|p6
```
