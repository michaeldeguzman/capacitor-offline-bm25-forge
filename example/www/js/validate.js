// Validation mode for plan section 5, items 2 to 8. Started by a launch flag, see app.js.
// Every result is one line, logged and shown on screen:
//   OBM25-VALIDATE|<platform>|<item>|<PASS|FAIL|INFO>|<detail>
// Phases: p1 = items 2 and 4, p2 = item 3 (run after a kill and relaunch), p3 = items 5 to 8.
// Timing phases: p4 = import and file size, p5 = cold load (info first), p6 = cold load (search first).
// Each timing phase runs after a kill and relaunch.
window.runValidation = async function runValidation(phase) {
  const { OfflineBM25 } = window.capacitorOfflineBM25;
  const platform = window.Capacitor.getPlatform();
  const COLLECTION = 'manual';
  const out = document.getElementById('out');

  function log(item, status, detail) {
    const line = `OBM25-VALIDATE|${platform}|${item}|${status}|${detail}`;
    console.log(line);
    out.textContent += line + '\n';
  }
  const pass = (item, ok, detail) => log(item, ok ? 'PASS' : 'FAIL', detail);
  const rejection = async fn => {
    try {
      await fn();
      return null;
    } catch (e) {
      return (e && e.message) || String(e);
    }
  };
  const ids = results => results.map(r => r.id).join(',');
  const median = xs => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];

  const fixture = await (await fetch('js/scores.json')).json();

  // Same comparison as the unit tests: count, score within 1e-6 at every rank, ids equal as a set
  // inside each tie group, and id ascending inside each tie group.
  async function compareAllQueries() {
    const problems = [];
    for (const q of fixture.queries) {
      const { results } = await OfflineBM25.search({ collection: COLLECTION, query: q.query, topK: 1000 });
      const expected = q.results;
      if (results.length !== expected.length) {
        problems.push(`${q.query}: count ${expected.length} vs ${results.length}`);
        continue;
      }
      results.forEach((r, i) => {
        if (Math.abs(r.score - expected[i].score) > 1e-6) problems.push(`${q.query}: score at rank ${i}`);
      });
      let start = 0;
      while (start < expected.length) {
        let end = start + 1;
        while (end < expected.length && Math.abs(expected[end].score - expected[start].score) < 1e-9) end++;
        const want = expected.slice(start, end).map(r => r.id).sort();
        const got = results.slice(start, end).map(r => r.id);
        if (want.join() !== [...got].sort().join()) problems.push(`${q.query}: ids at ranks ${start}-${end}`);
        if (got.join() !== [...got].sort().join()) problems.push(`${q.query}: tie order at ranks ${start}-${end}`);
        start = end;
      }
    }
    return { queries: fixture.queries.length, problems };
  }

  // Deterministic items for the timing runs.
  //   Item k (0 to 1999): the text of seed procedure (k mod 50) plus 3 extra words, id "g" + k padded
  //   to 4 digits, metadata = the seed title. The extra words come from a fixed linear congruential
  //   generator, x = (x * 1103515245 + 12345) mod 2^31, starting at 12345, indexing the sorted list
  //   of distinct lowercase words of the 50 seed texts.
  //   With unique = true, each item also gets 3 synthetic words that appear in no other item: word n
  //   (n = 3k, 3k+1, 3k+2, so 6,000 words) is "q" + n in base 19 over the consonants
  //   "bcdfghjklmnpqrtvwxz", 4 letters, most significant first. Consonant-only words are not stop
  //   words and the Porter stemmer leaves them unchanged, so every word stays a distinct term.
  function makeItems(unique) {
    const words = [...new Set(window.PROCEDURES.flatMap(p => p.text.toLowerCase().match(/[a-z]+/g)))].sort();
    let x = 12345;
    const next = () => (x = (Math.imul(x, 1103515245) + 12345) & 0x7fffffff);
    const alphabet = 'bcdfghjklmnpqrtvwxz';
    const synthetic = n => {
      let w = '';
      for (let i = 0; i < 4; i++) {
        w = alphabet[n % 19] + w;
        n = Math.floor(n / 19);
      }
      return 'q' + w;
    };
    const items = [];
    for (let k = 0; k < 2000; k++) {
      const base = window.PROCEDURES[k % 50];
      const extra = [words[next() % words.length], words[next() % words.length], words[next() % words.length]];
      if (unique) extra.push(synthetic(3 * k), synthetic(3 * k + 1), synthetic(3 * k + 2));
      items.push({ id: 'g' + String(k).padStart(4, '0'), text: base.text + ' ' + extra.join(' '), metadata: base.metadata });
    }
    return items;
  }

  const LaunchArgs = window.LaunchArgs; // registered once in app.js
  const TIMING_COLLECTIONS = ['manual', 'bench2k', 'bench2kU'];
  const label = { manual: '50 items', bench2k: '2000 items', bench2kU: '2000 items, 6000 unique words' };
  const fmt = v => v.toFixed(1);

  async function warmSearch(name) {
    const times = [];
    for (let rep = 0; rep < 5; rep++) {
      for (const q of fixture.queries) {
        const s = performance.now();
        await OfflineBM25.search({ collection: name, query: q.query, topK: 10 });
        times.push(performance.now() - s);
      }
    }
    const sorted = [...times].sort((a, b) => a - b);
    return `searches=${times.length}; warm_median_ms=${fmt(median(times))}; warm_p95_ms=${fmt(sorted[Math.floor(sorted.length * 0.95)])}; warm_max_ms=${fmt(sorted[sorted.length - 1])}`;
  }

  log('PHASE', 'INFO', `${phase} begin; navigator.onLine=${navigator.onLine}`);

  if (phase === 'p1') {
    await OfflineBM25.clear({ collection: COLLECTION });
    log('SETUP', 'INFO', 'collection cleared');

    let t = performance.now();
    const r = await OfflineBM25.upsertMany({ collection: COLLECTION, items: window.PROCEDURES });
    const ms = Math.round(performance.now() - t);
    pass('ITEM2', r.count === 50 && r.skipped.length === 0, `count=${r.count}; skipped=${r.skipped.length}; ${ms} ms`);

    const top = await OfflineBM25.search({ collection: COLLECTION, query: 'pump seal' });
    pass('ITEM4-pump-seal', top.results.length > 0 && top.results[0].id === 'p14',
      `top=${top.results[0] && top.results[0].id}; results=${ids(top.results)}; navigator.onLine=${navigator.onLine}`);
    const c = await compareAllQueries();
    pass('ITEM4-all-queries', c.problems.length === 0, `${c.queries} queries; ${c.problems.length} problems ${c.problems.slice(0, 3).join(' / ')}`);
  } else if (phase === 'p2') {
    const info = await OfflineBM25.getCollectionInfo({ collection: COLLECTION });
    pass('ITEM3', info.exists && info.count === 50, `exists=${info.exists}; count=${info.count}; uniqueTerms=${info.uniqueTerms}; tokenizerVersion=${info.tokenizerVersion}`);
    const c = await compareAllQueries();
    pass('ITEM3-queries-after-relaunch', c.problems.length === 0, `${c.queries} queries; ${c.problems.length} problems`);
  } else if (phase === 'p3') {
    // Item 5: re-upsert p14 with new text.
    const before = await OfflineBM25.search({ collection: COLLECTION, query: 'seal', topK: 100 });
    const upsert = await OfflineBM25.upsertMany({
      collection: COLLECTION,
      items: [{ id: 'p14', text: 'Gasket swap. Fit a new gasket kit on the hydraulic ram.', metadata: 'Gasket swap' }],
    });
    const info5 = await OfflineBM25.getCollectionInfo({ collection: COLLECTION });
    const gasket = await OfflineBM25.search({ collection: COLLECTION, query: 'gasket' });
    const seal = await OfflineBM25.search({ collection: COLLECTION, query: 'seal', topK: 100 });
    const pumpSeal = await OfflineBM25.search({ collection: COLLECTION, query: 'pump seal' });
    pass('ITEM5',
      before.results.some(r => r.id === 'p14') && upsert.count === 1 && info5.count === 50 &&
        gasket.results[0].id === 'p14' && gasket.results[0].metadata === 'Gasket swap' &&
        !seal.results.some(r => r.id === 'p14') && pumpSeal.results[0].id !== 'p14',
      `upsert.count=${upsert.count}; info.count=${info5.count}; 'gasket' top=${gasket.results[0].id}; 'seal' before has p14=${before.results.some(r => r.id === 'p14')}; 'seal' after has p14=${seal.results.some(r => r.id === 'p14')}; 'pump seal' top=${pumpSeal.results[0].id}`);

    // Item 6: remove two ids, then clear.
    const removed = await OfflineBM25.remove({ collection: COLLECTION, ids: ['p01', 'p02'] });
    const info48 = await OfflineBM25.getCollectionInfo({ collection: COLLECTION });
    await OfflineBM25.clear({ collection: COLLECTION });
    const gone = await OfflineBM25.getCollectionInfo({ collection: COLLECTION });
    const afterClear = await rejection(() => OfflineBM25.search({ collection: COLLECTION, query: 'pump' }));
    pass('ITEM6', removed.count === 2 && info48.count === 48 && !gone.exists && gone.count === 0 &&
      afterClear === "collection 'manual' does not exist",
      `removed=${removed.count}; count after remove=${info48.count}; exists after clear=${gone.exists}; search after clear: ${afterClear}`);

    // Item 7: bad input rejects with a readable message and the app keeps running.
    const cases = [
      ['empty collection', () => OfflineBM25.upsertMany({ collection: '', items: [] }), 'collection is required and must not be empty'],
      ['whitespace collection', () => OfflineBM25.upsertMany({ collection: '   ', items: [] }), 'collection is required and must not be empty'],
      ['empty collection info', () => OfflineBM25.getCollectionInfo({ collection: '' }), 'collection is required and must not be empty'],
      ['unknown collection search', () => OfflineBM25.search({ collection: 'nope', query: 'pump' }), "collection 'nope' does not exist"],
      ['unknown collection remove', () => OfflineBM25.remove({ collection: 'nope', ids: ['a'] }), "collection 'nope' does not exist"],
      ['item without id', () => OfflineBM25.upsertMany({ collection: 'bad', items: [{ text: 'no id' }] }), 'items[0] needs a non-empty string id and a string text'],
      ['missing items', () => OfflineBM25.upsertMany({ collection: 'bad' }), 'items is required'],
    ];
    for (const [name, fn, expected] of cases) {
      const message = await rejection(fn);
      pass('ITEM7-' + name.replace(/ /g, '-'), message === expected, `message=${message}`);
    }
    const unknown = await OfflineBM25.getCollectionInfo({ collection: 'nope' });
    pass('ITEM7-unknown-info', unknown.exists === false && unknown.count === 0 && unknown.currentTokenizerVersion === 2,
      `exists=${unknown.exists}; count=${unknown.count}; currentTokenizerVersion=${unknown.currentTokenizerVersion}`);
    const badExists = await OfflineBM25.getCollectionInfo({ collection: 'bad' });
    pass('ITEM7-rejected-call-wrote-nothing', badExists.exists === false, `bad exists=${badExists.exists}`);
    pass('ITEM7-alive', true, 'the app is still running after every rejection');

    // Item 8: 2,000 items generated from the seed, see makeItems.
    const items = makeItems(false);
    await OfflineBM25.clear({ collection: 'bench' });
    const t = performance.now();
    const imp = await OfflineBM25.upsertMany({ collection: 'bench', items });
    const importMs = Math.round(performance.now() - t);
    const info = await OfflineBM25.getCollectionInfo({ collection: 'bench' });
    const times = [];
    for (let rep = 0; rep < 5; rep++) {
      for (const q of fixture.queries) {
        const s = performance.now();
        await OfflineBM25.search({ collection: 'bench', query: q.query, topK: 10 });
        times.push(performance.now() - s);
      }
    }
    const sorted = [...times].sort((a, b) => a - b);
    const fmt = v => v.toFixed(1);
    pass('ITEM8', imp.count === 2000 && imp.skipped.length === 0 && info.count === 2000,
      `import_ms=${importMs}; count=${imp.count}; skipped=${imp.skipped.length}; uniqueTerms=${info.uniqueTerms}; avgLength=${info.avgLength.toFixed(2)}; ` +
      `searches=${times.length}; search_median_ms=${fmt(median(times))}; search_p95_ms=${fmt(sorted[Math.floor(sorted.length * 0.95)])}; search_max_ms=${fmt(sorted[sorted.length - 1])}`);
    await OfflineBM25.clear({ collection: 'bench' });
    log('SETUP', 'INFO', 'bench collection cleared');
  } else if (phase === 'p4') {
    // Import: 50 items, 2,000 items, 2,000 items with unique words. Then file sizes.
    const sets = { manual: window.PROCEDURES, bench2k: makeItems(false), bench2kU: makeItems(true) };
    for (const name of TIMING_COLLECTIONS) {
      await OfflineBM25.clear({ collection: name });
      const t = performance.now();
      const r = await OfflineBM25.upsertMany({ collection: name, items: sets[name] });
      const ms = Math.round(performance.now() - t);
      const info = await OfflineBM25.getCollectionInfo({ collection: name });
      pass('TIMING-IMPORT-' + name, r.count === sets[name].length && r.skipped.length === 0,
        `${label[name]}; import_ms=${ms}; count=${r.count}; skipped=${r.skipped.length}; uniqueTerms=${info.uniqueTerms}; avgLength=${info.avgLength.toFixed(2)}`);
    }
    const { files } = await LaunchArgs.fileSizes();
    for (const f of files) log('TIMING-FILESIZE', 'INFO', `${f.name}; bytes=${f.bytes}`);
  } else if (phase === 'p5' || phase === 'p6') {
    // Cold load, after a kill and relaunch. p5: the first call on a collection is getCollectionInfo,
    // then the first search. p6: the first call is search, so its time includes the load from disk.
    // isAvailable runs first, so the first bridge call in the process is not counted as load time.
    let t = performance.now();
    await OfflineBM25.isAvailable();
    log('TIMING-BRIDGE', 'INFO', `first_call_ms=${fmt(performance.now() - t)}`);
    for (const name of TIMING_COLLECTIONS) {
      let first, second;
      if (phase === 'p5') {
        t = performance.now();
        const info = await OfflineBM25.getCollectionInfo({ collection: name });
        first = `first_getCollectionInfo_ms=${fmt(performance.now() - t)}; count=${info.count}`;
        t = performance.now();
        const r = await OfflineBM25.search({ collection: name, query: 'pump seal', topK: 10 });
        second = `first_search_ms=${fmt(performance.now() - t)}; results=${r.results.length}`;
      } else {
        t = performance.now();
        const r = await OfflineBM25.search({ collection: name, query: 'pump seal', topK: 10 });
        first = `first_search_ms=${fmt(performance.now() - t)}; results=${r.results.length}`;
        t = performance.now();
        const info = await OfflineBM25.getCollectionInfo({ collection: name });
        second = `then_getCollectionInfo_ms=${fmt(performance.now() - t)}; count=${info.count}`;
      }
      pass('TIMING-COLD-' + name, true, `${label[name]}; ${first}; ${second}; ${await warmSearch(name)}`);
    }
  } else {
    log('PHASE', 'FAIL', `unknown phase ${phase}`);
  }
  log('PHASE', 'DONE', phase);
};
