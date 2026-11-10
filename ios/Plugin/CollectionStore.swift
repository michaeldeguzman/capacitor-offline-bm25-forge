import Foundation

/// The collections of the plugin, on disk and in memory. One JSON file per collection.
///
/// Every public method is synchronous and throws BM25Error with a readable message. The plugin
/// calls them on one serial queue, so the store holds no lock. Tests call them directly.
final class CollectionStore {
    static let defaultTopK = 5
    static let defaultK1 = 1.2
    static let defaultB = 0.75

    let directory: URL
    private var cache: [String: IndexCollection] = [:] // keyed by file name, see cacheKey

    init(directory: URL) {
        self.directory = directory
    }

    // MARK: Names

    /// The longest encoded file name, in bytes, including the ".bm25.json" suffix.
    static let maxFileNameBytes = 200

    /// Returns the collection name when it can be stored. Any name is accepted except an empty or
    /// whitespace-only one (whitespace as in CharRules) and one whose encoded file name is longer
    /// than maxFileNameBytes. Names are case-sensitive.
    ///
    /// A lone surrogate cannot be written as UTF-8, so Kotlin rejects it. A Swift String cannot
    /// hold one: the bridge replaces it with U+FFFD before this code runs, so on iOS such a name
    /// is stored as U+FFFD.
    static func validate(name: String?) throws -> String {
        guard let name = name, !name.utf16.allSatisfy(CharRules.isWhiteSpace) else {
            throw BM25Error("collection is required and must not be empty")
        }
        let bytes = fileName(for: name).utf8.count
        guard bytes <= maxFileNameBytes else {
            throw BM25Error("collection name is too long. Its encoded file name would be \(bytes) bytes and the limit is \(maxFileNameBytes)")
        }
        return name
    }

    /// Maps a name to its file name. The name is read as UTF-8 bytes. Every byte outside a-z, 0-9,
    /// underscore and hyphen becomes %XX with uppercase hex. Capital letters are encoded too, so
    /// names that differ only by case get different files on a case-insensitive file system, and
    /// no name can contain a path separator or a dot-dot. Kotlin produces the same file name.
    static func fileName(for name: String) -> String {
        var out = ""
        for u in name.utf8 {
            if (0x30...0x39).contains(u) || (0x61...0x7A).contains(u) || u == 0x5F || u == 0x2D {
                out.append(Character(Unicode.Scalar(u)))
            } else {
                out += String(format: "%%%02X", u)
            }
        }
        return out + ".bm25.json"
    }

    private func url(for name: String) -> URL {
        directory.appendingPathComponent(CollectionStore.fileName(for: name))
    }

    /// Cache key. It is the file name, which is ASCII, so canonically equivalent names that
    /// are different on disk stay different here.
    private func cacheKey(_ name: String) -> String { CollectionStore.fileName(for: name) }

    // MARK: Loading and saving

    private func existing(_ name: String) throws -> IndexCollection? {
        if let cached = cache[cacheKey(name)] { return cached }
        let fileURL = url(for: name)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let loaded = try IndexCollection.decode(try Data(contentsOf: fileURL))
            cache[cacheKey(name)] = loaded
            return loaded
        } catch let error as BM25Error {
            throw BM25Error("collection '\(name)' could not be read: \(error.message)")
        } catch {
            throw BM25Error("collection '\(name)' could not be read: \(error.localizedDescription)")
        }
    }

    private func save(_ collection: IndexCollection, as name: String) throws {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // .atomic writes a temporary file and renames it over the target.
            try collection.encode(collection: name).write(to: url(for: name), options: .atomic)
        } catch {
            cache.removeValue(forKey: cacheKey(name)) // the next access reloads what is on disk
            throw BM25Error("collection '\(name)' could not be saved: \(error.localizedDescription)")
        }
    }

    private func require(_ name: String) throws -> IndexCollection {
        guard let collection = try existing(name) else {
            throw BM25Error("collection '\(name)' does not exist")
        }
        return collection
    }

    // MARK: Operations

    /// Indexes the items and returns how many were stored and which ids were skipped. An item is
    /// skipped when its text gives no tokens. If the id was already in the collection, the old
    /// entry is removed, because the replacement has nothing to index. When an id appears twice in
    /// one call, the last one wins.
    func upsertMany(collection rawName: String?, items rawItems: [[String: Any]]?) throws -> (count: Int, skipped: [String]) {
        let name = try CollectionStore.validate(name: rawName)
        guard let rawItems = rawItems else { throw BM25Error("items is required") }

        var order: [CodeUnits] = []
        var latest: [CodeUnits: (id: String, text: String, metadata: String)] = [:]
        for (index, raw) in rawItems.enumerated() {
            guard let id = raw["id"] as? String, !id.isEmpty, let text = raw["text"] as? String else {
                throw BM25Error("items[\(index)] needs a non-empty string id and a string text")
            }
            if let metadata = raw["metadata"], !(metadata is String), !(metadata is NSNull) {
                throw BM25Error("items[\(index)].metadata must be a string")
            }
            let key = codeUnits(id)
            if latest[key] == nil { order.append(key) }
            latest[key] = (id, text, raw["metadata"] as? String ?? "")
        }

        let collection = try existing(name) ?? IndexCollection(tokenizerVersion: Tokenizer.version)
        if collection.tokenizerVersion != Tokenizer.version {
            throw BM25Error("collection '\(name)' was built with tokenizer version \(collection.tokenizerVersion) and the current version is \(Tokenizer.version). Clear it and import again")
        }
        var count = 0
        var skipped: [String] = []
        for key in order {
            guard let item = latest[key] else { continue }
            let tokens = Tokenizer.tokenize(item.text)
            if tokens.isEmpty {
                collection.remove(id: item.id)
                skipped.append(item.id)
            } else {
                collection.upsert(id: item.id, metadata: item.metadata, tokens: tokens)
                count += 1
            }
        }
        collection.recomputeStats()
        cache[cacheKey(name)] = collection
        try save(collection, as: name)
        return (count, skipped)
    }

    func search(collection rawName: String?, query: String?, topK: Int?, minScore: Double?,
                k1: Double?, b: Double?) throws -> [SearchHit] {
        let name = try CollectionStore.validate(name: rawName)
        guard let query = query else { throw BM25Error("query is required") }
        let collection = try require(name)
        let terms = Tokenizer.tokenize(query)
        if terms.isEmpty { return [] }
        let k = (topK ?? 0) > 0 ? topK! : CollectionStore.defaultTopK
        return collection.search(queryTerms: terms, topK: k, minScore: minScore ?? 0,
                                 k1: k1 ?? CollectionStore.defaultK1, b: b ?? CollectionStore.defaultB)
    }

    func remove(collection rawName: String?, ids: [String]?) throws -> Int {
        let name = try CollectionStore.validate(name: rawName)
        guard let ids = ids else { throw BM25Error("ids is required") }
        let collection = try require(name)
        var removed = 0
        for id in ids where collection.remove(id: id) { removed += 1 }
        collection.recomputeStats()
        try save(collection, as: name)
        return removed
    }

    /// Deletes the collection. An unknown collection is a no-op.
    func clear(collection rawName: String?) throws {
        let name = try CollectionStore.validate(name: rawName)
        cache.removeValue(forKey: cacheKey(name))
        let fileURL = url(for: name)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do { try FileManager.default.removeItem(at: fileURL) } catch {
                throw BM25Error("collection '\(name)' could not be deleted: \(error.localizedDescription)")
            }
        }
    }

    struct Info {
        let exists: Bool
        let count: Int
        let uniqueTerms: Int
        let avgLength: Double
        let tokenizerVersion: Int
        let currentTokenizerVersion: Int
        let needsReindex: Bool
    }

    func getCollectionInfo(collection rawName: String?) throws -> Info {
        let name = try CollectionStore.validate(name: rawName)
        guard let c = try existing(name) else {
            return Info(exists: false, count: 0, uniqueTerms: 0, avgLength: 0, tokenizerVersion: 0,
                        currentTokenizerVersion: Tokenizer.version, needsReindex: false)
        }
        return Info(exists: true, count: c.count, uniqueTerms: c.uniqueTerms, avgLength: c.avgLength,
                    tokenizerVersion: c.tokenizerVersion, currentTokenizerVersion: Tokenizer.version,
                    needsReindex: c.tokenizerVersion != Tokenizer.version)
    }
}
