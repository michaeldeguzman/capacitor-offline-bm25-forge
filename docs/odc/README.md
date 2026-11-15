# ODC library: OfflineKeywordSearch

How to wrap the plugin in an ODC Mobile Library. The JavaScript nodes are in `js/`, the structures in `structures.json` and the sample data in `seed/` as JSON. I built this shape for my own libraries, and the same JavaScript is checked against a mock plugin with `node tools/odc/check-js.js`. MABS built and launched the Android APK on an API 32 emulator and the iOS Simulator build. I validated the demo through MABS on an iPhone 17 Pro Max (iOS 27.2). I have not run the full demo on Android, and it is not planned for now.

## 1. Library and extensibility

Create an ODC **Mobile Library** named `OfflineKeywordSearch`. Create the demo as a **Mobile app**. The kind is fixed at creation and cannot be converted later. Open **Extensibility Configurations** and paste `extensibility.json`:

```json
{
  "buildConfigurations": {
    "capacitor": {
      "source": {
        "npm": "capacitor-offline-bm25@0.1.0"
      }
    }
  }
}
```

The source is the npm package at an exact version. To move to a newer plugin version, change the version after the `@`. As an alternative, use the tag in the public release repo. The tag includes the built `dist` folder, so no build step is needed:

```json
{
  "buildConfigurations": {
    "capacitor": {
      "source": {
        "npm": "git+https://github.com/michaeldeguzman/capacitor-offline-bm25-forge.git#v0.1.0"
      }
    }
  }
}
```

To use another release, change the tag at the end of the URL. The plugin needs no iOS usage description and no Android permission.

In Extensibility, tick **Mobile plugin compatibility: Capacitor**. After any change to the Extensibility Configuration, publish the library, republish the demo and create a new mobile package. Existing packages keep the old configuration.

## 2. Structures (Public = Yes)

Use **Add Structure from JSON** with each object in `structures.json`, rename it, and set Public to Yes.

| Structure | Attributes |
|---|---|
| `KeywordItem` | `Id` (Text), `Text` (Text), `Metadata` (Text) |
| `KeywordMatch` | `Id` (Text), `Score` (Decimal), `Metadata` (Text), `MatchedTerms` (Integer) |
| `KeywordCollectionInfo` | `Exists` (Boolean), `Count` (Integer), `UniqueTerms` (Integer), `AvgLength` (Decimal), `TokenizerVersion` (Integer), `CurrentTokenizerVersion` (Integer), `NeedsReindex` (Boolean) |
| `Result` | `Success` (Boolean), `ErrorMessage` (Text) |

The attribute names must match exactly. The JavaScript writes JSON with these names, and the JSON Deserialize nodes read them.

## 3. Client actions (Public = Yes)

Every action has one JavaScript node. Paste the file with the action's name from `js/`. Every action except `IsPluginAvailable` returns a `Result`. `IsPluginAvailable` returns flat outputs.

| Action | Inputs | Outputs | Flow |
|---|---|---|---|
| `IsPluginAvailable` | none | `Available`, `TokenizerVersion`, `Success`, `ErrorMessage` | JS node, Assign |
| `UpsertMany` | `Collection`, `Items` (List of `KeywordItem`) | `Count`, `SkippedIds` (Text List), `Result` | JSON Serialize `Items`, JS node, JSON Deserialize `SkippedJson` as Text List, Assign |
| `Search` | `Collection`, `Query`, `TopK` (5), `MinScore` (0), `K1` (1.2), `B` (0.75) | `Results` (List of `KeywordMatch`), `Result` | JS node, JSON Deserialize `ResultsJson` as List of `KeywordMatch`, Assign |
| `Remove` | `Collection`, `Ids` (Text List) | `Count`, `Result` | JSON Serialize `Ids`, JS node, Assign |
| `Clear` | `Collection` | `Result` | JS node, Assign |
| `GetCollectionInfo` | `Collection` | `Info` (`KeywordCollectionInfo`), `Result` | JS node, JSON Deserialize `InfoJson` as `KeywordCollectionInfo`, Assign |
| `Tokenize` | `Text` | `Tokens` (Text List), `Result` | JS node, JSON Deserialize `TokensJson` as Text List, Assign |

`TopK`, `MinScore`, `K1` and `B` are optional, with the defaults in brackets. The Decimal inputs can reach JavaScript as objects, so `Search.js` converts them with `toNumber()`.

## 4. How the JavaScript nodes work

- Each JS node has its own parameters. Add an Input Parameter for each input and set its value to the action input or to the JSON Serialize output. Read it as `$parameters.Name`.
- Add an Output Parameter for each output the code sets, as `$parameters.Name = value`. An Assign after the node copies it to the action output.
- Parameters are primitives only. Lists cross the boundary as JSON Text, so a JSON Serialize runs before the node and a JSON Deserialize after it.
- The code calls `$resolve()` with no arguments, on success and on failure. On failure it sets `Success` to false and `ErrorMessage` to the plugin's message, and it returns an empty list or a default object, so the JSON Deserialize after it never fails.
- The input and output names for each file are in the comment at the top of the file.

## 5. Check the library

1. Publish the library, add it as a dependency to a Mobile app, and call `IsPluginAvailable` on a device build. ODC treats the library as a producer only once the app uses at least one of its elements, so ticking it in Manage Dependencies is not enough. Confirm on the app's Producers tab in the Portal. It returns `Available` true and `TokenizerVersion` 2.
2. Call `UpsertMany` with the items in `seed/seed-procedures.json` (indexed as `Title + ". " + Body`, with `Code` as the id). It returns `Count` 50. A search for `pump seal` returns `p14` first.
3. The expected ranking for 20 queries is in `tests/fixtures/scores.json`.

### Demo data from a server action

A demo app can carry its documents as a resource, read them in a server action, copy them once into a local entity, and search that copy offline. The sample set is `seed/seed-procedures-v2.json`, 50 procedures. Each `Body` in it ends with a sentence of identifiers. `seed/seed-procedures.json` is the original set without identifiers, which `tests/fixtures/scores.json` was generated from. `seed/demo-expected.json` holds the ranked results for 20 demo queries over the v2 set.

1. Create a structure `SeedProcedure` with `Code`, `Title`, `Body` and `Category`, all Text. Use **Add Structure from JSON** with the first record of `seed/seed-procedures-v2.json`.
2. Add `seed/seed-procedures-v2.json` to the app as a resource. Create a server action `GetSeedProcedures` that reads the resource, JSON Deserializes it into a `List of SeedProcedure` and returns the list.
3. Create a local entity `LocalProcedure` with `Code` (Text 20), `Title` (Text 200), `Body` (Text 2000) and `Category` (Text 200). Set the lengths before the first publish. A client action calls `GetSeedProcedures`, creates or updates local rows by `Code`, and deletes local rows whose `Code` is no longer in the list. It stops without changes if the list is empty.
4. Load nothing automatically. Leave On Initialize empty. Add a **Load from server** button that runs the sync and shows `<n> procedures stored`, or `Could not load procedures: ` plus the error message on failure. Add a **Build index** button that clears an existing collection and indexes from `LocalProcedure`, or shows `Load from server first` when `LocalProcedure` is empty. Add a **Refresh status** button that shows `IsPluginAvailable`, the `LocalProcedure` count and `GetCollectionInfo`. Tap Load while online, then Build. Every search after that works offline, and a relaunch keeps the index because nothing rebuilds it on start.

Build every list with For Each and ListAppend. Do not use ListAppendAll with an assignment that maps to a fixed row, such as the current row of an aggregate. That mapping copies one row N times, so the list holds N copies of one id and the index keeps one item. The index then holds one item instead of 50. After the first build of the index, `GetCollectionInfo` must show `Count 50`.

If `LocalProcedure.Body` keeps the default Text length (50), the bodies are cut off, the indexed text changes, and the expected scores in `seed/demo-expected.json` no longer match. ODC raises no error. Check one record after the first load: the `p01` Body in `LocalProcedure` must equal the JSON text, with the same length. The longest body is `p01`, at 232 characters.

### Identifiers and tokens

The v2 data has fault codes (`E-217`), part numbers (`MS-4471-B`), model numbers (`VX-1150`) and Australian standards references (`AS 1851`). BM25 does not match a code as one string. The tokenizer lowercases the text, splits it on every character that is not a letter or a digit, drops stop words and single digits, and stems what is left. A hyphen therefore splits `E-217` into the tokens `e` and `217`.

Matching is per token, and each token is weighted by how rare it is in the collection. In the sample data the token `217` is in one procedure and `e` is in six. A query for `E-217` ranks the procedure with `217` first, at 5.14, and the procedures with only `e` trail at 2.11 and below. `E-271` differs from `E-217` in the rare token, so it ranks a different procedure first. The pairs `MS-4471-B` and `MS-4471-C`, `BT-3382` and `BT-3328`, and `VX-1150` and `VX-1510` behave the same way.

This is not an exact match on the whole code. A code that shares tokens with another code scores on the shared tokens as well. Stop words and stemming change some codes: `AS 1851` becomes the token `1851`, `V-7` becomes the single letter `v`, and `2RS` is stemmed to `2r`. `seed/identifier-tokens.md` lists the tokens for every identifier in the sample data and flags the weak ones. The expected results come from the C# BM25Engine. On the iPhone, the demo index matched it: `Count 50`, `UniqueTerms 572`, `AvgLength 22.3`.

#### Limits for identifiers

- **A single letter or digit is the distinctive part.** `V-7` reduces to the token `v`, because the tokenizer drops the single digit `7`. `V-7` and `V-3` become the same token, so the code cannot be found on its own.
- **`AS` is a stop word and trailing single digits are dropped.** `AS 1674.1` and `AS 1674.2` both become the token `1674`, so they index the same. A query for `AS 1674.2` finds the procedure that cites `AS 1674.1`.
- **Shared numbers match each other.** `UP-3000` loses `up` as a stop word and `AS/NZS 3000` loses `as`, so both hold the token `3000`. A query for `3000` returns both.
- **A partial code matches every identifier that shares the remaining tokens.** `MS-4471` returns the procedures with `MS-4471-B` and `MS-4471-C`, tied, and a procedure with only the token `ms` after them.

`GetSeedProcedures` is callable without sign-in if the screen has no role. That suits demo data. Real documents need a role check.

This guide gives the steps. I validated a demo built from them through MABS on an iPhone 17 Pro Max (iOS 27.2). I have not run it on Android through MABS beyond a build and a launch, and that is not planned for now.

The example apps in `example/` show the same calls without ODC.

## 6. Package and install

Publish the Mobile app, then create one package per platform on its **Mobile distribution** tab in the Portal.

**Packages.** The iOS package downloads as a zip holding `App.app`. That is a Simulator build. Check it with `vtool -show-build App.app/App | grep platform`, where `IOSSIMULATOR` means Simulator. The Android package is an APK.

**iOS Simulator.** `open -a Simulator` may fail on some Xcode versions, so use `simctl` directly.

1. If no simulator is booted, run `xcrun simctl boot "<device name>"`.
2. Run `xcrun simctl install booted <path>/App.app`.
3. Read the bundle id: `/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" <path>/App.app/Info.plist`.
4. Run `xcrun simctl launch booted <bundle id>`. It prints a process id on success.
5. Take a screenshot: `xcrun simctl io booted screenshot <file>.png`.

**Android emulator.**

1. Start it with `<android sdk>/emulator/emulator -avd <avd name>`.
2. Run `adb install -r <apk>`.
3. Find the package: `adb shell pm list packages | grep -i offlinekeyword`.
4. Launch: `adb shell monkey -p <package> -c android.intent.category.LAUNCHER 1`.
5. Confirm it is running: `adb shell pidof <package>`.
6. Take a screenshot: `adb exec-out screencap -p > <file>.png`.

Use the full path to `adb` if it is not on `PATH`. Airplane Mode may still be on from an earlier run.

**iPhone.** A device needs a signed Development package. In the Apple Developer account, register an App ID for the app's bundle id (read it from the app), register the iPhone, create a Development certificate and export it from Keychain as a `.p12` with a password, and create a Development provisioning profile for that App ID, certificate and device. Then create an iOS package with build type **Development** and upload the `.p12`, its password and the `.mobileprovision`. Install it through Xcode: **Window**, **Devices and Simulators**, **Installed Apps**, **+**. A device build contains `embedded.mobileprovision` inside `App.app`.

**Test order.** Start with the Android emulator, which needs no signing. Then the iOS Simulator. Then the iPhone in Airplane Mode for the offline check.

The full demo has not run on Android through MABS, so this guide has no Android results.
