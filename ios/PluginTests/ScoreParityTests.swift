import XCTest
@testable import Plugin

final class ScoreParityTests: XCTestCase {
    private let tolerance = 1e-6
    private let tieEpsilon = 1e-9

    func testEveryQueryMatchesCSharp() throws {
        let fixture = try FixtureLoader.load("scores")
        let k1 = try XCTUnwrap(fixture["k1"] as? Double)
        let b = try XCTUnwrap(fixture["b"] as? Double)
        let documents = try XCTUnwrap(fixture["documents"] as? [[String: Any]])
        let queries = try XCTUnwrap(fixture["queries"] as? [[String: Any]])
        XCTAssertEqual(documents.count, fixture["totalDocuments"] as? Int)
        XCTAssertEqual(queries.count, fixture["queryCount"] as? Int)

        // Index the documents with the Swift tokenizer, as the plugin will.
        var ids: [String] = []
        var termFrequencies: [[String: Int]] = []
        var lengths: [Int] = []
        var documentFrequency: [String: Int] = [:]
        for document in documents {
            let id = try XCTUnwrap(document["id"] as? String)
            let text = try XCTUnwrap(document["text"] as? String)
            let tokens = Tokenizer.tokenize(text)
            XCTAssertEqual(tokens.count, document["tokenCount"] as? Int, "token count for \(id)")
            var tf: [String: Int] = [:]
            for token in tokens { tf[token, default: 0] += 1 }
            for term in tf.keys { documentFrequency[term, default: 0] += 1 }
            ids.append(id)
            termFrequencies.append(tf)
            lengths.append(tokens.count)
        }
        let avgLength = Double(lengths.reduce(0, +)) / Double(documents.count)
        XCTAssertEqual(avgLength, fixture["avgLength"] as? Double ?? -1, accuracy: tolerance)

        var problems: [String] = []
        for query in queries {
            let text = try XCTUnwrap(query["query"] as? String)
            let expectedTerms = try XCTUnwrap(query["queryTerms"] as? [String])
            let expected = try XCTUnwrap(query["results"] as? [[String: Any]])

            let queryTerms = Tokenizer.tokenize(text)
            if queryTerms != expectedTerms {
                problems.append("query=\(text) terms csharp=\(expectedTerms) swift=\(queryTerms)")
                continue
            }

            var postings: [PostingCandidate] = []
            var seen = Set<String>()
            let distinctTerms = queryTerms.filter { seen.insert($0).inserted }
            for d in 0..<ids.count {
                for term in distinctTerms {
                    guard let f = termFrequencies[d][term] else { continue }
                    postings.append(PostingCandidate(
                        chunkId: Int64(d + 1), term: term, termFrequencyInChunk: f,
                        documentFrequency: documentFrequency[term] ?? 0, chunkTokenCount: lengths[d]))
                }
            }
            let actual = BM25Scorer.score(
                queryTerms: queryTerms, postings: postings, totalChunks: ids.count,
                avgChunkLength: avgLength, k1: k1, b: b,
                tieBreakId: { ids[Int($0) - 1] })

            if actual.count != expected.count {
                problems.append("query=\(text) result count csharp=\(expected.count) swift=\(actual.count)")
                continue
            }

            // Scores: same value at every rank position, within the tolerance.
            for (rank, pair) in zip(expected, actual).enumerated() {
                let expectedScore = try XCTUnwrap(pair.0["score"] as? Double)
                if abs(expectedScore - pair.1.score) > tolerance {
                    problems.append("query=\(text) rank=\(rank) score csharp=\(expectedScore) swift=\(pair.1.score)")
                }
            }

            // Ranking: same ids at every rank. Ids with equal scores form a tie group, and
            // C# List.Sort gives no order inside a tie group, so I compare each group as a set.
            var start = 0
            while start < expected.count {
                var end = start + 1
                let startScore = try XCTUnwrap(expected[start]["score"] as? Double)
                while end < expected.count,
                      abs((expected[end]["score"] as? Double ?? .nan) - startScore) < tieEpsilon {
                    end += 1
                }
                let expectedIds = Set(expected[start..<end].compactMap { $0["id"] as? String })
                let actualIds = Set(actual[start..<end].map { ids[Int($0.chunkId) - 1] })
                if expectedIds != actualIds {
                    problems.append("query=\(text) ranks \(start)..<\(end) csharp=\(expectedIds.sorted()) swift=\(actualIds.sorted())")
                }
                start = end
            }
        }
        print("scores: \(queries.count) queries, \(problems.count) problems")
        XCTAssertTrue(problems.isEmpty, "Score mismatches:\n" + problems.joined(separator: "\n"))
    }

    /// The hand-calculated example from BM25ScorerTests.cs.
    func testHandCalculatedExample() {
        let postings = [
            PostingCandidate(chunkId: 1, term: "cach", termFrequencyInChunk: 2, documentFrequency: 2, chunkTokenCount: 8),
            PostingCandidate(chunkId: 1, term: "invalid", termFrequencyInChunk: 1, documentFrequency: 2, chunkTokenCount: 8),
            PostingCandidate(chunkId: 2, term: "cach", termFrequencyInChunk: 1, documentFrequency: 2, chunkTokenCount: 12),
            PostingCandidate(chunkId: 3, term: "invalid", termFrequencyInChunk: 3, documentFrequency: 2, chunkTokenCount: 10)
        ]
        let results = BM25Scorer.score(queryTerms: ["cach", "invalid"], postings: postings,
                                       totalChunks: 4, avgChunkLength: 10, k1: 1.2, b: 0.75,
                                       tieBreakId: { String($0) })
        XCTAssertEqual(results.map { $0.chunkId }, [1, 3, 2])
        XCTAssertEqual(results[0].score, 1.7647960803319571, accuracy: tolerance)
        XCTAssertEqual(results[1].score, 1.089231283737057, accuracy: tolerance)
        XCTAssertEqual(results[2].score, 0.64072428455121, accuracy: tolerance)
    }

    /// U+03AC and U+1F71 are canonically equivalent, so Swift String == treats them as equal.
    /// C# compares ordinally and keeps them apart. The scorer must do the same.
    func testTermsAreComparedByCodeUnitsNotCanonicalEquivalence() {
        let a = "\u{03AC}"
        let b = "\u{1F71}"
        XCTAssertEqual(a, b) // documents the Swift behaviour the scorer avoids
        let postings = [PostingCandidate(chunkId: 1, term: a, termFrequencyInChunk: 1,
                                         documentFrequency: 1, chunkTokenCount: 10)]
        let results = BM25Scorer.score(queryTerms: [b], postings: postings,
                                       totalChunks: 5, avgChunkLength: 10, k1: 1.2, b: 0.75,
                                       tieBreakId: { String($0) })
        XCTAssertTrue(results.isEmpty)
    }

    /// Ties are ordered by id ascending, compared ordinally. "B" sorts before "a" and "a" before "b".
    func testTiesOrderByIdAscendingOrdinal() {
        let idsByChunk: [Int64: String] = [1: "b", 2: "a", 3: "B", 4: "c", 5: "\u{00E9}"]
        let postings = idsByChunk.keys.sorted().map {
            PostingCandidate(chunkId: $0, term: "cach", termFrequencyInChunk: 1,
                             documentFrequency: 5, chunkTokenCount: 10)
        }
        // A better scoring chunk goes first whatever its id.
        let all = postings + [PostingCandidate(chunkId: 6, term: "cach", termFrequencyInChunk: 4,
                                               documentFrequency: 5, chunkTokenCount: 10)]
        var ids = idsByChunk
        ids[6] = "z"
        let results = BM25Scorer.score(queryTerms: ["cach"], postings: all, totalChunks: 10,
                                       avgChunkLength: 10, k1: 1.2, b: 0.75,
                                       tieBreakId: { ids[$0] ?? "" })
        XCTAssertEqual(results.map { ids[$0.chunkId] ?? "" }, ["z", "B", "a", "b", "c", "\u{00E9}"])
    }

    func testZeroLengthChunkIsNotNaN() {
        let postings = [PostingCandidate(chunkId: 1, term: "cach", termFrequencyInChunk: 1,
                                         documentFrequency: 1, chunkTokenCount: 0)]
        let results = BM25Scorer.score(queryTerms: ["cach"], postings: postings,
                                       totalChunks: 5, avgChunkLength: 10, k1: 1.2, b: 0.75,
                                       tieBreakId: { String($0) })
        XCTAssertEqual(results.count, 1)
        XCTAssertFalse(results[0].score.isNaN)
    }
}
