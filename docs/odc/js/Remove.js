// JS node of the client action Remove.
// Inputs: Collection (Text), IdsJson (Text, the JSON Serialize output of the Text List).
// Outputs: Count (Integer), Success (Boolean), ErrorMessage (Text).
const P = window.CapacitorPlugins ? window.CapacitorPlugins.OfflineBM25 : null;

const fail = (message) => {
  $parameters.Count = 0;
  $parameters.Success = false;
  $parameters.ErrorMessage = message;
  $resolve();
};

if (!P) {
  fail("OfflineBM25 plugin not found on window.CapacitorPlugins.");
  return;
}

let ids;
try {
  const parsed = JSON.parse($parameters.IdsJson || "[]");
  ids = (Array.isArray(parsed) ? parsed : []).map((x) => String(x));
} catch (err) {
  fail("Ids is not valid JSON: " + String(err && err.message ? err.message : err));
  return;
}

P.remove({ collection: $parameters.Collection, ids: ids })
  .then((r) => {
    $parameters.Count = Number(r.count) || 0;
    $parameters.Success = true;
    $parameters.ErrorMessage = "";
    $resolve();
  })
  .catch((err) => {
    fail(String(err && err.message ? err.message : err));
  });
