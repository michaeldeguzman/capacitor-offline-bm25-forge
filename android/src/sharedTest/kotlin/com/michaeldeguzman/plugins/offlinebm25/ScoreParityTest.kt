package com.michaeldeguzman.plugins.offlinebm25

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

class ScoreParityTest {
    private val tolerance = 1e-6
    private val tieEpsilon = 1e-9

    @Test
    fun everyQueryMatchesCSharp() {
        val fixture = JSONObject(Fixtures.read("scores"))
        val k1 = fixture.getDouble("k1")
        val b = fixture.getDouble("b")
        val documents = fixture.getJSONArray("documents")
        val queries = fixture.getJSONArray("queries")
        assertEquals(fixture.getInt("totalDocuments"), documents.length())
        assertEquals(fixture.getInt("queryCount"), queries.length())

        // Index the documents with the Kotlin tokenizer, as the plugin will.
        val ids = ArrayList<String>()
        val termFrequencies = ArrayList<Map<String, Int>>()
        val lengths = ArrayList<Int>()
        val documentFrequency = HashMap<String, Int>()
        for (i in 0 until documents.length()) {
            val document = documents.getJSONObject(i)
            val id = document.getString("id")
            val tokens = Tokenizer.tokenize(document.getString("text"))
            assertEquals("token count for $id", document.getInt("tokenCount"), tokens.size)
            val tf = HashMap<String, Int>()
            for (token in tokens) tf[token] = (tf[token] ?: 0) + 1
            for (term in tf.keys) documentFrequency[term] = (documentFrequency[term] ?: 0) + 1
            ids.add(id)
            termFrequencies.add(tf)
            lengths.add(tokens.size)
        }
        val avgLength = lengths.sum().toDouble() / documents.length()
        assertEquals(fixture.getDouble("avgLength"), avgLength, tolerance)

        val problems = ArrayList<String>()
        for (q in 0 until queries.length()) {
            val query = queries.getJSONObject(q)
            val text = query.getString("query")
            val termsJson = query.getJSONArray("queryTerms")
            val expectedTerms = (0 until termsJson.length()).map { termsJson.getString(it) }
            val expected = query.getJSONArray("results")

            val queryTerms = Tokenizer.tokenize(text)
            if (queryTerms != expectedTerms) {
                problems.add("query=$text terms csharp=$expectedTerms kotlin=$queryTerms")
                continue
            }

            val postings = ArrayList<PostingCandidate>()
            for (d in ids.indices) {
                for (term in queryTerms.distinct()) {
                    val f = termFrequencies[d][term] ?: continue
                    postings.add(PostingCandidate((d + 1).toLong(), term, f, documentFrequency.getValue(term), lengths[d]))
                }
            }
            val actual = BM25Scorer.score(queryTerms, postings, ids.size, avgLength, k1, b) { ids[(it - 1).toInt()] }

            if (actual.size != expected.length()) {
                problems.add("query=$text result count csharp=${expected.length()} kotlin=${actual.size}")
                continue
            }

            // Scores: same value at every rank position, within the tolerance.
            for (rank in actual.indices) {
                val expectedScore = expected.getJSONObject(rank).getDouble("score")
                if (abs(expectedScore - actual[rank].score) > tolerance) {
                    problems.add("query=$text rank=$rank score csharp=$expectedScore kotlin=${actual[rank].score}")
                }
            }

            // Ranking: same ids at every rank. Ids with equal scores form a tie group. C# gives no
            // order inside a tie group, so I compare each group as a set.
            var start = 0
            while (start < actual.size) {
                var end = start + 1
                val startScore = expected.getJSONObject(start).getDouble("score")
                while (end < actual.size && abs(expected.getJSONObject(end).getDouble("score") - startScore) < tieEpsilon) end++
                val expectedIds = (start until end).map { expected.getJSONObject(it).getString("id") }.toSet()
                val actualIds = (start until end).map { ids[(actual[it].chunkId - 1).toInt()] }.toSet()
                if (expectedIds != actualIds) {
                    problems.add("query=$text ranks $start until $end csharp=${expectedIds.sorted()} kotlin=${actualIds.sorted()}")
                }
                start = end
            }
        }
        println("PARITY|scores|${queries.length()} queries|${problems.size} problems")
        assertTrue("Score mismatches:\n" + problems.joinToString("\n"), problems.isEmpty())
    }

    /** The hand-calculated example from BM25ScorerTests.cs. */
    @Test
    fun handCalculatedExample() {
        val postings = listOf(
            PostingCandidate(1, "cach", 2, 2, 8),
            PostingCandidate(1, "invalid", 1, 2, 8),
            PostingCandidate(2, "cach", 1, 2, 12),
            PostingCandidate(3, "invalid", 3, 2, 10),
        )
        val results = BM25Scorer.score(listOf("cach", "invalid"), postings, 4, 10.0, 1.2, 0.75) { it.toString() }
        assertEquals(listOf(1L, 3L, 2L), results.map { it.chunkId })
        assertEquals(1.7647960803319571, results[0].score, tolerance)
        assertEquals(1.089231283737057, results[1].score, tolerance)
        assertEquals(0.64072428455121, results[2].score, tolerance)
    }

    /** Ties are ordered by id ascending, compared by code units. "B" sorts before "a" and "a" before "b". */
    @Test
    fun tiesOrderByIdAscendingOrdinal() {
        val ids = mapOf(1L to "b", 2L to "a", 3L to "B", 4L to "c", 5L to "é", 6L to "z")
        val postings = (1L..5L).map { PostingCandidate(it, "cach", 1, 5, 10) } +
            PostingCandidate(6, "cach", 4, 5, 10) // better score goes first whatever its id
        val results = BM25Scorer.score(listOf("cach"), postings, 10, 10.0, 1.2, 0.75) { ids.getValue(it) }
        assertEquals(listOf("z", "B", "a", "b", "c", "é"), results.map { ids.getValue(it.chunkId) })
    }

    @Test
    fun zeroLengthChunkIsNotNaN() {
        val postings = listOf(PostingCandidate(1, "cach", 1, 1, 0))
        val results = BM25Scorer.score(listOf("cach"), postings, 5, 10.0, 1.2, 0.75) { it.toString() }
        assertEquals(1, results.size)
        assertFalse(results[0].score.isNaN())
    }
}
