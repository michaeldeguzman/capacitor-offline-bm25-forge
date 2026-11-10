// Checks the ODC JS nodes in docs/odc/js against a mock OfflineBM25 plugin.
// Run: node tools/odc/check-js.js
// Every case checks that $resolve is called exactly once with no arguments and that every
// output is a primitive. The mock plugin returns the response shapes of the real plugin.
const fs = require("fs");
const path = require("path");
const assert = require("assert");

const dir = path.join(__dirname, "..", "..", "docs", "odc", "js");

function run(file, input, plugin) {
  const code = fs.readFileSync(path.join(dir, file + ".js"), "utf8");
  const $parameters = Object.assign({}, input);
  const windowObject = plugin === undefined ? {} : { CapacitorPlugins: plugin === null ? {} : { OfflineBM25: plugin } };
  const calls = [];
  return new Promise((resolve) => {
    const $resolve = function () { calls.push(Array.prototype.slice.call(arguments)); };
    // JS nodes use a top-level return, so the code runs as a function body.
    new Function("$parameters", "$resolve", "window", code)($parameters, $resolve, windowObject);
    setTimeout(() => resolve({ out: $parameters, calls }), 25);
  }).then((result) => {
    assert.strictEqual(result.calls.length, 1, file + ": $resolve must be called exactly once");
    assert.strictEqual(result.calls[0].length, 0, file + ": $resolve must have no arguments");
    for (const [key, value] of Object.entries(result.out)) {
      if (key in input) continue;
      assert.ok(["string", "number", "boolean"].includes(typeof value), file + ": output " + key + " is not a primitive");
    }
    return result;
  });
}

const seen = [];
const mock = (name, impl) => (opts) => { seen.push([name, opts]); return impl(opts); };
const ok = (value) => Promise.resolve(value);
const reject = (reason) => Promise.reject(reason);
let passed = 0;
async function check(label, fn) { await fn(); passed++; console.log("PASS " + label); }

(async () => {
  const missing = [undefined, null]; // no CapacitorPlugins at all, and CapacitorPlugins without OfflineBM25
  const files = { IsAvailable: {}, UpsertMany: { Collection: "c", ItemsJson: "[]" }, Search: { Collection: "c", Query: "q" },
    Remove: { Collection: "c", IdsJson: "[]" }, Clear: { Collection: "c" }, GetCollectionInfo: { Collection: "c" }, Tokenize: { Text: "t" } };

  for (const [file, input] of Object.entries(files)) {
    for (const m of missing) {
      await check(file + ": plugin missing" + (m === null ? " (empty CapacitorPlugins)" : ""), async () => {
        const { out } = await run(file, input, m);
        assert.strictEqual(out.Success, false);
        assert.strictEqual(out.ErrorMessage, "OfflineBM25 plugin not found on window.CapacitorPlugins.");
      });
    }
  }

  await check("IsAvailable: success and rejection", async () => {
    let r = await run("IsAvailable", {}, { isAvailable: () => ok({ available: true, tokenizerVersion: 2 }) });
    assert.deepStrictEqual([r.out.Available, r.out.TokenizerVersion, r.out.Success, r.out.ErrorMessage], [true, 2, true, ""]);
    r = await run("IsAvailable", {}, { isAvailable: () => reject(new Error("boom")) });
    assert.deepStrictEqual([r.out.Available, r.out.Success, r.out.ErrorMessage], [false, false, "boom"]);
  });

  await check("UpsertMany: maps Id/Text/Metadata, returns count and skipped", async () => {
    seen.length = 0;
    const input = { Collection: "manual", ItemsJson: '[{"Id":"a","Text":"pump","Metadata":"M"},{"Id":"b","Text":null,"Metadata":null}]' };
    const r = await run("UpsertMany", input, { upsertMany: mock("upsertMany", () => ok({ count: 1, skipped: ["b"] })) });
    assert.deepStrictEqual(seen[0][1], { collection: "manual", items: [{ id: "a", text: "pump", metadata: "M" }, { id: "b", text: "", metadata: "" }] });
    assert.deepStrictEqual([r.out.Count, r.out.SkippedJson, r.out.Success, r.out.ErrorMessage], [1, '["b"]', true, ""]);
  });
  await check("UpsertMany: invalid JSON and plugin rejection", async () => {
    let r = await run("UpsertMany", { Collection: "c", ItemsJson: "{not json" }, { upsertMany: () => ok({}) });
    assert.strictEqual(r.out.Success, false);
    assert.ok(r.out.ErrorMessage.startsWith("Items is not valid JSON:"));
    assert.deepStrictEqual([r.out.Count, r.out.SkippedJson], [0, "[]"]);
    r = await run("UpsertMany", { Collection: "", ItemsJson: "[]" }, { upsertMany: () => reject("collection is required and must not be empty") });
    assert.deepStrictEqual([r.out.Success, r.out.ErrorMessage], [false, "collection is required and must not be empty"]);
  });

  await check("Search: Decimal objects go through toNumber, 0 is kept, missing values are omitted", async () => {
    seen.length = 0;
    const decimal = (n) => ({ toNumber: () => n });
    const plugin = { search: mock("search", () => ok({ results: [{ id: "p14", score: 6.5, metadata: "Pump seal replacement", matchedTerms: 2 }] })) };
    let r = await run("Search", { Collection: "manual", Query: "pump seal", TopK: 7, MinScore: decimal(0.5), K1: decimal(1.2), B: decimal(0) }, plugin);
    assert.deepStrictEqual(seen[0][1], { collection: "manual", query: "pump seal", topK: 7, minScore: 0.5, k1: 1.2, b: 0 });
    assert.deepStrictEqual(JSON.parse(r.out.ResultsJson), [{ Id: "p14", Score: 6.5, Metadata: "Pump seal replacement", MatchedTerms: 2 }]);
    assert.strictEqual(r.out.Success, true);
    seen.length = 0;
    r = await run("Search", { Collection: "manual", Query: null, TopK: undefined, MinScore: null, K1: undefined, B: undefined }, plugin);
    assert.deepStrictEqual(seen[0][1], { collection: "manual", query: "" });
  });
  await check("Search: rejection returns an empty list and the message", async () => {
    const r = await run("Search", { Collection: "x", Query: "q" }, { search: () => reject(new Error("collection 'x' does not exist")) });
    assert.deepStrictEqual([r.out.ResultsJson, r.out.Success, r.out.ErrorMessage], ["[]", false, "collection 'x' does not exist"]);
  });

  await check("Remove: ids as strings, count back", async () => {
    seen.length = 0;
    const r = await run("Remove", { Collection: "c", IdsJson: '["p01","p02"]' }, { remove: mock("remove", () => ok({ count: 2 })) });
    assert.deepStrictEqual(seen[0][1], { collection: "c", ids: ["p01", "p02"] });
    assert.deepStrictEqual([r.out.Count, r.out.Success], [2, true]);
    const bad = await run("Remove", { Collection: "c", IdsJson: "nope" }, { remove: () => ok({ count: 0 }) });
    assert.strictEqual(bad.out.Success, false);
  });

  await check("Clear: success and rejection", async () => {
    let r = await run("Clear", { Collection: "c" }, { clear: () => ok(undefined) });
    assert.deepStrictEqual([r.out.Success, r.out.ErrorMessage], [true, ""]);
    r = await run("Clear", { Collection: "" }, { clear: () => reject(new Error("collection is required and must not be empty")) });
    assert.deepStrictEqual([r.out.Success, r.out.ErrorMessage], [false, "collection is required and must not be empty"]);
  });

  await check("GetCollectionInfo: PascalCase object, and a full default object on failure", async () => {
    const info = { exists: true, count: 50, uniqueTerms: 359, avgLength: 11.9, tokenizerVersion: 2, currentTokenizerVersion: 2, needsReindex: false };
    let r = await run("GetCollectionInfo", { Collection: "c" }, { getCollectionInfo: () => ok(info) });
    assert.deepStrictEqual(JSON.parse(r.out.InfoJson), { Exists: true, Count: 50, UniqueTerms: 359, AvgLength: 11.9, TokenizerVersion: 2, CurrentTokenizerVersion: 2, NeedsReindex: false });
    r = await run("GetCollectionInfo", { Collection: "" }, { getCollectionInfo: () => reject(new Error("bad")) });
    assert.deepStrictEqual(Object.keys(JSON.parse(r.out.InfoJson)), ["Exists", "Count", "UniqueTerms", "AvgLength", "TokenizerVersion", "CurrentTokenizerVersion", "NeedsReindex"]);
    assert.deepStrictEqual([r.out.Success, r.out.ErrorMessage], [false, "bad"]);
  });

  await check("Tokenize: tokens as JSON", async () => {
    seen.length = 0;
    const r = await run("Tokenize", { Text: "ERR-BM25-003" }, { tokenize: mock("tokenize", () => ok({ tokens: ["err", "bm25", "003"] })) });
    assert.deepStrictEqual(seen[0][1], { text: "ERR-BM25-003" });
    assert.strictEqual(r.out.TokensJson, '["err","bm25","003"]');
  });

  console.log(passed + " checks passed");
})().catch((e) => { console.error("FAIL " + e.message); process.exit(1); });
