# Character classes: Swift and Kotlin ports vs .NET

Evidence for the README section "Parity and known differences". This is not a test fixture.
Regenerate with `tools/charclass/run.sh`.

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

Swift String equality applies canonical equivalence. Once lowercased, 471 letter or digit code units are canonically equivalent to a different unit, so a Swift String key would merge terms that C# keeps apart. Example: U+03AC and U+1F71. The Swift scorer keys terms by UTF-16 units to avoid this.

<details>
<summary>The 471 units in 429 groups</summary>

Each row has the first lowercased unit found in a scan from U+0000 up, and the code units whose lowercase form Swift String equality treats as equal to it. Two code units can share one lowercase form, so a row can list more units than the group has distinct lowercase forms.

| First lowercased unit | Equal code units |
|---|---|
| U+02B9 | U+0374 |
| U+0390 | U+1FD3 |
| U+03AC | U+1F71, U+1FBB |
| U+03AD | U+1F73, U+1FC9 |
| U+03AE | U+1F75, U+1FCB |
| U+03AF | U+1F77, U+1FDB |
| U+03B0 | U+1FE3 |
| U+03B9 | U+1FBE |
| U+03CC | U+1F79, U+1FF9 |
| U+03CD | U+1F7B, U+1FEB |
| U+03CE | U+1F7D, U+1FFB |
| U+3B9D | U+FAD2 |
| U+4018 | U+FAD3 |
| U+4039 | U+FAD4 |
| U+4E0D | U+F967 |
| U+4E26 | U+FA70 |
| U+4E32 | U+F905 |
| U+4E39 | U+F95E |
| U+4E82 | U+F91B |
| U+4E86 | U+F9BA |
| U+4EAE | U+F977 |
| U+4EC0 | U+F9FD |
| U+4EE4 | U+F9A8 |
| U+4F80 | U+FA73 |
| U+4F86 | U+F92D |
| U+4F8B | U+F9B5 |
| U+4FAE | U+FA30 |
| U+4FBF | U+F965 |
| U+502B | U+F9D4 |
| U+50DA | U+F9BB |
| U+50E7 | U+FA31 |
| U+5140 | U+FA0C |
| U+5145 | U+FA74 |
| U+514D | U+FA32 |
| U+5168 | U+FA72 |
| U+5169 | U+F978 |
| U+516D | U+F9D1 |
| U+5180 | U+FA75 |
| U+51B5 | U+FA71 |
| U+51B7 | U+F92E |
| U+51C9 | U+F979 |
| U+51CC | U+F955 |
| U+51DC | U+F954 |
| U+51DE | U+FA15 |
| U+5207 | U+FA00 |
| U+5217 | U+F99C |
| U+5229 | U+F9DD |
| U+523A | U+F9FF |
| U+5289 | U+F9C7 |
| U+529B | U+F98A |
| U+52A3 | U+F99D |
| U+52C7 | U+FA76 |
| U+52C9 | U+FA33 |
| U+52D2 | U+F952 |
| U+52DE | U+F92F |
| U+52E4 | U+FA34 |
| U+52F5 | U+F97F |
| U+52FA | U+FA77 |
| U+5317 | U+F963 |
| U+533F | U+F9EB |
| U+5351 | U+FA35 |
| U+5375 | U+F91C |
| U+53C3 | U+F96B |
| U+53E5 | U+F906 |
| U+540F | U+F9DE |
| U+541D | U+F9ED |
| U+5442 | U+F980 |
| U+54BD | U+F99E |
| U+5555 | U+FA79 |
| U+5587 | U+F90B |
| U+5599 | U+FA7A |
| U+559D | U+FA36, U+FA78 |
| U+55C0 | U+FA0D |
| U+55E2 | U+FA7B |
| U+5606 | U+FA37 |
| U+5668 | U+FA38 |
| U+56F9 | U+F9A9 |
| U+5840 | U+FA39 |
| U+585A | U+FA10, U+FA7C |
| U+585E | U+F96C |
| U+58A8 | U+FA3A |
| U+58B3 | U+FA7D |
| U+58D8 | U+F94A |
| U+58DF | U+F942 |
| U+5944 | U+FA7E |
| U+5948 | U+F90C |
| U+5951 | U+F909 |
| U+5954 | U+FA7F |
| U+5973 | U+F981 |
| U+5A62 | U+FA80 |
| U+5B28 | U+FA81 |
| U+5B85 | U+FA04 |
| U+5BE7 | U+F95F, U+F9AA |
| U+5BEE | U+F9BC |
| U+5C3F | U+F9BD |
| U+5C62 | U+F94B |
| U+5C64 | U+FA3B |
| U+5C65 | U+F9DF |
| U+5C6E | U+FA3C |
| U+5D19 | U+F9D5 |
| U+5D50 | U+F921 |
| U+5DBA | U+F9AB |
| U+5E74 | U+F98E |
| U+5EA6 | U+FA01 |
| U+5EC9 | U+F9A2 |
| U+5ECA | U+F928 |
| U+5ED2 | U+FA82 |
| U+5ED3 | U+FA0B |
| U+5ED9 | U+FA83 |
| U+5EEC | U+F982 |
| U+5F04 | U+F943 |
| U+5F69 | U+FA84 |
| U+5F8B | U+F9D8 |
| U+5FA9 | U+F966 |
| U+5FAD | U+FA85 |
| U+5FF5 | U+F9A3 |
| U+6012 | U+F960 |
| U+601C | U+F9AC |
| U+6075 | U+FA6B |
| U+6094 | U+FA3D |
| U+60D8 | U+FA86 |
| U+60E1 | U+F9B9 |
| U+6108 | U+FA88 |
| U+6144 | U+F9D9 |
| U+614E | U+FA87 |
| U+6160 | U+FA8A |
| U+6168 | U+FA3E |
| U+618E | U+FA3F, U+FA89 |
| U+6190 | U+F98F |
| U+61F2 | U+FA40, U+FA8B |
| U+61F6 | U+F90D |
| U+6200 | U+F990 |
| U+622E | U+F9D2 |
| U+6234 | U+FA8C |
| U+62C9 | U+F925 |
| U+62CF | U+F95B |
| U+62D3 | U+FA02 |
| U+62FE | U+F973 |
| U+637B | U+F9A4 |
| U+63A0 | U+F975 |
| U+63C4 | U+FA8D |
| U+641C | U+FA8E |
| U+6452 | U+FA8F |
| U+649A | U+F991 |
| U+64C4 | U+F930 |
| U+654F | U+FA41 |
| U+6556 | U+FA90 |
| U+6578 | U+F969 |
| U+6599 | U+F9BE |
| U+65C5 | U+F983 |
| U+65E2 | U+FA42 |
| U+6613 | U+F9E0 |
| U+6674 | U+FA12, U+FA91 |
| U+6688 | U+F9C5 |
| U+6691 | U+FA43 |
| U+66B4 | U+FA06 |
| U+66C6 | U+F98B |
| U+66F4 | U+F901 |
| U+6717 | U+F929, U+FA92 |
| U+671B | U+FA93 |
| U+674E | U+F9E1 |
| U+6756 | U+FA94 |
| U+677B | U+F9C8 |
| U+6797 | U+F9F4 |
| U+67F3 | U+F9C9 |
| U+6817 | U+F9DA |
| U+6881 | U+F97A |
| U+6885 | U+FA44 |
| U+68A8 | U+F9E2 |
| U+6A02 | U+F914, U+F95C, U+F9BF |
| U+6A13 | U+F94C |
| U+6AD3 | U+F931 |
| U+6B04 | U+F91D |
| U+6B77 | U+F98C |
| U+6B79 | U+FA95 |
| U+6BAE | U+F9A5 |
| U+6BBA | U+F970, U+FA96 |
| U+6C88 | U+F972 |
| U+6CCC | U+F968 |
| U+6CE5 | U+F9E3 |
| U+6D1B | U+F915 |
| U+6D1E | U+FA05 |
| U+6D41 | U+F9CA, U+FA97 |
| U+6D6A | U+F92A |
| U+6D77 | U+FA45 |
| U+6DCB | U+F9F5 |
| U+6DDA | U+F94D |
| U+6DEA | U+F9D6 |
| U+6E1A | U+FA46 |
| U+6E9C | U+F9CB |
| U+6EBA | U+F9EC |
| U+6ECB | U+FA99 |
| U+6ED1 | U+F904 |
| U+6EDB | U+FA98 |
| U+6F0F | U+F94E |
| U+6F22 | U+FA47, U+FA9A |
| U+6F23 | U+F992 |
| U+6FEB | U+F922 |
| U+6FFE | U+F984 |
| U+701E | U+FA9B |
| U+7099 | U+F9FB |
| U+70C8 | U+F99F |
| U+70D9 | U+F916 |
| U+7149 | U+F993 |
| U+716E | U+FA48, U+FA9C |
| U+71CE | U+F9C0 |
| U+71D0 | U+F9EE |
| U+7210 | U+F932 |
| U+721B | U+F91E |
| U+722B | U+FA49 |
| U+7235 | U+FA9E |
| U+7262 | U+F946 |
| U+72AF | U+FA9F |
| U+72C0 | U+F9FA |
| U+72FC | U+F92B |
| U+732A | U+FA16, U+FAA0 |
| U+7375 | U+F9A7 |
| U+7387 | U+F961, U+F9DB |
| U+73B2 | U+F9AD |
| U+73DE | U+F917 |
| U+7406 | U+F9E4 |
| U+7409 | U+F9CC |
| U+7422 | U+FA4A |
| U+7469 | U+F9AE |
| U+7471 | U+FAA1 |
| U+7489 | U+F994 |
| U+7498 | U+F9EF |
| U+7506 | U+FAA2 |
| U+753B | U+FAA3 |
| U+7559 | U+F9CD |
| U+7565 | U+F976 |
| U+7570 | U+F962 |
| U+75E2 | U+F9E5 |
| U+761D | U+FAA4 |
| U+761F | U+FAA5 |
| U+7642 | U+F9C1 |
| U+7669 | U+F90E |
| U+76CA | U+FA17, U+FAA6 |
| U+76DB | U+FAA7 |
| U+76E7 | U+F933 |
| U+76F4 | U+FAA8 |
| U+7701 | U+F96D |
| U+7740 | U+FAAA |
| U+774A | U+FAA9 |
| U+77A7 | U+FA9D |
| U+786B | U+F9CE |
| U+788C | U+F93B |
| U+7891 | U+FA4B |
| U+78CA | U+F947 |
| U+78CC | U+FAAB |
| U+78FB | U+F964 |
| U+792A | U+F985 |
| U+793C | U+FA18 |
| U+793E | U+FA4C |
| U+7948 | U+FA4E |
| U+7949 | U+FA4D |
| U+7950 | U+FA4F |
| U+7956 | U+FA50 |
| U+795D | U+FA51 |
| U+795E | U+FA19 |
| U+7965 | U+FA1A |
| U+797F | U+F93C |
| U+798D | U+FA52 |
| U+798E | U+FA53 |
| U+798F | U+FA1B |
| U+79AE | U+F9B6 |
| U+79CA | U+F995 |
| U+7A1C | U+F956 |
| U+7A40 | U+FA54 |
| U+7A81 | U+FA55 |
| U+7AB1 | U+FAAC |
| U+7ACB | U+F9F7 |
| U+7B20 | U+F9F8 |
| U+7BC0 | U+FA56, U+FAAD |
| U+7C3E | U+F9A6 |
| U+7C60 | U+F944 |
| U+7C7B | U+FAAE |
| U+7C92 | U+F9F9 |
| U+7CBE | U+FA1D |
| U+7CD6 | U+FA03 |
| U+7CE7 | U+F97B |
| U+7D10 | U+F9CF |
| U+7D22 | U+F96A |
| U+7D2F | U+F94F |
| U+7D5B | U+FAAF |
| U+7DA0 | U+F93D |
| U+7DBE | U+F957 |
| U+7DF4 | U+F996, U+FA57, U+FAB0 |
| U+7E09 | U+FA58 |
| U+7E37 | U+F950 |
| U+7E41 | U+FA59 |
| U+7F3E | U+FAB1 |
| U+7F72 | U+FA5A |
| U+7F79 | U+F9E6 |
| U+7F85 | U+F90F |
| U+7F9A | U+F9AF |
| U+7FBD | U+FA1E |
| U+8001 | U+F934 |
| U+8005 | U+FA5B, U+FAB2 |
| U+8046 | U+F9B0 |
| U+806F | U+F997 |
| U+807E | U+F945 |
| U+808B | U+F953 |
| U+81D8 | U+F926 |
| U+81E8 | U+F9F6 |
| U+81ED | U+FA5C |
| U+8218 | U+FA6D |
| U+826F | U+F97C |
| U+8279 | U+FA5D, U+FA5E |
| U+82E5 | U+F974 |
| U+8336 | U+F9FE |
| U+8352 | U+FAB3 |
| U+83C9 | U+F93E |
| U+83EF | U+FAB4 |
| U+83F1 | U+F958 |
| U+843D | U+F918 |
| U+8449 | U+F96E |
| U+8457 | U+FA5F |
| U+84EE | U+F999 |
| U+84FC | U+F9C2 |
| U+85CD | U+F923 |
| U+85FA | U+F9F0 |
| U+8606 | U+F935 |
| U+8612 | U+FA20 |
| U+862D | U+F91F |
| U+863F | U+F910 |
| U+865C | U+F936 |
| U+8779 | U+FAB5 |
| U+87BA | U+F911 |
| U+881F | U+F927 |
| U+884C | U+FA08 |
| U+88C2 | U+F9A0 |
| U+88CF | U+F9E7 |
| U+88E1 | U+F9E8 |
| U+88F8 | U+F912 |
| U+8910 | U+FA60 |
| U+8941 | U+FAB6 |
| U+8964 | U+F924 |
| U+8986 | U+FAB7 |
| U+898B | U+FA0A |
| U+8996 | U+FA61, U+FAB8 |
| U+8AAA | U+F96F, U+F9A1 |
| U+8ABF | U+FAB9 |
| U+8ACB | U+FABB |
| U+8AD2 | U+F97D |
| U+8AD6 | U+F941 |
| U+8AED | U+FABE |
| U+8AF8 | U+FA22, U+FABA |
| U+8AFE | U+F95D, U+FABD |
| U+8B01 | U+FA62, U+FABC |
| U+8B39 | U+FA63, U+FABF |
| U+8B58 | U+F9FC |
| U+8B80 | U+F95A |
| U+8B8A | U+FAC0 |
| U+8C48 | U+F900 |
| U+8CC2 | U+F948 |
| U+8CC8 | U+F903 |
| U+8CD3 | U+FA64 |
| U+8D08 | U+FA65, U+FAC1 |
| U+8DEF | U+F937 |
| U+8ECA | U+F902 |
| U+8F26 | U+F998 |
| U+8F2A | U+F9D7 |
| U+8F38 | U+FAC2 |
| U+8F3B | U+FA07 |
| U+8F62 | U+F98D |
| U+8FB0 | U+F971 |
| U+8FB6 | U+FA66 |
| U+9023 | U+F99A |
| U+9038 | U+FA25, U+FA67 |
| U+9072 | U+FAC3 |
| U+907C | U+F9C3 |
| U+908F | U+F913 |
| U+90CE | U+F92C |
| U+90DE | U+FA2E |
| U+90FD | U+FA26 |
| U+916A | U+F919 |
| U+9199 | U+FAC4 |
| U+91B4 | U+F9B7 |
| U+91CC | U+F9E9 |
| U+91CF | U+F97E |
| U+91D1 | U+F90A |
| U+9234 | U+F9B1 |
| U+9276 | U+FAC5 |
| U+9304 | U+F93F |
| U+934A | U+F99B |
| U+95AD | U+F986 |
| U+962E | U+F9C6 |
| U+964B | U+F951 |
| U+964D | U+FA09 |
| U+9675 | U+F959 |
| U+9678 | U+F9D3 |
| U+967C | U+FAC6 |
| U+9686 | U+F9DC |
| U+96A3 | U+F9F1 |
| U+96B7 | U+FA2F |
| U+96B8 | U+F9B8 |
| U+96E2 | U+F9EA |
| U+96E3 | U+FA68, U+FAC7 |
| U+96F6 | U+F9B2 |
| U+96F7 | U+F949 |
| U+9732 | U+F938 |
| U+9748 | U+F9B3 |
| U+9756 | U+FA1C, U+FAC8 |
| U+97DB | U+FAC9 |
| U+97FF | U+FA69, U+FACA |
| U+980B | U+FACB |
| U+9818 | U+F9B4 |
| U+983B | U+FA6A, U+FACC |
| U+985E | U+F9D0 |
| U+98EF | U+FA2A |
| U+98FC | U+FA2B |
| U+9928 | U+FA2C |
| U+99F1 | U+F91A |
| U+9A6A | U+F987 |
| U+9B12 | U+FACD |
| U+9B6F | U+F939 |
| U+9C57 | U+F9F2 |
| U+9DB4 | U+FA2D |
| U+9DFA | U+F93A |
| U+9E1E | U+F920 |
| U+9E7F | U+F940 |
| U+9E97 | U+F988 |
| U+9E9F | U+F9F3 |
| U+9ECE | U+F989 |
| U+9F43 | U+FAD8 |
| U+9F8D | U+F9C4 |
| U+9F8E | U+FAD9 |
| U+9F9C | U+F907, U+F908, U+FACE |

</details>

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

## How to rerun

Run `tools/charclass/run.sh` from the repository root. It rewrites this file. It needs the .NET 10 SDK, macOS with Xcode (`swiftc`) and `python3`. The Kotlin legs also need JDK 17, the Android SDK and, for the emulator leg, an AVD. Set `AVD` to choose the emulator. The script writes the .NET data, about 1 MB, to a temporary folder and deletes it afterwards.

To run part of it, set `SKIP_SWIFT=1`, `SKIP_JVM=1` or `SKIP_DEVICE=1` to leave out a leg. Set `OUT=<path>` to write the report to another file. A skipped leg is missing from the output. The .NET leg always runs.

The versions listed in each section are the ones I used. Other versions know other Unicode characters, so the counts can differ. The script compares the rules for single UTF-16 code units. It does not run the tokenizer on text.
