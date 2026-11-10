# cangjie-fluency-macos

Microsoft-style **sentence input for Cangjie** on macOS, for [Squirrel / 鼠鬚管](https://github.com/rime/squirrel)
(Rime for macOS). Type a whole phrase of Cangjie codes without picking characters; the buffer re-segments and
auto-corrects as you type; Enter commits the sentence.

* English: this section. 繁體中文: scroll down to [繁體中文](#繁體中文).
* Everything it needs comes from the owner's main repository
  [githubhjs/cangjie-fluency](https://github.com/githubhjs/cangjie-fluency): the schema files, the Cangjie tables (`tables/`),
  the word list and the language model (`data/`), the converter (`tools/`) and, for a Mac without Squirrel, the unmodified upstream
  Squirrel 1.1.2 installer (release `deps-v1`, GPL-3.0, notice attached there). Provenance and licences of the data files are in the
  main repo's `tables/README.md` and `data/README.md`. **No other third party is contacted**: not PIME, not rime-essay, not
  rime-octagram-data, not Homebrew, not GitHub's `rime/squirrel` repository.
* Status: **install, table conversion and deploy were run on a real Mac (macOS 26.5.2, Apple silicon, Squirrel 1.1.2, 2026-11-10)
  with the previous (download-from-third-parties) version of this installer; the owner then typed with it in Squirrel and got the
  right characters (顏值, 頻率: reported, no log kept).** The new bundle/offline/pkg code paths were tested on Linux only, with
  stubs. See [Verified / unverified](#verified--unverified) and `docs/test-log.md`.

## What you get

* `cangjie3_fluency` (倉頡三代整句), the main schema. Windows XP's built-in 新倉頡 is a modified **3rd-generation**
  Cangjie, so the 3rd-generation code table is the closest match for people who learned on it (about a fifth of the
  characters have different codes than 5th generation). It is listed first, so it is your default Squirrel schema.
* Optional `--with-cangjie5`: also `cangjie5_fluency` (5th generation).
* The full language model `zh-hant-t-essay-bgw.gram` (41,415,724 bytes, librime-octagram). Squirrel 1.1.2 bundles a smaller
  10.5 MB file with the same name; the installer always puts the full one in `~/Library/Rime`.

## Install

### Option A: full release zip (works offline)

Download `cangjie-fluency-macos-<version>-full.zip` from this repository's Releases, unzip, then in Terminal:

```
cd cangjie-fluency-macos-<version>
bash install.sh --offline
```

The zip holds the installer, schema files, tables, word list, the language model, the converter and `deps/Squirrel-1.1.2.pkg`
(about 64 MB zipped). `--offline` never touches the network and stops with a clear message if a file is missing. A `slim` zip (installer
+ schema files + converter) fetches the rest from the main repo.

### Option B: one line

```
curl -fsSL https://raw.githubusercontent.com/githubhjs/cangjie-fluency-macos/main/install.sh | bash
```

or the safer way (download, read, dry-run, run):

```
curl -fsSL -o install.sh https://raw.githubusercontent.com/githubhjs/cangjie-fluency-macos/main/install.sh
less install.sh
bash install.sh --dry-run
bash install.sh
```

Options: `--offline` (no network; files must be next to `install.sh`), `--no-deps` (do not install Squirrel when it is missing),
`--rime-dir DIR` (default `~/Library/Rime`, or `$RIME_DIR`), `--ref TAG` (version of the main repo to download missing files
from, default `v0.4.0`), `--with-cangjie5`, `--no-model`, `--no-deploy`, `--dry-run`, `--uninstall`.

The installer needs only bash, `/usr/bin/perl`, awk and (unless `--offline`) curl, all of which ship with macOS. It:

1. Checks for `/Library/Input Methods/Squirrel.app`. **If it is missing**, it takes `Squirrel-1.1.2.pkg` (from `deps/` of the full
   zip, else from the main repo's release `deps-v1`), checks its SHA-256 and runs `sudo installer -pkg ... -target /` (asks for
   your password). If Squirrel is already installed it is left alone. `--no-deps` skips this and stops instead.
2. Takes every other file from the folder next to `install.sh` (layout `weasel/ tables/ data/ tools/`), otherwise from
   `raw.githubusercontent.com/githubhjs/cangjie-fluency/<ref>/`. Tables, word list, model and pkg are **SHA-256 checked** against
   hashes pinned in the script.
3. Converts `tables/mscj3.cin` **on your machine** with `tools/cin2rime.pl` into `cangjie3.base.dict.yaml`, always using the
   repository's `data/essay.txt` for the frequency weights, so the table is byte-identical on every platform (checked against the
   python converter and a Linux run, see `docs/test-log.md`).
4. Installs the repository's `essay.txt` into `~/Library/Rime` only when neither Squirrel's bundle nor that folder has one, and
   always installs the full language model there.
5. Creates `default.custom.yaml`, or, if you already have one, backs it up and inserts `- schema: cangjie3_fluency` as the first
   entry of your existing `schema_list` (indentation, line endings and `- {schema: x}` style kept). If your file has no
   `schema_list` it is not touched and the installer prints what to add. Your list is never overwritten.
6. Asks Squirrel to redeploy (`Squirrel --reload`). That only reaches Squirrel while it is running; otherwise use the menu bar
   icon > Deploy.

Re-running is safe: identical files are not rewritten and get no backup; a changed file gets exactly one timestamped backup
(`name.bak-YYYYmmdd-HHMMSS`).

**After installing Squirrel for the first time, add it by hand:** System Settings > Keyboard > Text Input > Input Sources > Edit...
> `+` > **Chinese, Traditional** > Squirrel (鼠鬚管). On macOS 26.5.2 the command-line registration (`Squirrel --register-input-source` /
`--enable-input-source`) printed "succeeds" but Squirrel did not appear in the input menu, so adding it in System Settings is the
step that matters (menu names on other macOS versions are unverified). Squirrel's own README says to log out and in only if typing
does not work in some apps after the first install.

## Switching to it

In any text field press `` Ctrl+` `` (or `F4`) and pick 倉頡三代整句. (Those hotkeys are in the default.yaml shipped inside
Squirrel 1.1.2: `Control+grave`, `Control+Shift+grave`, `F4`.)

## Check that the language model loaded

Type something once with the schema, then:

```
grep -h "use grammar" "${TMPDIR%/}"/rime.squirrel/* | tail -3
```

`use grammar: zh-hant-t-essay-bgw` means loaded. No such line: the schema still works, only sentence correction is weaker.
glog buffers the log, so the line can appear late (after Squirrel has run a while or quit).

## Typing notes

* Type the codes of several characters in a row: `mwyl` gives 面; `dhedhkb` gives 板橋 as you type the last code
  (3rd generation codes: 板 = `dhe`, 橋 = `dhkb`). Continue typing and earlier characters get corrected.
* **A character with a single-letter code needs a trailing space**: 中午 is `l oj` (中 = `l`).
* Enter commits the whole sentence. `,` `.` `!` `?` commit the sentence and then type the full-width punctuation.
* Backspace removes one code, Esc clears the buffer. Characters with the same code (雙/隻 and the like) are ranked by
  word frequency; wrong one: arrow keys or PageDown.
* Reverse lookup: `` ` `` then pinyin. Left Shift toggles Chinese/English and commits the buffer.

**Language model.** Our test sentences (51 everyday sentences, 40 same-code hard sentences, 91 whole sentences in total, and 34
same-code pairs such as 手感/手怠 and 頻率/顏率) give the same result with and without the model, because those words already
have frequencies in `essay.txt`. We have not found a case that measures a model effect. The model file is shipped in the main
repository and installed anyway.

## Known limits

* Installed and deployed on one real Mac (with the earlier installer), typing confirmed by the owner for two words. The schema files
  are the same as on Windows; `cangjie3_fluency` was tested on Linux librime and in that Mac session.
* The empty-buffer behaviour of space, upper-case letters and symbols differs from Microsoft's, as in the Windows version
  (see the main repo's docs).
* The table is `tables/mscj3.cin`, a modified 3rd generation as shipped in Windows, not an official table of anyone's.
  Whether it equals Windows XP's table exactly is unverified (面, 非, 作, 知/佑 were checked).
* Squirrel's bundled `essay.txt` is not byte-identical to the one in this repo's `data/`, but the converter always uses the repo's
  copy, so the generated table does not depend on it.

## Verified / unverified

Verified on Linux (2026-11-10), `tests/test_install.sh` with 95 checks, bash 3.2-style code, stubs for curl/sudo/Squirrel:

* A full-bundle `--offline` install makes **zero network calls** (curl/wget/sudo replaced by stubs that record and fail).
* The generated `cangjie3.base.dict.yaml` from the perl converter is byte-identical to the python converter's output and to the
  direct perl run; SHA-256 mismatches (table, Squirrel pkg) stop the install; the online path only requests
  `githubusercontent.com/githubhjs/cangjie-fluency/...`; a missing Squirrel is installed from the bundled pkg through a stub of
  `sudo installer` (never run for real here); `--no-deps` stops instead.
* The Squirrel 1.1.2 package (sha256 `61474601...8287`) contains `Contents/Frameworks/rime-plugins/librime-octagram.dylib`,
  `Contents/SharedSupport/essay.txt`, `luna_quanpin.schema.yaml` and a 10,513,408-byte `zh-hant-t-essay-bgw.gram`.
* Squirrel's `--reload` posts a reload notification that makes the running app deploy; the user folder is `~/Library/Rime`.

Verified on a real Mac with the previous installer (macOS 26.5.2, arm64, `/bin/bash` 3.2.57, `/usr/bin/perl` 5.34.1, Squirrel 1.1.2):
the one-line install ran to the end; the perl table was byte-identical to the python one; deploy gave **no `E` lines**; the owner typed
顏值 and 頻率 and got the right characters. **Do not use `Squirrel --build`** to deploy (it treats the current folder as the shared
data folder); use `--reload` or the menu bar icon > Deploy.

Still unverified: the new installer on a Mac (offline mode, installing Squirrel from the pkg with `sudo installer`, `shasum` use);
the `use grammar` / `failed to load grammar` log line on the Mac (glog buffers: after typing, `Squirrel --quit` and
`grep -h -E "use grammar|failed to load grammar" "${TMPDIR%/}"/rime.squirrel/*`); whether a gram in `~/Library/Rime` takes precedence
over the one inside the app bundle (assumed); Squirrel versions older than 1.1.2; Intel Macs; other macOS versions.

## Uninstall

```
bash install.sh --uninstall
```

removes only the files this installer created (it keeps a manifest, `~/Library/Rime/.cangjie-fluency-macos.manifest`) and
only if you have not changed them since. Backups (`*.bak-*`) are kept. Squirrel itself is not removed. A pre-existing
`default.custom.yaml` that was edited is not changed back: the installer tells you which lines to delete (or restore the `.bak-`
copy). Then redeploy.

## Releases

```
./make-release.sh ~/projects/cangjie-fluency v0.2.0    # dist/*-full.zip and *-slim.zip; needs the main repo checkout
```

## Credits and licensing

* The Cangjie input method was created by Chu Bong-Foo (朱邦復), who publicly waived the patent in 1982.
* [rime/rime-cangjie](https://github.com/rime/rime-cangjie), [rime/rime-quick](https://github.com/rime/rime-quick) and eight04's
  `quick5_fluency` prototype ([rime-quick#2](https://github.com/rime/rime-quick/issues/2)): the ideas this builds on.
* [cangjie-system/rime-cangjie-integrated](https://github.com/cangjie-system/rime-cangjie-integrated) (MIT) collects Cangjie tables
  for Rime; it is a plain table input method, and this project adds the sentence-style mode.
* Squirrel (GPL-3.0) is by the Rime project; the pkg in the full zip and in the release `deps-v1` is the unmodified upstream
  1.1.2 file, with its licence and a notice in `deps/` / the release.
* Provenance and licensing of the tables, word list and language model: the main repo's `tables/README.md` and `data/README.md`.
* This repository: LGPL-3.0, see `LICENSE`.

---

# 繁體中文

macOS 上 Squirrel（鼠鬚管，Rime for macOS）的**倉頡整句輸入**：像微軟新倉頡一樣，一路打整串字根，緩衝區會自動重新斷詞、修正，
最後按 Enter 上屏。所需檔案全部由主倉庫 [githubhjs/cangjie-fluency](https://github.com/githubhjs/cangjie-fluency) 提供：方案檔、
倉頡碼表（`tables/`）、詞彙表與語言模型（`data/`）、轉換工具（`tools/`），以及（Mac 沒裝 Squirrel 時）未修改的 Squirrel 1.1.2 安裝包
（主倉庫 release `deps-v1`，GPL-3.0）。各資料檔的來源與授權請看主倉庫的 `tables/README.md`、`data/README.md`。
**不會連到任何其他第三方**（不是 PIME、rime-essay、rime-octagram-data，也不用 Homebrew）。

**狀態：已在一台真實的 Mac（macOS 26.5.2、Apple 晶片、Squirrel 1.1.2）上用舊版安裝腳本完成安裝、碼表轉換與部署（0 錯誤），
並由本人實際打出「顏值」「頻率」得到正確的字；新的離線／內附安裝包流程只在 Linux 用假指令測過。**

## 為什麼是三代

Windows XP 內建的新倉頡是三代倉頡的修改版，所以預設方案 `cangjie3_fluency`（倉頡三代整句）用三代碼表，
對從 XP 練起的人最接近；約兩成的字碼和五代不同。想要五代版可加 `--with-cangjie5`，另外安裝 `cangjie5_fluency`。

## 安裝

### 方式 A：完整離線包

到本倉庫的 Releases 下載 `cangjie-fluency-macos-<版本>-full.zip`，解壓後在終端機：

```
cd cangjie-fluency-macos-<版本>
bash install.sh --offline
```

完整包含安裝腳本、方案檔、碼表、詞彙表、語言模型、轉換工具與 `deps/Squirrel-1.1.2.pkg`（壓縮後約 64 MB）。`--offline` 完全不連網，缺檔會明確報錯。
另有 `slim` 精簡包，其餘檔案安裝時從主倉庫下載。

### 方式 B：一行指令

```
curl -fsSL https://raw.githubusercontent.com/githubhjs/cangjie-fluency-macos/main/install.sh | bash
```

比較安全的做法（先下載、看過、先 dry-run 再執行）：

```
curl -fsSL -o install.sh https://raw.githubusercontent.com/githubhjs/cangjie-fluency-macos/main/install.sh
less install.sh
bash install.sh --dry-run
bash install.sh
```

腳本只用 macOS 內建的 bash、`/usr/bin/perl`、awk（沒有 `--offline` 時還有 curl）。它會：沒裝 Squirrel 就用附帶（或主倉庫 release 的）
`Squirrel-1.1.2.pkg`，核對 SHA-256 後執行 `sudo installer -pkg ... -target /`（會問密碼；已經裝了就不動；`--no-deps` 可跳過）→
其他檔案優先取腳本旁邊的資料夾，否則從主倉庫下載，碼表、詞彙表、模型都核對 SHA-256 → 在你的電腦上轉換三代碼表（一律用主倉庫的
`data/essay.txt` 當權重，各平台結果逐位元組相同）→ 安裝完整語言模型 → 合併 `default.custom.yaml`（已有的檔案會先備份，
並只在你現有的 `schema_list` 最前面插入 `- schema: cangjie3_fluency`；沒有 `schema_list` 就不動它，只告訴你要加什麼）→ 請 Squirrel 重新部署。
重複執行是安全的：內容相同的檔案不會重寫、不會備份。

選項：`--offline`、`--no-deps`、`--rime-dir DIR`、`--ref TAG`（預設 `v0.4.0`）、`--with-cangjie5`、`--no-model`、`--no-deploy`、`--dry-run`、`--uninstall`。

**第一次裝好 Squirrel 之後要手動加入輸入法**：系統設定 > 鍵盤 > 文字輸入 > 輸入方式 > 編輯… > `+` > 中文（繁體）> Squirrel（鼠鬚管）。
在 macOS 26.5.2 上用指令註冊會顯示成功但選單裡不會出現，所以手動加入這一步是必要的。（Squirrel 官方說明：只有初次安裝後在部分應用程式打不出字時，才需要登出再登入。）

若自動部署沒反應（Squirrel 沒在執行時，`--reload` 沒有對象）：按選單列的 Squirrel 圖示 > Deploy（重新部署）。

## 切換方案

在任何輸入框按 `` Ctrl+` ``（或 `F4`），選「倉頡三代整句」。

## 確認語言模型有載入

用這個方案打過字之後：

```
grep -h "use grammar" "${TMPDIR%/}"/rime.squirrel/* | tail -3
```

看到 `use grammar: zh-hant-t-essay-bgw` 就是有載入；沒有這行方案仍可用，只是整句修正較弱（記錄檔有緩衝，可能很晚才出現）。

## 打法

* 一路打字根：`mwyl` → 面；`dhedhkb` → 打到最後一碼時變成「板橋」（三代：板 `dhe`、橋 `dhkb`）。繼續打會自動修正前面的字。
* **只有一個字根的字後面要接空格**：「中午」打 `l oj`。
* Enter 上屏整句；`,` `.` `!` `?` 會先上屏整句再輸出全形標點。
* Backspace 退一個字根、Esc 清空；同碼字（雙/隻…）靠詞頻排序，不對就用方向鍵或 PageDown 換。
* 反查：`` ` `` 後輸入拼音。左 Shift 切換中英文並上屏緩衝區。

**語言模型**：我們的測試句（51 句日常句、40 句同碼困難句，共 91 句整句，以及 34 組同碼詞對，例如 手感/手怠、頻率/顏率）
有沒有語言模型結果都相同，因為這些詞在 `essay.txt` 裡已有詞頻；我們沒有找到能量出語言模型效果的案例。模型檔放在主倉庫裡，仍會一併安裝。

## 已知限制

* 空緩衝區時空格、大寫字母、符號的行為和微軟不完全相同（細節見主倉庫文件）。
* **Squirrel 1.1.2 內建的 `zh-hant-t-essay-bgw.gram` 只有 10,513,408 位元組，本腳本安裝的是 41,415,724 位元組的完整版**，放在 `~/Library/Rime`
  （使用者資料夾優先於 app 內的檔案，這點在 Mac 上**未驗證**）。
* 三代碼表是否與 Windows XP 完全一致：**未驗證**（只核對了 面、非、作、知/佑）。

## 移除

```
bash install.sh --uninstall
```

只會刪除這個腳本自己建立、而且你之後沒有改過的檔案（清單在 `~/Library/Rime/.cangjie-fluency-macos.manifest`），備份檔（`*.bak-*`）保留，
Squirrel 本身不會移除。你自己的 `default.custom.yaml` 不會被改回去，腳本會提醒你刪掉哪幾行（或還原 `.bak-` 備份）。之後再重新部署。

## 來源與授權

倉頡輸入法由朱邦復先生創製，他已公開放棄專利權（1982）。感謝 rime/rime-cangjie、rime/rime-quick、eight04 的 `quick5_fluency`
原型（rime-quick#2），以及 [cangjie-system/rime-cangjie-integrated](https://github.com/cangjie-system/rime-cangjie-integrated)（MIT）。
Squirrel（GPL-3.0）由 Rime 專案開發；完整包與 `deps-v1` release 中的安裝包是未修改的上游 1.1.2。
碼表、詞彙表、語言模型的來源與授權：主倉庫的 `tables/README.md`、`data/README.md`。本倉庫授權：LGPL-3.0，見 `LICENSE`。
