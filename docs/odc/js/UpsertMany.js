// JS node of the client action UpsertMany.
// Inputs: Collection (Text), ItemsJson (Text, the JSON Serialize output of the KeywordItem list).
// Outputs: Count (Integer), SkippedJson (Text, a JSON list of ids), Success (Boolean), ErrorMessage (Text).
const P = window.CapacitorPlugins ? window.CapacitorPlugins.OfflineBM25 : null;

const fail = (message) => {
  $parameters.Count = 0;
  $parameters.SkippedJson = "[]";
  $parameters.Success = false;
  $parameters.ErrorMessage = message;
  $resolve();
};

if (!P) {
  fail("OfflineBM25 plugin not found on window.CapacitorPlugins.");
  return;
}

// JSON Serialize writes the attribute names as Id, Text and Metadata. The plugin wants id, text, metadata.
let items;
try {
  const parsed = JSON.parse($parameters.ItemsJson || "[]");
  items = (Array.isArray(parsed) ? parsed : []).map((x) => ({
    id: x.Id !== undefined ? x.Id : x.id,
    text: x.Text !== undefined && x.Text !== null ? x.Text : "",
    metadata: x.Metadata !== undefined && x.Metadata !== null ? x.Metadata : ""
  }));
} catch (err) {
  fail("Items is not valid JSON: " + String(err && err.message ? err.message : err));
  return;
}

P.upsertMany({ collection: $parameters.Collection, items: items })
  .then((r) => {
    $parameters.Count = Number(r.count) || 0;
    $parameters.SkippedJson = JSON.stringify(r.skipped || []);
    $parameters.Success = true;
    $parameters.ErrorMessage = "";
    $resolve();
  })
  .catch((err) => {
    fail(String(err && err.message ? err.message : err));
  });
