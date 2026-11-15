"""Renders CHARCLASS| lines printed by CharClassComparisonTest as a Markdown section.

Usage: kotlin_report.py <title> <file with CHARCLASS| lines>
"""
import sys

title, path = sys.argv[1], sys.argv[2]
runtime = dotnet = units = None
totals = {}
diffs = []
ended = False
seen = set()
for line in open(path, encoding="utf-8"):
    i = line.find("CHARCLASS|")
    if i < 0:
        continue
    f = line[i:].rstrip("\n").split("|")
    if f[1] == "runtime":
        runtime = f[2]
    elif f[1] == "dotnet":
        dotnet = f[2]
    elif f[1] == "units":
        units = f[2]
    elif f[1] == "total":
        totals[f[2]] = int(f[3])
    elif f[1] == "diff":
        if tuple(f) not in seen:
            seen.add(tuple(f))
            diffs.append(f[2:])
    elif f[1] == "end":
        ended = True

if not ended:
    sys.exit("no complete CHARCLASS output in " + path)

print(f"## {title}")
print()
print(f"- Runtime: {runtime}")
print(f"- .NET: {dotnet}")
print(f"- Code units compared: {units} (U+0000 to U+FFFF, every UTF-16 unit)")
print()
print("| Rule | Units that differ from .NET |")
print("|---|---|")
for rule in ("IsLetterOrDigit", "IsWhiteSpace", "IsDigit", "ToLowerInvariant"):
    print(f"| {rule} | {totals.get(rule, 0)} |")
print()
if diffs:
    print("Differences, as ranges of consecutive code units. For ToLowerInvariant the values shown are for the first unit of the range.")
    print()
    print("| Rule | First | Last | Units | .NET | Kotlin |")
    print("|---|---|---|---|---|---|")
    for rule, first, last, count, dn, kt in diffs:
        print(f"| {rule} | {first} | {last} | {count} | {dn} | {kt} |")
else:
    print("The two implementations agree on every code unit.")
print()
