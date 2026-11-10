import Foundation
import Capacitor

/// Capacitor entry point for OfflineBM25. Every method that touches the index runs on one
/// serial queue, so reads and writes never overlap.
@objc(OfflineBM25Plugin)
public class OfflineBM25Plugin: CAPPlugin {
    private let queue = DispatchQueue(label: "offline-bm25")
    private lazy var store: CollectionStore = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return CollectionStore(directory: base.appendingPathComponent("OfflineBM25", isDirectory: true))
    }()

    private func run(_ call: CAPPluginCall, _ work: @escaping () throws -> Void) {
        queue.async {
            do { try work() } catch let error as BM25Error {
                call.reject(error.message)
            } catch {
                call.reject("unexpected error: \(error.localizedDescription)")
            }
        }
    }

    @objc func isAvailable(_ call: CAPPluginCall) {
        call.resolve(["available": true, "tokenizerVersion": Tokenizer.version])
    }

    @objc func upsertMany(_ call: CAPPluginCall) {
        let name = call.getString("collection")
        let items = call.getArray("items", JSObject.self)?.map { $0 as [String: Any] }
        run(call) {
            let result = try self.store.upsertMany(collection: name, items: items)
            call.resolve(["count": result.count, "skipped": result.skipped])
        }
    }

    @objc func search(_ call: CAPPluginCall) {
        let name = call.getString("collection")
        let query = call.getString("query")
        let topK = call.getInt("topK")
        let minScore = call.getDouble("minScore")
        let k1 = call.getDouble("k1")
        let b = call.getDouble("b")
        run(call) {
            let hits = try self.store.search(collection: name, query: query, topK: topK,
                                             minScore: minScore, k1: k1, b: b)
            let results = hits.map {
                ["id": $0.id, "score": $0.score, "metadata": $0.metadata,
                 "matchedTerms": $0.matchedTerms] as JSObject
            }
            call.resolve(["results": results])
        }
    }

    @objc func remove(_ call: CAPPluginCall) {
        let name = call.getString("collection")
        let ids = call.getArray("ids", String.self)
        run(call) {
            call.resolve(["count": try self.store.remove(collection: name, ids: ids)])
        }
    }

    @objc func clear(_ call: CAPPluginCall) {
        let name = call.getString("collection")
        run(call) {
            try self.store.clear(collection: name)
            call.resolve()
        }
    }

    @objc func getCollectionInfo(_ call: CAPPluginCall) {
        let name = call.getString("collection")
        run(call) {
            let i = try self.store.getCollectionInfo(collection: name)
            call.resolve([
                "exists": i.exists, "count": i.count, "uniqueTerms": i.uniqueTerms,
                "avgLength": i.avgLength, "tokenizerVersion": i.tokenizerVersion,
                "currentTokenizerVersion": i.currentTokenizerVersion, "needsReindex": i.needsReindex,
            ])
        }
    }

    @objc func tokenize(_ call: CAPPluginCall) {
        guard let text = call.getString("text") else { return call.reject("text is required") }
        queue.async { call.resolve(["tokens": Tokenizer.tokenize(text)]) }
    }
}
