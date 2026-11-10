package com.michaeldeguzman.plugins.offlinebm25

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TokenizerParityTest {
    @Test
    fun everyCaseMatchesCSharp() {
        val fixture = JSONObject(Fixtures.read("tokenizer"))
        val cases = fixture.getJSONArray("cases")
        assertEquals(fixture.getInt("count"), cases.length())
        assertTrue(cases.length() > 0)

        val mismatches = ArrayList<String>()
        for (i in 0 until cases.length()) {
            val item = cases.getJSONObject(i)
            val input = item.getString("input")
            val tokensJson = item.getJSONArray("tokens")
            val expected = (0 until tokensJson.length()).map { tokensJson.getString(it) }
            val actual = Tokenizer.tokenize(input)
            if (actual != expected) {
                mismatches.add("case=${item.getString("name")} input=${JSONObject.quote(input)} csharp=$expected kotlin=$actual")
            }
        }
        println("PARITY|tokenizer|${cases.length()} cases|${mismatches.size} mismatches")
        assertTrue("Tokenizer mismatches:\n" + mismatches.joinToString("\n"), mismatches.isEmpty())
    }

    /** Kotlin String equality is ordinal. A stop word match must not depend on case or accents. */
    @Test
    fun stopWordMatchIsOrdinal() {
        assertTrue(StopWords.isStopWord("the"))
        assertFalse(StopWords.isStopWord("The"))
        assertFalse(StopWords.isStopWord("thé"))
        assertEquals(174, StopWords.english.size)
    }
}
