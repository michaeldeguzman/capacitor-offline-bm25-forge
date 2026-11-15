import Foundation

// Compares CharRules (ios/Plugin/Tokenizer.swift) with the .NET data file for all 65,536
// UTF-16 code units and prints a Markdown report on stdout.
// Usage: charclass <dotnet data file> <swift version line>

let lines = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
    .split(separator: "\n", omittingEmptySubsequences: true)
let swiftVersion = CommandLine.arguments[2]
let dotnetVersion = lines.first.map { String($0.dropFirst(2)) } ?? "unknown"

struct Diff { let rule: String; let unit: UInt16; let dotnet: String; let swift: String }
var diffs: [Diff] = []
var rows = 0
for line in lines.dropFirst() {
    let f = line.split(separator: " ")
    let unit = UInt16(f[0], radix: 16)!
    rows += 1
    let checks: [(String, Bool, Bool)] = [
        ("IsLetterOrDigit", f[1] == "1", CharRules.isLetterOrDigit(unit)),
        ("IsWhiteSpace", f[2] == "1", CharRules.isWhiteSpace(unit)),
        ("IsDigit", f[3] == "1", CharRules.isDigit(unit)),
    ]
    for (rule, dotnet, swift) in checks where dotnet != swift {
        diffs.append(Diff(rule: rule, unit: unit, dotnet: "\(dotnet)", swift: "\(swift)"))
    }
    let dotnetLower = UInt16(f[4], radix: 16)!
    let swiftLower = CharRules.lowercase(unit)
    if dotnetLower != swiftLower {
        diffs.append(Diff(rule: "ToLowerInvariant", unit: unit,
                          dotnet: hex(dotnetLower), swift: hex(swiftLower)))
    }
}

func hex(_ u: UInt16) -> String { "U+" + String(format: "%04X", u) }

// Distinct lowercased letter or digit units that Swift String equality treats as equal.
var firstSeen: [String: UInt16] = [:]
var equivalentUnits = 0
var groups: [UInt16: [UInt16]] = [:]
for u in 0...0xFFFF {
    let low = CharRules.lowercase(UInt16(u))
    guard CharRules.isLetterOrDigit(low) else { continue }
    let s = String(decoding: [low], as: UTF16.self)
    if let other = firstSeen[s], other != low {
        equivalentUnits += 1
        groups[other, default: []].append(UInt16(u))
    } else {
        firstSeen[s] = low
    }
}

func categoryName(_ unit: UInt16) -> String {
    guard let scalar = Unicode.Scalar(unit) else { return "surrogate" }
    return "\(scalar.properties.generalCategory)"
}

print("## Swift (iOS)")
print()
print("- .NET: \(dotnetVersion)")
print("- Swift: \(swiftVersion)")
print("- Code units compared: \(rows) (U+0000 to U+FFFF, every UTF-16 unit)")
print("- Rules compared: char.IsLetterOrDigit, char.IsWhiteSpace, char.IsDigit, string.ToLowerInvariant on one unit")
print("- Differences: \(diffs.count)")
print()
if diffs.isEmpty {
    print("The two implementations agree on every code unit.")
} else {
    print("| Rule | Code unit | .NET | Swift | Swift general category |")
    print("|---|---|---|---|---|")
    for d in diffs {
        print("| \(d.rule) | \(hex(d.unit)) | \(d.dotnet) | \(d.swift) | \(categoryName(d.unit)) |")
    }
}
print()
print("### Canonical equivalence")
print()
print("Swift String equality applies canonical equivalence. Once lowercased, \(equivalentUnits) letter or digit code units are canonically equivalent to a different unit, so a Swift String key would merge terms that C# keeps apart. Example: U+03AC and U+1F71. The Swift scorer keys terms by UTF-16 units to avoid this.")
print()
print("<details>")
print("<summary>The \(equivalentUnits) units in \(groups.count) groups</summary>")
print()
print("Each row has the first lowercased unit found in a scan from U+0000 up, and the code units whose lowercase form Swift String equality treats as equal to it. Two code units can share one lowercase form, so a row can list more units than the group has distinct lowercase forms.")
print()
print("| First lowercased unit | Equal code units |")
print("|---|---|")
for first in groups.keys.sorted() {
    print("| \(hex(first)) | \(groups[first]!.map(hex).joined(separator: ", ")) |")
}
print()
print("</details>")
