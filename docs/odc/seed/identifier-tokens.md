# Identifier tokens

Each identifier below is in a `Body` of `seed-procedures-v2.json`. The tokens come from running BM25Engine `Tokenizer.Tokenize` on the identifier alone, so they are lowercased, split on every character that is not a letter or digit, stripped of stop words, dropped when a token is a single digit, and Porter-stemmed. Document frequency counts the procedures that contain the token after indexing `Title + ". " + Body`, out of 50.

| Identifier | Procedure | Tokens | Document frequency | Status |
|---|---|---|---|---|
| 6308-2RS | p01 | 6308, 2r | 6308 1, 2r 1 | ok |
| VA-102 | p01 | va, 102 | va 1, 102 1 | ok |
| BT-3382 | p02 | bt, 3382 | bt 2, 3382 1 | ok |
| HH-6061-12 | p03 | hh, 6061, 12 | hh 1, 6061 1, 12 2 | ok |
| F-24 | p03 | f, 24 | f 2, 24 1 | letter kept |
| VX-1150 | p04 | vx, 1150 | vx 2, 1150 1 | ok |
| AL-31 | p04 | al, 31 | al 3, 31 3 | ok |
| FE-9200 | p05 | fe, 9200 | fe 1, 9200 1 | ok |
| AS 4024.1 | p06 | 4024 | 4024 1 | part dropped |
| LK-0057 | p06 | lk, 0057 | lk 1, 0057 1 | ok |
| H-52 | p07 | h, 52 | h 1, 52 1 | letter kept |
| MT-250L | p07 | mt, 250l | mt 1, 250l 1 | ok |
| GB-7240 | p08 | gb, 7240 | gb 1, 7240 1 | ok |
| DW-1805 | p08 | dw, 1805 | dw 1, 1805 1 | ok |
| BT-3328 | p09 | bt, 3328 | bt 2, 3328 1 | ok |
| AL-47 | p09 | al, 47 | al 3, 47 1 | ok |
| AS 3788 | p10 | 3788 | 3788 1 | part dropped |
| GG-2214 | p10 | gg, 2214 | gg 1, 2214 1 | ok |
| AS 1851 | p11 | 1851 | 1851 1 | part dropped |
| AS 2444 | p11 | 2444 | 2444 1 | part dropped |
| EX-0382 | p11 | ex, 0382 | ex 1, 0382 1 | ok |
| EW-14 | p12 | ew, 14 | ew 1, 14 1 | ok |
| FL-2500 | p13 | fl, 2500 | fl 1, 2500 1 | ok |
| C-31 | p13 | c, 31 | c 2, 31 3 | letter kept |
| MS-4471-B | p14 | ms, 4471, b | ms 3, 4471 2, b 1 | letter kept |
| E-217 | p14 | e, 217 | e 6, 217 1 | letter kept |
| E-271 | p15 | e, 271 | e 6, 271 1 | letter kept |
| SB-880 | p15 | sb, 880 | sb 2, 880 1 | ok |
| AS/NZS 3000 | p16 | nz, 3000 | nz 3, 3000 2 | part dropped |
| SB-12 | p16 | sb, 12 | sb 2, 12 2 | ok |
| CB-63A | p17 | cb, 63a | cb 1, 63a 1 | ok |
| F-08 | p17 | f, 08 | f 2, 08 1 | letter kept |
| GN-45K | p18 | gn, 45k | gn 1, 45k 1 | ok |
| E-122 | p18 | e, 122 | e 6, 122 1 | letter kept |
| TG-200 | p19 | tg, 200 | tg 1, 200 1 | ok |
| CC-30 | p20 | cc, 30 | cc 1, 30 2 | ok |
| CU-3600 | p20 | cu, 3600 | cu 2, 3600 2 | ok |
| R-410A | p21 | r, 410a | r 1, 410a 1 | letter kept |
| L-05 | p21 | l, 05 | l 1, 05 1 | letter kept |
| CU-3600 | p21 | cu, 3600 | cu 2, 3600 2 | ok |
| TS-20K | p22 | ts, 20k | ts 1, 20k 1 | ok |
| CH-550 | p23 | ch, 550 | ch 1, 550 1 | ok |
| E-300 | p23 | e, 300 | e 6, 300 3 | letter kept |
| BX-77 | p24 | bx, 77 | bx 1, 77 1 | ok |
| MS-2208 | p25 | ms, 2208 | ms 3, 2208 1 | ok |
| GV-150 | p25 | gv, 150 | gv 1, 150 1 | ok |
| RV-4410 | p26 | rv, 4410 | rv 1, 4410 1 | ok |
| ST-17 | p27 | st, 17 | st 1, 17 1 | ok |
| TR-0931 | p27 | tr, 0931 | tr 1, 0931 1 | ok |
| WM-3200 | p28 | wm, 3200 | wm 1, 3200 1 | ok |
| E7018 | p28 | e7018 | e7018 1 | ok |
| AS 1674.1 | p28 | 1674 | 1674 1 | part dropped |
| CK-250 | p29 | ck, 250 | ck 1, 250 2 | ok |
| JS-250 | p29 | js, 250 | js 1, 250 2 | ok |
| WH-300 | p30 | wh, 300 | wh 1, 300 3 | ok |
| VX-1510 | p31 | vx, 1510 | vx 2, 1510 1 | ok |
| AL-58 | p31 | al, 58 | al 3, 58 1 | ok |
| IJ-50 | p32 | ij, 50 | ij 1, 50 1 | ok |
| PL-218 | p32 | pl, 218 | pl 1, 218 1 | ok |
| RD-07 | p33 | rd, 07 | rd 1, 07 1 | ok |
| DC-4 | p34 | dc | dc 1 | part dropped |
| DR-112 | p34 | dr, 112 | dr 1, 112 1 | ok |
| LF-02 | p35 | lf, 02 | lf 1, 02 1 | ok |
| LED-T8-18W | p36 | led, t8, 18w | led 1, t8 1, 18w 1 | ok |
| AS 2293.2 | p37 | 2293 | 2293 1 | part dropped |
| ES-31 | p37 | es, 31 | es 1, 31 3 | ok |
| BP-12V | p37 | bp, 12v | bp 2, 12v 1 | ok |
| AN-1100 | p38 | 1100 | 1100 1 | part dropped |
| HW-250 | p38 | hw, 250 | hw 1, 250 2 | ok |
| BF-77421 | p39 | bf, 77421 | bf 1, 77421 1 | ok |
| FS-20 | p40 | fs, 20 | fs 1, 20 1 | ok |
| MS-4471-C | p40 | ms, 4471, c | ms 3, 4471 2, c 2 | letter kept |
| SP-75 | p40 | sp, 75 | sp 2, 75 1 | ok |
| FC-30 | p41 | fc, 30 | fc 1, 30 2 | ok |
| FN-900 | p42 | fn, 900 | fn 1, 900 1 | ok |
| V-7 | p42 | v | v 1 | FLAG |
| LA-300 | p43 | la, 300 | la 1, 300 3 | ok |
| AR-2231 | p43 | ar, 2231 | ar 1, 2231 1 | ok |
| P-3 | p43 | p | p 1 | FLAG |
| RC-60 | p44 | rc, 60 | rc 1, 60 1 | ok |
| SP-19 | p44 | sp, 19 | sp 2, 19 1 | ok |
| FV-0455 | p45 | fv, 0455 | fv 1, 0455 1 | ok |
| AS/NZS 1892.1 | p46 | nz, 1892 | nz 3, 1892 1 | part dropped |
| LD-33 | p46 | ld, 33 | ld 1, 33 1 | ok |
| SK-120 | p47 | sk, 120 | sk 1, 120 1 | ok |
| SC-6019 | p48 | sc, 6019 | sc 1, 6019 1 | ok |
| AS/NZS 5033 | p49 | nz, 5033 | nz 3, 5033 1 | part dropped |
| IV-5000 | p49 | iv, 5000 | iv 1, 5000 1 | ok |
| E-512 | p49 | e, 512 | e 6, 512 1 | letter kept |
| UP-3000 | p50 | 3000 | 3000 2 | part dropped |
| BP-1240 | p50 | bp, 1240 | bp 2, 1240 1 | ok |
| E-81 | p50 | e, 81 | e 6, 81 1 | letter kept |

## Flagged

- `V-7` (p42): tokens v. `v` is a single letter and is kept; `7` is a single digit and is dropped. No distinctive token survives, so a query for it matches every procedure that has the same letter.
- `P-3` (p43): tokens p. `p` is a single letter and is kept; `3` is a single digit and is dropped. No distinctive token survives, so a query for it matches every procedure that has the same letter.

## Dropped parts

These identifiers keep at least one distinctive token and lose another part of the code.

- `AS 4024.1` (p06): `as` is a stop word and is dropped; `1` is a single digit and is dropped.
- `AS 3788` (p10): `as` is a stop word and is dropped.
- `AS 1851` (p11): `as` is a stop word and is dropped.
- `AS 2444` (p11): `as` is a stop word and is dropped.
- `AS/NZS 3000` (p16): `as` is a stop word and is dropped.
- `AS 1674.1` (p28): `as` is a stop word and is dropped; `1` is a single digit and is dropped.
- `DC-4` (p34): `4` is a single digit and is dropped.
- `AS 2293.2` (p37): `as` is a stop word and is dropped; `2` is a single digit and is dropped.
- `AN-1100` (p38): `an` is a stop word and is dropped.
- `AS/NZS 1892.1` (p46): `as` is a stop word and is dropped; `1` is a single digit and is dropped.
- `AS/NZS 5033` (p49): `as` is a stop word and is dropped.
- `UP-3000` (p50): `up` is a stop word and is dropped.

## Single-letter tokens

The tokenizer keeps a single letter, so it matches every procedure that has the same letter. A letter with a high document frequency adds little to the rank, and the number carries the match. A rare letter such as `b` in `MS-4471-B` can separate two codes. Identifiers with a kept letter: `F-24` (p03), `H-52` (p07), `C-31` (p13), `MS-4471-B` (p14), `E-217` (p14), `E-271` (p15), `F-08` (p17), `E-122` (p18), `R-410A` (p21), `L-05` (p21), `E-300` (p23), `MS-4471-C` (p40), `E-512` (p49), `E-81` (p50).
