// JS node of the client action Clear.
// Inputs: Collection (Text).
// Outputs: Success (Boolean), ErrorMessage (Text).
const P = window.CapacitorPlugins ? window.CapacitorPlugins.OfflineBM25 : null;

const fail = (message) => {
  $parameters.Success = false;
  $parameters.ErrorMessage = message;
  $resolve();
};

if (!P) {
  fail("OfflineBM25 plugin not found on window.CapacitorPlugins.");
  return;
}

P.clear({ collection: $parameters.Collection })
  .then(() => {
    $parameters.Success = true;
    $parameters.ErrorMessage = "";
    $resolve();
  })
  .catch((err) => {
    fail(String(err && err.message ? err.message : err));
  });
