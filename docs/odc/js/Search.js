// JS node of the client action Search.
// Inputs: Collection (Text), Query (Text), TopK (Integer), MinScore (Decimal), K1 (Decimal), B (Decimal).
// Outputs: ResultsJson (Text, a JSON list of matches), Success (Boolean), ErrorMessage (Text).
const P = window.CapacitorPlugins ? window.CapacitorPlugins.OfflineBM25 : null;

// OutSystems may pass Decimal values as objects, not numbers.
const toNum = (v) => (v != null && typeof v.toNumber === "function") ? v.toNumber() : Number(v);
// A missing value must not become 0, because Number(null) is 0.
const optional = (v) => (v == null ? NaN : toNum(v));

const fail = (message) => {
  $parameters.ResultsJson = "[]";
  $parameters.Success = false;
  $parameters.ErrorMessage = message;
  $resolve();
};

if (!P) {
  fail("OfflineBM25 plugin not found on window.CapacitorPlugins.");
  return;
}

const options = {
  collection: $parameters.Collection,
  query: $parameters.Query == null ? "" : String($parameters.Query)
};
// Send a tuning value only when it is a number. The plugin applies its own default otherwise.
// A value of 0 is valid for MinScore and B, so the test is isFinite, not "greater than 0".
const topK = optional($parameters.TopK);
if (Number.isFinite(topK)) options.topK = Math.trunc(topK);
const minScore = optional($parameters.MinScore);
if (Number.isFinite(minScore)) options.minScore = minScore;
const k1 = optional($parameters.K1);
if (Number.isFinite(k1)) options.k1 = k1;
const b = optional($parameters.B);
if (Number.isFinite(b)) options.b = b;

P.search(options)
  .then((r) => {
    $parameters.ResultsJson = JSON.stringify((r.results || []).map((x) => ({
      Id: x.id,
      Score: x.score,
      Metadata: x.metadata == null ? "" : x.metadata,
      MatchedTerms: x.matchedTerms
    })));
    $parameters.Success = true;
    $parameters.ErrorMessage = "";
    $resolve();
  })
  .catch((err) => {
    fail(String(err && err.message ? err.message : err));
  });
