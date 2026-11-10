#!/bin/bash
# cangjie-fluency-macos installer: Microsoft-style sentence input for Cangjie on Squirrel (Rime for macOS).
#
# bash 3.2 compatible (the bash that ships with macOS). Uses only: curl, perl (/usr/bin/perl), awk, cmp, wc, tr, cksum/shasum.
# No python, no GNU-only options (no sha256sum, readlink -f, stat -c, date -d, sed -i).
#
# Run (safer form: download, read, run):
#   curl -fsSL -o install.sh https://raw.githubusercontent.com/githubhjs/cangjie-fluency-macos/main/install.sh
#   bash install.sh --dry-run
#   bash install.sh
#
# Everything is written below the Rime user folder (default ~/Library/Rime). No sudo.
# Existing files are never overwritten without a timestamped backup (*.bak-YYYYmmdd-HHMMSS).

# Everything is inside functions and main runs on the last line, so "curl ... | bash" cannot be
# truncated or have its stdin eaten half-way through.

CJF_VERSION="0.1.0"

usage() {
  cat <<'USAGE'
usage: bash install.sh [options]

  --rime-dir DIR     Rime user folder (default: $RIME_DIR, else ~/Library/Rime)
  --ref TAG          version (tag/branch) of githubhjs/cangjie-fluency to take the schema files from (default: v0.2.0)
  --with-cangjie5    also install the 5th-generation schema cangjie5_fluency (+ cangjie5.base.dict.yaml)
  --no-model         do not download the 41 MB language model (zh-hant-t-essay-bgw.gram)
  --no-deploy        install files only; do not ask Squirrel to redeploy
  --dry-run          show what would be done; change nothing, download nothing
  --uninstall        remove the files this installer created (backups and your default.custom.yaml are kept)
  -h, --help         this text
USAGE
}

say()  { printf '[cangjie-fluency] %s\n' "$*"; }
warn() { printf '[cangjie-fluency] WARNING: %s\n' "$*" >&2; }
die()  { printf '[cangjie-fluency] ERROR: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- helpers (bash 3.2, BSD tools)

file_size() { wc -c < "$1" | tr -d ' \t'; }

same_content() { [ -f "$2" ] && cmp -s "$1" "$2"; }

# sha256 for display only: shasum (macOS), else openssl, else cksum
checksum_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print "sha256:" $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print "sha256:" $NF}'
  else
    cksum < "$1" | awk '{print "cksum:" $1 "-" $2}'
  fi
}

# download URL DEST LABEL  (progress bar only for big files on a terminal)
progress_flag() { if [ "${1:-}" = "big" ] && [ -t 2 ]; then printf %s "-#"; else printf %s "-sS"; fi; }

download() {
  local url="$1" dest="$2" label="$3" prog
  prog=$(progress_flag "${4:-}")
  say "downloading $label"
  curl -fL $prog --retry 2 --connect-timeout 20 -o "$dest" "$url" || die "download failed: $url"
}

require_min() { # FILE MINBYTES LABEL
  local n
  n=$(file_size "$1")
  [ "$n" -ge "$2" ] || die "$3 is only $n bytes (expected at least $2); the download looks wrong"
}

# manifest: one line per file this installer created:  <cksum crc> <size> <name>
manifest_has() { [ -f "$MANIFEST" ] && awk -v n="$1" '$3==n {f=1} END {exit f?0:1}' "$MANIFEST"; }

manifest_set() { # NAME  (records the current content of $RIME_DIR/NAME)
  local name="$1" tmp
  tmp="$TMP/manifest.new"
  if [ -f "$MANIFEST" ]; then awk -v n="$name" '$3!=n' "$MANIFEST" > "$tmp"; else : > "$tmp"; fi
  printf '%s %s\n' "$(cksum < "$RIME_DIR/$name" | awk '{print $1 " " $2}')" "$name" >> "$tmp"
  cp "$tmp" "$MANIFEST"
}

backup_file() { # PATH -> prints backup path
  local p="$1" b n=1
  b="$p.bak-$STAMP"
  while [ -e "$b" ]; do n=$((n + 1)); b="$p.bak-$STAMP-$n"; done
  cp -p "$p" "$b" || die "cannot back up $p"
  printf '%s' "$b"
}

# place TMPFILE NAME : identical content = nothing; changed = one backup, then replace; new = create.
# Files that did not exist before are recorded in the manifest (so --uninstall removes only those).
place_file() {
  local tmp="$1" name="$2" dest b
  dest="$RIME_DIR/$name"
  if [ -f "$dest" ]; then
    if cmp -s "$tmp" "$dest"; then
      say "up to date: $name"
      return 0
    fi
    b=$(backup_file "$dest")
    say "backed up $name -> $(basename "$b")"
    cp "$tmp" "$dest.part" && mv "$dest.part" "$dest" || die "cannot write $dest"
    say "updated: $name"
    if manifest_has "$name"; then manifest_set "$name"; fi
  else
    cp "$tmp" "$dest.part" && mv "$dest.part" "$dest" || die "cannot write $dest"
    say "installed: $name"
    manifest_set "$name"
  fi
}

# the schema files are never copied into this repo: take a local copy only when one sits next to this script
find_local() { # NAME -> path or empty
  local n="$1" d
  [ -n "${SCRIPT_DIR:-}" ] || return 0
  for d in "$SCRIPT_DIR" "$SCRIPT_DIR/weasel"; do
    if [ -f "$d/$n" ]; then printf '%s' "$d/$n"; return 0; fi
  done
  return 0
}

# ---------------------------------------------------------------- default.custom.yaml surgery (perl, binary-safe)
# usage: perl - IN OUT ID...   prints one of: already | patched | nolist | inline
# patched: OUT holds the new content with every missing ID inserted as the first entries of schema_list
# (indentation, line endings, "- {schema: x}" brace style and a missing final newline are preserved).
patch_schema_list() {
  "$PERL" - "$@" <<'PERL'
use strict;
use warnings;
my ($in, $out, @ids) = @ARGV;
open(my $fh, '<:raw', $in) or die "cannot read $in: $!\n";
local $/;
my $data = <$fh>;
close $fh;
$data = '' unless defined $data;
my @lines = split(/(?<=\n)/, $data);
my $key = -1;
for my $i (0 .. $#lines) {
    my $t = $lines[$i];
    $t =~ s/\r?\n\z//;
    if ($t =~ /\A([ \t]*)schema_list:[ \t]*(?:#.*)?\z/) { $key = $i; last; }
    if ($t =~ /\A[ \t]*schema_list:[ \t]*\S/ && $t !~ /\A[ \t]*schema_list:[ \t]*#/) { print "inline\n"; exit 0; }
}
if ($key < 0) { print "nolist\n"; exit 0; }
(my $kl = $lines[$key]) =~ s/\r?\n\z//;
my ($kind) = $kl =~ /\A([ \t]*)/;
my $eol = ($lines[$key] =~ /(\r?\n)\z/) ? $1 : (($data =~ /\r\n/) ? "\r\n" : "\n");

# scan the list body: collect listed ids, find the first item (for indentation and style)
my ($indent, $first, $brace_in);
my %listed;
for my $j ($key + 1 .. $#lines) {
    my $t = $lines[$j];
    $t =~ s/\r?\n\z//;
    next if $t =~ /\A[ \t]*(?:#.*)?\z/;
    my ($ind) = $t =~ /\A([ \t]*)/;
    my $is_item = ($t =~ /\A[ \t]*-(?:[ \t]|\z)/);
    last if !$is_item && length($ind) <= length($kind);
    next unless $is_item;
    if (!defined $first) {
        $first = $j;
        $indent = $ind;
        if ($t =~ /\A[ \t]*-[ \t]*\{([ \t]*)schema:/) { $brace_in = $1; }
    }
    my $body = $t;
    $body =~ s/#.*\z//;
    while ($body =~ /(?<![A-Za-z0-9_])([A-Za-z0-9_]+)(?![A-Za-z0-9_])/g) { $listed{$1} = 1; }
}
my @missing = grep { !$listed{$_} } @ids;
if (!@missing) { print "already\n"; exit 0; }
$indent = $kind . '  ' unless defined $indent;
my $new = '';
for my $id (@missing) {
    if (defined $brace_in) { $new .= $indent . '- {' . $brace_in . 'schema: ' . $id . $brace_in . '}' . $eol; }
    else                   { $new .= $indent . '- schema: ' . $id . $eol; }
}
my @res = @lines;
$res[$key] .= $eol if $res[$key] !~ /\n\z/;     # key line was the last line without newline
splice(@res, $key + 1, 0, $new);
open(my $o, '>:raw', $out) or die "cannot write $out: $!\n";
print {$o} join('', @res);
close($o) or die "cannot close $out: $!\n";
print "patched\n";
PERL
}

# ---------------------------------------------------------------- main

main() {
  RIME_DIR="${RIME_DIR:-$HOME/Library/Rime}"
  REF="${CJF_REF:-v0.2.0}"
  WITH_C5=0; NO_MODEL=0; NO_DEPLOY=0; DRY=0; UNINSTALL=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --rime-dir)       [ $# -ge 2 ] || die "--rime-dir needs a folder"; RIME_DIR="$2"; shift ;;
      --rime-dir=*)     RIME_DIR="${1#--rime-dir=}" ;;
      --ref)            [ $# -ge 2 ] || die "--ref needs a tag"; REF="$2"; shift ;;
      --ref=*)          REF="${1#--ref=}" ;;
      --with-cangjie5)  WITH_C5=1 ;;
      --no-model)       NO_MODEL=1 ;;
      --no-deploy)      NO_DEPLOY=1 ;;
      --dry-run)        DRY=1 ;;
      --uninstall)      UNINSTALL=1 ;;
      -h|--help)        usage; return 0 ;;
      *)                usage >&2; die "unknown option: $1" ;;
    esac
    shift
  done
  [ -n "$RIME_DIR" ] || die "empty Rime folder"

  SQUIRREL_APP="${SQUIRREL_APP_DIR:-/Library/Input Methods/Squirrel.app}"
  RAW_BASE="${CJF_RAW_BASE:-https://raw.githubusercontent.com/githubhjs/cangjie-fluency/$REF}"
  MACOS_RAW="${CJF_MACOS_RAW:-https://raw.githubusercontent.com/githubhjs/cangjie-fluency-macos/main}"
  CIN_URL="${CJF_CIN_URL:-https://raw.githubusercontent.com/EasyIME/PIME/master/python/cinbase/cin/mscj3.cin}"
  ESSAY_URL="${CJF_ESSAY_URL:-https://raw.githubusercontent.com/rime/rime-essay/master/essay.txt}"
  C5BASE_URL="${CJF_C5BASE_URL:-https://raw.githubusercontent.com/rime/rime-cangjie/master/cangjie5.base.dict.yaml}"
  GRAM_URL="${CJF_GRAM_URL:-https://github.com/lotem/rime-octagram-data/raw/hant/zh-hant-t-essay-bgw.gram}"
  GRAM_URL2="${CJF_GRAM_URL2-https://raw.githubusercontent.com/lotem/rime-octagram-data/hant/zh-hant-t-essay-bgw.gram}"
  GRAM_SIZE="${CJF_GRAM_SIZE:-41415724}"
  STAMP=$(date +%Y%m%d-%H%M%S)
  MANIFEST="$RIME_DIR/.cangjie-fluency-macos.manifest"

  SCRIPT_DIR=""
  if [ -f "$0" ]; then SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd); fi

  TMP=$(mktemp -d "${TMPDIR:-/tmp}/cjf.XXXXXX") || die "cannot create a temporary folder"
  trap 'rm -r "$TMP" 2>/dev/null' EXIT

  if [ "$DRY" = 1 ]; then say "DRY RUN: nothing will be changed or downloaded."; fi
  say "Rime user folder: $RIME_DIR"

  if [ "$UNINSTALL" = 1 ]; then do_uninstall; return $?; fi

  # ---- tools
  command -v curl >/dev/null 2>&1 || die "curl not found (it ships with macOS)"
  PERL=/usr/bin/perl
  [ -x "$PERL" ] || PERL=$(command -v perl 2>/dev/null)
  [ -n "$PERL" ] && [ -x "$PERL" ] || die "perl not found (macOS ships /usr/bin/perl)"

  # ---- Squirrel
  SS="$SQUIRREL_APP/Contents/SharedSupport"
  if [ ! -d "$SQUIRREL_APP" ]; then
    msg="Squirrel (Rime for macOS) is not installed at \"$SQUIRREL_APP\". Install it first, then run this again:
    brew install --cask squirrel-app          (the cask is named squirrel-app, not squirrel)
  or download Squirrel-<version>.pkg from https://github.com/rime/squirrel/releases and open it.
  Then log out and in, and add Squirrel in System Settings > Keyboard > Input Sources (Chinese, Traditional > Squirrel)."
    if [ "$DRY" = 1 ]; then warn "$msg"; else die "$msg"; fi
  else
    ver=""
    if command -v defaults >/dev/null 2>&1; then ver=$(defaults read "$SQUIRREL_APP/Contents/Info" CFBundleShortVersionString 2>/dev/null); fi
    say "Squirrel found: $SQUIRREL_APP ${ver:+(version $ver)}"
    if [ ! -f "$SQUIRREL_APP/Contents/Frameworks/rime-plugins/librime-octagram.dylib" ]; then
      warn "this Squirrel build has no librime-octagram plugin: the schema still works, but the language model is ignored (sentence correction is weaker)."
    fi
  fi

  if [ ! -d "$RIME_DIR" ]; then
    if [ "$DRY" = 1 ]; then say "DRY: would create $RIME_DIR"; else mkdir -p "$RIME_DIR" || die "cannot create $RIME_DIR"; fi
  fi

  # ---- schema files (this repo does not duplicate them: pinned tag of githubhjs/cangjie-fluency)
  SCHEMA_FILES="cangjie3_fluency.schema.yaml cangjie3_fluency.dict.yaml"
  if [ "$WITH_C5" = 1 ]; then SCHEMA_FILES="$SCHEMA_FILES cangjie5_fluency.schema.yaml cangjie5_fluency.dict.yaml"; fi
  for f in $SCHEMA_FILES; do
    loc=$(find_local "$f")
    if [ "$DRY" = 1 ]; then
      if [ -n "$loc" ]; then say "DRY: would copy local $loc"; else say "DRY: would download $RAW_BASE/weasel/$f"; fi
      continue
    fi
    if [ -n "$loc" ]; then
      say "using local copy: $loc"
      cp "$loc" "$TMP/$f"
    else
      download "$RAW_BASE/weasel/$f" "$TMP/$f" "$f ($REF)"
    fi
    require_min "$TMP/$f" 300 "$f"
    grep -q 'name:' "$TMP/$f" || die "$f does not look like a Rime yaml file"
    place_file "$TMP/$f" "$f"
  done

  # ---- essay.txt (word list for the dictionary and the weights of the converter)
  ESSAY_SRC=""
  if [ -f "$RIME_DIR/essay.txt" ]; then ESSAY_SRC="$RIME_DIR/essay.txt"
  elif [ -f "$SS/essay.txt" ]; then ESSAY_SRC="$SS/essay.txt"; fi
  if [ -n "$ESSAY_SRC" ]; then
    say "essay.txt found: $ESSAY_SRC"
  elif [ "$DRY" = 1 ]; then
    say "DRY: would download $ESSAY_URL -> $RIME_DIR/essay.txt"
  else
    download "$ESSAY_URL" "$TMP/essay.txt" "essay.txt" big
    require_min "$TMP/essay.txt" 1000000 "essay.txt"
    place_file "$TMP/essay.txt" "essay.txt"
    ESSAY_SRC="$RIME_DIR/essay.txt"
  fi

  # ---- cangjie3.base.dict.yaml: download mscj3.cin and convert here. Never stored in the repo (license unknown).
  CONV=""
  if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/tools/cin2rime.pl" ]; then CONV="$SCRIPT_DIR/tools/cin2rime.pl"; fi
  if [ "$DRY" = 1 ]; then
    say "DRY: would download $CIN_URL, convert it with cin2rime.pl (essay weights) -> $RIME_DIR/cangjie3.base.dict.yaml"
  else
    if [ -z "$CONV" ]; then
      download "$MACOS_RAW/tools/cin2rime.pl" "$TMP/cin2rime.pl" "tools/cin2rime.pl"
      CONV="$TMP/cin2rime.pl"
    fi
    download "$CIN_URL" "$TMP/mscj3.cin" "mscj3.cin (PIME)"
    require_min "$TMP/mscj3.cin" 100000 "mscj3.cin"
    if "$PERL" "$CONV" "$TMP/mscj3.cin" "$TMP/cangjie3.base.dict.yaml" --essay "$ESSAY_SRC" > "$TMP/conv.log" 2>&1; then
      say "converted table: $(tr '\n' ' ' < "$TMP/conv.log")"
    else
      cat "$TMP/conv.log" >&2
      die "converting mscj3.cin failed"
    fi
    require_min "$TMP/cangjie3.base.dict.yaml" 200000 "cangjie3.base.dict.yaml"
    place_file "$TMP/cangjie3.base.dict.yaml" "cangjie3.base.dict.yaml"
  fi

  # ---- optional 5th generation
  if [ "$WITH_C5" = 1 ]; then
    if [ -f "$RIME_DIR/cangjie5.base.dict.yaml" ]; then
      say "cangjie5.base.dict.yaml already present."
    elif [ "$DRY" = 1 ]; then
      say "DRY: would download $C5BASE_URL"
    else
      download "$C5BASE_URL" "$TMP/cangjie5.base.dict.yaml" "cangjie5.base.dict.yaml (rime-cangjie)"
      require_min "$TMP/cangjie5.base.dict.yaml" 100000 "cangjie5.base.dict.yaml"
      place_file "$TMP/cangjie5.base.dict.yaml" "cangjie5.base.dict.yaml"
    fi
  fi

  # ---- language model. The model bundled in Squirrel 1.1.2 has the same name but only 10.5 MB; the
  # copy in the user folder takes precedence, so the full model is installed here.
  GRAM="$RIME_DIR/zh-hant-t-essay-bgw.gram"
  if [ "$NO_MODEL" = 1 ]; then
    say "skipping language model (--no-model)."
  elif [ -f "$GRAM" ] && [ "$(file_size "$GRAM")" = "$GRAM_SIZE" ]; then
    say "language model already present ($GRAM_SIZE bytes)."
  elif [ "$DRY" = 1 ]; then
    say "DRY: would download $GRAM_URL ($GRAM_SIZE bytes) -> $GRAM"
  else
    got=0
    for u in $GRAM_URL $GRAM_URL2; do
      say "downloading zh-hant-t-essay-bgw.gram (about 41 MB) from $u"
      if curl -fL $(progress_flag big) --retry 2 --connect-timeout 20 -o "$TMP/model.gram" "$u"; then
        n=$(file_size "$TMP/model.gram")
        if [ "$n" = "$GRAM_SIZE" ]; then got=1; break; fi
        warn "language model from $u has $n bytes, expected $GRAM_SIZE"
      else
        warn "download from $u failed"
      fi
    done
    [ "$got" = 1 ] || die "could not download the language model (use --no-model to skip it; sentence correction is then weaker)"
    say "model $(checksum_of "$TMP/model.gram")"
    place_file "$TMP/model.gram" "zh-hant-t-essay-bgw.gram"
  fi

  # ---- default.custom.yaml
  IDS="cangjie3_fluency"
  if [ "$WITH_C5" = 1 ]; then IDS="$IDS cangjie5_fluency"; fi
  DC="$RIME_DIR/default.custom.yaml"
  if [ ! -f "$DC" ]; then
    {
      printf '%s\n' '# encoding: utf-8' '# created by cangjie-fluency-macos install.sh' 'patch:' '  schema_list:'
      for id in $IDS; do printf '    - schema: %s\n' "$id"; done
      printf '    - schema: %s\n' luna_pinyin luna_pinyin_simp luna_pinyin_fluency bopomofo bopomofo_tw cangjie5 stroke terra_pinyin
    } > "$TMP/default.custom.yaml"
    if [ "$DRY" = 1 ]; then say "DRY: would create default.custom.yaml (cangjie3_fluency first)"
    else place_file "$TMP/default.custom.yaml" "default.custom.yaml"; fi
  else
    st=$(patch_schema_list "$DC" "$TMP/default.custom.new" $IDS) || die "could not analyse $DC"
    case "$st" in
      already) say "default.custom.yaml already lists: $IDS" ;;
      patched)
        if [ "$DRY" = 1 ]; then say "DRY: would back up default.custom.yaml and add the missing schema(s) of [$IDS] at the top of its schema_list"
        else place_file "$TMP/default.custom.new" "default.custom.yaml"; say "added the missing schema(s) of [$IDS] as the first entries of your schema_list"; fi ;;
      *)
        warn "your default.custom.yaml has no editable schema_list (status: $st), so I did not touch it. Add this under 'patch:' yourself (first = default):"
        printf '  schema_list:\n'
        for id in $IDS; do printf '    - schema: %s\n' "$id"; done
        printf '    - schema: luna_pinyin    # ...and the rest of your schemas\n' ;;
    esac
  fi

  # ---- deploy
  SQ_EXE="$SQUIRREL_APP/Contents/MacOS/Squirrel"
  if [ "$NO_DEPLOY" = 1 ] || [ "$DRY" = 1 ]; then
    say "not deploying. Deploy later: Squirrel menu bar icon > Deploy, or: \"$SQ_EXE\" --reload"
  elif [ -x "$SQ_EXE" ]; then
    say "asking Squirrel to redeploy (first deploy takes about 30 seconds)..."
    if "$SQ_EXE" --reload; then
      say "reload requested. This only reaches Squirrel while it is running; if nothing happens, click the Squirrel icon in the menu bar > Deploy."
    else
      warn "\"$SQ_EXE\" --reload failed. Use the Squirrel menu bar icon > Deploy instead."
    fi
  else
    warn "Squirrel executable not found; deploy by hand: menu bar icon > Deploy."
  fi

  if [ "$DRY" = 1 ]; then say "DRY RUN finished; nothing was changed."; return 0; fi
  cat <<'NEXT'

[cangjie-fluency] Done. Next steps:
  1. Switch to the Squirrel input source, press Ctrl+` (or F4) and choose the schema "倉頡三代整句" (cangjie3_fluency).
  2. Type a whole phrase of Cangjie codes, e.g. mwyl (面), then Enter commits. Single-letter codes need a trailing space
     (中午 is "l oj").
  3. Check that the language model loaded (after typing once; log folder is $TMPDIR/rime.squirrel/):
       grep -h "use grammar" "${TMPDIR%/}"/rime.squirrel/* | tail -3
     No "use grammar" line = the model is not loaded (the schema still works).
NEXT
}

do_uninstall() {
  if [ ! -f "$MANIFEST" ]; then
    say "no manifest ($MANIFEST): this installer did not create any file here, nothing to remove."
    return 0
  fi
  local crc size name cur
  while read -r crc size name; do
    [ -n "$name" ] || continue
    if [ ! -f "$RIME_DIR/$name" ]; then say "already gone: $name"; continue; fi
    cur=$(cksum < "$RIME_DIR/$name" | awk '{print $1 " " $2}')
    if [ "$cur" != "$crc $size" ]; then
      warn "kept $name: it was changed after the installer wrote it"
      continue
    fi
    if [ "$DRY" = 1 ]; then say "DRY: would remove $name"
    else rm "$RIME_DIR/$name" && say "removed $name"; fi
  done < "$MANIFEST"
  if [ "$DRY" != 1 ]; then rm "$MANIFEST"; fi
  say "backups (*.bak-*) were kept."
  if [ -f "$RIME_DIR/default.custom.yaml" ] && grep -q 'cangjie[35]_fluency' "$RIME_DIR/default.custom.yaml"; then
    warn "default.custom.yaml still lists the fluency schema(s); remove those '- schema: ...' lines yourself (or restore a default.custom.yaml.bak-* backup)."
  fi
  if [ "$NO_DEPLOY" != 1 ] && [ "$DRY" != 1 ] && [ -x "$SQUIRREL_APP/Contents/MacOS/Squirrel" ]; then
    "$SQUIRREL_APP/Contents/MacOS/Squirrel" --reload || true
  fi
  return 0
}

main "$@"
exit $?
