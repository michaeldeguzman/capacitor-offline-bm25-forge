// JS node of the client action Tokenize.
// Inputs: Text (Text).
// Outputs: TokensJson (Text, a JSON list of tokens), Success (Boolean), ErrorMessage (Text).
const P = window.CapacitorPlugins ? window.CapacitorPlugins.OfflineBM25 : null;

const fail = (message) => {
  $parameters.TokensJson = "[]";
  $parameters.Success = false;
  $parameters.ErrorMessage = message;
  $resolve();
};

if (!P) {
  fail("OfflineBM25 plugin not found on window.CapacitorPlugins.");
  return;
}

P.tokenize({ text: $parameters.Text == null ? "" : String($parameters.Text) })
  .then((r) => {
    $parameters.TokensJson = JSON.stringify(r.tokens || []);
    $parameters.Success = true;
    $parameters.ErrorMessage = "";
    $resolve();
  })
  .catch((err) => {
    fail(String(err && err.message ? err.message : err));
  });
