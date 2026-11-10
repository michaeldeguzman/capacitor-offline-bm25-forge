// Minimal test page: index the seed procedures, search, show scores.
const { OfflineBM25 } = window.capacitorOfflineBM25;
const COLLECTION = 'manual';
const $ = id => document.getElementById(id);

async function showInfo() {
  const i = await OfflineBM25.getCollectionInfo({ collection: COLLECTION });
  $('info').textContent = i.exists
    ? `${i.count} items, ${i.uniqueTerms} terms, avg length ${i.avgLength.toFixed(2)}, tokenizer v${i.tokenizerVersion}${i.needsReindex ? ' (needs reindex)' : ''}`
    : 'collection does not exist';
  return i;
}

async function indexAll() {
  const t = performance.now();
  const r = await OfflineBM25.upsertMany({ collection: COLLECTION, items: window.PROCEDURES });
  $('out').textContent = `indexed ${r.count}, skipped ${r.skipped.length} in ${Math.round(performance.now() - t)} ms`;
  await showInfo();
}

async function runSearch() {
  const query = $('query').value;
  const t = performance.now();
  const { results } = await OfflineBM25.search({ collection: COLLECTION, query, topK: 10 });
  const ms = Math.round(performance.now() - t);
  $('out').textContent =
    `${results.length} results in ${ms} ms\n` +
    results.map(r => `${r.score.toFixed(4)}  ${r.id}  ${r.metadata}  (${r.matchedTerms} terms)`).join('\n');
}

function fail(e) {
  const message = (e && e.message) || String(e);
  $('out').textContent = 'error: ' + message;
  console.log(`OBM25-VALIDATE|${window.Capacitor.getPlatform()}|ERROR|FAIL|${message}`);
}

$('index').onclick = () => indexAll().catch(fail);
$('clear').onclick = () => OfflineBM25.clear({ collection: COLLECTION }).then(showInfo).catch(fail);
$('search').onclick = () => runSearch().catch(fail);

// On launch: with a validate flag, run validation mode (see validate.js). Otherwise index if the
// collection is empty, then run the default query.
(async () => {
  window.LaunchArgs = window.Capacitor.registerPlugin('LaunchArgs');
  const { validate } = await window.LaunchArgs.get();
  if (validate) return window.runValidation(validate);
  const i = await showInfo();
  if (!i.exists) await indexAll();
  await runSearch();
})().catch(fail);
