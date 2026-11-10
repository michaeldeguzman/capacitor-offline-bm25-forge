import XCTest
@testable import Plugin

final class IndexTests: XCTestCase {
    private var directory: URL!
    private var store: CollectionStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bm25-tests-\(UUID().uuidString)", isDirectory: true)
        store = CollectionStore(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func item(_ id: String, _ text: String, _ metadata: String? = nil) -> [String: Any] {
        var d: [String: Any] = ["id": id, "text": text]
        if let metadata = metadata { d["metadata"] = metadata }
        return d
    }

    private func search(_ query: String, topK: Int? = 100, in name: String = "c") throws -> [SearchHit] {
        try store.search(collection: name, query: query, topK: topK, minScore: nil, k1: nil, b: nil)
    }

    private func message(_ work: () throws -> Any?) -> String? {
        do { _ = try work(); return nil } catch let e as BM25Error { return e.message } catch { return "\(error)" }
    }

    // MARK: Index parity

    func testIndexMatchesCSharpForAllQueries() throws {
        let fixture = try FixtureLoader.load("scores")
        let documents = try XCTUnwrap(fixture["documents"] as? [[String: Any]])
        let queries = try XCTUnwrap(fixture["queries"] as? [[String: Any]])
        let result = try store.upsertMany(collection: "seed", items: documents.map {
            item($0["id"] as! String, $0["text"] as! String)
        })
        XCTAssertEqual(result.count, 50)
        XCTAssertEqual(result.skipped, [])

        var problems: [String] = []
        for query in queries {
            let text = query["query"] as! String
            let expected = query["results"] as! [[String: Any]]
            let hits = try search(text, topK: 1000, in: "seed")
            if hits.count != expected.count {
                problems.append("query=\(text) count csharp=\(expected.count) swift=\(hits.count)")
                continue
            }
            for (rank, hit) in hits.enumerated() {
                let want = expected[rank]["score"] as! Double
                if abs(want - hit.score) > 1e-6 { problems.append("query=\(text) rank=\(rank) score csharp=\(want) swift=\(hit.score)") }
            }
            // Same ids per tie group. Inside a group the plugin order is id ascending.
            var start = 0
            while start < expected.count {
                var end = start + 1
                let s0 = expected[start]["score"] as! Double
                while end < expected.count, abs((expected[end]["score"] as! Double) - s0) < 1e-9 { end += 1 }
                let want = Set(expected[start..<end].map { $0["id"] as! String })
                let got = hits[start..<end].map { $0.id }
                if want != Set(got) { problems.append("query=\(text) ranks \(start)..<\(end) csharp=\(want.sorted()) swift=\(got)") }
                if got != got.sorted(by: { codeUnits($0).lexicographicallyPrecedes(codeUnits($1)) }) {
                    problems.append("query=\(text) ranks \(start)..<\(end) tie order not id ascending: \(got)")
                }
                start = end
            }
        }
        print("index: \(queries.count) queries, \(problems.count) problems")
        XCTAssertTrue(problems.isEmpty, problems.joined(separator: "\n"))
    }

    // MARK: Persistence

    func testReloadInFreshInstanceGivesSameResults() throws {
        let fixture = try FixtureLoader.load("scores")
        let documents = try XCTUnwrap(fixture["documents"] as? [[String: Any]])
        let queries = (try XCTUnwrap(fixture["queries"] as? [[String: Any]])).map { $0["query"] as! String }
        _ = try store.upsertMany(collection: "seed", items: documents.map {
            item($0["id"] as! String, $0["text"] as! String, "meta " + ($0["id"] as! String))
        })
        let before = try queries.map { try search($0, topK: 1000, in: "seed") }
        let infoBefore = try store.getCollectionInfo(collection: "seed")

        let fresh = CollectionStore(directory: directory)
        let after = try queries.map {
            try fresh.search(collection: "seed", query: $0, topK: 1000, minScore: nil, k1: nil, b: nil)
        }
        for (a, b) in zip(before, after) {
            XCTAssertEqual(a.map { $0.id }, b.map { $0.id })
            XCTAssertEqual(a.map { $0.score }, b.map { $0.score })
            XCTAssertEqual(a.map { $0.metadata }, b.map { $0.metadata })
            XCTAssertEqual(a.map { $0.matchedTerms }, b.map { $0.matchedTerms })
        }
        let infoAfter = try fresh.getCollectionInfo(collection: "seed")
        XCTAssertEqual(infoAfter.count, 50)
        XCTAssertEqual(infoAfter.uniqueTerms, infoBefore.uniqueTerms)
        XCTAssertEqual(infoAfter.avgLength, infoBefore.avgLength)
    }

    func testFileHoldsTermsAsListAndNoOriginalText() throws {
        _ = try store.upsertMany(collection: "demo", items: [item("a", "Pump seal replacement", "Pump seal")])
        let file = directory.appendingPathComponent("demo.bm25.json")
        let text = try String(contentsOf: file, encoding: .utf8)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        XCTAssertEqual(root["terms"] as? [String], ["pump", "replac", "seal"])
        XCTAssertEqual(root["tokenizerVersion"] as? Int, 2)
        XCTAssertFalse(text.contains("replacement"), "original text must not be stored")
        print("persisted: \(text)")
    }

    func testCanonicallyEquivalentTermsAndIdsStaySeparateAfterReload() throws {
        // U+03AC and U+1F71 are canonically equivalent. Swift String == says they are equal.
        let a = "\u{03AC}", b = "\u{1F71}"
        XCTAssertEqual(a, b)
        _ = try store.upsertMany(collection: "c", items: [item("one", a), item("two", b)])
        // The ids "\u{00E9}" and "e\u{0301}" are canonically equivalent too.
        _ = try store.upsertMany(collection: "ids", items: [item("\u{00E9}", "pump"), item("e\u{0301}", "pump")])

        let fresh = CollectionStore(directory: directory)
        XCTAssertEqual(try fresh.getCollectionInfo(collection: "c").uniqueTerms, 2)
        let hitsA = try fresh.search(collection: "c", query: a, topK: 10, minScore: nil, k1: nil, b: nil)
        let hitsB = try fresh.search(collection: "c", query: b, topK: 10, minScore: nil, k1: nil, b: nil)
        XCTAssertEqual(hitsA.map { $0.id }, ["one"])
        XCTAssertEqual(hitsB.map { $0.id }, ["two"])
        XCTAssertEqual(try fresh.getCollectionInfo(collection: "ids").count, 2)
        let both = try fresh.search(collection: "ids", query: "pump", topK: 10, minScore: nil, k1: nil, b: nil)
        XCTAssertEqual(both.count, 2)
        XCTAssertEqual(try fresh.remove(collection: "ids", ids: ["e\u{0301}"]), 1)
        XCTAssertEqual(try fresh.getCollectionInfo(collection: "ids").count, 1)
    }

    func testStaleTokenizerVersionIsFlaggedAndUpsertRejected() throws {
        _ = try store.upsertMany(collection: "old", items: [item("a", "pump")])
        let file = directory.appendingPathComponent("old.bm25.json")
        let text = try String(contentsOf: file, encoding: .utf8).replacingOccurrences(of: "\"tokenizerVersion\":2", with: "\"tokenizerVersion\":1")
        try text.write(to: file, atomically: true, encoding: .utf8)
        let fresh = CollectionStore(directory: directory)
        let info = try fresh.getCollectionInfo(collection: "old")
        XCTAssertTrue(info.needsReindex)
        XCTAssertEqual(info.tokenizerVersion, 1)
        XCTAssertEqual(info.currentTokenizerVersion, 2)
        XCTAssertEqual(message { try fresh.upsertMany(collection: "old", items: [self.item("b", "seal")]) },
                       "collection 'old' was built with tokenizer version 1 and the current version is 2. Clear it and import again")
        try fresh.clear(collection: "old")
        XCTAssertEqual(try fresh.upsertMany(collection: "old", items: [item("b", "seal")]).count, 1)
    }

    func testCorruptFileGivesReadableError() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "not json".write(to: directory.appendingPathComponent("bad.bm25.json"), atomically: true, encoding: .utf8)
        let msg = message { try self.store.getCollectionInfo(collection: "bad") }
        XCTAssertTrue(msg?.hasPrefix("collection 'bad' could not be read:") == true, msg ?? "nil")
    }

    // MARK: Write operations

    func testUpsertReplaceKeepsCountAndFollowsNewText() throws {
        _ = try store.upsertMany(collection: "c", items: [item("a", "pump seal"), item("b", "generator")])
        XCTAssertEqual(try search("seal").map { $0.id }, ["a"])
        _ = try store.upsertMany(collection: "c", items: [item("a", "fire extinguisher", "new")])
        let info = try store.getCollectionInfo(collection: "c")
        XCTAssertEqual(info.count, 2)
        XCTAssertEqual(try search("seal").count, 0)
        XCTAssertEqual(try search("extinguisher").map { $0.metadata }, ["new"])
        XCTAssertEqual(info.uniqueTerms, 3) // fire, extinguish, gener
    }

    func testRemoveAndClear() throws {
        _ = try store.upsertMany(collection: "c", items: [item("a", "pump"), item("b", "pump seal"), item("c", "seal")])
        XCTAssertEqual(try store.remove(collection: "c", ids: ["a", "missing", "b"]), 2)
        XCTAssertEqual(try store.getCollectionInfo(collection: "c").count, 1)
        XCTAssertEqual(try search("pump").count, 0)
        XCTAssertEqual(try store.getCollectionInfo(collection: "c").uniqueTerms, 1)
        try store.clear(collection: "c")
        XCTAssertFalse(try store.getCollectionInfo(collection: "c").exists)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("c.bm25.json").path))
        try store.clear(collection: "never-existed") // no-op
    }

    func testSkippedIdsAndStats() throws {
        let r = try store.upsertMany(collection: "c", items: [
            item("empty", ""), item("stop", "the a an of and"), item("ok", "pump seal"), item("punct", "!!! ---"),
        ])
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.skipped, ["empty", "stop", "punct"])
        let info = try store.getCollectionInfo(collection: "c")
        XCTAssertEqual(info.count, 1)
        XCTAssertEqual(info.avgLength, 2.0)
        // Re-upserting an indexed id with empty text removes it and reports it as skipped.
        let again = try store.upsertMany(collection: "c", items: [item("ok", "the")])
        XCTAssertEqual(again.skipped, ["ok"])
        XCTAssertEqual(try store.getCollectionInfo(collection: "c").count, 0)
    }

    func testDuplicateIdsInOneCallLastWins() throws {
        let r = try store.upsertMany(collection: "c", items: [item("a", "pump", "first"), item("a", "seal", "last")])
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(try search("pump").count, 0)
        XCTAssertEqual(try search("seal").map { $0.metadata }, ["last"])
    }

    // MARK: Search behaviour

    func testAllStopWordAndEmptyQueriesResolveWithNoResults() throws {
        _ = try store.upsertMany(collection: "c", items: [item("a", "pump seal")])
        XCTAssertEqual(try search("the of and").count, 0)
        XCTAssertEqual(try search("").count, 0)
        XCTAssertEqual(try search("   ").count, 0)
        XCTAssertEqual(try search("nothingmatches").count, 0)
    }

    func testDefaultsAndMatchedTerms() throws {
        let items = (1...8).map { item(String(format: "id%02d", $0), "pump seal number \($0 * 11) " + String(repeating: "valve ", count: $0)) }
        _ = try store.upsertMany(collection: "c", items: items)
        // topK default 5, and 0 or less means 5.
        XCTAssertEqual(try store.search(collection: "c", query: "pump", topK: nil, minScore: nil, k1: nil, b: nil).count, 5)
        XCTAssertEqual(try store.search(collection: "c", query: "pump", topK: 0, minScore: nil, k1: nil, b: nil).count, 5)
        XCTAssertEqual(try store.search(collection: "c", query: "pump", topK: -3, minScore: nil, k1: nil, b: nil).count, 5)
        XCTAssertEqual(try store.search(collection: "c", query: "pump", topK: 2, minScore: nil, k1: nil, b: nil).count, 2)
        // k1 1.2 and b 0.75 are the defaults.
        let implicit = try store.search(collection: "c", query: "pump seal", topK: 8, minScore: nil, k1: nil, b: nil)
        let explicit = try store.search(collection: "c", query: "pump seal", topK: 8, minScore: 0, k1: 1.2, b: 0.75)
        XCTAssertEqual(implicit.map { $0.score }, explicit.map { $0.score })
        let other = try store.search(collection: "c", query: "pump seal", topK: 8, minScore: nil, k1: 2.0, b: 0.2)
        XCTAssertNotEqual(implicit.map { $0.score }, other.map { $0.score })
        // matchedTerms counts distinct query terms in the item. A repeated query term counts once.
        XCTAssertEqual(implicit.map { $0.matchedTerms }, Array(repeating: 2, count: 8))
        let repeated = try store.search(collection: "c", query: "pump pump", topK: 1, minScore: nil, k1: nil, b: nil)
        XCTAssertEqual(repeated.first?.matchedTerms, 1)
        let partial = try store.search(collection: "c", query: "pump 22", topK: 8, minScore: nil, k1: nil, b: nil)
        XCTAssertEqual(partial.first?.id, "id02")
        XCTAssertEqual(partial.first?.matchedTerms, 2)
        // minScore cuts low scores.
        let top = implicit[0].score
        XCTAssertEqual(try store.search(collection: "c", query: "pump seal", topK: 8, minScore: top + 1, k1: nil, b: nil).count, 0)
    }

    func testTiesOrderByIdAscending() throws {
        _ = try store.upsertMany(collection: "c", items: [item("b", "pump"), item("a", "pump"), item("B", "pump")])
        XCTAssertEqual(try search("pump").map { $0.id }, ["B", "a", "b"])
    }

    // MARK: Bad input

    func testBadInput() throws {
        let bad = "collection is required and must not be empty"
        XCTAssertEqual(message { try self.store.getCollectionInfo(collection: nil) }, bad)
        XCTAssertEqual(message { try self.store.getCollectionInfo(collection: "") }, bad)
        XCTAssertEqual(message { try self.store.getCollectionInfo(collection: "  \t") }, bad)
        XCTAssertEqual(message { try self.store.upsertMany(collection: "", items: []) }, bad)
        XCTAssertEqual(message { try self.store.clear(collection: " ") }, bad)

        // Only the encoded file name length can reject a non-blank name.
        let longest = String(repeating: "a", count: 190) // 190 bytes plus ".bm25.json" is 200
        XCTAssertNoThrow(try store.upsertMany(collection: longest, items: [item("a", "pump")]))
        let tooLong = String(repeating: "a", count: 191)
        XCTAssertEqual(message { try self.store.upsertMany(collection: tooLong, items: [self.item("a", "pump")]) },
                       "collection name is too long. Its encoded file name would be 201 bytes and the limit is 200")
        // A capital letter or a non-ASCII letter costs more bytes: "\u{00E9}" is %C3%A9, six bytes.
        let wide = String(repeating: "\u{00E9}", count: 31) // 186 bytes plus 10 is 196
        XCTAssertNoThrow(try store.upsertMany(collection: wide, items: [item("a", "pump")]))
        let tooWide = String(repeating: "\u{00E9}", count: 32) // 192 plus 10 is 202
        XCTAssertEqual(message { try self.store.upsertMany(collection: tooWide, items: [self.item("a", "pump")]) },
                       "collection name is too long. Its encoded file name would be 202 bytes and the limit is 200")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent(CollectionStore.fileName(for: tooLong)).path))

        XCTAssertEqual(message { try self.search("pump", in: "unknown") }, "collection 'unknown' does not exist")
        XCTAssertEqual(message { try self.store.remove(collection: "unknown", ids: ["a"]) }, "collection 'unknown' does not exist")
        let info = try store.getCollectionInfo(collection: "unknown")
        XCTAssertFalse(info.exists)
        XCTAssertEqual([info.count, info.uniqueTerms, info.tokenizerVersion], [0, 0, 0])
        XCTAssertEqual(info.avgLength, 0)
        XCTAssertEqual(info.currentTokenizerVersion, 2)
        XCTAssertFalse(info.needsReindex)

        _ = try store.upsertMany(collection: "c", items: [item("a", "pump")])
        XCTAssertEqual(message { try self.store.search(collection: "c", query: nil, topK: nil, minScore: nil, k1: nil, b: nil) }, "query is required")
        XCTAssertEqual(message { try self.store.remove(collection: "c", ids: nil) }, "ids is required")
        XCTAssertEqual(message { try self.store.upsertMany(collection: "c", items: nil) }, "items is required")
        XCTAssertEqual(message { try self.store.upsertMany(collection: "c", items: [["text": "no id"]]) },
                       "items[0] needs a non-empty string id and a string text")
        XCTAssertEqual(message { try self.store.upsertMany(collection: "c", items: [self.item("ok", "pump"), ["id": "", "text": "x"]]) },
                       "items[1] needs a non-empty string id and a string text")
        XCTAssertEqual(message { try self.store.upsertMany(collection: "c", items: [["id": "a", "text": "x", "metadata": 5]]) },
                       "items[0].metadata must be a string")
        XCTAssertEqual(try store.getCollectionInfo(collection: "c").count, 1, "a rejected call changes nothing")
    }

    func testFileNamesEncodeEveryByteOutsideLowercaseDigitsUnderscoreHyphen() {
        XCTAssertEqual(CollectionStore.fileName(for: "demo_1-b"), "demo_1-b.bm25.json")
        XCTAssertEqual(CollectionStore.fileName(for: "Demo"), "%44emo.bm25.json")
        XCTAssertEqual(CollectionStore.fileName(for: "a.b"), "a%2Eb.bm25.json")
        XCTAssertEqual(CollectionStore.fileName(for: "../x"), "%2E%2E%2Fx.bm25.json")
        XCTAssertEqual(CollectionStore.fileName(for: "a b"), "a%20b.bm25.json")
        XCTAssertEqual(CollectionStore.fileName(for: "caf\u{00E9}"), "caf%C3%A9.bm25.json")
        XCTAssertEqual(CollectionStore.fileName(for: "\u{4E2D}"), "%E4%B8%AD.bm25.json")
        XCTAssertEqual(CollectionStore.fileName(for: "\u{1F600}"), "%F0%9F%98%80.bm25.json") // a surrogate pair is one 4-byte sequence
        XCTAssertEqual(CollectionStore.fileName(for: "a\0b"), "a%00b.bm25.json")
    }

    func testAnyNonBlankNameWorksAndStaysInsideTheDirectory() throws {
        let names = ["../x", "a/b", "a\\b", ".hidden", "..", ".", "a b", "caf\u{00E9}", "\u{4E2D}\u{6587}", "\u{1F600}", "a\0b", "Demo"]
        for name in names {
            XCTAssertEqual(try store.upsertMany(collection: name, items: [item("a", "pump \(name.utf8.count)")]).count, 1, name.debugDescription)
        }
        // Nothing escaped the directory, and every name has its own file.
        let entries = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(entries.count, names.count)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.deletingLastPathComponent().appendingPathComponent("x.bm25.json").path))
        let fresh = CollectionStore(directory: directory)
        for name in names {
            XCTAssertEqual(try fresh.getCollectionInfo(collection: name).count, 1, name.debugDescription)
            XCTAssertEqual(try fresh.search(collection: name, query: "pump", topK: 5, minScore: nil, k1: nil, b: nil).count, 1)
        }
    }

    func testNamesAreCaseSensitiveAndCanonicalEquivalentNamesAreDifferent() throws {
        _ = try store.upsertMany(collection: "Demo", items: [item("a", "pump")])
        _ = try store.upsertMany(collection: "demo", items: [item("b", "seal"), item("c", "valve")])
        // "\u{00E9}" and "e\u{0301}" are canonically equivalent. They are different names here.
        _ = try store.upsertMany(collection: "\u{00E9}", items: [item("one", "pump")])
        _ = try store.upsertMany(collection: "e\u{0301}", items: [item("two", "pump"), item("three", "seal")])
        let fresh = CollectionStore(directory: directory)
        XCTAssertEqual(try fresh.getCollectionInfo(collection: "Demo").count, 1)
        XCTAssertEqual(try fresh.getCollectionInfo(collection: "demo").count, 2)
        XCTAssertEqual(try fresh.getCollectionInfo(collection: "\u{00E9}").count, 1)
        XCTAssertEqual(try fresh.getCollectionInfo(collection: "e\u{0301}").count, 2)
        try fresh.clear(collection: "Demo")
        XCTAssertFalse(try fresh.getCollectionInfo(collection: "Demo").exists)
        XCTAssertTrue(try fresh.getCollectionInfo(collection: "demo").exists)
        try fresh.clear(collection: "\u{00E9}")
        XCTAssertTrue(try fresh.getCollectionInfo(collection: "e\u{0301}").exists)
    }

    func testTokenizeOperation() {
        XCTAssertEqual(Tokenizer.tokenize("ERR-BM25-003"), ["err", "bm25", "003"])
        XCTAssertEqual(Tokenizer.version, 2)
    }
}
