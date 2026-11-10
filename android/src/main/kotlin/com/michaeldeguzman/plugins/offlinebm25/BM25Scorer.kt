package com.michaeldeguzman.plugins.offlinebm25

import kotlin.math.ln

/**
 * One (term, chunk) posting. Mirrors BM25Engine PostingCandidate.
 * documentFrequency is a property of the term. It is the same on every posting for that term.
 */
data class PostingCandidate(
    val chunkId: Long,
    val term: String,
    val termFrequencyInChunk: Int,
    val documentFrequency: Int,
    val chunkTokenCount: Int,
)

/** A chunk's BM25 score against a query. Mirrors BM25Engine BM25ScoreResult. */
data class BM25ScoreResult(val chunkId: Long, val score: Double)

/**
 * Okapi BM25 with the always-positive IDF variant, as in BM25Engine BM25Scorer.
 * k1 and b are parameters. The scorer holds no defaults.
 */
object BM25Scorer {
    /**
     * Scores every chunk that appears in postings and returns the results sorted by score,
     * highest first. A chunk with several postings sums one term score per posting.
     *
     * C# does not define the order of equal scores (List.Sort is unstable). The plugin orders
     * them by id ascending, compared by UTF-16 code units. tieBreakId maps a chunk id to the
     * caller's string id. It is required, so no caller can fall back to another order.
     * Kotlin String.compareTo compares UTF-16 code units, which is the ordinal order.
     */
    fun score(
        queryTerms: List<String>,
        postings: List<PostingCandidate>,
        totalChunks: Int,
        avgChunkLength: Double,
        k1: Double,
        b: Double,
        tieBreakId: (Long) -> String,
    ): List<BM25ScoreResult> {
        // Kotlin String equals and hashCode use UTF-16 code units, so terms are keyed ordinally.
        val queryTermSet = queryTerms.toHashSet()

        // Read the document frequency once per term. The last posting for a term wins, as in C#.
        val documentFrequencyByTerm = HashMap<String, Int>()
        for (posting in postings) {
            if (posting.term !in queryTermSet) continue
            documentFrequencyByTerm[posting.term] = posting.documentFrequency
        }

        val idfByTerm = HashMap<String, Double>()
        for (term in queryTermSet) {
            val n = (documentFrequencyByTerm[term] ?: 0).toDouble()
            idfByTerm[term] = ln((totalChunks - n + 0.5) / (n + 0.5) + 1)
        }

        // Group postings by chunk. LinkedHashMap keeps the first-seen order of chunk ids.
        val postingsByChunk = LinkedHashMap<Long, MutableList<PostingCandidate>>()
        for (posting in postings) {
            if (posting.term !in queryTermSet) continue
            postingsByChunk.getOrPut(posting.chunkId) { ArrayList() }.add(posting)
        }

        val results = ArrayList<BM25ScoreResult>(postingsByChunk.size)
        for ((chunkId, chunkPostings) in postingsByChunk) {
            var score = 0.0
            for (posting in chunkPostings) {
                val idf = idfByTerm.getValue(posting.term)
                val f = posting.termFrequencyInChunk.toDouble()
                val lengthNorm = 1 - b + b * (posting.chunkTokenCount / avgChunkLength)
                score += idf * (f * (k1 + 1)) / (f + k1 * lengthNorm)
            }
            results.add(BM25ScoreResult(chunkId, score))
        }

        // Score descending, then id ascending by UTF-16 code units. The order is total as long
        // as ids are unique, so the result does not depend on whether the sort is stable.
        val keyed = results.map { it to tieBreakId(it.chunkId) }
        return keyed
            .sortedWith { x, y ->
                if (x.first.score != y.first.score) y.first.score.compareTo(x.first.score)
                else x.second.compareTo(y.second)
            }
            .map { it.first }
    }
}
