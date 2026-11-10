# ODC library: OfflineKeywordSearch

How to wrap the plugin in an ODC Mobile Library. The JavaScript nodes are in `js/`, the structures in `structures.json` and the sample data in `seed/`. I built this shape for my own libraries, and the same JavaScript is checked against a mock plugin with `node tools/odc/check-js.js`. I have not yet run it through a MABS build.

## 1. Library and extensibility

Create an ODC **Mobile Library** named `OfflineKeywordSearch`. Open **Extensibility Configurations** and paste `extensibility.json`:

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

To use another release, change the tag at the end of the URL. The plugin needs no iOS usage description and no Android permission.

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

Every action has one JavaScript node. Paste the file with the action's name from `js/`. Every action except `IsAvailable` returns a `Result`. `IsAvailable` returns flat outputs.

| Action | Inputs | Outputs | Flow |
|---|---|---|---|
| `IsAvailable` | none | `Available`, `TokenizerVersion`, `Success`, `ErrorMessage` | JS node, Assign |
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

1. Publish the library, add it as a dependency to a Mobile app, and call `IsAvailable` on a device build. It returns `Available` true and `TokenizerVersion` 2.
2. Call `UpsertMany` with the items in `seed/seed-procedures.json` (indexed as `Title + ". " + Body`, with `Code` as the id). It returns `Count` 50. A search for `pump seal` returns `p14` first.
3. The expected ranking for 20 queries is in `tests/fixtures/scores.json`.

The example apps in `example/` show the same calls without ODC.
