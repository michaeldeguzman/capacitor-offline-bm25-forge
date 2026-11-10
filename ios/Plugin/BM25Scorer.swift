import Foundation

/// One (term, chunk) posting. Mirrors BM25Engine PostingCandidate.
/// documentFrequency is a property of the term. It is the same on every posting for that term.
struct PostingCandidate {
    var chunkId: Int64
    var term: String
    var termFrequencyInChunk: Int
    var documentFrequency: Int
    var chunkTokenCount: Int
}

/// A chunk's BM25 score against a query. Mirrors BM25Engine BM25ScoreResult.
struct BM25ScoreResult {
    var chunkId: Int64
    var score: Double
}

/// Okapi BM25 with the always-positive IDF variant, as in BM25Engine BM25Scorer.
/// k1 and b are parameters. The scorer holds no defaults.
enum BM25Scorer {
    /// Scores every chunk that appears in postings and returns the results sorted by score,
    /// highest first. A chunk with several postings sums one term score per posting.
    ///
    /// C# does not define the order of equal scores (List.Sort is unstable). The plugin orders
    /// them by id ascending, compared ordinally by UTF-16 code units. tieBreakId maps a chunk id
    /// to the caller's string id. It is required, so no caller can fall back to another order.
    static func score(
        queryTerms: [String],
        postings: [PostingCandidate],
        totalChunks: Int,
        avgChunkLength: Double,
        k1: Double,
        b: Double,
        tieBreakId: (Int64) -> String
    ) -> [BM25ScoreResult] {
        // Terms are keyed by UTF-16 code units. Swift String equality applies canonical
        // equivalence and would merge terms that C# keeps apart (for example U+03AC and U+1F71).
        func key(_ term: String) -> [UInt16] { Array(term.utf16) }

        let queryTermSet = Set(queryTerms.map(key))

        // Read the document frequency once per term. The last posting for a term wins, as in C#.
        var documentFrequencyByTerm: [[UInt16]: Int] = [:]
        for posting in postings where queryTermSet.contains(key(posting.term)) {
            documentFrequencyByTerm[key(posting.term)] = posting.documentFrequency
        }

        var idfByTerm: [[UInt16]: Double] = [:]
        for term in queryTermSet {
            let n = Double(documentFrequencyByTerm[term] ?? 0)
            idfByTerm[term] = log((Double(totalChunks) - n + 0.5) / (n + 0.5) + 1)
        }

        // Group postings by chunk. chunkOrder keeps the first-seen order of chunk ids.
        var chunkOrder: [Int64] = []
        var postingsByChunk: [Int64: [PostingCandidate]] = [:]
        for posting in postings where queryTermSet.contains(key(posting.term)) {
            if postingsByChunk[posting.chunkId] == nil {
                chunkOrder.append(posting.chunkId)
                postingsByChunk[posting.chunkId] = []
            }
            postingsByChunk[posting.chunkId]?.append(posting)
        }

        var results: [BM25ScoreResult] = []
        results.reserveCapacity(chunkOrder.count)
        for chunkId in chunkOrder {
            var score = 0.0
            for posting in postingsByChunk[chunkId] ?? [] {
                let idf = idfByTerm[key(posting.term)] ?? 0
                let f = Double(posting.termFrequencyInChunk)
                let lengthNorm = 1 - b + b * (Double(posting.chunkTokenCount) / avgChunkLength)
                score += idf * (f * (k1 + 1)) / (f + k1 * lengthNorm)
            }
            results.append(BM25ScoreResult(chunkId: chunkId, score: score))
        }

        // Score descending, then id ascending by UTF-16 code units. The order is total as long as
        // ids are unique, so the result does not depend on whether the sort is stable.
        return results
            .map { (result: $0, key: Array(tieBreakId($0.chunkId).utf16)) }
            .sorted { x, y in
                if x.result.score != y.result.score { return x.result.score > y.result.score }
                return x.key.lexicographicallyPrecedes(y.key)
            }
            .map { $0.result }
    }
}
