#!/bin/bash
# Tests for install.sh. No Squirrel needed: it is a fake app folder (SQUIRREL_APP_DIR). The bundle layout comes from a
# checkout of the main repo (CJF_MAIN_REPO, default /home/hjs/projects/cangjie-fluency): the REAL tables, essay.txt and
# language model are used with their SHA-256 checks; weasel/ is copied so a test can change it.
# Usage: bash tests/test_install.sh
# Written for bash 3.2 (no associative arrays, no ${var,,}, no mapfile).

REPO=$(cd "$(dirname "$0")/.." && pwd)
MAIN="${CJF_MAIN_REPO:-/home/hjs/projects/cangjie-fluency}"
W=$(mktemp -d "${TMPDIR:-/tmp}/cjf-test.XXXXXX") || exit 1
trap 'rm -r "$W"' EXIT
PASS=0; FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
check() { # DESC CMD...
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi
}
count_bak() { ls "$1" 2>/dev/null | grep -c '\.bak-' ; }

# ---------------------------------------------------------------- bundle = main repo layout (big files symlinked)
SRC="$W/bundle"; mkdir -p "$SRC/deps"
cp -R "$MAIN/weasel" "$SRC/weasel"; rm -rf "$SRC/weasel/docs"
ln -s "$MAIN/tables" "$SRC/tables"; ln -s "$MAIN/data" "$SRC/data"; ln -s "$MAIN/tools" "$SRC/tools"
ln -s "$MAIN/dl/Squirrel-1.1.2.pkg" "$SRC/deps/Squirrel-1.1.2.pkg"

# mock sweep pad in bundle
SWEEP_STUB="$W/sweep_src"; mkdir -p "$SWEEP_STUB"
cat > "$SWEEP_STUB/cangjie_sweep_pad.py" <<'PY'
#!/usr/bin/env python3
import sys
if "--self-check" in sys.argv:
    print("self-check ok")
    sys.exit(0)
print("cangjie sweep pad")
PY
chmod +x "$SWEEP_STUB/cangjie_sweep_pad.py"
(cd "$SWEEP_STUB" && zip -q -r "$W/cangjie-sweep-pad.zip" cangjie_sweep_pad.py)
shasum -a 256 "$W/cangjie-sweep-pad.zip" | awk '{print $1}' > "$W/cangjie-sweep-pad.zip.sha256"

mkdir -p "$SRC/sweep-pad"
cp "$W/cangjie-sweep-pad.zip" "$SRC/sweep-pad/cangjie-sweep-pad.zip"
cp "$W/cangjie-sweep-pad.zip.sha256" "$SRC/sweep-pad/cangjie-sweep-pad.zip.sha256"

export CJF_SRC_DIR="$SRC"
export CJF_SWEEP_DIR="$W/sweep"
export CJF_BIN_DIR="$W/bin"
export CJF_APP_DIR="$W/apps"

# a curl/wget/sudo that only record: any use means the test (or installer) touched the network
STUB="$W/stub"; mkdir -p "$STUB"; NETLOG="$W/net.log"; : > "$NETLOG"
for c in curl wget sudo; do printf '#!/bin/sh\necho "%s $*" >> "%s"\nexit 22\n' "$c" "$NETLOG" > "$STUB/$c"; chmod +x "$STUB/$c"; done
export PATH="$STUB:$PATH"

# new_env NAME [noessay] -> sets RD (rime dir), APP (fake Squirrel), LOG (stub log)
new_env() {
  local base="$W/$1"
  RD="$base/rime"; APP="$base/Squirrel.app"; LOG="$base/stub.log"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/SharedSupport" "$APP/Contents/Frameworks/rime-plugins" "$RD"
  : > "$APP/Contents/Frameworks/rime-plugins/librime-octagram.dylib"
  [ "${2:-}" = noessay ] || ln -s "$MAIN/data/essay.txt" "$APP/Contents/SharedSupport/essay.txt"
  printf '#!/bin/sh\necho "$@" >> "%s"\n' "$LOG" > "$APP/Contents/MacOS/Squirrel"
  chmod +x "$APP/Contents/MacOS/Squirrel"
  export SQUIRREL_APP_DIR="$APP"
  : > "$LOG"
}
inst() { bash "$REPO/install.sh" --rime-dir "$RD" "$@"; }   # output in $OUT
run()  { OUT=$(inst "$@" 2>&1); RC=$?; }
bakcount() { count_bak "$RD"; }

echo "== 1. fresh install, full bundle, --offline"
new_env fresh
run --with-cangjie5 --offline
[ "$RC" = 0 ] || printf "%s\n" "$OUT"
check "exit 0" test "$RC" = 0
for f in cangjie3_fluency.schema.yaml cangjie3_fluency.dict.yaml cangjie3.base.dict.yaml cangjie5_fluency.schema.yaml \
         cangjie5_fluency.dict.yaml cangjie5.base.dict.yaml zh-hant-t-essay-bgw.gram default.custom.yaml; do
  check "installed $f" test -s "$RD/$f"
done
check "model is the full 41,415,724 byte file" test "$(wc -c < "$RD/zh-hant-t-essay-bgw.gram" | tr -d ' ')" = 41415724
check "essay.txt not copied (found in the Squirrel bundle)" test ! -e "$RD/essay.txt"
check "no backups" test "$(bakcount)" = 0
check "no .part files left" test -z "$(ls "$RD" | grep '\.part$')"
check "ZERO network calls (curl/wget/sudo stubs never used)" test ! -s "$NETLOG"
check "default.custom.yaml: cangjie3_fluency is first schema" test "$(grep -- '- schema:' "$RD/default.custom.yaml" | head -1)" = "    - schema: cangjie3_fluency"
check "default.custom.yaml lists cangjie5_fluency" grep -q 'schema: cangjie5_fluency$' "$RD/default.custom.yaml"
check "generated table equals the python converter output (repo essay.txt weights)" sh -c "python3 -I '$MAIN/tools/cin2rime.py' '$MAIN/tables/mscj3.cin' '$W/py.yaml' --essay '$MAIN/data/essay.txt' >/dev/null && cmp -s '$W/py.yaml' '$RD/cangjie3.base.dict.yaml'"
check "generated table equals a direct perl converter run" sh -c "perl '$MAIN/tools/cin2rime.pl' '$MAIN/tables/mscj3.cin' '$W/pl.yaml' --essay '$MAIN/data/essay.txt' >/dev/null && cmp -s '$W/pl.yaml' '$RD/cangjie3.base.dict.yaml'"
check "Squirrel --reload was called" grep -qx -- '--reload' "$LOG"
check "manifest written" test -s "$RD/.cangjie-fluency-macos.manifest"
check "installed sweep pad" test -s "$W/sweep/cangjie_sweep_pad.py"
check "installed sweep launcher" test -x "$W/bin/cangjie-sweep-pad"
check "installed sweep command" test -x "$W/apps/Cangjie Sweep.command"
check "sweep pad self-check passed" sh -c "printf '%s' \"\$1\" | grep -q 'Sweep Pad self-check passed'" _ "$OUT"

echo "== 2. identical re-run"
run --with-cangjie5 --offline
check "exit 0" test "$RC" = 0
check "no backups" test "$(bakcount)" = 0
check "says up to date" sh -c "printf '%s' \"\$1\" | grep -q 'up to date: cangjie3_fluency.schema.yaml'" _ "$OUT"
check "model recognised as present" sh -c "printf '%s' \"\$1\" | grep -q 'language model already present'" _ "$OUT"
check "default.custom.yaml: already listed" sh -c "printf '%s' \"\$1\" | grep -q 'already lists'" _ "$OUT"

echo "== 3. changed source: exactly one backup"
printf '# changed upstream\n' >> "$SRC/weasel/cangjie3_fluency.schema.yaml"
run --with-cangjie5 --offline --no-model
check "exactly one backup" test "$(bakcount)" = 1
check "backup is of the schema" test -n "$(ls "$RD" | grep '^cangjie3_fluency.schema.yaml.bak-')"
check "new content installed" grep -q 'changed upstream' "$RD/cangjie3_fluency.schema.yaml"
run --with-cangjie5 --offline --no-model
check "re-run again: still one backup" test "$(bakcount)" = 1
cp "$MAIN/weasel/cangjie3_fluency.schema.yaml" "$SRC/weasel/cangjie3_fluency.schema.yaml"

echo "== 4. default.custom.yaml cases"
dc_case() { # NAME  -> new env with a prepared default.custom.yaml (content in $W/dc.in), runs the installer
  new_env "$1"; cp "$W/dc.in" "$RD/default.custom.yaml"; run --no-model --no-deploy --offline
}
printf '%s\n' '# my config' 'patch:' '  schema_list:' '    - schema: luna_pinyin' '    - schema: cangjie5' '  menu/page_size: 7' > "$W/dc.in"
dc_case dc_lf
printf '%s\n' '# my config' 'patch:' '  schema_list:' '    - schema: cangjie3_fluency' '    - schema: cangjie3_fuzzy' '    - schema: luna_pinyin' '    - schema: cangjie5' '  menu/page_size: 7' > "$W/dc.want"
check "LF: inserted first, indentation kept, rest untouched" cmp -s "$W/dc.want" "$RD/default.custom.yaml"
check "LF: exactly one backup of default.custom.yaml" test "$(ls "$RD" | grep -c '^default.custom.yaml.bak-')" = 1
check "LF: backup equals the original" cmp -s "$W/dc.in" "$RD"/default.custom.yaml.bak-*

printf '# my config\r\npatch:\r\n  schema_list:\r\n    - schema: luna_pinyin\r\n    - schema: cangjie5' > "$W/dc.in"
dc_case dc_crlf
printf '# my config\r\npatch:\r\n  schema_list:\r\n    - schema: cangjie3_fluency\r\n    - schema: cangjie3_fuzzy\r\n    - schema: luna_pinyin\r\n    - schema: cangjie5' > "$W/dc.want"
check "CRLF, no trailing newline: CRLF kept, no newline added" cmp -s "$W/dc.want" "$RD/default.custom.yaml"

printf '%s\n' 'patch:' '  schema_list:' '    - {schema: luna_pinyin}' '    - {schema: cangjie5}' > "$W/dc.in"
dc_case dc_brace
printf '%s\n' 'patch:' '  schema_list:' '    - {schema: cangjie3_fluency}' '    - {schema: cangjie3_fuzzy}' '    - {schema: luna_pinyin}' '    - {schema: cangjie5}' > "$W/dc.want"
check "brace style kept" cmp -s "$W/dc.want" "$RD/default.custom.yaml"

printf '%s\n' 'patch:' '  menu/page_size: 7' > "$W/dc.in"
dc_case dc_nolist
check "no schema_list: file untouched" cmp -s "$W/dc.in" "$RD/default.custom.yaml"
check "no schema_list: no backup" test "$(ls "$RD" | grep -c '^default.custom.yaml.bak-')" = 0
check "no schema_list: tells the user what to add" sh -c "printf '%s' \"\$1\" | grep -q -- '- schema: cangjie3_fluency'" _ "$OUT"
check "no schema_list: installer still succeeded" test "$RC" = 0

printf '%s\n' 'patch:' '  schema_list:' '    - schema: luna_pinyin' '    - schema: cangjie3_fluency' '    - schema: cangjie3_fuzzy' > "$W/dc.in"
dc_case dc_already
check "already listed: untouched" cmp -s "$W/dc.in" "$RD/default.custom.yaml"
check "already listed: no backup" test "$(ls "$RD" | grep -c '^default.custom.yaml.bak-')" = 0

printf '%s\n' 'patch:' '  schema_list:' '    - schema: cangjie5_fluency' '    - schema: luna_pinyin' > "$W/dc.in"
dc_case dc_c5only
printf '%s\n' 'patch:' '  schema_list:' '    - schema: cangjie3_fluency' '    - schema: cangjie3_fuzzy' '    - schema: cangjie5_fluency' '    - schema: luna_pinyin' > "$W/dc.want"
check "only cangjie5_fluency listed: cangjie3_fluency added first (exact id match)" cmp -s "$W/dc.want" "$RD/default.custom.yaml"

echo "== 4b. fuzzy: files, order, options"
new_env fz1; run --with-cangjie5 --no-model --no-deploy --offline
for f in cangjie3_fuzzy.schema.yaml cangjie3_fuzzy_prism.schema.yaml cangjie5_fuzzy.schema.yaml cangjie5_fuzzy_prism.schema.yaml; do
  check "fuzzy: $f installed byte-identical to the repo copy" cmp -s "$MAIN/weasel/$f" "$RD/$f"
done
check "fuzzy default order: fluency first, fuzzy second" test "$(grep -- '- schema:' "$RD/default.custom.yaml" | head -4 | tr -d ' \n')" = "-schema:cangjie3_fluency-schema:cangjie3_fuzzy-schema:cangjie5_fluency-schema:cangjie5_fuzzy"
new_env fz2; run --with-cangjie5 --no-model --no-deploy --offline --fuzzy-default
check "--fuzzy-default fresh: fuzzy first" test "$(grep -- '- schema:' "$RD/default.custom.yaml" | head -4 | tr -d ' \n')" = "-schema:cangjie3_fuzzy-schema:cangjie5_fuzzy-schema:cangjie3_fluency-schema:cangjie5_fluency"
printf '%s\n' 'patch:' '  schema_list:' '    - schema: cangjie3_fluency' '    - schema: luna_pinyin' > "$W/dc.in"
new_env fz3; cp "$W/dc.in" "$RD/default.custom.yaml"; run --no-model --no-deploy --offline --fuzzy-default
check "--fuzzy-default existing list: fuzzy at the top" test "$(grep -- '- schema:' "$RD/default.custom.yaml" | tr -d ' \n')" = "-schema:cangjie3_fuzzy-schema:cangjie3_fluency-schema:luna_pinyin"
check "--fuzzy-default: the closing note names cangjie3_fuzzy as the default" sh -c "printf '%s' \"\$1\" | grep -q 'DEFAULT schema is cangjie3_fuzzy'" _ "$OUT"
new_env fz4; cp "$W/dc.in" "$RD/default.custom.yaml"; run --no-model --no-deploy --offline
check "default existing list: fuzzy right after fluency" test "$(grep -- '- schema:' "$RD/default.custom.yaml" | tr -d ' \n')" = "-schema:cangjie3_fluency-schema:cangjie3_fuzzy-schema:luna_pinyin"
new_env fz5; run --no-model --no-deploy --offline --no-fuzzy
check "--no-fuzzy: no fuzzy files" test -z "$(ls "$RD" | grep fuzzy)"
check "--no-fuzzy: no fuzzy id in the list" test -z "$(grep fuzzy "$RD/default.custom.yaml")"

echo "== 4c. fuzzy range"
for rg in narrow wide; do
  new_env rg_$rg; run --with-cangjie5 --no-model --no-deploy --offline --fuzzy-range $rg
  for f in cangjie3_fuzzy.schema.yaml cangjie3_fuzzy_prism.schema.yaml cangjie5_fuzzy.schema.yaml cangjie5_fuzzy_prism.schema.yaml; do
    check "--fuzzy-range $rg: $f is the $rg copy" cmp -s "$MAIN/weasel/fuzzy-$rg/$f" "$RD/$f"
  done
done
new_env rg_bad; run --no-model --no-deploy --offline --fuzzy-range huge
check "--fuzzy-range huge is refused" test "$RC" != 0

printf '%s\n' 'patch:' '  schema_list:' '    # - schema: cangjie3_fluency' '    - schema: luna_pinyin' > "$W/dc.in"
dc_case dc_comment
check "commented-out entry does not count" grep -qx '    - schema: cangjie3_fluency' "$RD/default.custom.yaml"

echo "== 5. --dry-run changes nothing and downloads nothing"
new_env dry; rmdir "$RD"
OUT=$(bash "$REPO/install.sh" --rime-dir "$RD" --with-cangjie5 --dry-run 2>&1); RC=$?
check "exit 0" test "$RC" = 0
check "Rime folder not created" test ! -e "$RD"
check "Squirrel not called" test ! -s "$LOG"
check "no network" test ! -s "$NETLOG"
check "dry-run: mentions Sweep Pad by default" sh -c "printf '%s' \"\$1\" | grep -q 'DRY: would install Sweep Pad'" _ "$OUT"
OUT_NOSWEEP=$(bash "$REPO/install.sh" --rime-dir "$RD" --dry-run --no-sweep 2>&1)
check "dry-run --no-sweep: skips Sweep Pad" sh -c "printf '%s' \"\$1\" | grep -q 'skipping Sweep Pad (--no-sweep)'" _ "$OUT_NOSWEEP"
check "dry-run --no-sweep: does not mention would install Sweep Pad" sh -c "! printf '%s' \"\$1\" | grep -q 'would install Sweep Pad'" _ "$OUT_NOSWEEP"
mkdir -p "$RD"; printf 'patch:\n  schema_list:\n    - schema: luna_pinyin\n' > "$RD/default.custom.yaml"; cp "$RD/default.custom.yaml" "$W/dry.before"
run --dry-run
check "existing default.custom.yaml untouched by dry run" cmp -s "$W/dry.before" "$RD/default.custom.yaml"
check "nothing else created" test "$(ls -A "$RD")" = "default.custom.yaml"

echo "== 6. --uninstall"
new_env uninst
run --with-cangjie5 --offline --no-model
printf "# changed\n" >> "$SRC/weasel/cangjie5_fluency.schema.yaml"; run --with-cangjie5 --offline --no-model   # makes one backup
printf "# user edit\n" >> "$RD/cangjie3_fluency.dict.yaml"
printf x > "$RD/keepme.txt"
BK=$(bakcount)
run --uninstall --no-deploy
check "exit 0" test "$RC" = 0
check "schema removed" test ! -e "$RD/cangjie3_fluency.schema.yaml"
check "generated table removed" test ! -e "$RD/cangjie3.base.dict.yaml"
check "file edited by the user is kept" test -e "$RD/cangjie3_fluency.dict.yaml"
check "foreign file kept" test -e "$RD/keepme.txt"
check "backups kept" test "$(bakcount)" = "$BK"
check "default.custom.yaml created by the installer and unchanged is removed" test ! -e "$RD/default.custom.yaml"
check "manifest removed" test ! -e "$RD/.cangjie-fluency-macos.manifest"
check "uninstall: sweep dir removed" test ! -e "$W/sweep"
check "uninstall: sweep launcher removed" test ! -e "$W/bin/cangjie-sweep-pad"
check "uninstall: sweep command removed" test ! -e "$W/apps/Cangjie Sweep.command"
cp "$MAIN/weasel/cangjie5_fluency.schema.yaml" "$SRC/weasel/cangjie5_fluency.schema.yaml"

echo "== 7. pre-existing file is replaced with a backup but never removed by --uninstall"
new_env preex
printf 'name: mine\n# my own schema\n' > "$RD/cangjie3_fluency.schema.yaml"
printf "patch:\n  schema_list:\n    - schema: luna_pinyin\n" > "$RD/default.custom.yaml"
run --no-model --no-deploy --offline
check "backup of the user's file" test "$(ls "$RD" | grep -c '^cangjie3_fluency.schema.yaml.bak-')" = 1
run --uninstall --no-deploy
check "pre-existing (replaced) file kept by uninstall" test -e "$RD/cangjie3_fluency.schema.yaml"
check "user default.custom.yaml (edited by us) is not touched by uninstall" test -e "$RD/default.custom.yaml"
check "uninstall tells the user to edit default.custom.yaml" sh -c "printf '%s' \"\$1\" | grep -q 'default.custom.yaml still lists'" _ "$OUT"

echo "== 8. Squirrel missing: installed from the bundled pkg (stub installer), present: left alone"
new_env nosq; export SQUIRREL_APP_DIR="$W/nosq/New.app"
cat > "$W/fake-installer.sh" <<'EOS'
#!/bin/sh
echo "$1" >> "$FAKE_INSTALL_LOG"
mkdir -p "$SQUIRREL_APP_DIR/Contents/MacOS" "$SQUIRREL_APP_DIR/Contents/SharedSupport"
printf '#!/bin/sh\nexit 0\n' > "$SQUIRREL_APP_DIR/Contents/MacOS/Squirrel"; chmod +x "$SQUIRREL_APP_DIR/Contents/MacOS/Squirrel"
EOS
chmod +x "$W/fake-installer.sh"; export FAKE_INSTALL_LOG="$W/fake-install.log"; : > "$FAKE_INSTALL_LOG"
export CJF_SQUIRREL_INSTALL_CMD="$W/fake-installer.sh"
run --no-model --no-deploy --offline
check "exit 0" test "$RC" = 0
check "pkg handed to the installer command (hash-checked bundle copy)" test -s "$FAKE_INSTALL_LOG"
check "Squirrel app now exists" test -d "$SQUIRREL_APP_DIR"
check "still zero network calls (offline, pkg from deps/)" test ! -s "$NETLOG"
check "tells the user to add Squirrel in Input Sources" sh -c "printf '%s' \"\$1\" | grep -q 'Input Sources'" _ "$OUT"
: > "$FAKE_INSTALL_LOG"; run --no-model --no-deploy --offline
check "Squirrel present: installer command NOT called again" test ! -s "$FAKE_INSTALL_LOG"
new_env nosq2; export SQUIRREL_APP_DIR="$W/nosq2/None.app"
run --no-model --no-deploy --offline --no-deps
check "--no-deps with Squirrel missing: fails clearly" test "$RC" != 0
check "--no-deps: pkg not touched" test ! -s "$FAKE_INSTALL_LOG"
# damaged pkg: SHA-256 mismatch stops before anything is installed
BADB="$W/badpkg"; mkdir -p "$BADB/deps"; cp -R "$SRC/weasel" "$BADB/weasel"; ln -s "$MAIN/tables" "$BADB/tables"; ln -s "$MAIN/data" "$BADB/data"; ln -s "$MAIN/tools" "$BADB/tools"; ln -s "$SRC/sweep-pad" "$BADB/sweep-pad"
printf 'not a pkg' > "$BADB/deps/Squirrel-1.1.2.pkg"
new_env nosq3; export SQUIRREL_APP_DIR="$W/nosq3/None.app"
OUT=$(CJF_SRC_DIR="$BADB" bash "$REPO/install.sh" --rime-dir "$RD" --no-model --no-deploy --offline 2>&1); RC=$?
check "bad pkg hash: stops" test "$RC" != 0
check "bad pkg hash: message" sh -c "printf '%s' \"\$1\" | grep -q 'SHA-256 mismatch'" _ "$OUT"
check "bad pkg hash: installer command not run" test ! -s "$FAKE_INSTALL_LOG"
unset CJF_SQUIRREL_INSTALL_CMD

echo "== 9. offline without a bundle fails; online path targets only the main repo; bad table hash stops"
new_env nobundle
mkdir "$W/solo"; cp "$REPO/install.sh" "$W/solo/install.sh"
OUT=$(env -u CJF_SRC_DIR bash "$W/solo/install.sh" --rime-dir "$RD" --no-model --no-deploy --offline 2>&1); RC=$?
check "offline, script alone: fails" test "$RC" != 0
check "offline, script alone: clear message" sh -c "printf '%s' \"\$1\" | grep -q -- '--offline'" _ "$OUT"
check "offline, script alone: no network" test ! -s "$NETLOG"
OUT=$(env -u CJF_SRC_DIR bash "$W/solo/install.sh" --rime-dir "$RD" --no-model --no-deploy --ref main 2>&1); RC=$?
check "online, script alone: curl asked for the main repo raw URL" grep -q 'raw.githubusercontent.com/githubhjs/cangjie-fluency/main/weasel/cangjie3_fluency.schema.yaml' "$NETLOG"
check "online: only the main repo is contacted" test -z "$(grep -v 'githubhjs/cangjie-fluency' "$NETLOG")"
BADT="$W/badtable"; mkdir -p "$BADT/tables"; cp -R "$SRC/weasel" "$BADT/weasel"; ln -s "$MAIN/data" "$BADT/data"; ln -s "$MAIN/tools" "$BADT/tools"; ln -s "$SRC/sweep-pad" "$BADT/sweep-pad"
cp "$MAIN/tables/mscj3.cin" "$BADT/tables/mscj3.cin"; printf 'x a\n' >> "$BADT/tables/mscj3.cin"
new_env badtable
OUT=$(CJF_SRC_DIR="$BADT" bash "$REPO/install.sh" --rime-dir "$RD" --no-model --no-deploy --offline 2>&1); RC=$?
check "bad table hash: stops" test "$RC" != 0
check "bad table hash: no generated table" test ! -e "$RD/cangjie3.base.dict.yaml"
new_env noessay noessay
OUT=$(inst --no-model --no-deploy --offline 2>&1); RC=$?
check "no Squirrel essay.txt: repo essay.txt installed into the Rime folder" test -s "$RD/essay.txt"
check "table still identical" cmp -s "$W/py.yaml" "$RD/cangjie3.base.dict.yaml"

echo "== 9b. sweep pad hash mismatch and offline"
# bundle with the main files but no sweep-pad/: the pad itself then comes from CJF_PAD_URL_BASE
NO_PAD_SRC="$W/bundle_nopad"; mkdir -p "$NO_PAD_SRC/deps"
cp -R "$MAIN/weasel" "$NO_PAD_SRC/weasel"; rm -rf "$NO_PAD_SRC/weasel/docs"
ln -s "$MAIN/tables" "$NO_PAD_SRC/tables"; ln -s "$MAIN/data" "$NO_PAD_SRC/data"; ln -s "$MAIN/tools" "$NO_PAD_SRC/tools"
ln -s "$MAIN/dl/Squirrel-1.1.2.pkg" "$NO_PAD_SRC/deps/Squirrel-1.1.2.pkg"
FAKE_PAD="$W/fake_pad_rel"; mkdir -p "$FAKE_PAD"
echo "corrupt data" > "$FAKE_PAD/cangjie-sweep-pad-v0.5.0.zip"
echo "0000000000000000000000000000000000000000000000000000000000000000  cangjie-sweep-pad-v0.5.0.zip" > "$FAKE_PAD/cangjie-sweep-pad-v0.5.0.zip.sha256"
new_env bad_pad_hash
OUT=$(CJF_PAD_URL_BASE="$FAKE_PAD" CJF_SRC_DIR="$NO_PAD_SRC" bash "$REPO/install.sh" --rime-dir "$RD" --no-model --no-deploy 2>&1); RC=$?
check "sweep pad bad hash: install stops" test "$RC" != 0
check "sweep pad bad hash: says SHA-256 mismatch" sh -c "printf '%s' \"\$1\" | grep -q 'SHA-256 mismatch'" _ "$OUT"

new_env offline_nopad
OUT=$(CJF_SRC_DIR="$NO_PAD_SRC" bash "$REPO/install.sh" --rime-dir "$RD" --offline --no-model --no-deploy 2>&1); RC=$?
check "offline without sweep-pad in bundle stops" test "$RC" != 0
check "offline without sweep-pad message" sh -c "printf '%s' \"\$1\" | grep -q 'sweep-pad/cangjie-sweep-pad.zip is missing'" _ "$OUT"

echo "== 10. static bash 3.2 review (patterns that do not exist in bash 3.2)"
for pat in "declare -A" mapfile readarray "&>>" "|&" sha256sum "readlink -f" "stat -c" "date -d" "sed -i" coproc "local -n"; do
  if grep -v "^[[:space:]]*#" "$REPO/install.sh" | grep -qF -- "$pat"; then bad "install.sh uses: $pat"; else ok "install.sh does not use: $pat"; fi
done
check "install.sh: no \${var,,} or \${var^^} (bash 4)" sh -c "! grep -v '^[[:space:]]*#' '$REPO/install.sh' | grep -Eq '\$\{[A-Za-z_0-9]+(,,|\^\^)'"
check "perl converter has no non-core module" sh -c "! grep -E '^use ' '$MAIN/tools/cin2rime.pl' | grep -Ev 'strict|warnings|utf8|Encode'"
check "install.sh has no third-party URL or Homebrew advice" sh -c "! grep -v 'python-tk' '$REPO/install.sh' | grep -Eqi 'EasyIME|PIME|rime/rime-|lotem/|brew install'"

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" = 0 ]
