# capacitor-offline-bm25

On-device BM25 keyword search for Capacitor apps. Text is tokenized, indexed and scored on the phone, with no network, no API key, and no data leaving the device. It gives the same tokens and scores as BM25Engine, my C# component for server-side keyword search in OutSystems, so a query behaves the same on the server and on the device.

Index short texts (FAQ entries, procedure steps, chunks of a document), then search them by words: "pump seal" finds "Pump seal replacement". It matches words, not meaning. For meaning, use [capacitor-semantic-search](https://github.com/michaeldeguzman/capacitor-semantic-search-forge). Their scores are not comparable, so do not blend or rank them together. It handles English only, and it does no phrase, boolean or fuzzy queries.

## Status

This is a beta release, `0.1.0-beta.2`. It is not on npm or the Forge. Install it from this repo at a tag.

| Platform | What I validated | What I did not |
|---|---|---|
| iOS | Unit tests on the Simulator. The validation steps in [docs/validation.md](docs/validation.md) on the Simulator and on a physical iPhone (iPhone 17 Pro Max, iOS 27.2) in Airplane Mode. | iOS 14 to 26. The plugin declares iOS 14.0, but Xcode 27.2 builds no lower than 15.0, so every build I ran used `IPHONEOS_DEPLOYMENT_TARGET=15.0`. |
| Android, tests | JVM unit tests and instrumented tests on an API 32 (Android 12) emulator. | A physical Android device. |
| Android, example app | The validation steps in [docs/validation.md](docs/validation.md) on that emulator, in Airplane Mode. | A physical Android device. |
| MABS | Nothing yet. | An ODC build of the library and the demo. The Android module applies the Kotlin Gradle plugin 1.8.22, and I have not checked that MABS builds it unchanged. |
| Web | Every method rejects with "OfflineBM25 is not available on web". | |

The Android module uses minSdk 22 and compileSdk 33, with Gradle 8.0.2 and AGP 8.0.0, the same setup as capacitor-semantic-search.

## Install

Built against Capacitor 5. The semantic plugin, built the same way, ran in a MABS 12.1 build. This plugin has not been through MABS yet.

```bash
npm install "git+https://github.com/michaeldeguzman/capacitor-offline-bm25-forge.git#v0.1.0-beta.2"
npx cap sync
```

The repo holds the built `dist` folder, so a git install has the `main`, `module` and `types` files.

For an ODC Mobile Library, put this in the library's Extensibility Configuration (also in [docs/odc/extensibility.json](docs/odc/extensibility.json)):

```json
{
  "buildConfigurations": {
    "capacitor": {
      "source": {
        "npm": "git+https://github.com/michaeldeguzman/capacitor-offline-bm25-forge.git#v0.1.0-beta.2"
      }
    }
  }
}
```

The ODC steps are in [docs/odc/README.md](docs/odc/README.md).

## Example

```typescript
import { OfflineBM25 } from 'capacitor-offline-bm25';

// 1. Check the plugin is there.
const { available, tokenizerVersion } = await OfflineBM25.isAvailable();

// 2. Index content once (for example after syncing it from your server).
const { count, skipped } = await OfflineBM25.upsertMany({
  collection: 'manual',
  items: [
    {
      id: 'p14',
      text: 'Pump seal replacement. Replace the mechanical seal when liquid drips from the shaft gland.',
      metadata: 'Pump seal replacement',
    },
    {
      id: 'p18',
      text: 'Generator load test. Run the standby generator under load once a month for thirty minutes.',
      metadata: 'Generator load test',
    },
  ],
});

// 3. Search, offline.
const { results } = await OfflineBM25.search({ collection: 'manual', query: 'pump seal', topK: 5 });
// results: [{ id: 'p14', score, metadata: 'Pump seal replacement', matchedTerms: 2 }]
// p18 has neither term, so it is not returned.

// 4. On app start, check whether the tokenizer has changed since the index was built.
const info = await OfflineBM25.getCollectionInfo({ collection: 'manual' });
if (info.needsReindex) {
  await OfflineBM25.clear({ collection: 'manual' });
  // Call upsertMany again with the same items.
}
```

Notes:
- `id` is yours. Upserting an existing id replaces its text and metadata. When one call repeats an id, the last item wins.
- `metadata` is a free-text string returned with each result.
- `skipped` lists ids whose text gave no tokens (empty, only punctuation, or only stop words). If such an id was already indexed, the old entry is removed.
- Scores are BM25 scores. They are not limited to 0 to 1, so a `minScore` from a similarity search does not carry over.

## API

| Method | Takes | Resolves with |
|---|---|---|
| `isAvailable()` | nothing | `{ available, tokenizerVersion }` |
| `upsertMany(options)` | `collection`, `items: { id, text, metadata? }[]` | `{ count, skipped }` |
| `search(options)` | `collection`, `query`, `topK?`, `minScore?`, `k1?`, `b?` | `{ results: { id, score, metadata, matchedTerms }[] }` |
| `remove(options)` | `collection`, `ids` | `{ count }` |
| `clear(options)` | `collection` | nothing |
| `getCollectionInfo(options)` | `collection` | `{ exists, count, uniqueTerms, avgLength, tokenizerVersion, currentTokenizerVersion, needsReindex }` |
| `tokenize(options)` | `text` | `{ tokens }` |

Defaults and behaviour:
- `search`: `topK` 5 (a value of 0 or less also gives 5), `minScore` 0, `k1` 1.2, `b` 0.75. A hit needs a score greater than or equal to `minScore`.
- `matchedTerms` is how many distinct query terms the item contains.
- A query that tokenizes to nothing (empty, or only stop words) resolves with no results. It is not an error.
- Equal scores are ordered by id ascending, compared by UTF-16 code units.
- `getCollectionInfo` on an unknown collection resolves with `exists: false` and zeros, and fills `currentTokenizerVersion`. `clear` on an unknown collection does nothing.
- `tokenize` returns the stemmed tokens, which helps when you debug why a query does or does not match.
- `tokenizerVersion` is 2. If a future release changes the tokenizer, `needsReindex` becomes true for old collections, and `upsertMany` into one is rejected until you clear it.

The TypeScript definitions are in [src/definitions.ts](src/definitions.ts).

## Collections and storage

Each collection is one JSON file: Application Support/OfflineBM25 on iOS, the app files directory under `offlinebm25` on Android. It holds a term list, the items (id, metadata, token count, term frequencies) and the inverted map. It does not hold the original text. Corpus statistics are recomputed after every write, and a write goes to a temporary file that then replaces the old one.

```
{"collection":"demo","format":1,"items":[{"id":"a","metadata":"Pump seal","terms":[[0,1],[1,1],[2,1]],"tokenCount":3}],"postings":[[0],[0],[0]],"terms":["pump","replac","seal"],"tokenizerVersion":2}
```

Terms and ids are compared by UTF-16 code units on both platforms. On iOS every term and id key is an array of code units, because a Swift `String` key would merge canonically equivalent terms.

A collection name can be any text except an empty or whitespace-only one. Names are case-sensitive. The file name is the name read as UTF-8 bytes, with every byte outside a-z, 0-9, underscore and hyphen written as `%XX`, plus `.bm25.json`. Capital letters are encoded too, so names that differ only by case never share a file on a case-insensitive disk, and no name can reach outside the storage directory. A name is rejected when its file name is longer than 200 bytes. Android also rejects a name with an unpaired surrogate. On iOS the bridge replaces such a surrogate with U+FFFD before the plugin sees it.

Every error rejects the call with one of these messages. `<name>` is the collection name and `<n>` an index into `items`.

| Case | Message |
|---|---|
| Missing, empty or whitespace-only collection | `collection is required and must not be empty` |
| Encoded file name over 200 bytes | `collection name is too long. Its encoded file name would be <bytes> bytes and the limit is 200` |
| Unpaired surrogate in a name (Android) | `collection name contains an unpaired surrogate and cannot be stored` |
| `search` or `remove` on an unknown collection | `collection '<name>' does not exist` |
| `search` without `query` | `query is required` |
| `remove` without `ids` | `ids is required` |
| `upsertMany` without `items` | `items is required` |
| Item without a non-empty string id or a string text | `items[<n>] needs a non-empty string id and a string text` |
| Item with a non-string metadata | `items[<n>].metadata must be a string` |
| `upsertMany` into a collection built with another tokenizer version | `collection '<name>' was built with tokenizer version <old> and the current version is 2. Clear it and import again` |
| Unreadable or corrupt file | `collection '<name>' could not be read: <reason>` |
| Failed write | `collection '<name>' could not be saved: <reason>` |
| Failed delete | `collection '<name>' could not be deleted` |
| `tokenize` without `text` | `text is required` |
| Any method on web | `OfflineBM25 is not available on web` |

## Parity with BM25Engine

The tokenizer, stop-word list, Porter stemmer and BM25 scorer are ports of BM25Engine, a C# External Logic component for OutSystems Developer Cloud. The rules:
- Lowercase, as C# `ToLowerInvariant`.
- Every character that is not a letter, digit or whitespace becomes a space, so punctuation is a token boundary (`ERR-BM25-003` gives `err`, `bm25`, `003`).
- Drop a token that is shorter than 2 characters and purely numeric.
- Drop English stop words (the BM25Engine list, matched ordinally).
- Porter-stem what remains.
- BM25 with `IDF = ln((N - n + 0.5) / (n + 0.5) + 1)`. `k1` and `b` are arguments, never fixed in the scorer.

The ports are tested against golden fixtures in [tests/fixtures](tests/fixtures), generated by running BM25Engine. See [tests/fixtures/README.md](tests/fixtures/README.md) for how. The fixtures are never edited by hand.

| Fixture | Content | Result on iOS, JVM and the Android emulator |
|---|---|---|
| `stemmer.json` | 162 word and stem pairs | identical |
| `tokenizer.json` | 37 cases, 20 of them extra strings (punctuation, error codes, contractions, numbers, accents, emoji) | identical |
| `scores.json` | 50 documents and 20 queries, `k1` 1.2, `b` 0.75, full ranked lists | same ranking, each score within 1e-6 |

Run the tests: on iOS `cd ios && pod install && xcodebuild test -workspace Plugin.xcworkspace -scheme PluginTests -destination 'platform=iOS Simulator,name=<a simulator>'`. On Android `cd android && ./gradlew test connectedAndroidTest` with Gradle 8.0.2 on a JDK 17 and an emulator running.

### Known differences

Both ports copy the C# character rules on UTF-16 code units. The Swift port never uses `Character`, which is a grapheme cluster. The Kotlin port iterates `Char`, which is a code unit.

- `char.IsLetterOrDigit`: general category Lu, Ll, Lt, Lm, Lo or Nd.
- `char.IsWhiteSpace`: category Zs, Zl or Zp, plus U+0009 to U+000D and U+0085. The Kotlin port does not call `Char.isWhitespace`, because Java treats U+001C to U+001F as whitespace and .NET does not.
- `ToLowerInvariant`: the single-scalar lowercase mapping of each code unit. U+0130 stays unchanged, as in .NET. Java maps U+0130 to `i`, so the Kotlin port special-cases it. Neither port uses a string-level lowercase, because those apply the final-sigma rule and C# does not.

Characters outside the Basic Multilingual Plane, such as emoji and mathematical bold letters, are surrogate pairs in UTF-16. Each surrogate is neither a letter nor whitespace, so these characters are dropped, as in C#.

I compared all 65,536 code units against .NET 10.0.8. Whitespace, `IsDigit` and U+0130 agree everywhere. The other differences come from the Unicode version of each runtime:

| Runtime | `IsLetterOrDigit` differs | `ToLowerInvariant` differs |
|---|---|---|
| Swift 6.4.2 on macOS (Unicode 17) | 8 units, which Swift calls letters and .NET does not: U+088F, U+0C5C, U+0CDC, U+A7CE, U+A7CF, U+A7D2, U+A7D4, U+A7F1 | 0 |
| Kotlin on JVM 17 | 64 units, which .NET calls letters and Java does not | 13 units |
| Kotlin on the Android 12 emulator (API 32) | the same 64 units | the same 13 units |

The Kotlin differences are characters added to Unicode after about version 13, such as Arabic Extended-B (U+0870 to U+088E), Latin Extended-D additions (U+A7C0 to U+A7DC) and CJK Unified Ideographs additions (U+9FFD to U+9FFF). None appears in English text. I tested API 32 only. The result on a device depends on the Unicode version of its OS. The full tables are in [docs/charclass-comparison.md](docs/charclass-comparison.md).

C# does not define the order of equal scores, because `List.Sort` is unstable. Both ports order ties by score descending, then id ascending, so a result list is the same on every run.

## Timings

These are Debug builds. The iOS Simulator and the Android emulator ran on a Mac. The iPhone is a physical iPhone 17 Pro Max on iOS 27.2. The Android emulator and the iPhone ran in Airplane Mode. The iOS Simulator ran online. The iOS WebView rounds times to whole milliseconds.

The items are generated from 50 seed procedures: item `k` takes the text of procedure `k mod 50` plus 3 extra words. The unique-words run adds 3 synthetic words that appear in no other item, so the term list has 6,359 terms instead of 359. Times are in milliseconds and include the bridge.

| Measure | iOS Simulator | Android emulator | iPhone 17 Pro Max |
|---|---|---|---|
| Import, 50 items | 6 | 18 | 45 |
| Import, 2,000 items | 155 | 196 | 237 |
| Import, 2,000 items with 6,000 unique words | 209 | 185 | 307 |
| Cold first `getCollectionInfo`, 2,000 items | 32.0 | 83.9 | 53.0 |
| Cold first `getCollectionInfo`, unique-words run | 43.0 | 106.7 | 50.0 |
| Warm search median / p95, 2,000 items | 1.0 / 4.0 | 1.0 / 3.5 | 1.0 / 5.0 |
| Warm search median / p95, unique-words run | 1.0 / 3.0 | 0.7 / 2.0 | 1.0 / 5.0 |

File sizes: 12,985 bytes for 50 items, 474,285 bytes for 2,000 items, and 623,156 bytes for the unique-words run. I did not measure a physical Android device or a Release build.

## Limits

- **English only.** The stop words and the Porter stemmer are English.
- **Words, not meaning.** "backup power plant needs its monthly run" does not find "Generator load test". Use a semantic search for that.
- **Single-term matching.** "pump seal" matches items with either term, ranked by BM25. There are no phrase, boolean or fuzzy queries, and no synonyms.
- **Contractions split at the apostrophe.** `don't` becomes `don` and `t`. This is a documented BM25Engine v2 trade-off.
- **Scores are not bounded to 0 to 1.**
- **No hybrid scoring.** A blend with a semantic search needs its own design and its own evaluation.
- **No web implementation.** Every method rejects on web.
- **Short texts.** I tested 2,000 items of about 15 tokens. I did not test long documents.

## ODC library

[docs/odc](docs/odc) has everything for an ODC Mobile Library that wraps the plugin: the seven JavaScript nodes, the structures, the seed data and a short guide. The JavaScript nodes are checked against a mock plugin with `node tools/odc/check-js.js`.

## Example apps

[example](example) is a minimal Capacitor app for iOS and Android. It indexes the 50 seed procedures on first launch, and it has a search box and a validation mode. Run `npm install` and `npm run sync` in `example/`, then build `ios/App/App.xcworkspace` or open `android/`. The validation scripts are in [tools/validate](tools/validate).

## Third-party notices

The Porter stemming algorithm is by M. F. Porter. BM25Engine is the reference implementation. See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). The plugin's own code is MIT licensed.

## Next

I plan to build the ODC library and demo in Studio and run them through MABS on an iPhone. After that I want to check Android on a physical device and the iOS 14 target on an older Xcode.
