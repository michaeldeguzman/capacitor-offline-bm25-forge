package com.michaeldeguzman.plugins.offlinebm25

import java.io.File
import java.io.FileOutputStream

/**
 * The collections of the plugin, on disk and in memory. One JSON file per collection.
 *
 * Every public method is synchronous and throws BM25Exception with a readable message. The plugin
 * calls them on one single-thread executor, so the store holds no lock. Tests call them directly.
 */
class CollectionStore(private val directory: File) {
    private val cache = HashMap<String, IndexCollection>() // keyed by file name

    data class UpsertResult(val count: Int, val skipped: List<String>)

    data class Info(
        val exists: Boolean,
        val count: Int,
        val uniqueTerms: Int,
        val avgLength: Double,
        val tokenizerVersion: Int,
        val currentTokenizerVersion: Int,
        val needsReindex: Boolean,
    )

    companion object {
        const val DEFAULT_TOP_K = 5
        const val DEFAULT_K1 = 1.2
        const val DEFAULT_B = 0.75

        /** The longest encoded file name, in bytes, including the ".bm25.json" suffix. */
        const val MAX_FILE_NAME_BYTES = 200

        /**
         * Returns the collection name when it can be stored. Any name is accepted except an empty or
         * whitespace-only one (whitespace as in CharRules), one with an unpaired surrogate, and one
         * whose encoded file name is longer than MAX_FILE_NAME_BYTES. Names are case-sensitive.
         *
         * An unpaired surrogate cannot be written as UTF-8, so I reject it. A Swift String cannot
         * hold one: the iOS bridge replaces it with U+FFFD before the plugin runs, so on iOS such a
         * name is stored as U+FFFD.
         */
        fun validate(name: String?): String {
            if (name == null || name.all { CharRules.isWhiteSpace(it) }) {
                throw BM25Exception("collection is required and must not be empty")
            }
            if (hasUnpairedSurrogate(name)) {
                throw BM25Exception("collection name contains an unpaired surrogate and cannot be stored")
            }
            val bytes = fileName(name).toByteArray(Charsets.UTF_8).size
            if (bytes > MAX_FILE_NAME_BYTES) {
                throw BM25Exception("collection name is too long. Its encoded file name would be $bytes bytes and the limit is $MAX_FILE_NAME_BYTES")
            }
            return name
        }

        private fun hasUnpairedSurrogate(s: String): Boolean {
            var i = 0
            while (i < s.length) {
                val c = s[i]
                if (Character.isHighSurrogate(c)) {
                    if (i + 1 < s.length && Character.isLowSurrogate(s[i + 1])) i++ else return true
                } else if (Character.isLowSurrogate(c)) {
                    return true
                }
                i++
            }
            return false
        }

        /**
         * Maps a name to its file name. The name is read as UTF-8 bytes. Every byte outside a-z, 0-9,
         * underscore and hyphen becomes %XX with uppercase hex. Capital letters are encoded too, so
         * names that differ only by case get different files on a case-insensitive file system, and
         * no name can contain a path separator or a dot-dot. Swift produces the same file name.
         * The name must not have an unpaired surrogate. validate checks that first.
         */
        fun fileName(name: String): String {
            val sb = StringBuilder()
            for (byte in name.toByteArray(Charsets.UTF_8)) {
                val v = byte.toInt() and 0xFF
                val c = v.toChar()
                if (c in '0'..'9' || c in 'a'..'z' || c == '_' || c == '-') sb.append(c)
                else sb.append('%').append(v.toString(16).uppercase().padStart(2, '0'))
            }
            return sb.append(".bm25.json").toString()
        }
    }

    private fun file(name: String) = File(directory, fileName(name))

    // Loading and saving

    private fun existing(name: String): IndexCollection? {
        cache[fileName(name)]?.let { return it }
        val f = file(name)
        if (!f.exists()) return null
        try {
            val loaded = IndexCollection.decode(f.readText(Charsets.UTF_8))
            cache[fileName(name)] = loaded
            return loaded
        } catch (e: BM25Exception) {
            throw BM25Exception("collection '$name' could not be read: ${e.message}")
        } catch (e: java.io.IOException) {
            throw BM25Exception("collection '$name' could not be read: ${e.message}")
        }
    }

    private fun save(collection: IndexCollection, name: String) {
        val target = file(name)
        val temp = File(directory, target.name + ".tmp")
        try {
            directory.mkdirs()
            FileOutputStream(temp).use { out ->
                out.write(collection.encode(name).toByteArray(Charsets.UTF_8))
                out.flush()
                out.fd.sync()
            }
            // renameTo replaces the target on the same file system. It is atomic on POSIX.
            if (!temp.renameTo(target)) throw java.io.IOException("rename failed")
        } catch (e: java.io.IOException) {
            temp.delete()
            cache.remove(fileName(name)) // the next access reloads what is on disk
            throw BM25Exception("collection '$name' could not be saved: ${e.message}")
        }
    }

    private fun require(name: String): IndexCollection =
        existing(name) ?: throw BM25Exception("collection '$name' does not exist")

    // Operations

    /**
     * Indexes the items and returns how many were stored and which ids were skipped. An item is
     * skipped when its text gives no tokens. If the id was already in the collection, the old
     * entry is removed, because the replacement has nothing to index. When an id appears twice in
     * one call, the last one wins. Each element of items is a map with id, text and optional metadata.
     */
    fun upsertMany(collectionName: String?, rawItems: List<Any?>?): UpsertResult {
        val name = validate(collectionName)
        if (rawItems == null) throw BM25Exception("items is required")

        class Entry(val id: String, val text: String, val metadata: String)
        val latest = LinkedHashMap<String, Entry>()
        rawItems.forEachIndexed { index, raw ->
            val map = raw as? Map<*, *>
            val id = map?.get("id") as? String
            val text = map?.get("text") as? String
            if (id == null || id.isEmpty() || text == null) {
                throw BM25Exception("items[$index] needs a non-empty string id and a string text")
            }
            val metadata = map["metadata"]
            if (metadata != null && metadata !is String) throw BM25Exception("items[$index].metadata must be a string")
            // LinkedHashMap keeps the first-seen position of an id, and the last value wins
            latest[id] = Entry(id, text, metadata as String? ?: "")
        }

        val collection = existing(name) ?: IndexCollection(Tokenizer.VERSION)
        if (collection.tokenizerVersion != Tokenizer.VERSION) {
            throw BM25Exception("collection '$name' was built with tokenizer version ${collection.tokenizerVersion} and the current version is ${Tokenizer.VERSION}. Clear it and import again")
        }
        var count = 0
        val skipped = ArrayList<String>()
        for (entry in latest.values) {
            val tokens = Tokenizer.tokenize(entry.text)
            if (tokens.isEmpty()) {
                collection.remove(entry.id)
                skipped.add(entry.id)
            } else {
                collection.upsert(entry.id, entry.metadata, tokens)
                count++
            }
        }
        collection.recomputeStats()
        cache[fileName(name)] = collection
        save(collection, name)
        return UpsertResult(count, skipped)
    }

    fun search(collectionName: String?, query: String?, topK: Int?, minScore: Double?, k1: Double?, b: Double?): List<SearchHit> {
        val name = validate(collectionName)
        if (query == null) throw BM25Exception("query is required")
        val collection = require(name)
        val terms = Tokenizer.tokenize(query)
        if (terms.isEmpty()) return emptyList()
        val k = if (topK != null && topK > 0) topK else DEFAULT_TOP_K
        return collection.search(terms, k, minScore ?: 0.0, k1 ?: DEFAULT_K1, b ?: DEFAULT_B)
    }

    fun remove(collectionName: String?, ids: List<String>?): Int {
        val name = validate(collectionName)
        if (ids == null) throw BM25Exception("ids is required")
        val collection = require(name)
        var removed = 0
        for (id in ids) if (collection.remove(id)) removed++
        collection.recomputeStats()
        save(collection, name)
        return removed
    }

    /** Deletes the collection. An unknown collection is a no-op. */
    fun clear(collectionName: String?) {
        val name = validate(collectionName)
        cache.remove(fileName(name))
        val f = file(name)
        if (f.exists() && !f.delete()) throw BM25Exception("collection '$name' could not be deleted")
    }

    fun getCollectionInfo(collectionName: String?): Info {
        val name = validate(collectionName)
        val c = existing(name) ?: return Info(false, 0, 0, 0.0, 0, Tokenizer.VERSION, false)
        return Info(true, c.count, c.uniqueTerms, c.avgLength, c.tokenizerVersion, Tokenizer.VERSION,
            c.tokenizerVersion != Tokenizer.VERSION)
    }
}
