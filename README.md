# cangjie-fluency-macos

Microsoft-style **sentence input for Cangjie** on macOS, for [Squirrel / 鼠鬚管](https://github.com/rime/squirrel)
(Rime for macOS). Type a whole phrase of Cangjie codes without picking characters; the buffer re-segments and
auto-corrects as you type; Enter commits the sentence.

* English: this section. 繁體中文: scroll down to [繁體中文](#繁體中文).
* The schema itself lives in the main repo, [githubhjs/cangjie-fluency](https://github.com/githubhjs/cangjie-fluency)
  (Windows / Weasel, same files). This repo only contains the macOS installer. The installer downloads the schema files
  from the main repo at a pinned tag (default `v0.2.0`), so there is a single source of truth.
* Status: **install, table conversion and deploy were run on a real Mac (macOS 26.5.2, Apple silicon, Squirrel 1.1.2, 2026-11-10);
  the owner then typed with it in Squirrel and got the right characters (顏值, 頻率: reported, no log kept); the
  `use grammar` log line is not confirmed yet.** See
  [Verified / unverified](#verified--unverified) and `docs/test-log.md`.

## What you get

* `cangjie3_fluency` (倉頡三代整句), the main schema. Windows XP's built-in 新倉頡 is a modified **3rd-generation**
  Cangjie, so the 3rd-generation code table is the closest match for people who learned on it (about a fifth of the
  characters have different codes than 5th generation). It is listed first, so it is your default Squirrel schema.
* Optional `--with-cangjie5`: also `cangjie5_fluency` (5th generation, table from rime-cangjie).
* The language model `zh-hant-t-essay-bgw.gram` (41 MB, librime-octagram) for better sentence choice.

## Install

Squirrel first (Ventura or newer, per the Homebrew cask):

```
brew install --cask squirrel-app
```

(The cask is called `squirrel-app`; `squirrel` is only an old alias. No Homebrew: download `Squirrel-<version>.pkg` from
<https://github.com/rime/squirrel/releases>.) Then add Squirrel under System Settings > Keyboard > Text Input >
Input Sources > Edit... > `+` > **Chinese, Traditional** > Squirrel (鼠鬚管), and log out and in once. Squirrel has two input
modes, `...Squirrel.Hans` (Simplified) and `...Squirrel.Hant` (Traditional); the Traditional one is the one to add.
**Tested on macOS 26.5.2:** installing the package and running `Squirrel --register-input-source` / `--enable-input-source`
(also through `launchctl asuser`) printed "succeeds", but Squirrel did **not** appear in the input menu and nothing was written to
`com.apple.HIToolbox`. Adding it by hand in System Settings is the step that matters (exact menu names on your macOS version
are unverified here: the Settings UI changes between releases).

Then, one line:

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

Options: `--rime-dir DIR` (default `~/Library/Rime`, or `$RIME_DIR`), `--ref TAG` (schema version from the main repo,
default `v0.2.0`), `--with-cangjie5`, `--no-model` (skip the 41 MB download), `--no-deploy`, `--dry-run`, `--uninstall`.

The installer needs only bash, curl, awk and `/usr/bin/perl`, all of which ship with macOS (no python, no sudo). It:

1. checks that Squirrel is installed;
2. downloads the schema + dict files for the pinned tag;
3. finds `essay.txt` (user folder, else inside the Squirrel app, else downloads it);
4. downloads PIME's `mscj3.cin` and converts it **on your machine** with `tools/cin2rime.pl`
   (a Perl port of the main repo's `cin2rime.py`, byte-identical output, see `docs/test-log.md`) into `cangjie3.base.dict.yaml`;
5. downloads the language model (size-checked, 41,415,724 bytes);
6. creates `default.custom.yaml`, or, if you already have one, backs it up and inserts `- schema: cangjie3_fluency` as the
   first entry of your existing `schema_list` (indentation, line endings and `- {schema: x}` style kept). If your file
   has no `schema_list` it is not touched and the installer prints what to add. Your list is never overwritten;
7. asks Squirrel to redeploy (`Squirrel --reload`). That only reaches Squirrel while it is running; otherwise use the
   menu bar icon > Deploy.

Re-running is safe: identical files are not rewritten and get no backup; a changed file gets exactly one timestamped
backup (`name.bak-YYYYmmdd-HHMMSS`). Everything is under the Rime user folder.

## Switching to it

In any text field press `` Ctrl+` `` (or `F4`) and pick 倉頡三代整句. (Those hotkeys are in the default.yaml shipped inside
Squirrel 1.1.2: `Control+grave`, `Control+Shift+grave`, `F4`.)

## Check that the language model loaded

Type something once with the schema, then:

```
grep -h "use grammar" "${TMPDIR%/}"/rime.squirrel/* | tail -3
```

`use grammar: zh-hant-t-essay-bgw` means loaded. No such line: the schema still works, only sentence correction is weaker.
(Squirrel sets its log folder to `$TMPDIR/rime.squirrel` in its source; the exact log file names are unverified.)

## Typing notes

* Type the codes of several characters in a row: `mwyl` gives 面; `dhedhkb` gives 板橋 as you type the last code
  (3rd generation codes: 板 = `dhe`, 橋 = `dhkb`). Continue typing and earlier characters get corrected.
* **A character with a single-letter code needs a trailing space**: 中午 is `l oj` (中 = `l`).
* Enter commits the whole sentence. `,` `.` `!` `?` commit the sentence and then type the full-width punctuation.
* Backspace removes one code, Esc clears the buffer. Characters with the same code (雙/隻 and the like) are ranked by
  word frequency; wrong one: arrow keys or PageDown.
* Reverse lookup: `` ` `` then pinyin.
* Left Shift toggles Chinese/English and commits the buffer.

## Known limits

* Installed and deployed on one real Mac; typing not yet confirmed (see below). The schema files are the same as on Windows, where `cangjie5_fluency` was tested
  with Weasel 0.17.4 and Linux librime 1.10; `cangjie3_fluency` was tested on Linux librime only.
* The language model made little difference on our test sentences (see the main repo's test logs).
* The `cangjie3.base.dict.yaml` weights use essay.txt word frequencies. The essay.txt bundled in Squirrel 1.1.2 is not
  byte-identical to rime-essay `master` (5,887,695 vs 5,887,319 bytes), so the order of same-code characters can differ
  slightly from the Windows build.
* The table is PIME's `mscj3.cin`, a modified 3rd generation as shipped in Windows, not an official table of anyone's.
* The empty-buffer behaviour of space, upper-case letters and symbols differs from Microsoft's, as in the Windows version
  (see the main repo's docs).

## Verified / unverified

Verified (by reading sources or unpacking the release on Linux, 2026-11-10):

* Homebrew cask is `squirrel-app` (formulae.brew.sh API: `squirrel-app.json` 200, `squirrel.json` 404, `old_tokens: ["squirrel"]`),
  version 1.1.2, needs macOS Ventura or newer, installs to `/Library/Input Methods/Squirrel.app`.
* The Squirrel 1.1.2 package (sha256 `61474601...8287`) contains `Contents/Frameworks/rime-plugins/librime-octagram.dylib`
  (also lua and predict), `Contents/SharedSupport/essay.txt`, `luna_quanpin.schema.yaml`, `zh-hant-t-essay-bgw.gram`
  and `zh-hant-t-essay-bgc.gram`. No `grammar.yaml` there, which is why the schema carries its own grammar settings.
* **The `zh-hant-t-essay-bgw.gram` inside Squirrel 1.1.2 is 10,513,408 bytes, the file this installer downloads is
  41,415,724 bytes** (lotem/rime-octagram-data branch `hant`). The installer puts the big one in `~/Library/Rime`.
* Squirrel's `--reload` posts a reload notification that makes the running app deploy (`Main.swift`,
  `SquirrelApplicationDelegate.swift`). The user folder is `~/Library/Rime`.
* The model line `use grammar: <language>` is logged by librime-octagram (`octagram.cc`).
* On Linux: the generated table is byte-identical to the python converter's; librime builds both schemas; per-key
  traces are in `docs/test-log.md`; `tests/test_install.sh` passes (80 checks).

Verified on a real Mac (macOS 26.5.2, arm64, `/bin/bash` 3.2.57, `/usr/bin/perl` 5.34.1, curl 8.7.1, Squirrel 1.1.2 from
`brew install --cask squirrel-app`, 2026-11-10):

* The one-line install (`curl ... | bash`) ran to the end with bash 3.2: Squirrel found, bundled `essay.txt` used, table downloaded from
  PIME and converted (22,174 entries, 21,010 characters), the 41,415,724-byte model downloaded, `default.custom.yaml` written.
* **The table the perl converter produced on the Mac is byte-identical to the python converter's output** for the same inputs
  (Squirrel's bundled `essay.txt` and PIME `mscj3.cin`), so the macOS path gives the same table as the Windows and Linux paths.
* `open -a "/Library/Input Methods/Squirrel.app"` then `Squirrel --reload` deployed all schemas with **no `E` lines** in the log;
  `build/` contains `cangjie3_fluency.table.bin` (15,187,380 B), `.prism.bin`, `.reverse.bin` and the schema. The log shows
  `loaded plugin: octagram` from `Squirrel.app/Contents/Frameworks/rime-plugins/`.
* Squirrel's log folder is `$TMPDIR/rime.squirrel/` with files like `rime.squirrel.<host>.<user>.log.INFO.<date>-<time>.<pid>.log`
  and `rime.squirrel.INFO` symlinks (the deploy itself logs to `rime.squirrel-builder.*`).
* **Do not use `Squirrel --build`** to deploy: it treats the current folder as the shared data folder, finds no `default.yaml`
  and logs "schema list not defined". Use `--reload` while Squirrel is running (or the menu bar icon > Deploy).

Still unverified:

* Typing with `cangjie3_fluency` in a real Squirrel session **was done by the owner** (2026-11-10, after adding Squirrel by hand in
  System Settings): 顏值 and 頻率 came out as the right characters. What is still unconfirmed is the `use grammar` /
  `failed to load grammar` log line: glog buffers the INFO file, so it may only appear after Squirrel has run a while or quit
  (on Linux it appeared only after the engine stopped). Please check: type, then, if nothing shows up, `Squirrel --quit` and run
  `grep -h -E "use grammar|failed to load grammar" "${TMPDIR%/}"/rime.squirrel/*`.
* Whether a gram in `~/Library/Rime` takes precedence over the one inside the app bundle (assumed; the Linux test found the model in
  the user folder when the shared folder had none).
* Squirrel versions older than 1.1.2: which plugins they bundle; Intel Macs; other macOS versions.

## Uninstall

```
bash install.sh --uninstall
```

removes only the files this installer created (it keeps a manifest, `~/Library/Rime/.cangjie-fluency-macos.manifest`) and
only if you have not changed them since. Backups (`*.bak-*`) are kept. A pre-existing `default.custom.yaml` that was
edited is not changed back: the installer tells you which lines to delete (or restore the `.bak-` copy). Then redeploy.

## Credits and licensing

* The Cangjie input method was created by Chu Bong-Foo (朱邦復), who publicly waived the patent in 1982.
* [rime/rime-cangjie](https://github.com/rime/rime-cangjie) (5th-generation table, schema ideas),
  [rime/rime-quick](https://github.com/rime/rime-quick) and eight04's `quick5_fluency` prototype
  ([rime-quick#2](https://github.com/rime/rime-quick/issues/2)).
* [PIME](https://github.com/EasyIME/PIME) `mscj3.cin` is the source of the 3rd-generation table.
* [cangjie-system/rime-cangjie-integrated](https://github.com/cangjie-system/rime-cangjie-integrated) (MIT) collects Cangjie tables for
  Rime (3rd generation, Microsoft-style, Yahoo, 5th and 6th generation); it is a plain table input method, and this project adds the
  sentence-style mode. Its `cangjie.3-ms.dict.yaml` (a Vista Microsoft Cangjie table) agrees with `mscj3.cin` on 98% of the shared
  characters and on candidate order, which is why we trust `mscj3.cin` to be the Microsoft 3rd-generation table.
* **Licensing note:** `mscj3.cin` has no license header. For that reason it, and `cangjie3.base.dict.yaml` generated from
  it, are never stored in this repository (see `.gitignore`); the installer downloads the table at install time and
  converts it on your machine. Do not commit them.
* This repository: LGPL-3.0, see `LICENSE`.

---

# 繁體中文

macOS 上 Squirrel（鼠鬚管，Rime for macOS）的**倉頡整句輸入**：像微軟新倉頡一樣，一路打整串字根，緩衝區會自動重新斷詞、修正，
最後按 Enter 上屏。方案檔與 Windows 版（小狼毫）相同，放在主倉庫 [githubhjs/cangjie-fluency](https://github.com/githubhjs/cangjie-fluency)，
本倉庫只有 macOS 安裝腳本，安裝時會從主倉庫的固定版本（預設 `v0.2.0`）下載方案檔。

**注意：已在一台真實的 Mac（macOS 26.5.2、Apple 晶片、Squirrel 1.1.2）上完成安裝、碼表轉換與部署（0 錯誤）；實際打字與語言模型是否載入還沒有人確認。** 哪些有驗證、哪些沒有，見上面 [Verified / unverified](#verified--unverified)。

## 為什麼是三代

Windows XP 內建的新倉頡是三代倉頡的修改版，所以預設方案 `cangjie3_fluency`（倉頡三代整句）用三代碼表（PIME 的 `mscj3.cin`），
對從 XP 練起的人最接近；約兩成的字碼和五代不同。想要五代版可加 `--with-cangjie5`，另外安裝 `cangjie5_fluency`。

## 安裝

先裝 Squirrel（Homebrew 的 cask 名稱是 **`squirrel-app`**，不是 `squirrel`；需要 macOS Ventura 以上）：

```
brew install --cask squirrel-app
```

沒有 Homebrew 就到 <https://github.com/rime/squirrel/releases> 下載 `Squirrel-<版本>.pkg`。裝完到「系統設定 > 鍵盤 > 輸入方式」
加入 Squirrel（中文，繁體），登出再登入一次。

一行安裝：

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

腳本只用 macOS 內建的 bash、curl、awk 和 `/usr/bin/perl`（不需要 python、不需要 sudo），全部寫在 `~/Library/Rime`：
下載方案檔、下載並**在你的電腦上**轉換三代碼表、下載 41 MB 語言模型、合併 `default.custom.yaml`（已有的檔案會先備份，
並只在你現有的 `schema_list` 最前面插入 `- schema: cangjie3_fluency`；沒有 `schema_list` 就不動它，只告訴你要加什麼），最後請 Squirrel 重新部署。
重複執行是安全的：內容相同的檔案不會重寫、不會備份。

選項：`--rime-dir DIR`、`--ref TAG`、`--with-cangjie5`、`--no-model`、`--no-deploy`、`--dry-run`、`--uninstall`。

若自動部署沒反應（Squirrel 沒在執行時，`--reload` 沒有對象）：按選單列的 Squirrel 圖示 > Deploy（重新部署）。

## 切換方案

在任何輸入框按 `` Ctrl+` ``（或 `F4`），選「倉頡三代整句」。（這兩個快捷鍵來自 Squirrel 1.1.2 內建的 default.yaml。）

## 確認語言模型有載入

用這個方案打過字之後：

```
grep -h "use grammar" "${TMPDIR%/}"/rime.squirrel/* | tail -3
```

看到 `use grammar: zh-hant-t-essay-bgw` 就是有載入；沒有這行方案仍可用，只是整句修正較弱。（記錄檔資料夾是從 Squirrel 原始碼讀到的，
實際檔名**未驗證**。）

## 打法

* 一路打字根：`mwyl` → 面；`dhedhkb` → 打到最後一碼時變成「板橋」（三代：板 `dhe`、橋 `dhkb`）。繼續打會自動修正前面的字。
* **只有一個字根的字後面要接空格**：「中午」打 `l oj`。
* Enter 上屏整句；`,` `.` `!` `?` 會先上屏整句再輸出全形標點。
* Backspace 退一個字根、Esc 清空；同碼字（雙/隻…）靠詞頻排序，不對就用方向鍵或 PageDown 換。
* 反查：`` ` `` 後輸入拼音。左 Shift 切換中英文並上屏緩衝區。

## 已知限制

* 沒有在 Mac 上測過；語言模型在我們的測試句上效果不大；空緩衝區時空格、大寫字母、符號的行為和微軟不完全相同（細節見主倉庫文件）。
* **Squirrel 1.1.2 內建的 `zh-hant-t-essay-bgw.gram` 只有 10,513,408 位元組，本腳本下載的是 41,415,724 位元組的完整版**，放在 `~/Library/Rime`
  （使用者資料夾優先於 app 內的檔案，這點在 Mac 上**未驗證**）。
* Squirrel 內建的 `essay.txt` 與 rime-essay `master` 版本不同，所以同碼字的排序可能和 Windows 版略有差異。

## 移除

```
bash install.sh --uninstall
```

只會刪除這個腳本自己建立、而且你之後沒有改過的檔案（清單在 `~/Library/Rime/.cangjie-fluency-macos.manifest`），備份檔（`*.bak-*`）保留。
你自己的 `default.custom.yaml` 不會被改回去，腳本會提醒你刪掉哪幾行（或還原 `.bak-` 備份）。之後再重新部署。

## 來源與授權

另外感謝 [cangjie-system/rime-cangjie-integrated](https://github.com/cangjie-system/rime-cangjie-integrated)（MIT）整理多種 Rime 倉頡碼表；
它是一般碼表輸入法，本專案補上整句模式。它的 `cangjie.3-ms.dict.yaml`（Vista 微軟倉頡碼表）和 `mscj3.cin` 在共同的字上 98% 碼相同、候選順序也相同。

倉頡輸入法由朱邦復先生創製，他已公開放棄專利權（1982）。感謝 rime/rime-cangjie、rime/rime-quick、eight04 的 `quick5_fluency`
原型（rime-quick#2），以及 PIME 的 `mscj3.cin`（三代碼表來源）。

**授權說明：** `mscj3.cin` 沒有授權標示，因此它與由它產生的 `cangjie3.base.dict.yaml` **絕不放進本倉庫**（已寫進 `.gitignore`），
安裝時才下載並在你的電腦上轉換。本倉庫授權：LGPL-3.0，見 `LICENSE`。
