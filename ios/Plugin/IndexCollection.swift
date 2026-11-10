import Foundation

/// Error with a message that is safe to show to the app. The plugin passes it to call.reject.
struct BM25Error: Error, LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// A term or an item id as UTF-16 code units. I key every dictionary and set by this type,
/// never by String, because Swift String equality applies canonical equivalence and would
/// merge terms and ids that C# and the persisted file keep apart.
typealias CodeUnits = [UInt16]

func codeUnits(_ s: String) -> CodeUnits { Array(s.utf16) }
func string(_ units: CodeUnits) -> String { String(decoding: units, as: UTF16.self) }
func ordinalLess(_ a: CodeUnits, _ b: CodeUnits) -> Bool { a.lexicographicallyPrecedes(b) }

struct SearchHit {
    let id: String
    let score: Double
    let metadata: String
    let matchedTerms: Int
}

/// The inverted index of one collection, in memory.
///
/// Per item it holds the id, the metadata, the token count and the term frequencies. It does not
/// hold the original text. A second map goes from each term to the ids that contain it. The
/// corpus statistics (item count, total tokens, unique terms) are recomputed by recomputeStats
/// after every write. Document frequency is the size of a term's id set, so it is always exact.
/// The class is not thread safe. The caller serialises access.
final class IndexCollection {
    struct Item {
        let id: String
        let metadata: String
        let tokenCount: Int
        let termFrequencies: [CodeUnits: Int]
    }

    let tokenizerVersion: Int
    private(set) var items: [CodeUnits: Item] = [:]
    private(set) var postings: [CodeUnits: Set<CodeUnits>] = [:]
    private(set) var totalTokens = 0
    private(set) var uniqueTerms = 0

    init(tokenizerVersion: Int) {
        self.tokenizerVersion = tokenizerVersion
    }

    var count: Int { items.count }
    var avgLength: Double { items.isEmpty ? 0 : Double(totalTokens) / Double(items.count) }

    func recomputeStats() {
        totalTokens = items.values.reduce(0) { $0 + $1.tokenCount }
        uniqueTerms = postings.count
    }

    /// Adds an item, or replaces the item with the same id. tokens is the tokenizer output.
    func upsert(id: String, metadata: String, tokens: [String]) {
        _ = remove(id: id)
        var frequencies: [CodeUnits: Int] = [:]
        for token in tokens { frequencies[codeUnits(token), default: 0] += 1 }
        let idKey = codeUnits(id)
        items[idKey] = Item(id: id, metadata: metadata, tokenCount: tokens.count,
                            termFrequencies: frequencies)
        for term in frequencies.keys { postings[term, default: []].insert(idKey) }
    }

    /// Removes an item. Returns false when the id is not in the collection.
    @discardableResult
    func remove(id: String) -> Bool {
        let idKey = codeUnits(id)
        guard let item = items.removeValue(forKey: idKey) else { return false }
        for term in item.termFrequencies.keys {
            postings[term]?.remove(idKey)
            if postings[term]?.isEmpty == true { postings.removeValue(forKey: term) }
        }
        return true
    }

    /// Scores the items that contain at least one query term. Results are ordered by score
    /// descending, then id ascending by UTF-16 code units, and cut to topK.
    func search(queryTerms: [String], topK: Int, minScore: Double, k1: Double, b: Double) -> [SearchHit] {
        var distinct: [CodeUnits] = []
        var seen = Set<CodeUnits>()
        for term in queryTerms where seen.insert(codeUnits(term)).inserted { distinct.append(codeUnits(term)) }
        if distinct.isEmpty || items.isEmpty { return [] }

        var candidateKeys = Set<CodeUnits>()
        for term in distinct { if let ids = postings[term] { candidateKeys.formUnion(ids) } }
        if candidateKeys.isEmpty { return [] }
        let ordered = candidateKeys.sorted(by: ordinalLess)

        var scorerPostings: [PostingCandidate] = []
        var matched: [Int] = []
        for (index, idKey) in ordered.enumerated() {
            guard let item = items[idKey] else { continue }
            var matchedTerms = 0
            for term in distinct {
                guard let tf = item.termFrequencies[term] else { continue }
                matchedTerms += 1
                scorerPostings.append(PostingCandidate(
                    chunkId: Int64(index), term: string(term), termFrequencyInChunk: tf,
                    documentFrequency: postings[term]?.count ?? 0, chunkTokenCount: item.tokenCount))
            }
            matched.append(matchedTerms)
        }

        let scored = BM25Scorer.score(
            queryTerms: distinct.map(string), postings: scorerPostings, totalChunks: items.count,
            avgChunkLength: avgLength, k1: k1, b: b,
            tieBreakId: { string(ordered[Int($0)]) })

        var hits: [SearchHit] = []
        for result in scored where result.score >= minScore {
            guard let item = items[ordered[Int(result.chunkId)]] else { continue }
            hits.append(SearchHit(id: item.id, score: result.score, metadata: item.metadata,
                                  matchedTerms: matched[Int(result.chunkId)]))
            if hits.count == topK { break }
        }
        return hits
    }

    // MARK: Persistence format
    //
    // One JSON object per collection. Terms are a list, never object keys:
    //   terms:     ["bear", "pump", ...]            sorted by UTF-16 code units, index = term number
    //   items:     [{"id", "metadata", "tokenCount", "terms": [[termNumber, frequency], ...]}, ...]
    //                                               sorted by id, index = item number
    //   postings:  [[itemNumber, ...], ...]         one list per term number: the inverted map
    // The original text is not stored.

    static let formatVersion = 1

    func encode(collection name: String) throws -> Data {
        let termKeys = postings.keys.sorted(by: ordinalLess)
        var termNumber: [CodeUnits: Int] = [:]
        for (i, t) in termKeys.enumerated() { termNumber[t] = i }
        let itemKeys = items.keys.sorted(by: ordinalLess)
        var itemNumber: [CodeUnits: Int] = [:]
        for (i, k) in itemKeys.enumerated() { itemNumber[k] = i }

        var itemsJSON: [[String: Any]] = []
        for k in itemKeys {
            guard let item = items[k] else { continue }
            let pairs = item.termFrequencies
                .map { [termNumber[$0.key] ?? -1, $0.value] }
                .sorted { $0[0] < $1[0] }
            itemsJSON.append(["id": item.id, "metadata": item.metadata,
                              "tokenCount": item.tokenCount, "terms": pairs])
        }
        let postingsJSON: [[Int]] = termKeys.map { t in
            (postings[t] ?? []).compactMap { itemNumber[$0] }.sorted()
        }
        let root: [String: Any] = [
            "format": IndexCollection.formatVersion,
            "collection": name,
            "tokenizerVersion": tokenizerVersion,
            "terms": termKeys.map(string),
            "items": itemsJSON,
            "postings": postingsJSON,
        ]
        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    static func decode(_ data: Data) throws -> IndexCollection {
        func bad(_ why: String) -> BM25Error { BM25Error(why) }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw bad("the file is not a JSON object")
        }
        guard root["format"] as? Int == formatVersion else {
            throw bad("unknown file format \(String(describing: root["format"]))")
        }
        guard let version = root["tokenizerVersion"] as? Int,
              let terms = root["terms"] as? [String],
              let itemsJSON = root["items"] as? [[String: Any]],
              let postingsJSON = root["postings"] as? [[Int]],
              postingsJSON.count == terms.count else {
            throw bad("the file is missing fields or has wrong types")
        }

        let collection = IndexCollection(tokenizerVersion: version)
        let termKeys = terms.map(codeUnits)
        var itemKeys: [CodeUnits] = []
        var termEntries = 0
        for entry in itemsJSON {
            guard let id = entry["id"] as? String, let metadata = entry["metadata"] as? String,
                  let tokenCount = entry["tokenCount"] as? Int,
                  let pairs = entry["terms"] as? [[Int]] else {
                throw bad("an item has missing fields or wrong types")
            }
            var frequencies: [CodeUnits: Int] = [:]
            for pair in pairs {
                guard pair.count == 2, pair[0] >= 0, pair[0] < termKeys.count else {
                    throw bad("an item refers to a term that does not exist")
                }
                frequencies[termKeys[pair[0]]] = pair[1]
            }
            termEntries += frequencies.count
            let key = codeUnits(id)
            guard collection.items[key] == nil else { throw bad("duplicate item id") }
            collection.items[key] = Item(id: id, metadata: metadata, tokenCount: tokenCount,
                                         termFrequencies: frequencies)
            itemKeys.append(key)
        }
        var postingEntries = 0
        for (termIndex, list) in postingsJSON.enumerated() {
            var ids = Set<CodeUnits>()
            for itemIndex in list {
                guard itemIndex >= 0, itemIndex < itemKeys.count else {
                    throw bad("a posting refers to an item that does not exist")
                }
                ids.insert(itemKeys[itemIndex])
            }
            postingEntries += ids.count
            collection.postings[termKeys[termIndex]] = ids
        }
        guard postingEntries == termEntries else { throw bad("postings do not match the items") }
        collection.recomputeStats()
        return collection
    }
}
