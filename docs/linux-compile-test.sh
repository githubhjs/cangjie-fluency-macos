#!/bin/bash
# Linux compile test for cangjie-fluency-macos (nothing here runs on a Mac).
# Needs the librime harness of the main repo (rimebin/, testenv/shared_nogy, weasel/docs/rime_driver.py):
#   MAIN=/home/hjs/projects/cangjie-fluency bash docs/linux-compile-test.sh
# No network: the installer runs with --offline on the main repo checkout (bundle layout). Writes only to ./testenv/ (git-ignored).
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
MAIN="${MAIN:-/home/hjs/projects/cangjie-fluency}"
T="$HERE/testenv/c3mac"
RD="$T/rime"; APP="$T/Squirrel.app"; SH="$T/shared"; DL="$T/dl"
R="$MAIN/rimebin/root"
export LD_LIBRARY_PATH="$R/usr/lib/aarch64-linux-gnu"

echo "### 0. clean state"
rm -r "$T" 2>/dev/null
mkdir -p "$RD" "$DL" "$APP/Contents/MacOS" "$APP/Contents/SharedSupport" "$APP/Contents/Frameworks/rime-plugins"
: > "$APP/Contents/Frameworks/rime-plugins/librime-octagram.dylib"
printf '#!/bin/sh\necho "stub Squirrel called with: $@"\n' > "$APP/Contents/MacOS/Squirrel"; chmod +x "$APP/Contents/MacOS/Squirrel"
echo "fake Squirrel app (no essay.txt in it, so the installer installs the repo essay.txt): $APP"

echo; echo "### 1. install.sh --offline (bundle = main repo checkout, --with-cangjie5)"
time SQUIRREL_APP_DIR="$APP" CJF_SRC_DIR="$MAIN" bash "$HERE/install.sh" --offline --rime-dir "$RD" --with-cangjie5
echo "exit=$?"; ls -l "$RD"

echo; echo "### 2. identical re-run (must change nothing, make no backup)"
SQUIRREL_APP_DIR="$APP" CJF_SRC_DIR="$MAIN" bash "$HERE/install.sh" --offline --rime-dir "$RD" --with-cangjie5 --no-deploy
echo "backups: $(ls "$RD" | grep -c '\.bak-')"

echo; echo "### 3. generated table vs the python converter (repo tables/mscj3.cin and data/essay.txt)"
sha256sum "$MAIN/tables/mscj3.cin" "$RD/essay.txt"
python3 -I "$MAIN/tools/cin2rime.py" "$MAIN/tables/mscj3.cin" "$DL/py.dict.yaml" --essay "$MAIN/data/essay.txt"
cmp "$DL/py.dict.yaml" "$RD/cangjie3.base.dict.yaml" && echo "BYTE-IDENTICAL: installer output == cin2rime.py output"
sha256sum "$DL/py.dict.yaml" "$RD/cangjie3.base.dict.yaml"

echo; echo "### 4. build with librime (rime_deployer --build), model only in the user dir"
mkdir -p "$SH"
for f in "$MAIN"/testenv/shared_nogy/*; do case "$f" in *.gram) ;; *) cp "$f" "$SH/" ;; esac; done
ls "$SH"
echo "default.custom.yaml written by the installer:"; cat "$RD/default.custom.yaml"
time "$R/usr/bin/rime_deployer" --build "$RD" "$SH"
echo "build exit=$?"; ls -l "$RD/build"

echo; echo "### 5. per-key traces (3rd-gen codes taken from the generated table)"
python3 -I "$MAIN/weasel/docs/rime_driver.py" --root "$R" --shared "$SH" --user "$RD" --base "$RD/cangjie3.base.dict.yaml" \
  --schema cangjie3_fluency --no-commit --log-dir "$T/log" "trace:面" "trace:板橋" "keys:mwyl" "keys:dhedhkb" "keys:l oj" 2>&1
echo; echo "grammar log line:"; grep -h "use grammar" "$T"/log/* 2>/dev/null | sort -u | head -3
echo "cangjie5_fluency (--with-cangjie5) builds? schema file present in build:"; ls "$RD/build" | grep -c cangjie5_fluency
