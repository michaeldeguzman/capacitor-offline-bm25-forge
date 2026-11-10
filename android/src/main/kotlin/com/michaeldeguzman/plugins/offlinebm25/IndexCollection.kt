package com.michaeldeguzman.plugins.offlinebm25

import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/** Error with a message that is safe to show to the app. The plugin passes it to call.reject. */
class BM25Exception(message: String) : Exception(message)

data class SearchHit(val id: String, val score: Double, val metadata: String, val matchedTerms: Int)

/**
 * The inverted index of one collection, in memory.
 *
 * Per item it holds the id, the metadata, the token count and the term frequencies. It does not
 * hold the original text. A second map goes from each term to the ids that contain it. The corpus
 * statistics (total tokens, unique terms) are recomputed by recomputeStats after every write.
 * Document frequency is the size of a term's id set, so it is always exact.
 * Kotlin String equality and hashing compare UTF-16 code units, so terms and ids are keyed
 * ordinally with no extra work. The class is not thread safe. The caller serialises access.
 */
class IndexCollection(val tokenizerVersion: Int) {
    class Item(
        val id: String,
        val metadata: String,
        val tokenCount: Int,
        val termFrequencies: Map<String, Int>,
    )

    val items = HashMap<String, Item>()
    val postings = HashMap<String, MutableSet<String>>()
    var totalTokens = 0
        private set
    var uniqueTerms = 0
        private set

    val count: Int get() = items.size
    val avgLength: Double get() = if (items.isEmpty()) 0.0 else totalTokens.toDouble() / items.size

    fun recomputeStats() {
        totalTokens = items.values.sumOf { it.tokenCount }
        uniqueTerms = postings.size
    }

    /** Adds an item, or replaces the item with the same id. tokens is the tokenizer output. */
    fun upsert(id: String, metadata: String, tokens: List<String>) {
        remove(id)
        val frequencies = HashMap<String, Int>()
        for (token in tokens) frequencies[token] = (frequencies[token] ?: 0) + 1
        items[id] = Item(id, metadata, tokens.size, frequencies)
        for (term in frequencies.keys) postings.getOrPut(term) { HashSet() }.add(id)
    }

    /** Removes an item. Returns false when the id is not in the collection. */
    fun remove(id: String): Boolean {
        val item = items.remove(id) ?: return false
        for (term in item.termFrequencies.keys) {
            val ids = postings[term] ?: continue
            ids.remove(id)
            if (ids.isEmpty()) postings.remove(term)
        }
        return true
    }

    /**
     * Scores the items that contain at least one query term. Results are ordered by score
     * descending, then id ascending by UTF-16 code units, and cut to topK.
     */
    fun search(queryTerms: List<String>, topK: Int, minScore: Double, k1: Double, b: Double): List<SearchHit> {
        val distinct = queryTerms.distinct()
        if (distinct.isEmpty() || items.isEmpty()) return emptyList()

        val candidates = HashSet<String>()
        for (term in distinct) postings[term]?.let { candidates.addAll(it) }
        if (candidates.isEmpty()) return emptyList()
        val ordered = candidates.sorted() // String order is UTF-16 code unit order

        val scorerPostings = ArrayList<PostingCandidate>()
        val matched = IntArray(ordered.size)
        for ((index, id) in ordered.withIndex()) {
            val item = items.getValue(id)
            for (term in distinct) {
                val tf = item.termFrequencies[term] ?: continue
                matched[index]++
                scorerPostings.add(PostingCandidate(index.toLong(), term, tf, postings[term]?.size ?: 0, item.tokenCount))
            }
        }

        val scored = BM25Scorer.score(distinct, scorerPostings, items.size, avgLength, k1, b) { ordered[it.toInt()] }
        val hits = ArrayList<SearchHit>()
        for (result in scored) {
            if (result.score < minScore) continue
            val item = items.getValue(ordered[result.chunkId.toInt()])
            hits.add(SearchHit(item.id, result.score, item.metadata, matched[result.chunkId.toInt()]))
            if (hits.size == topK) break
        }
        return hits
    }

    /*
     * Persistence format. One JSON object per collection. Terms are a list, never object keys:
     *   terms:     ["bear", "pump", ...]            sorted by UTF-16 code units, index = term number
     *   items:     [{"id", "metadata", "tokenCount", "terms": [[termNumber, frequency], ...]}, ...]
     *                                               sorted by id, index = item number
     *   postings:  [[itemNumber, ...], ...]         one list per term number: the inverted map
     * The original text is not stored. The writer escapes every non-ASCII unit as \uXXXX, so a
     * lone surrogate in an id or metadata survives the round trip through UTF-8.
     */

    fun encode(collection: String): String {
        val termKeys = postings.keys.sorted()
        val termNumber = HashMap<String, Int>()
        termKeys.forEachIndexed { i, t -> termNumber[t] = i }
        val itemKeys = items.keys.sorted()
        val itemNumber = HashMap<String, Int>()
        itemKeys.forEachIndexed { i, k -> itemNumber[k] = i }

        val sb = StringBuilder()
        sb.append("{\"collection\":").append(quote(collection))
        sb.append(",\"format\":").append(FORMAT_VERSION)
        sb.append(",\"items\":[")
        itemKeys.forEachIndexed { i, key ->
            val item = items.getValue(key)
            if (i > 0) sb.append(',')
            sb.append("{\"id\":").append(quote(item.id))
            sb.append(",\"metadata\":").append(quote(item.metadata))
            sb.append(",\"terms\":[")
            val pairs = item.termFrequencies.entries.map { termNumber.getValue(it.key) to it.value }.sortedBy { it.first }
            pairs.forEachIndexed { j, (term, freq) ->
                if (j > 0) sb.append(',')
                sb.append('[').append(term).append(',').append(freq).append(']')
            }
            sb.append("],\"tokenCount\":").append(item.tokenCount).append('}')
        }
        sb.append("],\"postings\":[")
        termKeys.forEachIndexed { i, term ->
            if (i > 0) sb.append(',')
            sb.append('[').append(postings.getValue(term).map { itemNumber.getValue(it) }.sorted().joinToString(",")).append(']')
        }
        sb.append("],\"terms\":[").append(termKeys.joinToString(",") { quote(it) })
        sb.append("],\"tokenizerVersion\":").append(tokenizerVersion).append('}')
        return sb.toString()
    }

    companion object {
        const val FORMAT_VERSION = 1

        private fun quote(s: String): String {
            val sb = StringBuilder(s.length + 2).append('"')
            for (c in s) {
                when {
                    c == '"' -> sb.append("\\\"")
                    c == '\\' -> sb.append("\\\\")
                    c.code < 0x20 || c.code > 0x7E -> sb.append("\\u").append(c.code.toString(16).padStart(4, '0'))
                    else -> sb.append(c)
                }
            }
            return sb.append('"').toString()
        }

        fun decode(text: String): IndexCollection {
            try {
                val root = JSONObject(text)
                if (root.getInt("format") != FORMAT_VERSION) throw BM25Exception("unknown file format ${root.get("format")}")
                val collection = IndexCollection(root.getInt("tokenizerVersion"))
                val termsJson = root.getJSONArray("terms")
                val termKeys = List(termsJson.length()) { termsJson.getString(it) }
                val postingsJson = root.getJSONArray("postings")
                if (postingsJson.length() != termKeys.size) throw BM25Exception("the file is missing fields or has wrong types")

                val itemsJson = root.getJSONArray("items")
                val itemKeys = ArrayList<String>(itemsJson.length())
                var termEntries = 0
                for (i in 0 until itemsJson.length()) {
                    val entry = itemsJson.getJSONObject(i)
                    val id = entry.getString("id")
                    val pairs = entry.getJSONArray("terms")
                    val frequencies = HashMap<String, Int>()
                    for (j in 0 until pairs.length()) {
                        val pair: JSONArray = pairs.getJSONArray(j)
                        val termIndex = pair.getInt(0)
                        if (pair.length() != 2 || termIndex < 0 || termIndex >= termKeys.size) {
                            throw BM25Exception("an item refers to a term that does not exist")
                        }
                        frequencies[termKeys[termIndex]] = pair.getInt(1)
                    }
                    termEntries += frequencies.size
                    if (collection.items.containsKey(id)) throw BM25Exception("duplicate item id")
                    collection.items[id] = Item(id, entry.getString("metadata"), entry.getInt("tokenCount"), frequencies)
                    itemKeys.add(id)
                }
                var postingEntries = 0
                for (t in termKeys.indices) {
                    val list = postingsJson.getJSONArray(t)
                    val ids = HashSet<String>()
                    for (k in 0 until list.length()) {
                        val itemIndex = list.getInt(k)
                        if (itemIndex < 0 || itemIndex >= itemKeys.size) throw BM25Exception("a posting refers to an item that does not exist")
                        ids.add(itemKeys[itemIndex])
                    }
                    postingEntries += ids.size
                    collection.postings[termKeys[t]] = ids
                }
                if (postingEntries != termEntries) throw BM25Exception("postings do not match the items")
                collection.recomputeStats()
                return collection
            } catch (e: JSONException) {
                throw BM25Exception("the file is missing fields or is not valid JSON")
            }
        }
    }
}
