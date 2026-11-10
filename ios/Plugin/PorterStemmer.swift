import Foundation

/// Porter stemming algorithm (M. F. Porter, 1980), ported line by line from BM25Engine
/// PorterStemmer.cs. Input is a lowercase token as UTF-16 code units. The state names
/// (b, k, j) and the step numbering follow the C# file so the two can be compared side by side.
enum PorterStemmer {
    /// Stems one token and returns the stem. Tokens of one or two code units come back unchanged.
    static func stem(_ word: [UInt16]) -> [UInt16] {
        if word.count <= 2 { return word }
        var algorithm = Algorithm(word)
        return algorithm.run()
    }

    /// Stems one token given as a String. Convenience wrapper over the code unit version.
    static func stem(_ word: String) -> String {
        String(decoding: stem(Array(word.utf16)), as: UTF16.self)
    }

    private static func u(_ s: String) -> [UInt16] { Array(s.utf16) }

    private struct Algorithm {
        private var b: [UInt16]
        private let k0 = 0
        private var k: Int
        private var j = 0

        init(_ word: [UInt16]) {
            // C# allocates word.Length + 10 so SetTo can write past the end.
            b = word + [UInt16](repeating: 0, count: 10)
            k = word.count - 1
        }

        mutating func run() -> [UInt16] {
            if k > k0 + 1 {
                step1()
                step2()
                step3()
                step4()
                step5()
                step6()
            }
            return Array(b[0...k])
        }

        private func ch(_ c: Character) -> UInt16 { c.utf16.first! }

        private func cons(_ i: Int) -> Bool {
            switch b[i] {
            case 0x61, 0x65, 0x69, 0x6F, 0x75: // a e i o u
                return false
            case 0x79: // y
                return i == k0 ? true : !cons(i - 1)
            default:
                return true
            }
        }

        private func m() -> Int {
            var n = 0
            var i = k0
            while true {
                if i > j { return n }
                if !cons(i) { break }
                i += 1
            }
            i += 1
            while true {
                while true {
                    if i > j { return n }
                    if cons(i) { break }
                    i += 1
                }
                i += 1
                n += 1
                while true {
                    if i > j { return n }
                    if !cons(i) { break }
                    i += 1
                }
                i += 1
            }
        }

        private func vowelInStem() -> Bool {
            var i = k0
            while i <= j {
                if !cons(i) { return true }
                i += 1
            }
            return false
        }

        private func doubleC(_ jj: Int) -> Bool {
            if jj < k0 + 1 { return false }
            if b[jj] != b[jj - 1] { return false }
            return cons(jj)
        }

        private func cvc(_ i: Int) -> Bool {
            if i < k0 + 2 || !cons(i) || cons(i - 1) || !cons(i - 2) { return false }
            let c = b[i]
            if c == 0x77 || c == 0x78 || c == 0x79 { return false } // w x y
            return true
        }

        private mutating func ends(_ s: String) -> Bool {
            let sx = PorterStemmer.u(s)
            let l = sx.count
            let o = k - l + 1
            if o < k0 { return false }
            for i in 0..<l where b[o + i] != sx[i] { return false }
            j = k - l
            return true
        }

        private mutating func setTo(_ s: String) {
            let sx = PorterStemmer.u(s)
            let l = sx.count
            let o = j + 1
            for i in 0..<l { b[o + i] = sx[i] }
            k = j + l
        }

        private mutating func r(_ s: String) {
            if m() > 0 { setTo(s) }
        }

        private mutating func step1() {
            if b[k] == 0x73 { // s
                if ends("sses") { k -= 2 }
                else if ends("ies") { setTo("i") }
                else if b[k - 1] != 0x73 { k -= 1 }
            }
            if ends("eed") {
                if m() > 0 { k -= 1 }
            } else if (ends("ed") || ends("ing")) && vowelInStem() {
                k = j
                if ends("at") { setTo("ate") }
                else if ends("bl") { setTo("ble") }
                else if ends("iz") { setTo("ize") }
                else if doubleC(k) {
                    k -= 1
                    let c = b[k]
                    if c == 0x6C || c == 0x73 || c == 0x7A { k += 1 } // l s z
                } else if m() == 1 && cvc(k) {
                    setTo("e")
                }
            }
        }

        private mutating func step2() {
            if ends("y") && vowelInStem() { b[k] = 0x69 } // i
        }

        private mutating func step3() {
            if k == k0 { return }
            switch b[k - 1] {
            case ch("a"):
                if ends("ational") { r("ate"); return }
                if ends("tional") { r("tion"); return }
            case ch("c"):
                if ends("enci") { r("ence"); return }
                if ends("anci") { r("ance"); return }
            case ch("e"):
                if ends("izer") { r("ize"); return }
            case ch("l"):
                if ends("bli") { r("ble"); return }
                if ends("alli") { r("al"); return }
                if ends("entli") { r("ent"); return }
                if ends("eli") { r("e"); return }
                if ends("ousli") { r("ous"); return }
            case ch("o"):
                if ends("ization") { r("ize"); return }
                if ends("ation") { r("ate"); return }
                if ends("ator") { r("ate"); return }
            case ch("s"):
                if ends("alism") { r("al"); return }
                if ends("iveness") { r("ive"); return }
                if ends("fulness") { r("ful"); return }
                if ends("ousness") { r("ous"); return }
            case ch("t"):
                if ends("aliti") { r("al"); return }
                if ends("iviti") { r("ive"); return }
                if ends("biliti") { r("ble"); return }
            case ch("g"):
                if ends("logi") { r("log"); return }
            default:
                break
            }
        }

        private mutating func step4() {
            switch b[k] {
            case ch("e"):
                if ends("icate") { r("ic"); return }
                if ends("ative") { r(""); return }
                if ends("alize") { r("al"); return }
            case ch("i"):
                if ends("iciti") { r("ic"); return }
            case ch("l"):
                if ends("ical") { r("ic"); return }
                if ends("ful") { r(""); return }
            case ch("s"):
                if ends("ness") { r(""); return }
            default:
                break
            }
        }

        private mutating func step5() {
            if k == k0 { return }
            switch b[k - 1] {
            case ch("a"):
                if ends("al") { break }
                return
            case ch("c"):
                if ends("ance") { break }
                if ends("ence") { break }
                return
            case ch("e"):
                if ends("er") { break }
                return
            case ch("i"):
                if ends("ic") { break }
                return
            case ch("l"):
                if ends("able") { break }
                if ends("ible") { break }
                return
            case ch("n"):
                if ends("ant") { break }
                if ends("ement") { break }
                if ends("ment") { break }
                if ends("ent") { break }
                return
            case ch("o"):
                if ends("ion") && j >= k0 && (b[j] == 0x73 || b[j] == 0x74) { break } // s t
                if ends("ou") { break }
                return
            case ch("s"):
                if ends("ism") { break }
                return
            case ch("t"):
                if ends("ate") { break }
                if ends("iti") { break }
                return
            case ch("u"):
                if ends("ous") { break }
                return
            case ch("v"):
                if ends("ive") { break }
                return
            case ch("z"):
                if ends("ize") { break }
                return
            default:
                return
            }
            if m() > 1 { k = j }
        }

        private mutating func step6() {
            j = k
            if b[k] == 0x65 { // e
                let a = m()
                if a > 1 || (a == 1 && !cvc(k - 1)) { k -= 1 }
            }
            if k >= k0 + 1 && b[k] == 0x6C && doubleC(k) && m() > 1 { k -= 1 } // l
        }
    }
}
