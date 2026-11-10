package com.michaeldeguzman.plugins.offlinebm25

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class StemmerParityTest {
    @Test
    fun everyStemMatchesCSharp() {
        val fixture = JSONObject(Fixtures.read("stemmer"))
        val pairs = fixture.getJSONArray("pairs")
        assertEquals(fixture.getInt("count"), pairs.length())
        assertTrue(pairs.length() > 0)

        val mismatches = ArrayList<String>()
        for (i in 0 until pairs.length()) {
            val pair = pairs.getJSONObject(i)
            val word = pair.getString("word")
            val expected = pair.getString("stem")
            val actual = PorterStemmer.stem(word)
            if (actual != expected) mismatches.add("word=$word csharp=$expected kotlin=$actual")
        }
        println("PARITY|stemmer|${pairs.length()} pairs|${mismatches.size} mismatches")
        assertTrue("Stemmer mismatches:\n" + mismatches.joinToString("\n"), mismatches.isEmpty())
    }
}
