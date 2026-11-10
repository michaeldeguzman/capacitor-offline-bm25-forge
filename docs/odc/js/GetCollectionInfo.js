// JS node of the client action GetCollectionInfo.
// Inputs: Collection (Text).
// Outputs: InfoJson (Text, one JSON object shaped like KeywordCollectionInfo), Success (Boolean), ErrorMessage (Text).
const P = window.CapacitorPlugins ? window.CapacitorPlugins.OfflineBM25 : null;

// A valid object even on failure, so the JSON Deserialize after this node never fails.
const EMPTY_INFO = JSON.stringify({
  Exists: false,
  Count: 0,
  UniqueTerms: 0,
  AvgLength: 0,
  TokenizerVersion: 0,
  CurrentTokenizerVersion: 0,
  NeedsReindex: false
});

const fail = (message) => {
  $parameters.InfoJson = EMPTY_INFO;
  $parameters.Success = false;
  $parameters.ErrorMessage = message;
  $resolve();
};

if (!P) {
  fail("OfflineBM25 plugin not found on window.CapacitorPlugins.");
  return;
}

P.getCollectionInfo({ collection: $parameters.Collection })
  .then((r) => {
    $parameters.InfoJson = JSON.stringify({
      Exists: r.exists === true,
      Count: Number(r.count) || 0,
      UniqueTerms: Number(r.uniqueTerms) || 0,
      AvgLength: Number(r.avgLength) || 0,
      TokenizerVersion: Number(r.tokenizerVersion) || 0,
      CurrentTokenizerVersion: Number(r.currentTokenizerVersion) || 0,
      NeedsReindex: r.needsReindex === true
    });
    $parameters.Success = true;
    $parameters.ErrorMessage = "";
    $resolve();
  })
  .catch((err) => {
    fail(String(err && err.message ? err.message : err));
  });
