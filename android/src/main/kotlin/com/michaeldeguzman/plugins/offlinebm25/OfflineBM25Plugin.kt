package com.michaeldeguzman.plugins.offlinebm25

import com.getcapacitor.JSArray
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors

/**
 * Capacitor entry point for OfflineBM25. Every method that touches the index runs on one
 * single-thread executor, so reads and writes never overlap.
 */
@CapacitorPlugin(name = "OfflineBM25")
class OfflineBM25Plugin : Plugin() {
    private val executor = Executors.newSingleThreadExecutor()
    private lateinit var store: CollectionStore

    override fun load() {
        store = CollectionStore(File(context.filesDir, "offlinebm25"))
    }

    private fun run(call: PluginCall, work: () -> Unit) {
        executor.execute {
            try {
                work()
            } catch (e: BM25Exception) {
                call.reject(e.message)
            } catch (e: Exception) {
                call.reject("unexpected error: ${e.message}")
            }
        }
    }

    @PluginMethod
    fun isAvailable(call: PluginCall) {
        val ret = JSObject()
        ret.put("available", true)
        ret.put("tokenizerVersion", Tokenizer.VERSION)
        call.resolve(ret)
    }

    @PluginMethod
    fun upsertMany(call: PluginCall) {
        val name = call.getString("collection")
        val array = call.getArray("items")
        val items: List<Any?>? = array?.let { a ->
            List(a.length()) { i ->
                val value = a.opt(i)
                if (value is JSONObject) {
                    // JSON null is treated as absent
                    value.keys().asSequence().mapNotNull { k -> value.opt(k)?.takeIf { it != JSONObject.NULL }?.let { k to it } }.toMap()
                } else value
            }
        }
        run(call) {
            val result = store.upsertMany(name, items)
            val ret = JSObject()
            ret.put("count", result.count)
            ret.put("skipped", JSArray(result.skipped))
            call.resolve(ret)
        }
    }

    @PluginMethod
    fun search(call: PluginCall) {
        val name = call.getString("collection")
        val query = call.getString("query")
        val topK = call.getInt("topK")
        val minScore = call.getDouble("minScore")
        val k1 = call.getDouble("k1")
        val b = call.getDouble("b")
        run(call) {
            val hits = store.search(name, query, topK, minScore, k1, b)
            val results = JSArray()
            for (hit in hits) {
                val o = JSObject()
                o.put("id", hit.id)
                o.put("score", hit.score)
                o.put("metadata", hit.metadata)
                o.put("matchedTerms", hit.matchedTerms)
                results.put(o)
            }
            val ret = JSObject()
            ret.put("results", results)
            call.resolve(ret)
        }
    }

    @PluginMethod
    fun remove(call: PluginCall) {
        val name = call.getString("collection")
        val array = call.getArray("ids")
        val ids: List<String>? = array?.let { a -> List(a.length()) { a.opt(it) }.filterIsInstance<String>() }
        run(call) {
            val ret = JSObject()
            ret.put("count", store.remove(name, ids))
            call.resolve(ret)
        }
    }

    @PluginMethod
    fun clear(call: PluginCall) {
        val name = call.getString("collection")
        run(call) {
            store.clear(name)
            call.resolve()
        }
    }

    @PluginMethod
    fun getCollectionInfo(call: PluginCall) {
        val name = call.getString("collection")
        run(call) {
            val i = store.getCollectionInfo(name)
            val ret = JSObject()
            ret.put("exists", i.exists)
            ret.put("count", i.count)
            ret.put("uniqueTerms", i.uniqueTerms)
            ret.put("avgLength", i.avgLength)
            ret.put("tokenizerVersion", i.tokenizerVersion)
            ret.put("currentTokenizerVersion", i.currentTokenizerVersion)
            ret.put("needsReindex", i.needsReindex)
            call.resolve(ret)
        }
    }

    @PluginMethod
    fun tokenize(call: PluginCall) {
        val text = call.getString("text") ?: return call.reject("text is required")
        executor.execute {
            val ret = JSObject()
            ret.put("tokens", JSArray(Tokenizer.tokenize(text)))
            call.resolve(ret)
        }
    }
}
