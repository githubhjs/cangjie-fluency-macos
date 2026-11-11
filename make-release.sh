#!/bin/bash
# Build the release zips of cangjie-fluency-macos.
#   usage: ./make-release.sh MAIN_REPO_CHECKOUT VERSION        e.g. ./make-release.sh ~/projects/cangjie-fluency v0.2.0
#   output: dist/cangjie-fluency-macos-VERSION-full.zip   everything needed offline (install.sh --offline works),
#                                                         including deps/Squirrel-1.1.2.pkg (unmodified upstream, GPL-3.0)
#           dist/cangjie-fluency-macos-VERSION-slim.zip   installer + schema files + converter; the rest (tables, word list,
#                                                         model, Squirrel pkg) is downloaded from the main repo
#                                                         (githubhjs/cangjie-fluency) at install time
# Bundle layout (what install.sh looks for next to itself): weasel/ tables/ data/ tools/ deps/
# The Squirrel pkg is taken from MAIN_REPO_CHECKOUT/dl/ (the file published in the release deps-v1).
set -eu
[ $# -eq 2 ] || { sed -n '2,9p' "$0"; exit 2; }
MAIN="$(cd "$1" && pwd)"; VER="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="cangjie-fluency-macos-$VER"
OUT="$HERE/dist"; mkdir -p "$OUT"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/cjf-rel.XXXXXX")"; trap 'rm -rf "$STAGE"' EXIT

sha256() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'; else sha256sum "$1" | awk '{print $1}'; fi; }
need() { [ -f "$MAIN/$1" ] || { echo "missing in main repo checkout: $1" >&2; exit 1; }; }
for f in weasel/cangjie3_fluency.schema.yaml weasel/cangjie3_fluency.dict.yaml weasel/cangjie5_fluency.schema.yaml \
         weasel/cangjie5_fluency.dict.yaml weasel/cangjie3_fuzzy.schema.yaml weasel/cangjie3_fuzzy_prism.schema.yaml weasel/cangjie5_fuzzy.schema.yaml weasel/cangjie5_fuzzy_prism.schema.yaml weasel/fuzzy-narrow/cangjie3_fuzzy.schema.yaml weasel/fuzzy-narrow/cangjie3_fuzzy_prism.schema.yaml weasel/fuzzy-narrow/cangjie5_fuzzy.schema.yaml weasel/fuzzy-narrow/cangjie5_fuzzy_prism.schema.yaml weasel/fuzzy-wide/cangjie3_fuzzy.schema.yaml weasel/fuzzy-wide/cangjie3_fuzzy_prism.schema.yaml weasel/fuzzy-wide/cangjie5_fuzzy.schema.yaml weasel/fuzzy-wide/cangjie5_fuzzy_prism.schema.yaml tools/cin2rime.pl tables/mscj3.cin tables/cangjie5.base.dict.yaml tables/SHA256SUMS \
         tables/README.md data/essay.txt data/zh-hant-t-essay-bgw.gram data/SHA256SUMS data/README.md \
         dl/Squirrel-1.1.2.pkg dl/NOTICE-third-party.txt dl/squirrel-LICENSE.txt; do need "$f"; done

# the hashes pinned in install.sh must match the files being shipped
for f in tables/mscj3.cin tables/cangjie5.base.dict.yaml data/essay.txt data/zh-hant-t-essay-bgw.gram dl/Squirrel-1.1.2.pkg; do
  h="$(sha256 "$MAIN/$f")"
  grep -q "$h" "$HERE/install.sh" || { echo "install.sh does not pin the SHA-256 of $f ($h)" >&2; exit 1; }
done

# fetch and verify Sweep Pad for the full offline bundle
PAD_REF="$(grep '^PAD_REF=' "$HERE/install.sh" | head -n1 | cut -d'"' -f2)"
PAD_REF="${CJF_PAD_REF:-${PAD_REF:-v0.3.0}}"
PAD_STAGE="$STAGE/sweep-pad"
mkdir -p "$PAD_STAGE"
PAD_URL_BASE="${CJF_PAD_URL_BASE:-https://github.com/githubhjs/cangjie-fuzzy-core/releases/download/$PAD_REF}"
PAD_ZIP_NAME="cangjie-sweep-pad-$PAD_REF.zip"
PAD_SHA_NAME="cangjie-sweep-pad-$PAD_REF.zip.sha256"

if [ -n "${CJF_PAD_ZIP:-}" ] && [ -f "$CJF_PAD_ZIP" ]; then
  cp "$CJF_PAD_ZIP" "$PAD_STAGE/cangjie-sweep-pad.zip"
  if [ -f "$CJF_PAD_ZIP.sha256" ]; then
    cp "$CJF_PAD_ZIP.sha256" "$PAD_STAGE/cangjie-sweep-pad.zip.sha256"
  fi
elif [ -d "$PAD_URL_BASE" ]; then
  cp "$PAD_URL_BASE/$PAD_ZIP_NAME" "$PAD_STAGE/cangjie-sweep-pad.zip"
  cp "$PAD_URL_BASE/$PAD_SHA_NAME" "$PAD_STAGE/cangjie-sweep-pad.zip.sha256"
else
  curl -fsSL --retry 3 -o "$PAD_STAGE/cangjie-sweep-pad.zip" "$PAD_URL_BASE/$PAD_ZIP_NAME"
  curl -fsSL --retry 3 -o "$PAD_STAGE/cangjie-sweep-pad.zip.sha256" "$PAD_URL_BASE/$PAD_SHA_NAME"
fi

if [ -f "$PAD_STAGE/cangjie-sweep-pad.zip.sha256" ]; then
  want_pad_sha="$(awk '{print $1}' "$PAD_STAGE/cangjie-sweep-pad.zip.sha256")"
  got_pad_sha="$(sha256 "$PAD_STAGE/cangjie-sweep-pad.zip")"
  [ "$want_pad_sha" = "$got_pad_sha" ] || { echo "Sweep Pad SHA-256 mismatch (want $want_pad_sha, got $got_pad_sha)" >&2; exit 1; }
fi

build() { # build full|slim
  kind="$1"; d="$STAGE/$NAME-$kind/$NAME"
  mkdir -p "$d/weasel" "$d/tools"
  cp "$HERE/install.sh" "$HERE/README.md" "$HERE/LICENSE" "$d/"
  chmod +x "$d/install.sh"
  for f in cangjie3_fluency.schema.yaml cangjie3_fluency.dict.yaml cangjie5_fluency.schema.yaml cangjie5_fluency.dict.yaml \
           cangjie3_fuzzy.schema.yaml cangjie3_fuzzy_prism.schema.yaml cangjie5_fuzzy.schema.yaml cangjie5_fuzzy_prism.schema.yaml; do cp "$MAIN/weasel/$f" "$d/weasel/"; done
  for rg in narrow wide; do mkdir -p "$d/weasel/fuzzy-$rg"; for f in cangjie3_fuzzy.schema.yaml cangjie3_fuzzy_prism.schema.yaml cangjie5_fuzzy.schema.yaml cangjie5_fuzzy_prism.schema.yaml; do cp "$MAIN/weasel/fuzzy-$rg/$f" "$d/weasel/fuzzy-$rg/"; done; done
  cp "$MAIN/tools/cin2rime.pl" "$d/tools/"
  if [ "$kind" = full ]; then
    mkdir -p "$d/tables" "$d/data" "$d/deps" "$d/sweep-pad"
    cp "$MAIN/tables/mscj3.cin" "$MAIN/tables/cangjie5.base.dict.yaml" "$MAIN/tables/SHA256SUMS" "$MAIN/tables/README.md" "$d/tables/"
    cp "$MAIN/data/essay.txt" "$MAIN/data/zh-hant-t-essay-bgw.gram" "$MAIN/data/SHA256SUMS" "$MAIN/data/README.md" "$d/data/"
    cp "$MAIN/dl/Squirrel-1.1.2.pkg" "$MAIN/dl/NOTICE-third-party.txt" "$MAIN/dl/squirrel-LICENSE.txt" "$d/deps/"
    cp "$PAD_STAGE/cangjie-sweep-pad.zip" "$d/sweep-pad/cangjie-sweep-pad.zip"
    if [ -f "$PAD_STAGE/cangjie-sweep-pad.zip.sha256" ]; then
      cp "$PAD_STAGE/cangjie-sweep-pad.zip.sha256" "$d/sweep-pad/cangjie-sweep-pad.zip.sha256"
    fi
  fi
  rm -f "$OUT/$NAME-$kind.zip"
  (cd "$STAGE/$NAME-$kind" && zip -q -r -X "$OUT/$NAME-$kind.zip" "$NAME")
  ls -l "$OUT/$NAME-$kind.zip" | awk '{print $5, $9}'
}
build full
build slim
(cd "$OUT" && for z in "$NAME-full.zip" "$NAME-slim.zip"; do printf '%s  %s\n' "$(sha256 "$z")" "$z"; done > "$NAME.SHA256SUMS" && cat "$NAME.SHA256SUMS")
