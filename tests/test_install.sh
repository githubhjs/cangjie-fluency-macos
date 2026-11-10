#!/bin/bash
# Tests for install.sh. No network, no Squirrel needed: Squirrel is a fake app folder (SQUIRREL_APP_DIR) and every
# download URL points to file:// fixtures that are generated here (nothing from PIME is stored in this repo).
# Usage: bash tests/test_install.sh
# Written for bash 3.2 (no associative arrays, no ${var,,}, no mapfile).

REPO=$(cd "$(dirname "$0")/.." && pwd)
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

# ---------------------------------------------------------------- fixtures
SRC="$W/src"; mkdir -p "$SRC/weasel"
for f in cangjie3_fluency.schema.yaml cangjie3_fluency.dict.yaml cangjie5_fluency.schema.yaml cangjie5_fluency.dict.yaml; do
  { printf '# fixture %s\nname: %s\nversion: "1"\n' "$f" "$f"; for i in 1 2 3 4 5 6 7 8; do printf '# padding line %s to pass the size sanity check\n' "$i"; done; } > "$SRC/weasel/$f"
done
# synthetic .cin (about 30000 single characters, a few multi-character and U+3000 lines), synthetic essay and base table
perl -e '
  binmode(STDOUT, ":utf8");
  print "%gen ctest\n%keyname begin\na \x{65E5}\n%keyname end\n%chardef begin\n";
  my @l = ("a".."z"); my $n = 0;
  for my $x (@l) { for my $y (@l) { for my $z (@l) { for my $w (@l) { next if $n >= 30000;
    my $c = chr(0x4E00 + $n); $n++;
    print "$x$y$z$w $c\n"; print "$x$y$z$w\x{3000}extra\n" if $n % 5000 == 0; } } } }
  print "a \x{65E5}\nzzzz AB\n%chardef end\n";' > "$SRC/mscj3.cin"
perl -e '
  binmode(STDOUT, ":utf8");
  for my $n (0 .. 29999) { print chr(0x4E00 + $n), "\t", 1000 + ($n * 7) % 5000, "\n"; }
  for my $n (0 .. 40000) { print "word$n\t", 100 + $n, "\n"; }' > "$SRC/essay.txt"
head -c 1100000 /dev/zero | tr '\0' 'x' >> "$SRC/essay.txt"; printf '\n' >> "$SRC/essay.txt"
perl -e 'print "# fixture\n"; for my $n (1 .. 12000) { print "x$n\tabc\t1\n" }' > "$SRC/cangjie5.base.dict.yaml"
head -c 1000 /dev/zero | tr '\0' 'g' > "$SRC/model.gram"

export CJF_RAW_BASE="file://$SRC"
export CJF_CIN_URL="file://$SRC/mscj3.cin"
export CJF_ESSAY_URL="file://$SRC/essay.txt"
export CJF_C5BASE_URL="file://$SRC/cangjie5.base.dict.yaml"
export CJF_GRAM_URL="file://$SRC/model.gram"
export CJF_GRAM_SIZE=1000
export CJF_GRAM_URL2=
export CJF_MACOS_RAW="file://$REPO"

# new_env NAME [noessay] -> sets RD (rime dir), APP (fake Squirrel), LOG (stub log)
new_env() {
  local base="$W/$1"
  RD="$base/rime"; APP="$base/Squirrel.app"; LOG="$base/stub.log"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/SharedSupport" "$APP/Contents/Frameworks/rime-plugins" "$RD"
  : > "$APP/Contents/Frameworks/rime-plugins/librime-octagram.dylib"
  [ "${2:-}" = noessay ] || cp "$SRC/essay.txt" "$APP/Contents/SharedSupport/essay.txt"
  printf '#!/bin/sh\necho "$@" >> "%s"\n' "$LOG" > "$APP/Contents/MacOS/Squirrel"
  chmod +x "$APP/Contents/MacOS/Squirrel"
  export SQUIRREL_APP_DIR="$APP"
  : > "$LOG"
}
inst() { bash "$REPO/install.sh" --rime-dir "$RD" "$@"; }   # output in $OUT
run()  { OUT=$(inst "$@" 2>&1); RC=$?; }
bakcount() { count_bak "$RD"; }

echo "== 1. fresh install"
new_env fresh
run --with-cangjie5
[ "$RC" = 0 ] || printf "%s\n" "$OUT"
check "exit 0" test "$RC" = 0
for f in cangjie3_fluency.schema.yaml cangjie3_fluency.dict.yaml cangjie3.base.dict.yaml cangjie5_fluency.schema.yaml \
         cangjie5_fluency.dict.yaml cangjie5.base.dict.yaml zh-hant-t-essay-bgw.gram default.custom.yaml; do
  check "installed $f" test -s "$RD/$f"
done
check "essay.txt not copied (found in the Squirrel bundle)" test ! -e "$RD/essay.txt"
check "no backups" test "$(bakcount)" = 0
check "no .part files left" test -z "$(ls "$RD" | grep '\.part$')"
check "default.custom.yaml: cangjie3_fluency is first schema" test "$(grep -- '- schema:' "$RD/default.custom.yaml" | head -1)" = "    - schema: cangjie3_fluency"
check "default.custom.yaml lists cangjie5_fluency" grep -q 'schema: cangjie5_fluency$' "$RD/default.custom.yaml"
perl "$REPO/tools/cin2rime.pl" "$SRC/mscj3.cin" "$W/expect.yaml" --essay "$SRC/essay.txt" >/dev/null
check "generated table equals perl converter output with the bundled essay.txt" cmp -s "$W/expect.yaml" "$RD/cangjie3.base.dict.yaml"
check "Squirrel --reload was called" grep -qx -- '--reload' "$LOG"
check "manifest written" test -s "$RD/.cangjie-fluency-macos.manifest"

echo "== 2. identical re-run"
run --with-cangjie5
check "exit 0" test "$RC" = 0
check "no backups" test "$(bakcount)" = 0
check "says up to date" sh -c "printf '%s' \"\$1\" | grep -q 'up to date: cangjie3_fluency.schema.yaml'" _ "$OUT"
check "default.custom.yaml: already listed" sh -c "printf '%s' \"\$1\" | grep -q 'already lists'" _ "$OUT"

echo "== 3. changed source: exactly one backup"
printf '# changed upstream\n' >> "$SRC/weasel/cangjie3_fluency.schema.yaml"
run --with-cangjie5
check "exactly one backup" test "$(bakcount)" = 1
check "backup is of the schema" test -n "$(ls "$RD" | grep '^cangjie3_fluency.schema.yaml.bak-')"
check "new content installed" grep -q 'changed upstream' "$RD/cangjie3_fluency.schema.yaml"
run --with-cangjie5
check "re-run again: still one backup" test "$(bakcount)" = 1
cp "$SRC/weasel/cangjie3_fluency.schema.yaml" "$W/sch.changed"
head -n -1 "$W/sch.changed" > "$SRC/weasel/cangjie3_fluency.schema.yaml"    # restore the fixture

echo "== 4. default.custom.yaml cases"
dc_case() { # NAME  -> new env with a prepared default.custom.yaml (content in $W/dc.in), runs the installer
  new_env "$1"; cp "$W/dc.in" "$RD/default.custom.yaml"; run --no-model --no-deploy
}
printf '%s\n' '# my config' 'patch:' '  schema_list:' '    - schema: luna_pinyin' '    - schema: cangjie5' '  menu/page_size: 7' > "$W/dc.in"
dc_case dc_lf
printf '%s\n' '# my config' 'patch:' '  schema_list:' '    - schema: cangjie3_fluency' '    - schema: luna_pinyin' '    - schema: cangjie5' '  menu/page_size: 7' > "$W/dc.want"
check "LF: inserted first, indentation kept, rest untouched" cmp -s "$W/dc.want" "$RD/default.custom.yaml"
check "LF: exactly one backup of default.custom.yaml" test "$(ls "$RD" | grep -c '^default.custom.yaml.bak-')" = 1
check "LF: backup equals the original" cmp -s "$W/dc.in" "$RD"/default.custom.yaml.bak-*

printf '# my config\r\npatch:\r\n  schema_list:\r\n    - schema: luna_pinyin\r\n    - schema: cangjie5' > "$W/dc.in"
dc_case dc_crlf
printf '# my config\r\npatch:\r\n  schema_list:\r\n    - schema: cangjie3_fluency\r\n    - schema: luna_pinyin\r\n    - schema: cangjie5' > "$W/dc.want"
check "CRLF, no trailing newline: CRLF kept, no newline added" cmp -s "$W/dc.want" "$RD/default.custom.yaml"

printf '%s\n' 'patch:' '  schema_list:' '    - {schema: luna_pinyin}' '    - {schema: cangjie5}' > "$W/dc.in"
dc_case dc_brace
printf '%s\n' 'patch:' '  schema_list:' '    - {schema: cangjie3_fluency}' '    - {schema: luna_pinyin}' '    - {schema: cangjie5}' > "$W/dc.want"
check "brace style kept" cmp -s "$W/dc.want" "$RD/default.custom.yaml"

printf '%s\n' 'patch:' '  menu/page_size: 7' > "$W/dc.in"
dc_case dc_nolist
check "no schema_list: file untouched" cmp -s "$W/dc.in" "$RD/default.custom.yaml"
check "no schema_list: no backup" test "$(ls "$RD" | grep -c '^default.custom.yaml.bak-')" = 0
check "no schema_list: tells the user what to add" sh -c "printf '%s' \"\$1\" | grep -q -- '- schema: cangjie3_fluency'" _ "$OUT"
check "no schema_list: installer still succeeded" test "$RC" = 0

printf '%s\n' 'patch:' '  schema_list:' '    - schema: luna_pinyin' '    - schema: cangjie3_fluency' > "$W/dc.in"
dc_case dc_already
check "already listed: untouched" cmp -s "$W/dc.in" "$RD/default.custom.yaml"
check "already listed: no backup" test "$(ls "$RD" | grep -c '^default.custom.yaml.bak-')" = 0

printf '%s\n' 'patch:' '  schema_list:' '    - schema: cangjie5_fluency' '    - schema: luna_pinyin' > "$W/dc.in"
dc_case dc_c5only
printf '%s\n' 'patch:' '  schema_list:' '    - schema: cangjie3_fluency' '    - schema: cangjie5_fluency' '    - schema: luna_pinyin' > "$W/dc.want"
check "only cangjie5_fluency listed: cangjie3_fluency added first (exact id match)" cmp -s "$W/dc.want" "$RD/default.custom.yaml"

printf '%s\n' 'patch:' '  schema_list:' '    # - schema: cangjie3_fluency' '    - schema: luna_pinyin' > "$W/dc.in"
dc_case dc_comment
check "commented-out entry does not count" grep -qx '    - schema: cangjie3_fluency' "$RD/default.custom.yaml"

echo "== 5. --dry-run changes nothing and downloads nothing"
new_env dry; rmdir "$RD"
OUT=$(CJF_CIN_URL=file:///nonexistent CJF_GRAM_URL=file:///nonexistent CJF_RAW_BASE=file:///nonexistent bash "$REPO/install.sh" --rime-dir "$RD" --with-cangjie5 --dry-run 2>&1); RC=$?
check "exit 0" test "$RC" = 0
check "Rime folder not created" test ! -e "$RD"
check "Squirrel not called" test ! -s "$LOG"
mkdir -p "$RD"; printf 'patch:\n  schema_list:\n    - schema: luna_pinyin\n' > "$RD/default.custom.yaml"; cp "$RD/default.custom.yaml" "$W/dry.before"
run --dry-run
check "existing default.custom.yaml untouched by dry run" cmp -s "$W/dry.before" "$RD/default.custom.yaml"
check "nothing else created" test "$(ls -A "$RD")" = "default.custom.yaml"

echo "== 6. --uninstall"
new_env uninst
run --with-cangjie5
printf "# changed\n" >> "$SRC/weasel/cangjie5_fluency.schema.yaml"; run --with-cangjie5   # makes one backup
printf "# user edit\n" >> "$RD/cangjie3_fluency.dict.yaml"
printf x > "$RD/keepme.txt"; cp "$RD/default.custom.yaml" "$W/uninst.dc"
BK=$(bakcount)
run --uninstall --no-deploy
check "exit 0" test "$RC" = 0
check "schema removed" test ! -e "$RD/cangjie3_fluency.schema.yaml"
check "generated table removed" test ! -e "$RD/cangjie3.base.dict.yaml"
check "language model removed" test ! -e "$RD/zh-hant-t-essay-bgw.gram"
check "file edited by the user is kept" test -e "$RD/cangjie3_fluency.dict.yaml"
check "foreign file kept" test -e "$RD/keepme.txt"
check "backups kept" test "$(bakcount)" = "$BK"
check "default.custom.yaml created by the installer and unchanged is removed" test ! -e "$RD/default.custom.yaml"
check "manifest removed" test ! -e "$RD/.cangjie-fluency-macos.manifest"

head -n -1 "$SRC/weasel/cangjie5_fluency.schema.yaml" > "$W/c5.restore" && cp "$W/c5.restore" "$SRC/weasel/cangjie5_fluency.schema.yaml"

echo "== 7. pre-existing file is replaced with a backup but never removed by --uninstall"
new_env preex
printf 'name: mine\n# my own schema\n' > "$RD/cangjie3_fluency.schema.yaml"
printf "patch:\n  schema_list:\n    - schema: luna_pinyin\n" > "$RD/default.custom.yaml"; cp "$RD/default.custom.yaml" "$W/preex.dc"
run --no-model --no-deploy
check "backup of the user's file" test "$(ls "$RD" | grep -c '^cangjie3_fluency.schema.yaml.bak-')" = 1
run --uninstall --no-deploy
check "pre-existing (replaced) file kept by uninstall" test -e "$RD/cangjie3_fluency.schema.yaml"
check "user default.custom.yaml (edited by us) is not touched by uninstall" test -e "$RD/default.custom.yaml"
check "uninstall tells the user to edit default.custom.yaml" sh -c "printf '%s' \"\$1\" | grep -q 'default.custom.yaml still lists'" _ "$OUT"

echo "== 8. no Squirrel -> clear error; essay.txt downloaded when missing; stand-alone script downloads the converter"
new_env nosq; export SQUIRREL_APP_DIR="$W/does-not-exist"
run
check "fails" test "$RC" != 0
check "mentions the right cask name" sh -c "printf '%s' \"\$1\" | grep -q 'brew install --cask squirrel-app'" _ "$OUT"
new_env noessay noessay
mkdir "$W/solo"; cp "$REPO/install.sh" "$W/solo/install.sh"
OUT=$(bash "$W/solo/install.sh" --rime-dir "$RD" --no-model --no-deploy 2>&1); RC=$?
check "stand-alone run exit 0" test "$RC" = 0
check "essay.txt downloaded into the Rime folder" test -s "$RD/essay.txt"
check "converter downloaded (not next to the script)" sh -c "printf '%s' \"\$1\" | grep -q 'downloading tools/cin2rime.pl'" _ "$OUT"
check "table equals the converter output" cmp -s "$W/expect.yaml" "$RD/cangjie3.base.dict.yaml"
check "model skipped with --no-model" test ! -e "$RD/zh-hant-t-essay-bgw.gram"

echo "== 9. wrong model size is rejected"
new_env badgram
OUT=$(CJF_GRAM_URL2= CJF_GRAM_SIZE=999 bash "$REPO/install.sh" --rime-dir "$RD" --no-deploy 2>&1); RC=$?
check "fails on size mismatch" test "$RC" != 0
check "no model installed" test ! -e "$RD/zh-hant-t-essay-bgw.gram"
new_env mirror
OUT=$(CJF_GRAM_URL=file:///nonexistent CJF_GRAM_URL2="file://$SRC/model.gram" bash "$REPO/install.sh" --rime-dir "$RD" --no-deploy 2>&1); RC=$?
check "falls back to the second model URL" test "$RC" = 0 -a -s "$RD/zh-hant-t-essay-bgw.gram"

echo "== 10. static bash 3.2 review (patterns that do not exist in bash 3.2)"
for pat in "declare -A" mapfile readarray "&>>" "|&" sha256sum "readlink -f" "stat -c" "date -d" "sed -i" coproc "local -n"; do
  if grep -v "^[[:space:]]*#" "$REPO/install.sh" | grep -qF -- "$pat"; then bad "install.sh uses: $pat"; else ok "install.sh does not use: $pat"; fi
done
check "install.sh: no \${var,,} or \${var^^} (bash 4)" sh -c "! grep -v '^[[:space:]]*#' '$REPO/install.sh' | grep -Eq '\$\{[A-Za-z_0-9]+(,,|\^\^)'"
check "perl converter has no non-core module" sh -c "! grep -E '^use ' '$REPO/tools/cin2rime.pl' | grep -Ev 'strict|warnings|utf8|Encode'"

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" = 0 ]
