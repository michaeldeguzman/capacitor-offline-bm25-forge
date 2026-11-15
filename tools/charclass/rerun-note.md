## How to rerun

Run `tools/charclass/run.sh` from the repository root. It rewrites this file. It needs the .NET 10 SDK, macOS with Xcode (`swiftc`) and `python3`. The Kotlin legs also need JDK 17, the Android SDK and, for the emulator leg, an AVD. Set `AVD` to choose the emulator. The script writes the .NET data, about 1 MB, to a temporary folder and deletes it afterwards.

To run part of it, set `SKIP_SWIFT=1`, `SKIP_JVM=1` or `SKIP_DEVICE=1` to leave out a leg. Set `OUT=<path>` to write the report to another file. A skipped leg is missing from the output. The .NET leg always runs.

The versions listed in each section are the ones I used. Other versions know other Unicode characters, so the counts can differ. The script compares the rules for single UTF-16 code units. It does not run the tokenizer on text.
