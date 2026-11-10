package com.michaeldeguzman.plugins.offlinebm25

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the CharRules decisions for non-ASCII code units. The expected values are the .NET results
 * for char.IsLetterOrDigit, char.IsWhiteSpace, char.IsDigit and ToLowerInvariant.
 */
class CharRuleTest {
    private fun units(vararg v: Int) = v.map { it.toChar() }

    @Test
    fun whiteSpace() {
        for (u in units(0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0x85, 0xA0, 0x2003, 0x2028, 0x2029, 0x3000)) {
            assertTrue(Integer.toHexString(u.code), CharRules.isWhiteSpace(u))
        }
        // Java Character.isWhitespace is true for U+001C to U+001F. .NET is not, so the rule is explicit.
        for (u in units(0x1C, 0x1D, 0x1E, 0x1F, 0x200B, 0xFEFF, 0x180E, 0x41, 0x5F)) {
            assertFalse(Integer.toHexString(u.code), CharRules.isWhiteSpace(u))
        }
    }

    @Test
    fun letterOrDigit() {
        for (u in units(0x41, 0x7A, 0x30, 0xE9, 0xDF, 0x3A3, 0x4E2D, 0x663, 0xFF11, 0x2B0)) {
            assertTrue(Integer.toHexString(u.code), CharRules.isLetterOrDigit(u))
        }
        // Combining marks, No, Nl, Cs, Cf, So and punctuation are not letters or digits.
        for (u in units(0x301, 0xB2, 0xBD, 0x2167, 0x2460, 0xD83D, 0xDD27, 0x200B, 0x2764, 0x2019, 0x2D, 0x5F)) {
            assertFalse(Integer.toHexString(u.code), CharRules.isLetterOrDigit(u))
        }
    }

    @Test
    fun digit() {
        for (u in units(0x30, 0x39, 0x663, 0xFF11)) assertTrue(Integer.toHexString(u.code), CharRules.isDigit(u))
        for (u in units(0xB2, 0x2167, 0x41)) assertFalse(Integer.toHexString(u.code), CharRules.isDigit(u))
    }

    @Test
    fun lowercase() {
        assertEquals(0x61.toChar(), CharRules.lowercase(0x41.toChar()))
        assertEquals(0xE9.toChar(), CharRules.lowercase(0xC9.toChar()))
        assertEquals(0x3C3.toChar(), CharRules.lowercase(0x3A3.toChar())) // Sigma goes to sigma, never final sigma
        assertEquals(0xDF.toChar(), CharRules.lowercase(0x1E9E.toChar())) // capital sharp s goes to sharp s
        assertEquals(0x6B.toChar(), CharRules.lowercase(0x212A.toChar())) // Kelvin sign goes to k
        assertEquals(0x130.toChar(), CharRules.lowercase(0x130.toChar())) // dotted capital I stays, as in .NET invariant
        assertEquals(0x131.toChar(), CharRules.lowercase(0x131.toChar()))
        assertEquals(0xD83D.toChar(), CharRules.lowercase(0xD83D.toChar())) // surrogates pass through
    }

    @Test
    fun javaMapsDottedCapitalIButDotNetDoesNot() {
        // Documents why CharRules.lowercase special-cases U+0130.
        assertEquals('i', Character.toLowerCase(0x130.toChar()))
        assertEquals(0x130.toChar(), CharRules.lowercase(0x130.toChar()))
    }

    @Test
    fun supplementaryCharactersAreDropped() {
        // Mathematical bold letters are letters in Unicode but surrogate pairs in UTF-16.
        assertEquals(listOf("pump"), Tokenizer.tokenize("𝐩𝐮𝐦𝐩 pump"))
    }
}
