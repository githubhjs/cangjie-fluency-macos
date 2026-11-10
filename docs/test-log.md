# Test log (Linux only, nothing was run on a Mac)

Date: 2026-11-10. Machine: Ubuntu aarch64 (GX10), perl 5.38.2, python 3, librime 1.10 + librime-octagram from the
main repo's harness (`rimebin/`, `weasel/docs/rime_driver.py`). **There was no Mac: macOS tools (`defaults`,
BSD `sed`/`awk`/`cmp`, `/usr/bin/perl` 5.30, bash 3.2, Squirrel itself) were NOT run.** Everything about Squirrel
comes from reading its sources and unpacking the released `Squirrel-1.1.2.pkg` (see the README, "Verified / unverified").

Reproduce: `bash tests/test_install.sh` and `MAIN=/path/to/cangjie-fluency bash docs/linux-compile-test.sh`.

## 1. Perl converter vs python converter (byte identical)

Inputs downloaded 2026-11-10:
`mscj3.cin` sha256 `a7b3d038...39a2` (202,819 bytes), `essay.txt` (rime-essay master) sha256 `3e8512eb...4ffb` (5,887,319 bytes).

```
python3 -I cin2rime.py   mscj3.cin py_essay.yaml --essay essay.txt   -> sha256 3fa5729ac8083893d4ea9f2c8edeb2d8ad74d9ebb921bedfc4d8d5138ba30def
perl tools/cin2rime.pl   mscj3.cin pl_essay.yaml --essay essay.txt   -> sha256 3fa5729ac8083893d4ea9f2c8edeb2d8ad74d9ebb921bedfc4d8d5138ba30def
cmp py_essay.yaml pl_essay.yaml     -> identical (silent)
cmp py_plain.yaml pl_plain.yaml     -> identical (silent, without --essay)
stdout statistics identical (chardef_entries 22182, duplicates_skipped 8, written 22174, distinct_chars 21010)
```

A small synthetic .cin (UTF-8 BOM, CRLF and lone-CR line ends, upper-case `%CHARDEF BEGIN`, a U+3000 after a code, a
two-character entry, a non-BMP character, duplicates) and a synthetic essay (CRLF line, non-BMP character) also gave
byte-identical output and statistics for both modes.

One known difference, on purpose: an essay.txt line whose weight is a non-ASCII digit such as `1²` makes the python
converter crash (`str.isdigit()` is true, `int()` fails); the perl port ignores such lines (it only accepts `[0-9]+`).
The real essay.txt has no such line.

## 2. tests/test_install.sh (80 checks, no network, fake Squirrel app, file:// fixtures)

```
== 1. fresh install
  ok   exit 0
  ok   installed cangjie3_fluency.schema.yaml
  ok   installed cangjie3_fluency.dict.yaml
  ok   installed cangjie3.base.dict.yaml
  ok   installed cangjie5_fluency.schema.yaml
  ok   installed cangjie5_fluency.dict.yaml
  ok   installed cangjie5.base.dict.yaml
  ok   installed zh-hant-t-essay-bgw.gram
  ok   installed default.custom.yaml
  ok   essay.txt not copied (found in the Squirrel bundle)
  ok   no backups
  ok   no .part files left
  ok   default.custom.yaml: cangjie3_fluency is first schema
  ok   default.custom.yaml lists cangjie5_fluency
  ok   generated table equals perl converter output with the bundled essay.txt
  ok   Squirrel --reload was called
  ok   manifest written
== 2. identical re-run
  ok   exit 0
  ok   no backups
  ok   says up to date
  ok   default.custom.yaml: already listed
== 3. changed source: exactly one backup
  ok   exactly one backup
  ok   backup is of the schema
  ok   new content installed
  ok   re-run again: still one backup
== 4. default.custom.yaml cases
  ok   LF: inserted first, indentation kept, rest untouched
  ok   LF: exactly one backup of default.custom.yaml
  ok   LF: backup equals the original
  ok   CRLF, no trailing newline: CRLF kept, no newline added
  ok   brace style kept
  ok   no schema_list: file untouched
  ok   no schema_list: no backup
  ok   no schema_list: tells the user what to add
  ok   no schema_list: installer still succeeded
  ok   already listed: untouched
  ok   already listed: no backup
  ok   only cangjie5_fluency listed: cangjie3_fluency added first (exact id match)
  ok   commented-out entry does not count
== 5. --dry-run changes nothing and downloads nothing
  ok   exit 0
  ok   Rime folder not created
  ok   Squirrel not called
  ok   existing default.custom.yaml untouched by dry run
  ok   nothing else created
== 6. --uninstall
  ok   exit 0
  ok   schema removed
  ok   generated table removed
  ok   language model removed
  ok   file edited by the user is kept
  ok   foreign file kept
  ok   backups kept
  ok   default.custom.yaml created by the installer and unchanged is removed
  ok   manifest removed
== 7. pre-existing file is replaced with a backup but never removed by --uninstall
  ok   backup of the user's file
  ok   pre-existing (replaced) file kept by uninstall
  ok   user default.custom.yaml (edited by us) is not touched by uninstall
  ok   uninstall tells the user to edit default.custom.yaml
== 8. no Squirrel -> clear error; essay.txt downloaded when missing; stand-alone script downloads the converter
  ok   fails
  ok   mentions the right cask name
  ok   stand-alone run exit 0
  ok   essay.txt downloaded into the Rime folder
  ok   converter downloaded (not next to the script)
  ok   table equals the converter output
  ok   model skipped with --no-model
== 9. wrong model size is rejected
  ok   fails on size mismatch
  ok   no model installed
  ok   falls back to the second model URL
== 10. static bash 3.2 review (patterns that do not exist in bash 3.2)
  ok   install.sh does not use: declare -A
  ok   install.sh does not use: mapfile
  ok   install.sh does not use: readarray
  ok   install.sh does not use: &>>
  ok   install.sh does not use: |&
  ok   install.sh does not use: sha256sum
  ok   install.sh does not use: readlink -f
  ok   install.sh does not use: stat -c
  ok   install.sh does not use: date -d
  ok   install.sh does not use: sed -i
  ok   install.sh does not use: coproc
  ok   install.sh does not use: local -n
  ok   install.sh: no ${var,,} or ${var^^} (bash 4)
  ok   perl converter has no non-core module

passed: 80  failed: 0
```

bash 3.2 compatibility was NOT run (no bash 3.2 here). What was done instead: (a) the script is checked statically by
the last block of the test (no `declare -A`, `mapfile`, `readarray`, `${var,,}`/`${var^^}`, `&>>`, `|&`, `coproc`,
`local -n`; none of `sha256sum`, `readlink -f`, `stat -c`, `date -d`, `sed -i`); (b) it uses no arrays at all (bash 3.2
fails on empty arrays under `set -u`; the script does not use `set -u`); (c) all of it ran under this machine's bash 5.
The only perl is `perl -` with a heredoc and the converter, both core-only (`strict`, `warnings`, `utf8`, `Encode`).

## 3. Compile test: real downloads, install.sh into a throwaway folder, librime build, per-key traces

`docs/linux-compile-test.sh`. The fake Squirrel app has no essay.txt, so the installer downloads it (like a Squirrel
build without one). The language model only exists in the user folder here (it was removed from the copied shared
folder), so the "use grammar" line proves librime-octagram finds a model placed by the installer in the user folder.

First attempt: `https://github.com/lotem/rime-octagram-data/raw/hant/zh-hant-t-essay-bgw.gram` answered HTTP 504 three
times in a row (later also from curl alone), while `https://raw.githubusercontent.com/lotem/rime-octagram-data/hant/zh-hant-t-essay-bgw.gram`
answered 200 with 41,415,724 bytes. install.sh therefore tries the github.com URL first and the raw.githubusercontent.com
URL second (tested: `falls back to the second model URL`). The run below is the second attempt.

Notes on the output: `rime_deployer --build` exits 1 only because the stripped-down shared folder of the harness lacks
the other schemas that the installer-written default.custom.yaml lists (`missing input schema: ...`); both fluency
schemas, luna_pinyin and luna_quanpin built (see the file list). On a real Squirrel those schemas are in SharedSupport.
The 3rd-gen codes in the traces come from the generated table (`--base cangjie3.base.dict.yaml`): 面 = mwyl, 板 = dhe, 橋 = dhkb.

```
### 0. clean state
fake Squirrel app (no essay.txt in it, so the installer must download it): /home/hjs/projects/cangjie-fluency-macos/testenv/c3mac/Squirrel.app

### 1. install.sh with real downloads (default ref, --with-cangjie5)
[cangjie-fluency] Rime user folder: /home/hjs/projects/cangjie-fluency-macos/testenv/c3mac/rime
[cangjie-fluency] Squirrel found: /home/hjs/projects/cangjie-fluency-macos/testenv/c3mac/Squirrel.app 
[cangjie-fluency] downloading cangjie3_fluency.schema.yaml (v0.2.0)
[cangjie-fluency] installed: cangjie3_fluency.schema.yaml
[cangjie-fluency] downloading cangjie3_fluency.dict.yaml (v0.2.0)
[cangjie-fluency] installed: cangjie3_fluency.dict.yaml
[cangjie-fluency] downloading cangjie5_fluency.schema.yaml (v0.2.0)
[cangjie-fluency] installed: cangjie5_fluency.schema.yaml
[cangjie-fluency] downloading cangjie5_fluency.dict.yaml (v0.2.0)
[cangjie-fluency] installed: cangjie5_fluency.dict.yaml
[cangjie-fluency] downloading essay.txt
[cangjie-fluency] installed: essay.txt
[cangjie-fluency] downloading mscj3.cin (PIME)
[cangjie-fluency] converted table: chardef_entries: 22182 multi_char_skipped: 0 duplicates_skipped: 8 malformed_skipped: 0 written: 22174 distinct_chars: 21010 
[cangjie-fluency] installed: cangjie3.base.dict.yaml
[cangjie-fluency] downloading cangjie5.base.dict.yaml (rime-cangjie)
[cangjie-fluency] installed: cangjie5.base.dict.yaml
[cangjie-fluency] downloading zh-hant-t-essay-bgw.gram (about 41 MB) from https://github.com/lotem/rime-octagram-data/raw/hant/zh-hant-t-essay-bgw.gram
[cangjie-fluency] model sha256:0488ebd6688f900a39200f2b794f2f99bcbf1e8fc27280ae4a2324b08b1559c1
[cangjie-fluency] installed: zh-hant-t-essay-bgw.gram
[cangjie-fluency] installed: default.custom.yaml
[cangjie-fluency] asking Squirrel to redeploy (first deploy takes about 30 seconds)...
stub Squirrel called with: --reload
[cangjie-fluency] reload requested. This only reaches Squirrel while it is running; if nothing happens, click the Squirrel icon in the menu bar > Deploy.

[cangjie-fluency] Done. Next steps:
  1. Switch to the Squirrel input source, press Ctrl+` (or F4) and choose the schema "倉頡三代整句" (cangjie3_fluency).
  2. Type a whole phrase of Cangjie codes, e.g. mwyl (面), then Enter commits. Single-letter codes need a trailing space
     (中午 is "l oj").
  3. Check that the language model loaded (after typing once; log folder is $TMPDIR/rime.squirrel/):
       grep -h "use grammar" "${TMPDIR%/}"/rime.squirrel/* | tail -3
     No "use grammar" line = the model is not loaded (the schema still works).

real	0m11.647s
user	0m0.591s
sys	0m0.337s
exit=0
total 46724
-rw-rw-r-- 1 hjs hjs   286151 Nov 10 18:19 cangjie3.base.dict.yaml
-rw-rw-r-- 1 hjs hjs      540 Nov 10 18:19 cangjie3_fluency.dict.yaml
-rw-rw-r-- 1 hjs hjs     4557 Nov 10 18:19 cangjie3_fluency.schema.yaml
-rw-rw-r-- 1 hjs hjs   219115 Nov 10 18:19 cangjie5.base.dict.yaml
-rw-rw-r-- 1 hjs hjs      500 Nov 10 18:19 cangjie5_fluency.dict.yaml
-rw-rw-r-- 1 hjs hjs     4231 Nov 10 18:19 cangjie5_fluency.schema.yaml
-rw-rw-r-- 1 hjs hjs      359 Nov 10 18:19 default.custom.yaml
-rw-rw-r-- 1 hjs hjs  5887319 Nov 10 18:19 essay.txt
-rw-rw-r-- 1 hjs hjs 41415724 Nov 10 18:19 zh-hant-t-essay-bgw.gram

### 2. identical re-run (must change nothing, make no backup)
[cangjie-fluency] Rime user folder: /home/hjs/projects/cangjie-fluency-macos/testenv/c3mac/rime
[cangjie-fluency] Squirrel found: /home/hjs/projects/cangjie-fluency-macos/testenv/c3mac/Squirrel.app 
[cangjie-fluency] downloading cangjie3_fluency.schema.yaml (v0.2.0)
[cangjie-fluency] up to date: cangjie3_fluency.schema.yaml
[cangjie-fluency] downloading cangjie3_fluency.dict.yaml (v0.2.0)
[cangjie-fluency] up to date: cangjie3_fluency.dict.yaml
[cangjie-fluency] downloading cangjie5_fluency.schema.yaml (v0.2.0)
[cangjie-fluency] up to date: cangjie5_fluency.schema.yaml
[cangjie-fluency] downloading cangjie5_fluency.dict.yaml (v0.2.0)
[cangjie-fluency] up to date: cangjie5_fluency.dict.yaml
[cangjie-fluency] essay.txt found: /home/hjs/projects/cangjie-fluency-macos/testenv/c3mac/rime/essay.txt
[cangjie-fluency] downloading mscj3.cin (PIME)
[cangjie-fluency] converted table: chardef_entries: 22182 multi_char_skipped: 0 duplicates_skipped: 8 malformed_skipped: 0 written: 22174 distinct_chars: 21010 
[cangjie-fluency] up to date: cangjie3.base.dict.yaml
[cangjie-fluency] cangjie5.base.dict.yaml already present.
[cangjie-fluency] language model already present (41415724 bytes).
[cangjie-fluency] default.custom.yaml already lists: cangjie3_fluency cangjie5_fluency
[cangjie-fluency] not deploying. Deploy later: Squirrel menu bar icon > Deploy, or: "/home/hjs/projects/cangjie-fluency-macos/testenv/c3mac/Squirrel.app/Contents/MacOS/Squirrel" --reload

[cangjie-fluency] Done. Next steps:
  1. Switch to the Squirrel input source, press Ctrl+` (or F4) and choose the schema "倉頡三代整句" (cangjie3_fluency).
  2. Type a whole phrase of Cangjie codes, e.g. mwyl (面), then Enter commits. Single-letter codes need a trailing space
     (中午 is "l oj").
  3. Check that the language model loaded (after typing once; log folder is $TMPDIR/rime.squirrel/):
       grep -h "use grammar" "${TMPDIR%/}"/rime.squirrel/* | tail -3
     No "use grammar" line = the model is not loaded (the schema still works).
backups: 0

### 3. generated table vs the python converter (same downloaded mscj3.cin and essay.txt)
a7b3d03898dc0b2b0bd7803ad0be7b940a1ed945ac5d6314ed832b1dbf6839a2  /home/hjs/projects/cangjie-fluency-macos/testenv/c3mac/dl/mscj3.cin
3e8512ebaa6657e35961b1f5762060717c647e3bf471d5e3b86e783b4e934ffb  /home/hjs/projects/cangjie-fluency-macos/testenv/c3mac/rime/essay.txt
chardef_entries: 22182
multi_char_skipped: 0
duplicates_skipped: 8
malformed_skipped: 0
written: 22174
distinct_chars: 21010
BYTE-IDENTICAL: installer output == cin2rime.py output
3fa5729ac8083893d4ea9f2c8edeb2d8ad74d9ebb921bedfc4d8d5138ba30def  /home/hjs/projects/cangjie-fluency-macos/testenv/c3mac/dl/py.dict.yaml
3fa5729ac8083893d4ea9f2c8edeb2d8ad74d9ebb921bedfc4d8d5138ba30def  /home/hjs/projects/cangjie-fluency-macos/testenv/c3mac/rime/cangjie3.base.dict.yaml

### 4. build with librime (rime_deployer --build), model only in the user dir
cangjie5.base.dict.yaml
default.yaml
essay.txt
key_bindings.yaml
luna_pinyin.dict.yaml
luna_pinyin.schema.yaml
luna_quanpin.schema.yaml
pinyin.yaml
punctuation.yaml
symbols.yaml
default.custom.yaml written by the installer:
# encoding: utf-8
# created by cangjie-fluency-macos install.sh
patch:
  schema_list:
    - schema: cangjie3_fluency
    - schema: cangjie5_fluency
    - schema: luna_pinyin
    - schema: luna_pinyin_simp
    - schema: luna_pinyin_fluency
    - schema: bopomofo
    - schema: bopomofo_tw
    - schema: cangjie5
    - schema: stroke
    - schema: terra_pinyin
E20261110 18:19:47.213521 2578023 deployment_tasks.cc:210] missing input schema: luna_pinyin_simp
E20261110 18:19:47.213644 2578023 deployment_tasks.cc:210] missing input schema: luna_pinyin_fluency
E20261110 18:19:47.213670 2578023 deployment_tasks.cc:210] missing input schema: bopomofo
E20261110 18:19:47.213699 2578023 deployment_tasks.cc:210] missing input schema: bopomofo_tw
E20261110 18:19:47.213723 2578023 deployment_tasks.cc:210] missing input schema: cangjie5
E20261110 18:19:47.213755 2578023 deployment_tasks.cc:210] missing input schema: terra_pinyin

real	0m4.509s
user	0m4.307s
sys	0m0.200s
build exit=1
total 46760
-rw-rw-r-- 1 hjs hjs   688936 Nov 10 18:19 cangjie3_fluency.prism.bin
-rw-rw-r-- 1 hjs hjs   171704 Nov 10 18:19 cangjie3_fluency.reverse.bin
-rw-rw-r-- 1 hjs hjs     6358 Nov 10 18:19 cangjie3_fluency.schema.yaml
-rw-rw-r-- 1 hjs hjs 15186292 Nov 10 18:19 cangjie3_fluency.table.bin
-rw-rw-r-- 1 hjs hjs   743792 Nov 10 18:19 cangjie5_fluency.prism.bin
-rw-rw-r-- 1 hjs hjs   181944 Nov 10 18:19 cangjie5_fluency.reverse.bin
-rw-rw-r-- 1 hjs hjs     6302 Nov 10 18:19 cangjie5_fluency.schema.yaml
-rw-rw-r-- 1 hjs hjs 17464416 Nov 10 18:19 cangjie5_fluency.table.bin
-rw-rw-r-- 1 hjs hjs     5249 Nov 10 18:19 default.yaml
-rw-rw-r-- 1 hjs hjs    31728 Nov 10 18:19 luna_pinyin.prism.bin
-rw-rw-r-- 1 hjs hjs   252760 Nov 10 18:19 luna_pinyin.reverse.bin
-rw-rw-r-- 1 hjs hjs    42023 Nov 10 18:19 luna_pinyin.schema.yaml
-rw-rw-r-- 1 hjs hjs 13011364 Nov 10 18:19 luna_pinyin.table.bin
-rw-rw-r-- 1 hjs hjs    16936 Nov 10 18:19 luna_quanpin.prism.bin
-rw-rw-r-- 1 hjs hjs    41734 Nov 10 18:19 luna_quanpin.schema.yaml

### 5. per-key traces (3rd-gen codes taken from the generated table)
== schema=cangjie3_fluency grammar=ON
-- trace 面 keys='mwyl'
  after 'm': top='不'
  after 'w': top='要'
  after 'y': top='面'
  after 'l': top='面'
-- trace 板橋 keys='dhedhkb'
  after 'd': top='來'
  after 'h': top='才'
  after 'e': top='皮'
  after 'd': top='才沐'
  after 'h': top='皮才'
  after 'k': top='皮枖'
  after 'b': top='板橋'
-- keys='mwyl'
  buffer: preedit='一田卜中' candidates=['面']
-- keys='dhedhkb'
  buffer: preedit='木竹水 木竹大月' candidates=['板橋', '皮', '板']
-- keys='l oj'
  buffer: preedit='中 人十' candidates=['中午', '中', '丨']

grammar log line:
I20261110 18:19:47.284066 2578721 octagram.cc:29] use grammar: zh-hant-t-essay-bgw
I20261110 18:19:47.288094 2578721 octagram.cc:29] use grammar: zh-hant-t-essay-bgw
cangjie5_fluency (--with-cangjie5) builds? schema file present in build:
4
```


## Self-contained rework (2026-11-10): everything from the main repo, no third party

Earlier sections describe the first installer, which downloaded the table from PIME, essay.txt from rime-essay and the model from
rime-octagram-data (that version was the one run on the real Mac). The installer now takes every file from the main repo
(bundle layout next to the script, else `raw.githubusercontent.com/githubhjs/cangjie-fluency/<ref>/`, default `v0.4.0`), SHA-256
checks the tables, essay.txt, the model and the Squirrel pkg, always converts with the repo's `data/essay.txt`, installs the full model
always, and installs Squirrel 1.1.2 from the bundled/`deps-v1` pkg with `sudo installer -pkg ... -target /` when
`/Library/Input Methods/Squirrel.app` is missing (no Homebrew). `--offline` never touches the network. The perl converter now lives only
in the main repo (`tools/cin2rime.pl`); this repo's copy was removed.

All of the following ran on **Linux** (the macOS-only parts are stubbed); nothing new was run on a Mac.

### `bash tests/test_install.sh`: 95 passed, 0 failed

Real main-repo files as the bundle (`CJF_SRC_DIR`, big files symlinked), fake `Squirrel.app`, stub `curl`/`wget`/`sudo`:

* fresh `--offline --with-cangjie5` install: all files, model 41,415,724 B, essay.txt not copied (Squirrel bundle has one),
  **zero calls to the curl/wget/sudo stubs**, `default.custom.yaml` with cangjie3_fluency first;
* **the generated table equals the python converter's output (`tools/cin2rime.py ... --essay data/essay.txt`) and a direct
  `perl tools/cin2rime.pl` run** (byte-identical, `cmp`);
* re-run: nothing rewritten, no backups, "language model already present"; changed schema file: exactly one backup;
* all `default.custom.yaml` cases (LF, CRLF without final newline, brace style, no list, already listed, only cangjie5_fluency,
  commented entry), dry-run (no files, no network, no Squirrel call), uninstall (manifest, edited files kept, backups kept);
* Squirrel missing: with the bundled `deps/Squirrel-1.1.2.pkg` (SHA-256 checked) a stand-in for `sudo installer` receives the pkg and
  creates the app; second run does not call it again; `--no-deps` stops with a clear error; a corrupted pkg stops with
  `SHA-256 mismatch` before anything runs (the real `sudo installer -pkg` was **never run**);
* script alone, `--offline`: fails naming `--offline`, no network; script alone, online (`--ref main`): curl asked for
  `raw.githubusercontent.com/githubhjs/cangjie-fluency/main/weasel/cangjie3_fluency.schema.yaml` and only `githubhjs/cangjie-fluency` URLs;
* a table with one extra line: `SHA-256 mismatch`, no generated table; no Squirrel `essay.txt`: the repo's essay.txt is installed into the Rime folder;
* static bash 3.2 review (no `declare -A`, `mapfile`, `sha256sum`, `readlink -f`, `sed -i`, ...), no third-party URL or `brew install` in `install.sh`.

### `./make-release.sh /home/hjs/projects/cangjie-fluency v0.2.0`

```
63853432 dist/cangjie-fluency-macos-v0.2.0-full.zip      (incl. deps/Squirrel-1.1.2.pkg 25,498,033 B, NOTICE-third-party.txt, squirrel-LICENSE.txt)
   27458 dist/cangjie-fluency-macos-v0.2.0-slim.zip
```

Full zip unzipped to a temp dir; `bash install.sh --offline --rime-dir <tmp> --no-deploy` with a fake Squirrel.app and stub curl/wget/sudo:
all files installed, 0 stub calls, `cangjie3.base.dict.yaml` produced by `/usr/bin/perl` is byte-identical to the python converter's output.
The builder refuses to run when a shipped file's SHA-256 is not the one pinned in `install.sh`.

### `docs/linux-compile-test.sh`

Now uses `--offline` with the main-repo checkout (no download); compares the installer's table with `cin2rime.py` on the repo's own
`tables/mscj3.cin` and `data/essay.txt`.

### Not verified

* No new run on a Mac: offline mode, `shasum`, installing Squirrel with a real `sudo installer -pkg`, and the first-install flow of the pkg are untested on macOS.
* `shellcheck` is not installed here; only `bash -n` and the bash 3.2 pattern review were run.
