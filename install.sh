#!/bin/bash
# cangjie-fluency-macos installer: Microsoft-style sentence input for Cangjie on Squirrel (Rime for macOS).
#
# bash 3.2 compatible (the bash that ships with macOS). Uses only: curl, perl (/usr/bin/perl), awk, cmp, wc, tr, cksum/shasum.
# No python, no GNU-only options (no sha256sum, readlink -f, stat -c, date -d, sed -i).
#
# Everything comes from the owner's main repository https://github.com/githubhjs/cangjie-fluency (tables, word list,
# language model, converter, schema files, and the unmodified Squirrel installer in its release deps-v1) and nothing
# from any other third party.  Per file: (1) next to this script in the layout of the full release zip, else
# (2) raw.githubusercontent.com/githubhjs/cangjie-fluency/<ref>/ (not with --offline).  Tables, essay.txt, the
# model and the Squirrel pkg are SHA-256 checked.
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

CJF_VERSION="0.2.0"

usage() {
  cat <<'USAGE'
usage: bash install.sh [options]

  --rime-dir DIR     Rime user folder (default: $RIME_DIR, else ~/Library/Rime)
  --ref TAG          version (tag/branch) of githubhjs/cangjie-fluency to download missing files from (default: v0.5.1)
  --offline          never touch the network: everything must be next to this script (full release zip layout)
  --no-deps          do not install Squirrel when it is missing (that needs sudo and the Squirrel pkg)
  --with-cangjie5    also install the 5th-generation schema cangjie5_fluency (+ cangjie5.base.dict.yaml)
  --no-model         do not install the 41 MB language model (zh-hant-t-essay-bgw.gram)
  --no-fuzzy         do not install the adjacent-key typo tolerance schemas (cangjie3_fuzzy)
  --fuzzy-default    make the typo-tolerant schema the FIRST (default) one instead of cangjie3_fluency
  --fuzzy-range narrow|normal|wide   how far a wrong key may be from the right one: narrow = left/right only,
                     normal (default) = also the diagonal neighbours, wide = one more ring
  --no-sweep         do not install the Cangjie Sweep Pad (tkinter gesture input helper)
  --pad-ref TAG      version (tag/branch) of githubhjs/cangjie-fuzzy-core for Sweep Pad (default: v0.2.0)
  --no-deploy        install files only; do not ask Squirrel to redeploy
  --dry-run          show what would be done; change nothing, download nothing
  --uninstall        remove the files this installer created (backups and your default.custom.yaml are kept)
  -h, --help         this text
USAGE
  cat <<'USAGE_ZH'

用法：bash install.sh [選項]

  --rime-dir DIR     Rime 使用者資料夾（預設：$RIME_DIR，否則 ~/Library/Rime）
  --ref TAG          缺少檔案時，從 githubhjs/cangjie-fluency 下載的版本（標籤/分支，預設：v0.5.1）
  --offline          完全不連網：所有檔案都必須放在本腳本旁邊（完整 release zip 的版面配置）
  --no-deps          Squirrel 不存在時不安裝（安裝需要 sudo 與 Squirrel pkg）
  --with-cangjie5    同時安裝五代方案 cangjie5_fluency（+ cangjie5.base.dict.yaml）
  --no-model         不安裝 41 MB 的語言模型（zh-hant-t-essay-bgw.gram）
  --no-fuzzy         不安裝相鄰鍵容錯方案（cangjie3_fuzzy）
  --fuzzy-default    把鄰鍵容錯方案排在第一個（預設），而不是 cangjie3_fluency
  --fuzzy-range narrow|normal|wide   打錯的鍵離正確的鍵多遠算數：narrow = 只有左右相鄰，
                     normal（預設）= 再加斜向相鄰，wide = 再多一圈
  --no-sweep         不安裝倉頡滑行輸入板（tkinter 滑行輸入輔助工具）
  --pad-ref TAG      從 githubhjs/cangjie-fuzzy-core 下載滑行板時使用的版本（預設：v0.2.0）
  --no-deploy        只安裝檔案；不要求 Squirrel 重新部署
  --dry-run          只顯示會做什麼；不更動、不下載
  --uninstall        移除本安裝程式建立的檔案（備份檔與你的 default.custom.yaml 會保留）
  -h, --help         顯示本說明
USAGE_ZH
}

# Each takes the English message, plus an optional Traditional Chinese line ($2) printed right after it.
say()  { printf '[cangjie-fluency] %s\n' "$1"; if [ $# -ge 2 ]; then printf '[cangjie-fluency] %s\n' "$2"; fi; }
warn() { printf '[cangjie-fluency] WARNING: %s\n' "$1" >&2; if [ $# -ge 2 ]; then printf '[cangjie-fluency] 警告：%s\n' "$2" >&2; fi; }
die()  { printf '[cangjie-fluency] ERROR: %s\n' "$1" >&2; if [ $# -ge 2 ]; then printf '[cangjie-fluency] 錯誤：%s\n' "$2" >&2; fi; exit 1; }

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

# sha256_of FILE -> hex digest (shasum on macOS; openssl or perl as fallbacks)
sha256_of() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 "$1" | awk '{print $NF}'
  else "$PERL" -MDigest::SHA -e 'open(F, "<:raw", $ARGV[0]) or die; print Digest::SHA->new(256)->addfile(*F)->hexdigest, "\n"' "$1"
  fi
}

verify_sha() { # FILE EXPECTED LABEL
  local got
  got=$(sha256_of "$1")
  [ "$got" = "$2" ] || die "$3: SHA-256 mismatch (got $got, expected $2). The file is damaged or the wrong version; nothing was installed from it." "$3：SHA-256 不符（實際 $got，預期 $2）。檔案損毀或版本不對；沒有安裝這個檔案的任何內容。"
}

# download URL DEST LABEL  (progress bar only for big files on a terminal)
progress_flag() { if [ "${1:-}" = "big" ] && [ -t 2 ]; then printf %s "-#"; else printf %s "-sS"; fi; }

download() {
  local url="$1" dest="$2" label="$3" prog
  [ "$OFFLINE" = 0 ] || die "internal error: network access attempted with --offline ($url)" "內部錯誤：使用 --offline 時卻嘗試連網（$url）"
  prog=$(progress_flag "${4:-}")
  say "downloading $label" "下載中：$label"
  curl -fL $prog --retry 2 --connect-timeout 20 -o "$dest" "$url" || die "download failed: $url" "下載失敗：$url"
}

require_min() { # FILE MINBYTES LABEL
  local n
  n=$(file_size "$1")
  [ "$n" -ge "$2" ] || die "$3 is only $n bytes (expected at least $2); the download looks wrong" "$3 只有 $n 位元組（至少應有 $2）；下載內容似乎不正確"
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
  cp -p "$p" "$b" || die "cannot back up $p" "無法備份 $p"
  printf '%s' "$b"
}

# place TMPFILE NAME : identical content = nothing; changed = one backup, then replace; new = create.
# Files that did not exist before are recorded in the manifest (so --uninstall removes only those).
place_file() {
  local tmp="$1" name="$2" dest b
  dest="$RIME_DIR/$name"
  if [ -f "$dest" ]; then
    if cmp -s "$tmp" "$dest"; then
      say "up to date: $name" "已是最新：$name"
      return 0
    fi
    b=$(backup_file "$dest")
    say "backed up $name -> $(basename "$b")" "已備份：$name -> $(basename "$b")"
    cp "$tmp" "$dest.part" && mv "$dest.part" "$dest" || die "cannot write $dest" "無法寫入 $dest"
    say "updated: $name" "已更新：$name"
    if manifest_has "$name"; then manifest_set "$name"; fi
  else
    cp "$tmp" "$dest.part" && mv "$dest.part" "$dest" || die "cannot write $dest" "無法寫入 $dest"
    say "installed: $name" "已安裝：$name"
    manifest_set "$name"
  fi
}

# get_src RELPATH DEST [SHA256] [big]: the bundle layout next to the script (or CJF_SRC_DIR) first, else download
get_src() {
  if [ -n "$SRC_LOCAL" ] && [ -f "$SRC_LOCAL/$1" ]; then
    cp "$SRC_LOCAL/$1" "$2" || die "cannot copy $SRC_LOCAL/$1" "無法複製 $SRC_LOCAL/$1"
  elif [ "$OFFLINE" = 1 ]; then
    die "--offline: $1 is missing from the bundle next to install.sh" "--offline：install.sh 旁邊的完整包裡缺少 $1"
  else
    download "$RAW_BASE/$1" "$2" "$1 ($REF)" "${4:-}"
  fi
  [ -s "$2" ] || die "$1 is empty" "$1 是空的"
  if [ -n "${3:-}" ]; then verify_sha "$2" "$3" "$1"; fi
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
# typo-tolerant ids go right after their base schema (never becoming the default) unless --fuzzy-default
my @special = $ENV{CJF_FUZZY_DEFAULT} ? () : grep { /_fuzzy\z/ } @missing;
my %is_special = map { $_ => 1 } @special;
@missing = grep { !$is_special{$_} } @missing;
$indent = $kind . '  ' unless defined $indent;
my $new = '';
for my $id (@missing) {
    if (defined $brace_in) { $new .= $indent . '- {' . $brace_in . 'schema: ' . $id . $brace_in . '}' . $eol; }
    else                   { $new .= $indent . '- schema: ' . $id . $eol; }
}
my @res = @lines;
$res[$key] .= $eol if $res[$key] !~ /\n\z/;     # key line was the last line without newline
splice(@res, $key + 1, 0, $new) if @missing;
@res = split(/(?<=\n)/, join('', @res));
for my $id (@special) {
    (my $base = $id) =~ s/_fuzzy\z/_fluency/;
    my $at = $key;
    for my $j ($key + 1 .. $#res) {
        my $t = $res[$j];
        $t =~ s/#.*\z//;
        if ($t =~ /\A[ \t]*-/ && $t =~ /(?<![A-Za-z0-9_])\Q$base\E(?![A-Za-z0-9_])/) { $at = $j; last; }
    }
    my $ln = defined $brace_in ? $indent . '- {' . $brace_in . 'schema: ' . $id . $brace_in . '}' . $eol : $indent . '- schema: ' . $id . $eol;
    $res[$at] .= $eol if $res[$at] !~ /\n\z/;
    splice(@res, $at + 1, 0, $ln);
}
open(my $o, '>:raw', $out) or die "cannot write $out: $!\n";
print {$o} join('', @res);
close($o) or die "cannot close $out: $!\n";
print "patched\n";
PERL
}

# ---------------------------------------------------------------- main

main() {
  RIME_DIR="${RIME_DIR:-$HOME/Library/Rime}"
  REF="${CJF_REF:-v0.5.1}"
  PAD_REPO="githubhjs/cangjie-fuzzy-core"
  PAD_REF="${CJF_PAD_REF:-v0.2.0}"
  WITH_C5=0; NO_FUZZY=0; FUZZY_DEFAULT=0; FUZZY_RANGE=normal; NO_MODEL=0; NO_SWEEP=0; NO_DEPLOY=0; NO_DEPS=0; OFFLINE=0; DRY=0; UNINSTALL=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --rime-dir)       [ $# -ge 2 ] || die "--rime-dir needs a folder" "--rime-dir 需要一個資料夾"; RIME_DIR="$2"; shift ;;
      --rime-dir=*)     RIME_DIR="${1#--rime-dir=}" ;;
      --ref)            [ $# -ge 2 ] || die "--ref needs a tag" "--ref 需要一個標籤"; REF="$2"; shift ;;
      --ref=*)          REF="${1#--ref=}" ;;
      --offline)        OFFLINE=1 ;;
      --no-deps)        NO_DEPS=1 ;;
      --with-cangjie5)  WITH_C5=1 ;;
      --no-model)       NO_MODEL=1 ;;
      --no-fuzzy)       NO_FUZZY=1 ;;
      --fuzzy-default)  FUZZY_DEFAULT=1 ;;
      --fuzzy-range)    shift; FUZZY_RANGE="${1:-}"; case "$FUZZY_RANGE" in narrow|normal|wide) ;; *) die "--fuzzy-range must be narrow, normal or wide" "--fuzzy-range 只能是 narrow、normal 或 wide" ;; esac ;;
      --no-sweep)       NO_SWEEP=1 ;;
      --pad-ref)        [ $# -ge 2 ] || die "--pad-ref needs a tag" "--pad-ref 需要一個標籤"; PAD_REF="$2"; shift ;;
      --pad-ref=*)      PAD_REF="${1#--pad-ref=}" ;;
      --no-deploy)      NO_DEPLOY=1 ;;
      --dry-run)        DRY=1 ;;
      --uninstall)      UNINSTALL=1 ;;
      -h|--help)        usage; return 0 ;;
      *)                usage >&2; die "unknown option: $1" "不認得的選項：$1" ;;
    esac
    shift
  done
  [ -n "$RIME_DIR" ] || die "empty Rime folder" "Rime 資料夾是空的"
  case "$PAD_REF" in *[!A-Za-z0-9._/-]*|"") die "--pad-ref contains unexpected characters" "--pad-ref 含有不允許的字元" ;; esac

  SWEEP_DIR="${CJF_SWEEP_DIR:-$HOME/Library/Application Support/cangjie-sweep}"
  BIN_DIR="${CJF_BIN_DIR:-$HOME/.local/bin}"
  APP_DIR="${CJF_APP_DIR:-$HOME/Applications}"
  SWEEP_LAUNCHER="$BIN_DIR/cangjie-sweep-pad"
  SWEEP_COMMAND="$APP_DIR/Cangjie Sweep.command"

  SQUIRREL_APP="${SQUIRREL_APP_DIR:-/Library/Input Methods/Squirrel.app}"
  RAW_BASE="https://raw.githubusercontent.com/githubhjs/cangjie-fluency/$REF"
  SQUIRREL_PKG_URL="https://github.com/githubhjs/cangjie-fluency/releases/download/deps-v1/Squirrel-1.1.2.pkg"
  SQUIRREL_PKG_SHA="614746013212937623d5bbab9901e9c43d1ec937aa32307d6b6092a05e308287"
  GRAM_SIZE=41415724
  GRAM_SHA="0488ebd6688f900a39200f2b794f2f99bcbf1e8fc27280ae4a2324b08b1559c1"
  ESSAY_SHA="3e8512ebaa6657e35961b1f5762060717c647e3bf471d5e3b86e783b4e934ffb"
  CIN3_SHA="a7b3d03898dc0b2b0bd7803ad0be7b940a1ed945ac5d6314ed832b1dbf6839a2"
  CJ5_BASE_SHA="0b7a801720bbf04cea06c55577c159e2e67b9bbb763bf00026a8520497772799"
  STAMP=$(date +%Y%m%d-%H%M%S)
  MANIFEST="$RIME_DIR/.cangjie-fluency-macos.manifest"

  SCRIPT_DIR=""
  if [ -f "$0" ]; then SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd); fi
  SRC_LOCAL=""
  for cand in "${CJF_SRC_DIR:-}" "$SCRIPT_DIR"; do   # CJF_SRC_DIR: any directory with the bundle layout
    [ -n "$cand" ] || continue
    if [ -f "$cand/weasel/cangjie3_fluency.schema.yaml" ] && [ -f "$cand/tools/cin2rime.pl" ]; then SRC_LOCAL="$cand"; break; fi
  done
  if [ -n "$SRC_LOCAL" ]; then say "using the files next to the installer (bundle layout): $SRC_LOCAL" "使用安裝程式旁邊的檔案（完整包版面配置）：$SRC_LOCAL"
  elif [ "$OFFLINE" = 1 ]; then die "--offline: the files (weasel/ tables/ data/ tools/) must be next to install.sh (use the full release zip)." "--offline：檔案（weasel/ tables/ data/ tools/）必須放在 install.sh 旁邊（請使用完整 release zip）。"
  else say "files come from githubhjs/cangjie-fluency at $REF" "檔案來自 githubhjs/cangjie-fluency（版本 $REF）"; fi

  TMP=$(mktemp -d "${TMPDIR:-/tmp}/cjf.XXXXXX") || die "cannot create a temporary folder" "無法建立暫存資料夾"
  trap 'rm -r "$TMP" 2>/dev/null' EXIT

  if [ "$DRY" = 1 ]; then say "DRY RUN: nothing will be changed or downloaded." "試跑模式：不會更動或下載任何東西。"; fi
  say "Rime user folder: $RIME_DIR" "Rime 使用者資料夾：$RIME_DIR"

  if [ "$UNINSTALL" = 1 ]; then do_uninstall; return $?; fi

  # ---- tools
  if [ "$OFFLINE" = 0 ]; then command -v curl >/dev/null 2>&1 || die "curl not found (it ships with macOS)" "找不到 curl（macOS 內建）"; fi
  PERL=/usr/bin/perl
  [ -x "$PERL" ] || PERL=$(command -v perl 2>/dev/null)
  [ -n "$PERL" ] && [ -x "$PERL" ] || die "perl not found (macOS ships /usr/bin/perl)" "找不到 perl（macOS 內建 /usr/bin/perl）"

  find_python() {
    if [ -n "${CJF_PYTHON:-}" ] && [ -x "$CJF_PYTHON" ]; then printf '%s' "$CJF_PYTHON"; return 0; fi
    # prefer the first python3 that can import tkinter (Homebrew python often lacks it); else the first one found
    first=""
    for cand in /opt/homebrew/bin/python3 /usr/bin/python3 /usr/local/bin/python3 "$(command -v python3 2>/dev/null || true)"; do
      [ -n "$cand" ] && [ -x "$cand" ] || continue
      [ -n "$first" ] || first="$cand"
      if "$cand" -c "import tkinter" >/dev/null 2>&1; then printf '%s' "$cand"; return 0; fi
    done
    [ -n "$first" ] && { printf '%s' "$first"; return 0; }
    return 1
  }

  PY=""
  if [ "$NO_SWEEP" = 0 ]; then
    PY=$(find_python || true)
    if [ -z "$PY" ]; then
      warn "python3 not found; Sweep Pad requires Python 3.8+ with tkinter." "找不到 python3；倉頡滑行輸入板需要 Python 3.8+ 與 tkinter。"
    elif ! "$PY" -c "import tkinter" >/dev/null 2>&1; then
      warn "python3 tkinter module is missing. Install it with: brew install python-tk" "缺少 python3 的 tkinter 模組。請安裝：brew install python-tk"
    fi
    say "NOTE: macOS needs Privacy & Security > Accessibility permission for the terminal/Python that runs the pad so key injection works (cannot be granted by script)." "注意：macOS 按鍵模擬需要「隱私權與安全性 > 輔助使用」權限（請授權執行滑行板的終端機或 Python，無法由腳本代為開啟）。"
  fi

  # ---- Squirrel (the engine). Present = left alone. Missing = the unmodified upstream pkg from the main repo's
  # release deps-v1 (or deps/ in the full zip), SHA-256 checked, installed with the macOS installer (sudo).
  SS="$SQUIRREL_APP/Contents/SharedSupport"
  if [ ! -d "$SQUIRREL_APP" ]; then
    if [ "$NO_DEPS" = 1 ]; then
      msgzh="找不到 Squirrel（macOS 版 Rime），安裝位置「$SQUIRREL_APP」不存在，而且指定了 --no-deps。請自行安裝 Squirrel-1.1.2.pkg（完整 zip 的 deps/ 資料夾，或 https://github.com/githubhjs/cangjie-fluency/releases/tag/deps-v1），然後再執行一次。"
      msg="Squirrel (Rime for macOS) is not installed at \"$SQUIRREL_APP\" and --no-deps was given. Install Squirrel-1.1.2.pkg (deps/ in the full zip, or https://github.com/githubhjs/cangjie-fluency/releases/tag/deps-v1) yourself, then run this again."
      if [ "$DRY" = 1 ]; then warn "$msg" "$msgzh"; else die "$msg" "$msgzh"; fi
    elif [ "$DRY" = 1 ]; then
      say "DRY: Squirrel is missing; would take Squirrel-1.1.2.pkg (SHA-256 $SQUIRREL_PKG_SHA) and run: sudo installer -pkg <pkg> -target /" "試跑：缺少 Squirrel；將取用 Squirrel-1.1.2.pkg（SHA-256 $SQUIRREL_PKG_SHA）並執行：sudo installer -pkg <pkg> -target /"
    else
      say "Squirrel is not installed: installing Squirrel 1.1.2 (unmodified upstream pkg, GPL-3.0) with sudo installer" "尚未安裝 Squirrel：用 sudo installer 安裝 Squirrel 1.1.2（未修改的上游 pkg，GPL-3.0）"
      get_src "deps/Squirrel-1.1.2.pkg" "$TMP/Squirrel-1.1.2.pkg" "$SQUIRREL_PKG_SHA" big
      if [ -n "${CJF_SQUIRREL_INSTALL_CMD:-}" ]; then
        $CJF_SQUIRREL_INSTALL_CMD "$TMP/Squirrel-1.1.2.pkg" || die "installing Squirrel failed" "安裝 Squirrel 失敗"
      else
        sudo installer -pkg "$TMP/Squirrel-1.1.2.pkg" -target / || die "installing Squirrel failed (sudo installer -pkg ... -target /)" "安裝 Squirrel 失敗（sudo installer -pkg ... -target /）"
      fi
      [ -d "$SQUIRREL_APP" ] || die "the Squirrel pkg ran but $SQUIRREL_APP does not exist" "Squirrel pkg 已執行，但 $SQUIRREL_APP 不存在"
      say "Squirrel installed. Add it in System Settings > Keyboard > Input Sources (Chinese, Traditional > Squirrel)." "Squirrel 已安裝。請到「系統設定 > 鍵盤 > 輸入方式」加入（繁體中文 > Squirrel）。"
      say "Squirrel itself says: log out and in only if typing fails in some apps after this first install." "Squirrel 官方說明：只有在第一次安裝後某些 App 打不了字時，才需要登出再登入。"
    fi
  fi
  if [ -d "$SQUIRREL_APP" ]; then
    ver=""
    if command -v defaults >/dev/null 2>&1; then ver=$(defaults read "$SQUIRREL_APP/Contents/Info" CFBundleShortVersionString 2>/dev/null); fi
    say "Squirrel found: $SQUIRREL_APP ${ver:+(version $ver)}" "已找到 Squirrel：$SQUIRREL_APP ${ver:+（版本 $ver）}"
    if [ ! -f "$SQUIRREL_APP/Contents/Frameworks/rime-plugins/librime-octagram.dylib" ]; then
      warn "this Squirrel build has no librime-octagram plugin: the schema still works, but the language model is ignored." "這個 Squirrel 版本沒有 librime-octagram 外掛：方案仍可使用，但語言模型會被忽略。"
    fi
  fi

  if [ ! -d "$RIME_DIR" ]; then
    if [ "$DRY" = 1 ]; then say "DRY: would create $RIME_DIR" "試跑：將會建立 $RIME_DIR"; else mkdir -p "$RIME_DIR" || die "cannot create $RIME_DIR" "無法建立 $RIME_DIR"; fi
  fi

  # ---- schema files + essay.txt + table + converter
  SCHEMA_FILES="cangjie3_fluency.schema.yaml cangjie3_fluency.dict.yaml"
  if [ "$NO_FUZZY" = 0 ]; then SCHEMA_FILES="$SCHEMA_FILES cangjie3_fuzzy.schema.yaml cangjie3_fuzzy_prism.schema.yaml"; fi
  if [ "$WITH_C5" = 1 ]; then SCHEMA_FILES="$SCHEMA_FILES cangjie5_fluency.schema.yaml cangjie5_fluency.dict.yaml"; fi
  if [ "$WITH_C5" = 1 ] && [ "$NO_FUZZY" = 0 ]; then SCHEMA_FILES="$SCHEMA_FILES cangjie5_fuzzy.schema.yaml cangjie5_fuzzy_prism.schema.yaml"; fi
  if [ "$DRY" = 1 ]; then
    for f in $SCHEMA_FILES; do say "DRY: would install $f" "試跑：將會安裝 $f"; done
    say "DRY: would convert tables/mscj3.cin (SHA-256 checked) with tools/cin2rime.pl and data/essay.txt weights -> $RIME_DIR/cangjie3.base.dict.yaml" "試跑：將會用 tools/cin2rime.pl 與 data/essay.txt 的權重轉換 tables/mscj3.cin（已檢查 SHA-256）-> $RIME_DIR/cangjie3.base.dict.yaml"
  else
    for f in $SCHEMA_FILES; do
      rel="weasel/$f"; case "$f" in *_fuzzy*) [ "$FUZZY_RANGE" = normal ] || rel="weasel/fuzzy-$FUZZY_RANGE/$f" ;; esac
      get_src "$rel" "$TMP/$f"
      grep -q 'name:' "$TMP/$f" || die "$f does not look like a Rime yaml file" "$f 看起來不是 Rime 的 yaml 檔"
      place_file "$TMP/$f" "$f"
    done

    # essay.txt: the repository's pinned copy ALWAYS feeds the converter (identical output on every platform);
    # it is installed into the user folder only when neither Squirrel nor the user folder has one.
    get_src "data/essay.txt" "$TMP/essay.txt" "$ESSAY_SHA" big
    if [ -f "$SS/essay.txt" ]; then say "Squirrel's own essay.txt found: not installing another copy" "找到 Squirrel 自己的 essay.txt：不再安裝另一份"
    elif [ -f "$RIME_DIR/essay.txt" ]; then say "essay.txt already in $RIME_DIR: left alone" "$RIME_DIR 裡已有 essay.txt：不動它"
    else place_file "$TMP/essay.txt" "essay.txt"; fi

    PERL=/usr/bin/perl
    [ -x "$PERL" ] || PERL=$(command -v perl 2>/dev/null)
    get_src "tools/cin2rime.pl" "$TMP/cin2rime.pl"
    get_src "tables/mscj3.cin" "$TMP/mscj3.cin" "$CIN3_SHA"
    if "$PERL" "$TMP/cin2rime.pl" "$TMP/mscj3.cin" "$TMP/cangjie3.base.dict.yaml" --essay "$TMP/essay.txt" > "$TMP/conv.log" 2>&1; then
      say "converted table: $(tr '\n' ' ' < "$TMP/conv.log")" "已轉換碼表：$(tr '\n' ' ' < "$TMP/conv.log")"
    else
      cat "$TMP/conv.log" >&2
      die "converting mscj3.cin failed" "轉換 mscj3.cin 失敗"
    fi
    require_min "$TMP/cangjie3.base.dict.yaml" 200000 "cangjie3.base.dict.yaml"
    place_file "$TMP/cangjie3.base.dict.yaml" "cangjie3.base.dict.yaml"
  fi

  # ---- optional 5th generation table
  if [ "$WITH_C5" = 1 ]; then
    if [ "$DRY" = 1 ]; then
      say "DRY: would install tables/cangjie5.base.dict.yaml (SHA-256 checked)" "試跑：將會安裝 tables/cangjie5.base.dict.yaml（已檢查 SHA-256）"
    else
      get_src "tables/cangjie5.base.dict.yaml" "$TMP/cangjie5.base.dict.yaml" "$CJ5_BASE_SHA"
      place_file "$TMP/cangjie5.base.dict.yaml" "cangjie5.base.dict.yaml"
    fi
  fi

  # ---- language model: always the repository's full model (Squirrel 1.1.2 bundles a 10.5 MB variant with the same
  # name; the copy in the user folder takes precedence). Size and SHA-256 checked.
  GRAM="$RIME_DIR/zh-hant-t-essay-bgw.gram"
  if [ "$NO_MODEL" = 1 ]; then
    say "skipping language model (--no-model)." "略過語言模型（--no-model）。"
  elif [ -f "$GRAM" ] && [ "$(file_size "$GRAM")" = "$GRAM_SIZE" ] && [ "$(sha256_of "$GRAM")" = "$GRAM_SHA" ]; then
    say "language model already present ($GRAM_SIZE bytes, SHA-256 ok)." "語言模型已存在（$GRAM_SIZE 位元組，SHA-256 正確）。"
  elif [ "$DRY" = 1 ]; then
    say "DRY: would install data/zh-hant-t-essay-bgw.gram ($GRAM_SIZE bytes, SHA-256 checked) -> $GRAM" "試跑：將會安裝 data/zh-hant-t-essay-bgw.gram（$GRAM_SIZE 位元組，已檢查 SHA-256）-> $GRAM"
  else
    get_src "data/zh-hant-t-essay-bgw.gram" "$TMP/model.gram" "$GRAM_SHA" big
    [ "$(file_size "$TMP/model.gram")" = "$GRAM_SIZE" ] || die "the language model has the wrong size (want $GRAM_SIZE)" "語言模型的大小不對（應為 $GRAM_SIZE）"
    place_file "$TMP/model.gram" "zh-hant-t-essay-bgw.gram"
  fi

  # ---- default.custom.yaml
  if [ "$FUZZY_DEFAULT" = 1 ] && [ "$NO_FUZZY" = 0 ]; then
    IDS="cangjie3_fuzzy"; if [ "$WITH_C5" = 1 ]; then IDS="$IDS cangjie5_fuzzy"; fi
    IDS="$IDS cangjie3_fluency"; if [ "$WITH_C5" = 1 ]; then IDS="$IDS cangjie5_fluency"; fi
  else
    IDS="cangjie3_fluency"; if [ "$NO_FUZZY" = 0 ]; then IDS="$IDS cangjie3_fuzzy"; fi
    if [ "$WITH_C5" = 1 ]; then IDS="$IDS cangjie5_fluency"; if [ "$NO_FUZZY" = 0 ]; then IDS="$IDS cangjie5_fuzzy"; fi; fi
  fi
  DC="$RIME_DIR/default.custom.yaml"
  if [ ! -f "$DC" ]; then
    {
      printf '%s\n' '# encoding: utf-8' '# created by cangjie-fluency-macos install.sh' 'patch:' '  schema_list:'
      for id in $IDS; do printf '    - schema: %s\n' "$id"; done
      printf '    - schema: %s\n' luna_pinyin luna_pinyin_simp luna_pinyin_fluency bopomofo bopomofo_tw cangjie5 stroke terra_pinyin
    } > "$TMP/default.custom.yaml"
    if [ "$DRY" = 1 ]; then say "DRY: would create default.custom.yaml (cangjie3_fluency first)" "試跑：將會建立 default.custom.yaml（cangjie3_fluency 排在最前面）"
    else place_file "$TMP/default.custom.yaml" "default.custom.yaml"; fi
  else
    st=$(CJF_FUZZY_DEFAULT="$FUZZY_DEFAULT" patch_schema_list "$DC" "$TMP/default.custom.new" $IDS) || die "could not analyse $DC" "無法分析 $DC"
    case "$st" in
      already) say "default.custom.yaml already lists: $IDS" "default.custom.yaml 已列出：$IDS" ;;
      patched)
        if [ "$DRY" = 1 ]; then say "DRY: would back up default.custom.yaml and add the missing schema(s) of [$IDS] at the top of its schema_list" "試跑：將會備份 default.custom.yaml，並把缺少的方案 [$IDS] 加到 schema_list 的最前面"
        else place_file "$TMP/default.custom.new" "default.custom.yaml"; say "added the missing schema(s) of [$IDS] as the first entries of your schema_list" "已把缺少的方案 [$IDS] 加到你的 schema_list 最前面"; fi ;;
      *)
        warn "your default.custom.yaml has no editable schema_list (status: $st), so I did not touch it. Add this under 'patch:' yourself (first = default):" "你的 default.custom.yaml 沒有可編輯的 schema_list（狀態：$st），所以沒有修改它。請自行把下面這段加到 'patch:' 底下（第一個 = 預設）："
        printf '  schema_list:\n'
        for id in $IDS; do printf '    - schema: %s\n' "$id"; done
        printf '    - schema: luna_pinyin    # ...and the rest of your schemas\n' ;;
    esac
  fi

  # ---- deploy
  SQ_EXE="$SQUIRREL_APP/Contents/MacOS/Squirrel"
  if [ "$NO_DEPLOY" = 1 ] || [ "$DRY" = 1 ]; then
    say "not deploying. Deploy later: Squirrel menu bar icon > Deploy, or: \"$SQ_EXE\" --reload" "不部署。之後請部署：選單列的 Squirrel 圖示 > Deploy，或執行：\"$SQ_EXE\" --reload"
  elif [ -x "$SQ_EXE" ]; then
    say "asking Squirrel to redeploy (first deploy takes about 30 seconds)..." "請 Squirrel 重新部署（第一次約需 30 秒）..."
    if "$SQ_EXE" --reload; then
      say "reload requested. This only reaches Squirrel while it is running; if nothing happens, click the Squirrel icon in the menu bar > Deploy." "已送出重新載入的要求。這只有在 Squirrel 執行中才會生效；如果沒有反應，請點選單列的 Squirrel 圖示 > Deploy。"
    else
      warn "\"$SQ_EXE\" --reload failed. Use the Squirrel menu bar icon > Deploy instead." "\"$SQ_EXE\" --reload 失敗。請改用選單列的 Squirrel 圖示 > Deploy。"
    fi
  else
    warn "Squirrel executable not found; deploy by hand: menu bar icon > Deploy." "找不到 Squirrel 執行檔；請手動部署：選單列圖示 > Deploy。"
  fi

  # ---- Cangjie Sweep Pad
  SWEEP_CHECK_OK=0
  if [ "$NO_SWEEP" = 0 ]; then
    if [ "$DRY" = 1 ]; then
      say "DRY: would install Sweep Pad $PAD_REF to $SWEEP_DIR" "試跑：將會安裝倉頡滑行輸入板 $PAD_REF 到 $SWEEP_DIR"
      say "DRY: would create launcher $SWEEP_LAUNCHER" "試跑：將會建立啟動器 $SWEEP_LAUNCHER"
      say "DRY: would create command $SWEEP_COMMAND" "試跑：將會建立雙擊執行檔 $SWEEP_COMMAND"
      say "DRY: would run self-check: python3 cangjie_sweep_pad.py --self-check" "試跑：將會執行自我檢查：python3 cangjie_sweep_pad.py --self-check"
    else
      pad_zip="$TMP/cangjie-sweep-pad.zip"
      pad_sha="$TMP/cangjie-sweep-pad.zip.sha256"
      expected_pad_sha=""
      pad_bundle_zip=""
      pad_bundle_sha=""

      if [ -n "$SRC_LOCAL" ] && [ -f "$SRC_LOCAL/sweep-pad/cangjie-sweep-pad.zip" ]; then
        pad_bundle_zip="$SRC_LOCAL/sweep-pad/cangjie-sweep-pad.zip"
        if [ -f "$SRC_LOCAL/sweep-pad/cangjie-sweep-pad.zip.sha256" ]; then
          pad_bundle_sha="$SRC_LOCAL/sweep-pad/cangjie-sweep-pad.zip.sha256"
        fi
      fi

      if [ -n "$pad_bundle_zip" ]; then
        say "using Sweep Pad from bundle: $pad_bundle_zip" "使用完整包隨附的滑行板：$pad_bundle_zip"
        cp "$pad_bundle_zip" "$pad_zip" || die "cannot copy $pad_bundle_zip" "無法複製 $pad_bundle_zip"
        if [ -n "$pad_bundle_sha" ]; then
          expected_pad_sha=$(awk '{print $1}' "$pad_bundle_sha")
        fi
      elif [ "$OFFLINE" = 1 ]; then
        die "--offline: sweep-pad/cangjie-sweep-pad.zip is missing from the bundle next to install.sh" "--offline：install.sh 旁邊的完整包裡缺少 sweep-pad/cangjie-sweep-pad.zip"
      else
        pad_base="${CJF_PAD_URL_BASE:-https://github.com/$PAD_REPO/releases/download/$PAD_REF}"
        pad_zip_name="cangjie-sweep-pad-$PAD_REF.zip"
        pad_sha_name="cangjie-sweep-pad-$PAD_REF.zip.sha256"
        say "downloading Sweep Pad $PAD_REF from $pad_base" "下載倉頡滑行輸入板 $PAD_REF：$pad_base"
        if [ -d "$pad_base" ]; then
          [ -f "$pad_base/$pad_zip_name" ] || die "$pad_base/$pad_zip_name not found" "找不到 $pad_base/$pad_zip_name"
          [ -f "$pad_base/$pad_sha_name" ] || die "$pad_base/$pad_sha_name not found" "找不到 $pad_base/$pad_sha_name"
          cp "$pad_base/$pad_zip_name" "$pad_zip"
          cp "$pad_base/$pad_sha_name" "$pad_sha"
        else
          download "$pad_base/$pad_zip_name" "$pad_zip" "$pad_zip_name" big
          download "$pad_base/$pad_sha_name" "$pad_sha" "$pad_sha_name"
        fi
        expected_pad_sha=$(awk '{print $1}' "$pad_sha")
      fi

      if [ -n "$expected_pad_sha" ]; then
        verify_sha "$pad_zip" "$expected_pad_sha" "cangjie-sweep-pad ($PAD_REF)"
      fi

      extract_dir="$TMP/sweep_extract"
      mkdir -p "$extract_dir"
      if command -v unzip >/dev/null 2>&1; then
        unzip -q -o "$pad_zip" -d "$extract_dir" || die "failed to extract $pad_zip" "解壓縮失敗：$pad_zip"
      elif [ -n "$PY" ] && [ -x "$PY" ]; then
        "$PY" -m zipfile -e "$pad_zip" "$extract_dir" || die "failed to extract $pad_zip" "解壓縮失敗：$pad_zip"
      else
        die "unzip or python3 required to extract Sweep Pad" "需要 unzip 或 python3 以解壓滑行板"
      fi

      [ -f "$extract_dir/cangjie_sweep_pad.py" ] || die "cangjie_sweep_pad.py not found in zip" "zip 內找不到 cangjie_sweep_pad.py"

      mkdir -p "$SWEEP_DIR" "$BIN_DIR" "$APP_DIR"

      dest_py="$SWEEP_DIR/cangjie_sweep_pad.py"
      if [ -f "$dest_py" ] && cmp -s "$extract_dir/cangjie_sweep_pad.py" "$dest_py"; then
        say "up to date: cangjie_sweep_pad.py" "已是最新：cangjie_sweep_pad.py"
      else
        if [ -f "$dest_py" ]; then
          b=$(backup_file "$dest_py")
          say "backed up cangjie_sweep_pad.py -> $(basename "$b")" "已備份 cangjie_sweep_pad.py -> $(basename "$b")"
        fi
        cp -p "$extract_dir/cangjie_sweep_pad.py" "$dest_py"
        chmod +x "$dest_py"
        say "installed: cangjie_sweep_pad.py" "已安裝：cangjie_sweep_pad.py"
      fi

      for extra in "$extract_dir"/*; do
        [ -e "$extra" ] || continue
        [ "$(basename "$extra")" != "cangjie_sweep_pad.py" ] || continue
        cp -Rp "$extra" "$SWEEP_DIR/"
      done

      py_runner="${PY:-/usr/bin/env python3}"
      cat > "$TMP/launcher.sh" <<LAUNCHER_EOF
#!/bin/bash
exec "$py_runner" "$dest_py" "\$@"
LAUNCHER_EOF
      if [ -f "$SWEEP_LAUNCHER" ] && cmp -s "$TMP/launcher.sh" "$SWEEP_LAUNCHER"; then
        say "up to date: $SWEEP_LAUNCHER" "已是最新：$SWEEP_LAUNCHER"
      else
        cp "$TMP/launcher.sh" "$SWEEP_LAUNCHER"
        chmod +x "$SWEEP_LAUNCHER"
        say "installed launcher: $SWEEP_LAUNCHER" "已安裝啟動器：$SWEEP_LAUNCHER"
      fi

      cat > "$TMP/command.sh" <<CMD_EOF
#!/bin/bash
exec "$py_runner" "$dest_py" "\$@"
CMD_EOF
      if [ -f "$SWEEP_COMMAND" ] && cmp -s "$TMP/command.sh" "$SWEEP_COMMAND"; then
        say "up to date: $SWEEP_COMMAND" "已是最新：$SWEEP_COMMAND"
      else
        cp "$TMP/command.sh" "$SWEEP_COMMAND"
        chmod +x "$SWEEP_COMMAND"
        say "installed command: $SWEEP_COMMAND" "已安裝雙擊執行檔：$SWEEP_COMMAND"
      fi

      if [ -f "$MANIFEST" ]; then
        printf '0 0 @sweep-installed\n0 0 @sweep-dir:%s\n0 0 @sweep-launcher:%s\n0 0 @sweep-command:%s\n' \
          "$SWEEP_DIR" "$SWEEP_LAUNCHER" "$SWEEP_COMMAND" >> "$MANIFEST"
      fi

      if [ -n "$PY" ] && [ -x "$PY" ]; then
        if "$PY" "$dest_py" --self-check > "$TMP/self-check.log" 2>&1; then
          SWEEP_CHECK_OK=1
          say "Sweep Pad self-check passed." "倉頡滑行輸入板自我檢查通過。"
        else
          warn "Sweep Pad self-check reported warnings: $(tr '\n' ' ' < "$TMP/self-check.log")" "滑行板自我檢查有警告：$(tr '\n' ' ' < "$TMP/self-check.log")"
        fi
      fi
    fi
  else
    say "skipping Sweep Pad (--no-sweep)." "略過倉頡滑行輸入板（--no-sweep）。"
  fi

  if [ "$DRY" = 1 ]; then say "DRY RUN finished; nothing was changed." "試跑結束；沒有更動任何東西。"; return 0; fi
  cat <<'NEXT'

[cangjie-fluency] Done. Next steps:
  1. Switch to the Squirrel input source, press Ctrl+` (or F4) and choose the schema "倉頡三代整句" (cangjie3_fluency).
  2. Type a whole phrase of Cangjie codes, e.g. mwyl (面), then Enter commits. Single-letter codes need a trailing space
     (中午 is "l oj").
  3. Check that the language model loaded (after typing once; log folder is $TMPDIR/rime.squirrel/):
       grep -h "use grammar" "${TMPDIR%/}"/rime.squirrel/* | tail -3
     No "use grammar" line = the model is not loaded (the schema still works).
NEXT
  cat <<'NEXT_ZH'

[cangjie-fluency] 完成。接下來：
  1. 切換到 Squirrel 輸入法，按 Ctrl+`（或 F4），選方案「倉頡三代整句」（cangjie3_fluency）。
  2. 一次輸入整段倉頡碼，例如 mwyl（面），再按 Enter 送出。單字母的碼後面要加空白
     （中午要打「l oj」）。
  3. 確認語言模型已載入（先打過一次字；記錄檔資料夾是 $TMPDIR/rime.squirrel/）：
       grep -h "use grammar" "${TMPDIR%/}"/rime.squirrel/* | tail -3
     沒有「use grammar」那一行 = 模型沒有載入（方案本身仍可使用）。
NEXT_ZH
  if [ "$FUZZY_DEFAULT" = 1 ] && [ "$NO_FUZZY" = 0 ]; then
    say "NOTE: with this install the DEFAULT schema is cangjie3_fuzzy (adjacent-key typo tolerance), so step 1 needs no Ctrl+\` / F4 choice; cangjie3_fluency is the next one in the list." "注意：這次安裝的預設方案是 cangjie3_fuzzy（鄰鍵容錯），所以第 1 步不必再按 Ctrl+\` 或 F4 選方案；cangjie3_fluency 在清單的下一個。"
  fi
  if [ "$NO_SWEEP" = 0 ]; then
    if [ "$SWEEP_CHECK_OK" = 1 ]; then
      say "Sweep Pad: ready at $SWEEP_DIR (launcher: $SWEEP_LAUNCHER, command: $SWEEP_COMMAND). Self-check: passed." "倉頡滑行輸入板：已就緒於 $SWEEP_DIR（啟動器：$SWEEP_LAUNCHER，雙擊執行檔：$SWEEP_COMMAND）。自我檢查：通過。"
    else
      say "Sweep Pad: installed at $SWEEP_DIR (launcher: $SWEEP_LAUNCHER, command: $SWEEP_COMMAND). Self-check had issues (see warnings above)." "倉頡滑行輸入板：已安裝於 $SWEEP_DIR（啟動器：$SWEEP_LAUNCHER，雙擊執行檔：$SWEEP_COMMAND）。自我檢查有異常（見上方警告）。"
    fi
  fi
}

do_uninstall() {
  if [ ! -f "$MANIFEST" ]; then
    say "no manifest ($MANIFEST): this installer did not create any file here, nothing to remove." "沒有清單檔（$MANIFEST）：本安裝程式沒有在這裡建立任何檔案，沒有東西可移除。"
    return 0
  fi
  local crc size name cur
  local has_sweep=0 s_dir="" s_launcher="" s_cmd=""
  while read -r crc size name; do
    [ -n "$name" ] || continue
    case "$name" in
      @sweep-installed) has_sweep=1; continue ;;
      @sweep-dir:*) s_dir="${name#@sweep-dir:}"; continue ;;
      @sweep-launcher:*) s_launcher="${name#@sweep-launcher:}"; continue ;;
      @sweep-command:*) s_cmd="${name#@sweep-command:}"; continue ;;
    esac
    if [ ! -f "$RIME_DIR/$name" ]; then say "already gone: $name" "已不存在：$name"; continue; fi
    cur=$(cksum < "$RIME_DIR/$name" | awk '{print $1 " " $2}')
    if [ "$cur" != "$crc $size" ]; then
      warn "kept $name: it was changed after the installer wrote it" "保留 $name：它在安裝程式寫入後被修改過"
      continue
    fi
    if [ "$DRY" = 1 ]; then say "DRY: would remove $name" "試跑：將會移除 $name"
    else rm "$RIME_DIR/$name" && say "removed $name" "已移除 $name"; fi
  done < "$MANIFEST"
  if [ "$has_sweep" = 1 ]; then
    s_dir="${s_dir:-$SWEEP_DIR}"
    s_launcher="${s_launcher:-$SWEEP_LAUNCHER}"
    s_cmd="${s_cmd:-$SWEEP_COMMAND}"
    if [ "$DRY" = 1 ]; then
      say "DRY: would remove Sweep Pad: $s_dir, $s_launcher, $s_cmd" "試跑：將會移除倉頡滑行輸入板：$s_dir、$s_launcher、$s_cmd"
    else
      [ ! -d "$s_dir" ] || rm -rf "$s_dir"
      [ ! -f "$s_launcher" ] || rm -f "$s_launcher"
      [ ! -f "$s_cmd" ] || rm -f "$s_cmd"
      say "removed Sweep Pad ($s_dir, $s_launcher, $s_cmd)" "已移除倉頡滑行輸入板（$s_dir、$s_launcher、$s_cmd）"
    fi
  fi
  if [ "$DRY" != 1 ]; then rm "$MANIFEST"; fi
  say "backups (*.bak-*) were kept." "備份檔（*.bak-*）已保留。"
  if [ -f "$RIME_DIR/default.custom.yaml" ] && grep -q 'cangjie[35]_fluency' "$RIME_DIR/default.custom.yaml"; then
    warn "default.custom.yaml still lists the fluency schema(s); remove those '- schema: ...' lines yourself (or restore a default.custom.yaml.bak-* backup)." "default.custom.yaml 仍列出 fluency 方案；請自行刪除那些「- schema: ...」行（或還原 default.custom.yaml.bak-* 備份）。"
  fi
  if [ "$NO_DEPLOY" != 1 ] && [ "$DRY" != 1 ] && [ -x "$SQUIRREL_APP/Contents/MacOS/Squirrel" ]; then
    "$SQUIRREL_APP/Contents/MacOS/Squirrel" --reload || true
  fi
  return 0
}

main "$@"
exit $?
