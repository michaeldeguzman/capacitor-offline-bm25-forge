# Golden fixtures

These three files are the reference output of BM25Engine, the C# component the Swift and Kotlin code ports. The XCTest and JUnit tests load them directly and compare:

| File | Content | Pass rule |
|---|---|---|
| `stemmer.json` | 162 word and stem pairs: 75 from the Porter paper's worked examples and 87 sampled from Porter's official test vocabulary | identical stems |
| `tokenizer.json` | 37 cases: 17 from the BM25Engine tokenizer tests and 20 extra strings (punctuation, error codes like `ERR-BM25-003`, contractions, numbers, mixed case, accents, emoji) | identical token lists |
| `scores.json` | 50 documents, 20 queries (10 paraphrased, 10 keyword), `k1` 1.2, `b` 0.75, and the full ranked list with scores for every query | same ranking, each score within 1e-6 |

## How they were generated

I wrote a small .NET console app in the development repository. It references BM25Engine and runs its code:
- Every stem comes from `PorterStemmer.Stem`. Every token list comes from `Tokenizer.Tokenize`.
- For `scores.json`, the app tokenizes each of the 50 documents (indexed as `Title + ". " + Body`), counts term frequencies and document frequencies, and calls `BM25Scorer.Score` for each query with `k1` 1.2 and `b` 0.75. It records the full ranked list.
- The inputs (words, strings, documents and queries) are checked in with the app. The expected values are never typed by hand. A test that fails is reported as a mismatch, and no fixture is edited to make it pass.
- The documents are 50 short maintenance procedures with generic equipment and no client data.

Output is deterministic: running the app again gives byte-identical files.

## Ties

C# `List.Sort` is unstable, so BM25Engine does not define the order of equal scores. The score tests compare each group of tied results as a set. The plugin orders ties by id ascending, and the index tests check that too.

## Regenerating

The app is not part of this release repo, because it needs a reference to BM25Engine. If you have BM25Engine, a .NET 10 console app that calls the three methods above on the same inputs reproduces these files.
