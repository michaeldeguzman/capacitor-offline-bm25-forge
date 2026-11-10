# Character classes: Swift and Kotlin ports vs .NET

Evidence for the README section "Parity and known differences". This is not a test fixture.
A script in the development repository generates it. It compares the Swift and Kotlin character rules with .NET for every UTF-16 code unit.

## Swift (iOS)

- .NET: .NET 10.0.8
- Swift: Apple Swift version 6.4.2 (swiftlang-6.4.2.1.9 clang-2100.4.1.1)
- Code units compared: 65536 (U+0000 to U+FFFF, every UTF-16 unit)
- Rules compared: char.IsLetterOrDigit, char.IsWhiteSpace, char.IsDigit, string.ToLowerInvariant on one unit
- Differences: 8

| Rule | Code unit | .NET | Swift | Swift general category |
|---|---|---|---|---|
| IsLetterOrDigit | U+088F | false | true | otherLetter |
| IsLetterOrDigit | U+0C5C | false | true | otherLetter |
| IsLetterOrDigit | U+0CDC | false | true | otherLetter |
| IsLetterOrDigit | U+A7CE | false | true | uppercaseLetter |
| IsLetterOrDigit | U+A7CF | false | true | lowercaseLetter |
| IsLetterOrDigit | U+A7D2 | false | true | uppercaseLetter |
| IsLetterOrDigit | U+A7D4 | false | true | uppercaseLetter |
| IsLetterOrDigit | U+A7F1 | false | true | modifierLetter |

### Canonical equivalence

Swift String equality applies canonical equivalence. 471 lowercased letter or digit code units are canonically equivalent to a different unit, so a Swift `String` key would merge terms that C# keeps apart. Example: U+03AC and U+1F71. The Swift scorer keys terms by UTF-16 units to avoid this.

## Kotlin on the JVM

- Runtime: JVM 17.0.21+9 Eclipse Adoptium
- .NET: .NET 10.0.8
- Code units compared: 65536 (U+0000 to U+FFFF, every UTF-16 unit)

| Rule | Units that differ from .NET |
|---|---|
| IsLetterOrDigit | 64 |
| IsWhiteSpace | 0 |
| IsDigit | 0 |
| ToLowerInvariant | 13 |

Differences, as ranges of consecutive code units. For ToLowerInvariant the values shown are for the first unit of the range.

| Rule | First | Last | Units | .NET | Kotlin |
|---|---|---|---|---|---|
| IsLetterOrDigit | U+0870 | U+0887 | 24 | true | false |
| IsLetterOrDigit | U+0889 | U+088E | 6 | true | false |
| IsLetterOrDigit | U+08B5 | U+08B5 | 1 | true | false |
| IsLetterOrDigit | U+08C8 | U+08C9 | 2 | true | false |
| IsLetterOrDigit | U+0C5D | U+0C5D | 1 | true | false |
| IsLetterOrDigit | U+0CDD | U+0CDD | 1 | true | false |
| IsLetterOrDigit | U+170D | U+170D | 1 | true | false |
| IsLetterOrDigit | U+171F | U+171F | 1 | true | false |
| IsLetterOrDigit | U+1B4C | U+1B4C | 1 | true | false |
| IsLetterOrDigit | U+1C89 | U+1C8A | 2 | true | false |
| ToLowerInvariant | U+1C89 | U+1C89 | 1 | U+1C8A | U+1C89 |
| IsLetterOrDigit | U+2C2F | U+2C2F | 1 | true | false |
| ToLowerInvariant | U+2C2F | U+2C2F | 1 | U+2C5F | U+2C2F |
| IsLetterOrDigit | U+2C5F | U+2C5F | 1 | true | false |
| IsLetterOrDigit | U+9FFD | U+9FFF | 3 | true | false |
| IsLetterOrDigit | U+A7C0 | U+A7C1 | 2 | true | false |
| ToLowerInvariant | U+A7C0 | U+A7C0 | 1 | U+A7C1 | U+A7C0 |
| IsLetterOrDigit | U+A7CB | U+A7CD | 3 | true | false |
| ToLowerInvariant | U+A7CB | U+A7CB | 1 | U+0264 | U+A7CB |
| ToLowerInvariant | U+A7CC | U+A7CC | 1 | U+A7CD | U+A7CC |
| ToLowerInvariant | U+A7CE | U+A7CE | 1 | U+A7CF | U+A7CE |
| IsLetterOrDigit | U+A7D0 | U+A7D1 | 2 | true | false |
| ToLowerInvariant | U+A7D0 | U+A7D0 | 1 | U+A7D1 | U+A7D0 |
| ToLowerInvariant | U+A7D2 | U+A7D2 | 1 | U+A7D3 | U+A7D2 |
| IsLetterOrDigit | U+A7D3 | U+A7D3 | 1 | true | false |
| ToLowerInvariant | U+A7D4 | U+A7D4 | 1 | U+A7D5 | U+A7D4 |
| IsLetterOrDigit | U+A7D5 | U+A7DC | 8 | true | false |
| ToLowerInvariant | U+A7D6 | U+A7D6 | 1 | U+A7D7 | U+A7D6 |
| ToLowerInvariant | U+A7D8 | U+A7D8 | 1 | U+A7D9 | U+A7D8 |
| ToLowerInvariant | U+A7DA | U+A7DA | 1 | U+A7DB | U+A7DA |
| ToLowerInvariant | U+A7DC | U+A7DC | 1 | U+019B | U+A7DC |
| IsLetterOrDigit | U+A7F2 | U+A7F4 | 3 | true | false |

## Kotlin on the Android emulator

- Runtime: Android API 32 Google sdk_gphone64_arm64 arm64-v8a
- .NET: .NET 10.0.8
- Code units compared: 65536 (U+0000 to U+FFFF, every UTF-16 unit)

| Rule | Units that differ from .NET |
|---|---|
| IsLetterOrDigit | 64 |
| IsWhiteSpace | 0 |
| IsDigit | 0 |
| ToLowerInvariant | 13 |

Differences, as ranges of consecutive code units. For ToLowerInvariant the values shown are for the first unit of the range.

| Rule | First | Last | Units | .NET | Kotlin |
|---|---|---|---|---|---|
| IsLetterOrDigit | U+0870 | U+0887 | 24 | true | false |
| IsLetterOrDigit | U+0889 | U+088E | 6 | true | false |
| IsLetterOrDigit | U+08B5 | U+08B5 | 1 | true | false |
| IsLetterOrDigit | U+08C8 | U+08C9 | 2 | true | false |
| IsLetterOrDigit | U+0C5D | U+0C5D | 1 | true | false |
| IsLetterOrDigit | U+0CDD | U+0CDD | 1 | true | false |
| IsLetterOrDigit | U+170D | U+170D | 1 | true | false |
| IsLetterOrDigit | U+171F | U+171F | 1 | true | false |
| IsLetterOrDigit | U+1B4C | U+1B4C | 1 | true | false |
| IsLetterOrDigit | U+1C89 | U+1C8A | 2 | true | false |
| ToLowerInvariant | U+1C89 | U+1C89 | 1 | U+1C8A | U+1C89 |
| IsLetterOrDigit | U+2C2F | U+2C2F | 1 | true | false |
| ToLowerInvariant | U+2C2F | U+2C2F | 1 | U+2C5F | U+2C2F |
| IsLetterOrDigit | U+2C5F | U+2C5F | 1 | true | false |
| IsLetterOrDigit | U+9FFD | U+9FFF | 3 | true | false |
| IsLetterOrDigit | U+A7C0 | U+A7C1 | 2 | true | false |
| ToLowerInvariant | U+A7C0 | U+A7C0 | 1 | U+A7C1 | U+A7C0 |
| IsLetterOrDigit | U+A7CB | U+A7CD | 3 | true | false |
| ToLowerInvariant | U+A7CB | U+A7CB | 1 | U+0264 | U+A7CB |
| ToLowerInvariant | U+A7CC | U+A7CC | 1 | U+A7CD | U+A7CC |
| ToLowerInvariant | U+A7CE | U+A7CE | 1 | U+A7CF | U+A7CE |
| IsLetterOrDigit | U+A7D0 | U+A7D1 | 2 | true | false |
| ToLowerInvariant | U+A7D0 | U+A7D0 | 1 | U+A7D1 | U+A7D0 |
| ToLowerInvariant | U+A7D2 | U+A7D2 | 1 | U+A7D3 | U+A7D2 |
| IsLetterOrDigit | U+A7D3 | U+A7D3 | 1 | true | false |
| ToLowerInvariant | U+A7D4 | U+A7D4 | 1 | U+A7D5 | U+A7D4 |
| IsLetterOrDigit | U+A7D5 | U+A7DC | 8 | true | false |
| ToLowerInvariant | U+A7D6 | U+A7D6 | 1 | U+A7D7 | U+A7D6 |
| ToLowerInvariant | U+A7D8 | U+A7D8 | 1 | U+A7D9 | U+A7D8 |
| ToLowerInvariant | U+A7DA | U+A7DA | 1 | U+A7DB | U+A7DA |
| ToLowerInvariant | U+A7DC | U+A7DC | 1 | U+019B | U+A7DC |
| IsLetterOrDigit | U+A7F2 | U+A7F4 | 3 | true | false |

