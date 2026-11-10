import Foundation

/// Character rules that copy the C# char methods used by BM25Engine Tokenizer.
///
/// C# works on UTF-16 code units. I do the same. Every function here takes one UInt16 code unit.
/// I never use Swift Character, because a Character is a grapheme cluster and classifies
/// differently from a code unit.
///
/// Rules:
/// - A surrogate code unit (0xD800 to 0xDFFF) has category Cs in C#. It is not a letter, digit
///   or whitespace, so it becomes a space. Every character outside the Basic Multilingual Plane
///   is therefore dropped, as in C#.
/// - isLetterOrDigit matches char.IsLetterOrDigit: general category Lu, Ll, Lt, Lm, Lo or Nd.
/// - isDigit matches char.IsDigit: general category Nd.
/// - isWhiteSpace matches char.IsWhiteSpace: general category Zs, Zl or Zp, plus U+0009 to
///   U+000D and U+0085.
/// - lowercase matches string.ToLowerInvariant for one code unit. I use the single scalar
///   lowercase mapping. If the Unicode full mapping has more than one scalar (only U+0130),
///   I keep the code unit unchanged, which is what .NET does under the invariant culture.
///   I do not use String.lowercased(), because it applies the final sigma context rule and
///   C# does not.
///
/// The general categories come from the Unicode tables in the Swift standard library. .NET
/// ships its own table version. A character assigned in one version and not the other would
/// differ. I compared all 65,536 code units against .NET 10.0.8 on 10 Nov 2026. Lowercase,
/// IsWhiteSpace and IsDigit agree on every unit. IsLetterOrDigit differs on 8 units that
/// Swift's tables (Unicode 17) classify as letters and .NET does not: U+088F, U+0C5C, U+0CDC,
/// U+A7CE, U+A7CF, U+A7D2, U+A7D4, U+A7F1. None is used in English text.
enum CharRules {
    private static func category(_ unit: UInt16) -> Unicode.GeneralCategory? {
        guard !(0xD800...0xDFFF).contains(unit), let scalar = Unicode.Scalar(unit) else {
            return nil
        }
        return scalar.properties.generalCategory
    }

    static func isLetterOrDigit(_ unit: UInt16) -> Bool {
        switch category(unit) {
        case .uppercaseLetter?, .lowercaseLetter?, .titlecaseLetter?, .modifierLetter?,
             .otherLetter?, .decimalNumber?:
            return true
        default:
            return false
        }
    }

    static func isDigit(_ unit: UInt16) -> Bool {
        category(unit) == .decimalNumber
    }

    static func isWhiteSpace(_ unit: UInt16) -> Bool {
        if (0x09...0x0D).contains(unit) || unit == 0x85 { return true }
        switch category(unit) {
        case .spaceSeparator?, .lineSeparator?, .paragraphSeparator?:
            return true
        default:
            return false
        }
    }

    static func lowercase(_ unit: UInt16) -> UInt16 {
        if unit < 0x80 {
            return (0x41...0x5A).contains(unit) ? unit + 0x20 : unit
        }
        guard category(unit) != nil, let scalar = Unicode.Scalar(unit) else {
            return unit
        }
        let mapped = scalar.properties.lowercaseMapping.unicodeScalars
        guard mapped.count == 1, let first = mapped.first, first.value <= 0xFFFF else {
            return unit
        }
        return UInt16(first.value)
    }
}

/// Tokenizer v2 from BM25Engine: lowercase, punctuation becomes a boundary, stop words
/// removed, Porter stem. I kept it stateless. Call it identically at ingestion and query time.
enum Tokenizer {
    /// The tokenizer version recorded per collection. Matches BM25Engine tokenizer v2.
    static let version = 2

    /// Tokenizes raw text into stemmed tokens and returns them in order, duplicates kept.
    /// Returns an empty array for empty, whitespace-only or all-stop-word input.
    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current: [UInt16] = []

        func flush() {
            if current.isEmpty { return }
            defer { current.removeAll(keepingCapacity: true) }
            if current.count < 2 && current.allSatisfy(CharRules.isDigit) { return }
            if StopWords.isStopWord(current) { return }
            tokens.append(String(decoding: PorterStemmer.stem(current), as: UTF16.self))
        }

        // Lowercase first, then classify. A kept unit is a letter, a digit or whitespace.
        // Whitespace and every other unit end the current token.
        for unit in text.utf16 {
            let lowered = CharRules.lowercase(unit)
            if CharRules.isLetterOrDigit(lowered) {
                current.append(lowered)
            } else {
                flush()
            }
        }
        flush()
        return tokens
    }
}
