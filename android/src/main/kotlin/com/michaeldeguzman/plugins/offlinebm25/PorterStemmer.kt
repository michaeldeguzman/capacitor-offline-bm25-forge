package com.michaeldeguzman.plugins.offlinebm25

/**
 * Porter stemming algorithm (M. F. Porter, 1980), ported line by line from BM25Engine
 * PorterStemmer.cs. Input is a lowercase token. The state names (b, k, j) and the step
 * numbering follow the C# file so the two can be compared side by side.
 */
object PorterStemmer {
    /** Stems one token and returns the stem. Tokens of one or two code units come back unchanged. */
    fun stem(word: String): String {
        if (word.length <= 2) return word
        return Algorithm(word).run()
    }

    private class Algorithm(word: String) {
        // C# allocates word.Length + 10 so setTo can write past the end.
        private val b = CharArray(word.length + 10).also { word.toCharArray(it) }
        private val k0 = 0
        private var k = word.length - 1
        private var j = 0

        fun run(): String {
            if (k > k0 + 1) {
                step1()
                step2()
                step3()
                step4()
                step5()
                step6()
            }
            return String(b, 0, k + 1)
        }

        private fun cons(i: Int): Boolean = when (b[i]) {
            'a', 'e', 'i', 'o', 'u' -> false
            'y' -> if (i == k0) true else !cons(i - 1)
            else -> true
        }

        private fun m(): Int {
            var n = 0
            var i = k0
            while (true) {
                if (i > j) return n
                if (!cons(i)) break
                i++
            }
            i++
            while (true) {
                while (true) {
                    if (i > j) return n
                    if (cons(i)) break
                    i++
                }
                i++
                n++
                while (true) {
                    if (i > j) return n
                    if (!cons(i)) break
                    i++
                }
                i++
            }
        }

        private fun vowelInStem(): Boolean {
            for (i in k0..j) if (!cons(i)) return true
            return false
        }

        private fun doubleC(jj: Int): Boolean {
            if (jj < k0 + 1) return false
            if (b[jj] != b[jj - 1]) return false
            return cons(jj)
        }

        private fun cvc(i: Int): Boolean {
            if (i < k0 + 2 || !cons(i) || cons(i - 1) || !cons(i - 2)) return false
            val ch = b[i]
            return !(ch == 'w' || ch == 'x' || ch == 'y')
        }

        private fun ends(s: String): Boolean {
            val l = s.length
            val o = k - l + 1
            if (o < k0) return false
            for (i in 0 until l) if (b[o + i] != s[i]) return false
            j = k - l
            return true
        }

        private fun setTo(s: String) {
            val l = s.length
            val o = j + 1
            for (i in 0 until l) b[o + i] = s[i]
            k = j + l
        }

        private fun r(s: String) {
            if (m() > 0) setTo(s)
        }

        private fun step1() {
            if (b[k] == 's') {
                if (ends("sses")) k -= 2
                else if (ends("ies")) setTo("i")
                else if (b[k - 1] != 's') k--
            }
            if (ends("eed")) {
                if (m() > 0) k--
            } else if ((ends("ed") || ends("ing")) && vowelInStem()) {
                k = j
                if (ends("at")) setTo("ate")
                else if (ends("bl")) setTo("ble")
                else if (ends("iz")) setTo("ize")
                else if (doubleC(k)) {
                    k--
                    val ch = b[k]
                    if (ch == 'l' || ch == 's' || ch == 'z') k++
                } else if (m() == 1 && cvc(k)) setTo("e")
            }
        }

        private fun step2() {
            if (ends("y") && vowelInStem()) b[k] = 'i'
        }

        private fun step3() {
            if (k == k0) return
            when (b[k - 1]) {
                'a' -> {
                    if (ends("ational")) { r("ate"); return }
                    if (ends("tional")) { r("tion"); return }
                }
                'c' -> {
                    if (ends("enci")) { r("ence"); return }
                    if (ends("anci")) { r("ance"); return }
                }
                'e' -> {
                    if (ends("izer")) { r("ize"); return }
                }
                'l' -> {
                    if (ends("bli")) { r("ble"); return }
                    if (ends("alli")) { r("al"); return }
                    if (ends("entli")) { r("ent"); return }
                    if (ends("eli")) { r("e"); return }
                    if (ends("ousli")) { r("ous"); return }
                }
                'o' -> {
                    if (ends("ization")) { r("ize"); return }
                    if (ends("ation")) { r("ate"); return }
                    if (ends("ator")) { r("ate"); return }
                }
                's' -> {
                    if (ends("alism")) { r("al"); return }
                    if (ends("iveness")) { r("ive"); return }
                    if (ends("fulness")) { r("ful"); return }
                    if (ends("ousness")) { r("ous"); return }
                }
                't' -> {
                    if (ends("aliti")) { r("al"); return }
                    if (ends("iviti")) { r("ive"); return }
                    if (ends("biliti")) { r("ble"); return }
                }
                'g' -> {
                    if (ends("logi")) { r("log"); return }
                }
            }
        }

        private fun step4() {
            when (b[k]) {
                'e' -> {
                    if (ends("icate")) { r("ic"); return }
                    if (ends("ative")) { r(""); return }
                    if (ends("alize")) { r("al"); return }
                }
                'i' -> {
                    if (ends("iciti")) { r("ic"); return }
                }
                'l' -> {
                    if (ends("ical")) { r("ic"); return }
                    if (ends("ful")) { r(""); return }
                }
                's' -> {
                    if (ends("ness")) { r(""); return }
                }
            }
        }

        /** In C# the switch breaks to a final "if (M() > 1) _k = _j". This returns true for that case. */
        private fun step5Matches(): Boolean {
            if (k == k0) return false
            return when (b[k - 1]) {
                'a' -> ends("al")
                'c' -> ends("ance") || ends("ence")
                'e' -> ends("er")
                'i' -> ends("ic")
                'l' -> ends("able") || ends("ible")
                'n' -> ends("ant") || ends("ement") || ends("ment") || ends("ent")
                'o' -> (ends("ion") && j >= k0 && (b[j] == 's' || b[j] == 't')) || ends("ou")
                's' -> ends("ism")
                't' -> ends("ate") || ends("iti")
                'u' -> ends("ous")
                'v' -> ends("ive")
                'z' -> ends("ize")
                else -> false
            }
        }

        private fun step5() {
            if (step5Matches() && m() > 1) k = j
        }

        private fun step6() {
            j = k
            if (b[k] == 'e') {
                val a = m()
                if (a > 1 || (a == 1 && !cvc(k - 1))) k--
            }
            if (k >= k0 + 1 && b[k] == 'l' && doubleC(k) && m() > 1) k--
        }
    }
}
