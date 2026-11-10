package com.michaeldeguzman.plugins.offlinebm25

/**
 * Character rules that copy the C# char methods used by BM25Engine Tokenizer.
 *
 * C# works on UTF-16 code units. Kotlin Char is a UTF-16 code unit, so I iterate Char and never
 * code points.
 *
 * Rules:
 * - A surrogate unit (0xD800 to 0xDFFF) has category Cs in C#. It is not a letter, digit or
 *   whitespace, so it becomes a boundary. Every character outside the Basic Multilingual Plane
 *   is therefore dropped, as in C#.
 * - isLetterOrDigit matches char.IsLetterOrDigit: general category Lu, Ll, Lt, Lm, Lo or Nd,
 *   read with Character.getType.
 * - isDigit matches char.IsDigit: general category Nd.
 * - I do not call Char.isWhitespace or Character.isWhitespace. Java defines whitespace
 *   differently from .NET. isWhiteSpace is explicit: category Zs, Zl or Zp, plus U+0009 to
 *   U+000D and U+0085.
 * - lowercase matches string.ToLowerInvariant for one code unit. Character.toLowerCase(Char)
 *   is the single-scalar mapping. It maps U+0130 to U+0069, and .NET leaves U+0130 unchanged,
 *   so I special-case U+0130. I do not use String.lowercase(), because it applies the final
 *   sigma rule and multi-character mappings, and C# does not.
 *
 * The general categories come from the Unicode tables of the running Java runtime or, on
 * Android, of the OS. .NET ships its own table version. A character assigned in one version and
 * not the other would differ. The comparison for all 65,536 units is in
 * docs/charclass-comparison.md.
 */
object CharRules {
    private fun type(unit: Char): Int = Character.getType(unit)

    fun isLetterOrDigit(unit: Char): Boolean = when (type(unit)) {
        Character.UPPERCASE_LETTER.toInt(),
        Character.LOWERCASE_LETTER.toInt(),
        Character.TITLECASE_LETTER.toInt(),
        Character.MODIFIER_LETTER.toInt(),
        Character.OTHER_LETTER.toInt(),
        Character.DECIMAL_DIGIT_NUMBER.toInt() -> true
        else -> false
    }

    fun isDigit(unit: Char): Boolean = type(unit) == Character.DECIMAL_DIGIT_NUMBER.toInt()

    fun isWhiteSpace(unit: Char): Boolean {
        if (unit in '\u0009'..'\u000D' || unit == '\u0085') return true
        return when (type(unit)) {
            Character.SPACE_SEPARATOR.toInt(),
            Character.LINE_SEPARATOR.toInt(),
            Character.PARAGRAPH_SEPARATOR.toInt() -> true
            else -> false
        }
    }

    fun lowercase(unit: Char): Char {
        if (unit == '\u0130') return unit
        return Character.toLowerCase(unit)
    }
}

/**
 * Tokenizer v2 from BM25Engine: lowercase, punctuation becomes a boundary, stop words removed,
 * Porter stem. I kept it stateless. Call it identically at ingestion and query time.
 */
object Tokenizer {
    /** The tokenizer version recorded per collection. Matches BM25Engine tokenizer v2. */
    const val VERSION = 2

    /**
     * Tokenizes raw text into stemmed tokens and returns them in order, duplicates kept.
     * Returns an empty list for empty, whitespace-only or all-stop-word input.
     */
    fun tokenize(text: String): List<String> {
        val tokens = ArrayList<String>()
        val current = StringBuilder()

        fun flush() {
            if (current.isEmpty()) return
            val token = current.toString()
            current.setLength(0)
            if (token.length < 2 && token.all { CharRules.isDigit(it) }) return
            if (StopWords.isStopWord(token)) return
            tokens.add(PorterStemmer.stem(token))
        }

        // Lowercase first, then classify. A letter or digit extends the token. Whitespace and
        // every other unit end it.
        for (unit in text) {
            val lowered = CharRules.lowercase(unit)
            if (CharRules.isLetterOrDigit(lowered)) current.append(lowered) else flush()
        }
        flush()
        return tokens
    }
}
