// JS node of the client action IsAvailable.
// Inputs: none.
// Outputs: Available (Boolean), TokenizerVersion (Integer), Success (Boolean), ErrorMessage (Text).
const P = window.CapacitorPlugins ? window.CapacitorPlugins.OfflineBM25 : null;

if (!P) {
  $parameters.Available = false;
  $parameters.TokenizerVersion = 0;
  $parameters.Success = false;
  $parameters.ErrorMessage = "OfflineBM25 plugin not found on window.CapacitorPlugins.";
  $resolve();
  return;
}

P.isAvailable()
  .then((r) => {
    $parameters.Available = r.available === true;
    $parameters.TokenizerVersion = Number(r.tokenizerVersion) || 0;
    $parameters.Success = true;
    $parameters.ErrorMessage = "";
    $resolve();
  })
  .catch((err) => {
    $parameters.Available = false;
    $parameters.TokenizerVersion = 0;
    $parameters.Success = false;
    $parameters.ErrorMessage = String(err && err.message ? err.message : err);
    $resolve();
  });
