package com.michaeldeguzman.plugins.offlinebm25

import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import kotlin.math.abs

class IndexTest {
    private lateinit var directory: File
    private lateinit var store: CollectionStore

    @Before
    fun setUp() {
        directory = Fixtures.tempDir()
        store = CollectionStore(directory)
    }

    @After
    fun tearDown() {
        directory.deleteRecursively()
    }

    private fun item(id: String, text: String, metadata: String? = null): Map<String, Any?> =
        if (metadata == null) mapOf("id" to id, "text" to text) else mapOf("id" to id, "text" to text, "metadata" to metadata)

    private fun search(query: String, topK: Int? = 100, name: String = "c", s: CollectionStore = store) =
        s.search(name, query, topK, null, null, null)

    private fun message(work: () -> Any?): String? =
        try { work(); null } catch (e: BM25Exception) { e.message }

    private fun seedDocuments(): List<JSONObject> {
        val documents = JSONObject(Fixtures.read("scores")).getJSONArray("documents")
        return List(documents.length()) { documents.getJSONObject(it) }
    }

    // Index parity

    @Test
    fun indexMatchesCSharpForAllQueries() {
        val fixture = JSONObject(Fixtures.read("scores"))
        val queries = fixture.getJSONArray("queries")
        val result = store.upsertMany("seed", seedDocuments().map { item(it.getString("id"), it.getString("text")) })
        assertEquals(50, result.count)
        assertEquals(emptyList<String>(), result.skipped)

        val problems = ArrayList<String>()
        for (q in 0 until queries.length()) {
            val query = queries.getJSONObject(q)
            val text = query.getString("query")
            val expected = query.getJSONArray("results")
            val hits = search(text, 1000, "seed")
            if (hits.size != expected.length()) {
                problems.add("query=$text count csharp=${expected.length()} kotlin=${hits.size}")
                continue
            }
            for (rank in hits.indices) {
                val want = expected.getJSONObject(rank).getDouble("score")
                if (abs(want - hits[rank].score) > 1e-6) problems.add("query=$text rank=$rank score csharp=$want kotlin=${hits[rank].score}")
            }
            // Same ids per tie group. Inside a group the plugin order is id ascending.
            var start = 0
            while (start < hits.size) {
                var end = start + 1
                val s0 = expected.getJSONObject(start).getDouble("score")
                while (end < hits.size && abs(expected.getJSONObject(end).getDouble("score") - s0) < 1e-9) end++
                val want = (start until end).map { expected.getJSONObject(it).getString("id") }.toSet()
                val got = (start until end).map { hits[it].id }
                if (want != got.toSet()) problems.add("query=$text ranks $start until $end csharp=${want.sorted()} kotlin=$got")
                if (got != got.sorted()) problems.add("query=$text ranks $start until $end tie order not id ascending: $got")
                start = end
            }
        }
        println("INDEX|${queries.length()} queries|${problems.size} problems")
        assertTrue(problems.joinToString("\n"), problems.isEmpty())
    }

    // Persistence

    @Test
    fun reloadInFreshInstanceGivesSameResults() {
        val queries = JSONObject(Fixtures.read("scores")).getJSONArray("queries").let { a -> List(a.length()) { a.getJSONObject(it).getString("query") } }
        store.upsertMany("seed", seedDocuments().map { item(it.getString("id"), it.getString("text"), "meta " + it.getString("id")) })
        val before = queries.map { search(it, 1000, "seed") }
        val infoBefore = store.getCollectionInfo("seed")

        val fresh = CollectionStore(directory)
        val after = queries.map { search(it, 1000, "seed", fresh) }
        assertEquals(before, after) // SearchHit is a data class: id, score, metadata and matchedTerms
        val infoAfter = fresh.getCollectionInfo("seed")
        assertEquals(50, infoAfter.count)
        assertEquals(infoBefore, infoAfter)
    }

    @Test
    fun fileHoldsTermsAsListAndNoOriginalText() {
        store.upsertMany("demo", listOf(item("a", "Pump seal replacement", "Pump seal")))
        val text = File(directory, "demo.bm25.json").readText(Charsets.UTF_8)
        val root = JSONObject(text)
        val terms = root.getJSONArray("terms")
        assertEquals(listOf("pump", "replac", "seal"), List(terms.length()) { terms.getString(it) })
        assertEquals(2, root.getInt("tokenizerVersion"))
        assertFalse("original text must not be stored", text.contains("replacement"))
        println("PERSISTED|$text")
    }

    @Test
    fun nonAsciiAndLoneSurrogatesSurviveSaveAndReload() {
        val lone = "x\uD800y"
        store.upsertMany("c", listOf(item("café", "pump", "méta $lone"), item("lone$lone", "seal")))
        val fresh = CollectionStore(directory)
        assertEquals(listOf("café"), search("pump", 10, "c", fresh).map { it.id })
        assertEquals("méta $lone", search("pump", 10, "c", fresh).first().metadata)
        assertEquals(listOf("lone$lone"), search("seal", 10, "c", fresh).map { it.id })
        assertTrue("the file is ASCII", File(directory, "c.bm25.json").readBytes().all { it >= 0 })
    }

    @Test
    fun termsDifferingOnlyByCanonicalEquivalenceStaySeparateAfterReload() {
        // U+03AC and U+1F71 are canonically equivalent. Kotlin keys by code units, so they differ.
        val a = "ά"
        val b = "ά"
        store.upsertMany("c", listOf(item("one", a), item("two", b)))
        store.upsertMany("ids", listOf(item("é", "pump"), item("é", "pump")))
        val fresh = CollectionStore(directory)
        assertEquals(2, fresh.getCollectionInfo("c").uniqueTerms)
        assertEquals(listOf("one"), search(a, 10, "c", fresh).map { it.id })
        assertEquals(listOf("two"), search(b, 10, "c", fresh).map { it.id })
        assertEquals(2, fresh.getCollectionInfo("ids").count)
        assertEquals(1, fresh.remove("ids", listOf("é")))
        assertEquals(1, fresh.getCollectionInfo("ids").count)
    }

    @Test
    fun staleTokenizerVersionIsFlaggedAndUpsertRejected() {
        store.upsertMany("old", listOf(item("a", "pump")))
        val f = File(directory, "old.bm25.json")
        f.writeText(f.readText().replace("\"tokenizerVersion\":2", "\"tokenizerVersion\":1"))
        val fresh = CollectionStore(directory)
        val info = fresh.getCollectionInfo("old")
        assertTrue(info.needsReindex)
        assertEquals(1, info.tokenizerVersion)
        assertEquals(2, info.currentTokenizerVersion)
        assertEquals(
            "collection 'old' was built with tokenizer version 1 and the current version is 2. Clear it and import again",
            message { fresh.upsertMany("old", listOf(item("b", "seal"))) },
        )
        fresh.clear("old")
        assertEquals(1, fresh.upsertMany("old", listOf(item("b", "seal"))).count)
    }

    @Test
    fun corruptFileGivesReadableError() {
        directory.mkdirs()
        File(directory, "bad.bm25.json").writeText("not json")
        val msg = message { store.getCollectionInfo("bad") }
        assertTrue(msg ?: "null", msg?.startsWith("collection 'bad' could not be read:") == true)
    }

    // Write operations

    @Test
    fun upsertReplaceKeepsCountAndFollowsNewText() {
        store.upsertMany("c", listOf(item("a", "pump seal"), item("b", "generator")))
        assertEquals(listOf("a"), search("seal").map { it.id })
        store.upsertMany("c", listOf(item("a", "fire extinguisher", "new")))
        val info = store.getCollectionInfo("c")
        assertEquals(2, info.count)
        assertEquals(0, search("seal").size)
        assertEquals(listOf("new"), search("extinguisher").map { it.metadata })
        assertEquals(3, info.uniqueTerms) // fire, extinguish, gener
    }

    @Test
    fun removeAndClear() {
        store.upsertMany("c", listOf(item("a", "pump"), item("b", "pump seal"), item("c", "seal")))
        assertEquals(2, store.remove("c", listOf("a", "missing", "b")))
        assertEquals(1, store.getCollectionInfo("c").count)
        assertEquals(0, search("pump").size)
        assertEquals(1, store.getCollectionInfo("c").uniqueTerms)
        store.clear("c")
        assertFalse(store.getCollectionInfo("c").exists)
        assertFalse(File(directory, "c.bm25.json").exists())
        store.clear("never-existed") // no-op
    }

    @Test
    fun skippedIdsAndStats() {
        val r = store.upsertMany("c", listOf(item("empty", ""), item("stop", "the a an of and"), item("ok", "pump seal"), item("punct", "!!! ---")))
        assertEquals(1, r.count)
        assertEquals(listOf("empty", "stop", "punct"), r.skipped)
        val info = store.getCollectionInfo("c")
        assertEquals(1, info.count)
        assertEquals(2.0, info.avgLength, 0.0)
        val again = store.upsertMany("c", listOf(item("ok", "the")))
        assertEquals(listOf("ok"), again.skipped)
        assertEquals(0, store.getCollectionInfo("c").count)
    }

    @Test
    fun duplicateIdsInOneCallLastWins() {
        val r = store.upsertMany("c", listOf(item("a", "pump", "first"), item("a", "seal", "last")))
        assertEquals(1, r.count)
        assertEquals(0, search("pump").size)
        assertEquals(listOf("last"), search("seal").map { it.metadata })
    }

    // Search behaviour

    @Test
    fun allStopWordAndEmptyQueriesResolveWithNoResults() {
        store.upsertMany("c", listOf(item("a", "pump seal")))
        assertEquals(0, search("the of and").size)
        assertEquals(0, search("").size)
        assertEquals(0, search("   ").size)
        assertEquals(0, search("nothingmatches").size)
    }

    @Test
    fun defaultsAndMatchedTerms() {
        store.upsertMany("c", (1..8).map { item("id%02d".format(it), "pump seal number ${it * 11} " + "valve ".repeat(it)) })
        fun s(q: String, topK: Int?, minScore: Double? = null, k1: Double? = null, b: Double? = null) =
            store.search("c", q, topK, minScore, k1, b)
        assertEquals(5, s("pump", null).size)
        assertEquals(5, s("pump", 0).size)
        assertEquals(5, s("pump", -3).size)
        assertEquals(2, s("pump", 2).size)
        val implicit = s("pump seal", 8)
        val explicit = s("pump seal", 8, 0.0, 1.2, 0.75)
        assertEquals(implicit.map { it.score }, explicit.map { it.score })
        assertNotEquals(implicit.map { it.score }, s("pump seal", 8, null, 2.0, 0.2).map { it.score })
        assertEquals(List(8) { 2 }, implicit.map { it.matchedTerms })
        assertEquals(1, s("pump pump", 1).first().matchedTerms)
        val partial = s("pump 22", 8)
        assertEquals("id02", partial.first().id)
        assertEquals(2, partial.first().matchedTerms)
        assertEquals(0, s("pump seal", 8, implicit[0].score + 1).size)
    }

    @Test
    fun tiesOrderByIdAscending() {
        store.upsertMany("c", listOf(item("b", "pump"), item("a", "pump"), item("B", "pump")))
        assertEquals(listOf("B", "a", "b"), search("pump").map { it.id })
    }

    // Bad input

    @Test
    fun badInput() {
        val bad = "collection is required and must not be empty"
        assertEquals(bad, message { store.getCollectionInfo(null) })
        assertEquals(bad, message { store.getCollectionInfo("") })
        assertEquals(bad, message { store.getCollectionInfo("  \t") })
        assertEquals(bad, message { store.upsertMany("", emptyList()) })
        assertEquals(bad, message { store.clear(" ") })

        // Only the encoded file name length or an unpaired surrogate can reject a non-blank name.
        val longest = "a".repeat(190) // 190 bytes plus ".bm25.json" is 200
        store.upsertMany(longest, listOf(item("a", "pump")))
        assertEquals(
            "collection name is too long. Its encoded file name would be 201 bytes and the limit is 200",
            message { store.upsertMany("a".repeat(191), listOf(item("a", "pump"))) },
        )
        // A non-ASCII letter costs more bytes: "é" is %C3%A9, six bytes.
        store.upsertMany("é".repeat(31), listOf(item("a", "pump"))) // 186 plus 10 is 196
        assertEquals(
            "collection name is too long. Its encoded file name would be 202 bytes and the limit is 200",
            message { store.upsertMany("é".repeat(32), listOf(item("a", "pump"))) }, // 192 plus 10 is 202
        )
        assertFalse(File(directory, CollectionStore.fileName("a".repeat(191))).exists())
        // An unpaired surrogate cannot be written as UTF-8. Kotlin rejects it. A pair is fine.
        for (name in listOf("a\uD800b", "\uDC00", "a\uD800")) {
            assertEquals("collection name contains an unpaired surrogate and cannot be stored", message { store.upsertMany(name, listOf(item("a", "pump"))) })
        }
        assertEquals(1, store.upsertMany("\uD83D\uDE00", listOf(item("a", "pump"))).count)

        assertEquals("collection 'unknown' does not exist", message { search("pump", name = "unknown") })
        assertEquals("collection 'unknown' does not exist", message { store.remove("unknown", listOf("a")) })
        val info = store.getCollectionInfo("unknown")
        assertFalse(info.exists)
        assertEquals(listOf(0, 0, 0), listOf(info.count, info.uniqueTerms, info.tokenizerVersion))
        assertEquals(0.0, info.avgLength, 0.0)
        assertEquals(2, info.currentTokenizerVersion)
        assertFalse(info.needsReindex)

        store.upsertMany("c", listOf(item("a", "pump")))
        assertEquals("query is required", message { store.search("c", null, null, null, null, null) })
        assertEquals("ids is required", message { store.remove("c", null) })
        assertEquals("items is required", message { store.upsertMany("c", null) })
        assertEquals("items[0] needs a non-empty string id and a string text", message { store.upsertMany("c", listOf(mapOf("text" to "no id"))) })
        assertEquals("items[1] needs a non-empty string id and a string text", message { store.upsertMany("c", listOf(item("ok", "pump"), mapOf("id" to "", "text" to "x"))) })
        assertEquals("items[0].metadata must be a string", message { store.upsertMany("c", listOf(mapOf("id" to "a", "text" to "x", "metadata" to 5))) })
        assertEquals("a rejected call changes nothing", 1, store.getCollectionInfo("c").count)
    }

    @Test
    fun fileNamesEncodeEveryByteOutsideLowercaseDigitsUnderscoreHyphen() {
        assertEquals("demo_1-b.bm25.json", CollectionStore.fileName("demo_1-b"))
        assertEquals("%44emo.bm25.json", CollectionStore.fileName("Demo"))
        assertEquals("a%2Eb.bm25.json", CollectionStore.fileName("a.b"))
        assertEquals("%2E%2E%2Fx.bm25.json", CollectionStore.fileName("../x"))
        assertEquals("a%20b.bm25.json", CollectionStore.fileName("a b"))
        assertEquals("caf%C3%A9.bm25.json", CollectionStore.fileName("café"))
        assertEquals("%E4%B8%AD.bm25.json", CollectionStore.fileName("中"))
        assertEquals("%F0%9F%98%80.bm25.json", CollectionStore.fileName("\uD83D\uDE00")) // a surrogate pair is one 4-byte sequence
        assertEquals("a%00b.bm25.json", CollectionStore.fileName("a\u0000b"))
    }

    @Test
    fun anyNonBlankNameWorksAndStaysInsideTheDirectory() {
        val names = listOf("../x", "a/b", "a\\b", ".hidden", "..", ".", "a b", "café", "中文", "\uD83D\uDE00", "a\u0000b", "Demo")
        for (name in names) assertEquals(name, 1, store.upsertMany(name, listOf(item("a", "pump ${name.length}"))).count)
        assertEquals(names.size, directory.list()!!.size)
        assertFalse(File(directory.parentFile, "x.bm25.json").exists())
        val fresh = CollectionStore(directory)
        for (name in names) {
            assertEquals(name, 1, fresh.getCollectionInfo(name).count)
            assertEquals(name, 1, fresh.search(name, "pump", 5, null, null, null).size)
        }
    }

    @Test
    fun namesAreCaseSensitiveAndCanonicalEquivalentNamesAreDifferent() {
        store.upsertMany("Demo", listOf(item("a", "pump")))
        store.upsertMany("demo", listOf(item("b", "seal"), item("c", "valve")))
        // "\u00E9" and "e\u0301" are canonically equivalent. They are different names.
        store.upsertMany("\u00E9", listOf(item("one", "pump")))
        store.upsertMany("e\u0301", listOf(item("two", "pump"), item("three", "seal")))
        val fresh = CollectionStore(directory)
        assertEquals(1, fresh.getCollectionInfo("Demo").count)
        assertEquals(2, fresh.getCollectionInfo("demo").count)
        assertEquals(1, fresh.getCollectionInfo("\u00E9").count)
        assertEquals(2, fresh.getCollectionInfo("e\u0301").count)
        fresh.clear("Demo")
        assertFalse(fresh.getCollectionInfo("Demo").exists)
        assertTrue(fresh.getCollectionInfo("demo").exists)
        fresh.clear("\u00E9")
        assertTrue(fresh.getCollectionInfo("e\u0301").exists)
    }

    @Test
    fun tokenizerVersionIsTwo() {
        assertEquals(2, Tokenizer.VERSION)
        assertEquals(listOf("err", "bm25", "003"), Tokenizer.tokenize("ERR-BM25-003"))
    }
}
