# cangjie-fluency-macos / 倉頡整句輸入（macOS 版）

在 macOS 上為 [Squirrel / 鼠鬚管](https://github.com/rime/squirrel)（Rime for macOS）提供微軟風格的**倉頡整句輸入**。
一路打整串倉頡碼，不必逐字選字；緩衝區會隨著輸入自動重新斷詞、修正；按 Enter 上屏整句。

* 英文：本節。繁體中文：往下捲到[繁體中文](#繁體中文)。（本檔每一節都是先中文、後英文。）
* 所需的一切都來自擁有者的主倉庫
  [githubhjs/cangjie-fluency](https://github.com/githubhjs/cangjie-fluency)：方案檔、倉頡碼表（`tables/`）、
  詞彙表與語言模型（`data/`）、轉換工具（`tools/`），以及（Mac 沒裝 Squirrel 時）未修改的上游
  Squirrel 1.1.2 安裝包（release `deps-v1`，GPL-3.0，該處附有聲明）。各資料檔的來源與授權請看主倉庫的
  `tables/README.md` 與 `data/README.md`。**不會連到任何其他第三方**：不是 PIME、不是 rime-essay、不是
  rime-octagram-data、不是 Homebrew，也不是 GitHub 上的 `rime/squirrel` 倉庫。
* 狀態：**安裝、碼表轉換與部署，已在一台真實的 Mac（macOS 26.5.2、Apple 晶片、Squirrel 1.1.2，2026-11-10）上，
  用本安裝腳本的前一版（從第三方下載的版本）執行過；之後擁有者在 Squirrel 中實際打字，得到正確的字
  （顏值、頻率：由擁有者口頭回報，沒有保留記錄）。** 新的內附包／離線／pkg 流程只在 Linux 上用假指令（stub）測過。
  請見[已驗證／未驗證](#verified--unverified)與 `docs/test-log.md`。

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

## What you get / 內容

* `cangjie3_fluency`（倉頡三代整句），主要方案。Windows XP 內建的新倉頡是修改過的**三代**倉頡，所以三代碼表
  對從 XP 練起的人最接近（約有五分之一的字，碼和五代不同）。它排在清單第一個，所以是你預設的 Squirrel 方案。
* 選用 `--with-cangjie5`：另外安裝 `cangjie5_fluency`（五代）。
* 完整語言模型 `zh-hant-t-essay-bgw.gram`（41,415,724 位元組，librime-octagram）。Squirrel 1.1.2 內附一個同名但較小的
  10.5 MB 檔案；本安裝腳本一律把完整版放進 `~/Library/Rime`。

* `cangjie3_fluency` (倉頡三代整句), the main schema. Windows XP's built-in 新倉頡 is a modified **3rd-generation**
  Cangjie, so the 3rd-generation code table is the closest match for people who learned on it (about a fifth of the
  characters have different codes than 5th generation). It is listed first, so it is your default Squirrel schema.
* Optional `--with-cangjie5`: also `cangjie5_fluency` (5th generation).
* The full language model `zh-hant-t-essay-bgw.gram` (41,415,724 bytes, librime-octagram). Squirrel 1.1.2 bundles a smaller
  10.5 MB file with the same name; the installer always puts the full one in `~/Library/Rime`.

## Install / 安裝

### Option A: full release zip (works offline) / 方式 A：完整發行 zip（可離線使用）

從本倉庫的 Releases 下載 `cangjie-fluency-macos-<version>-full.zip`，解壓後在終端機執行下方的指令。

此 zip 內含安裝腳本、方案檔、碼表、詞彙表、語言模型、轉換工具與 `deps/Squirrel-1.1.2.pkg`（壓縮後約 64 MB）。
`--offline` 完全不連網，缺檔時會以明確訊息停止。`slim` 精簡 zip（安裝腳本＋方案檔＋轉換工具）其餘檔案從主倉庫取得。

Download `cangjie-fluency-macos-<version>-full.zip` from this repository's Releases, unzip, then in Terminal:

```
cd cangjie-fluency-macos-<version>
bash install.sh --offline
```

The zip holds the installer, schema files, tables, word list, the language model, the converter and `deps/Squirrel-1.1.2.pkg`
(about 64 MB zipped). `--offline` never touches the network and stops with a clear message if a file is missing. A `slim` zip (installer
+ schema files + converter) fetches the rest from the main repo.

### Option B: one line / 方式 B：一行指令

下方第一段指令是一行安裝；第二段是比較安全的做法（下載、閱讀、先 dry-run、再執行）。

選項：`--offline`（不連網；檔案必須放在 `install.sh` 旁邊）、`--no-deps`（缺 Squirrel 時不安裝它）、
`--rime-dir DIR`（預設 `~/Library/Rime`，或 `$RIME_DIR`）、`--ref TAG`（缺少的檔案要從主倉庫哪個版本下載，
預設 `v0.5.1`）、`--with-cangjie5`、`--no-model`、`--no-sweep`（不安裝滑行板）、`--pad-ref TAG`（滑行板版本標籤，預設 `v0.1.0`）、`--no-deploy`、`--dry-run`、`--uninstall`。

安裝腳本只需要 bash、`/usr/bin/perl`、awk，以及（沒有 `--offline` 時）curl，這些 macOS 都內建。它會：

1. 檢查 `/Library/Input Methods/Squirrel.app`。**若不存在**，就取用 `Squirrel-1.1.2.pkg`（優先用完整 zip 的 `deps/`，
   否則用主倉庫 release `deps-v1`），核對其 SHA-256，再執行 `sudo installer -pkg ... -target /`（會要求輸入你的密碼）。
   若已安裝 Squirrel 就不動它。`--no-deps` 會跳過這一步並直接停止。
2. 其他所有檔案，取自 `install.sh` 旁邊的資料夾（目錄結構 `weasel/ tables/ data/ tools/`），否則取自
   `raw.githubusercontent.com/githubhjs/cangjie-fluency/<ref>/`。碼表、詞彙表、模型與 pkg 都會對照腳本內固定的雜湊值做
   **SHA-256 核對**。
3. 在**你的電腦上**用 `tools/cin2rime.pl` 把 `tables/mscj3.cin` 轉換成 `cangjie3.base.dict.yaml`，詞頻權重一律使用
   倉庫的 `data/essay.txt`，因此各平台產生的碼表逐位元組相同（已與 python 轉換器及一次 Linux 執行比對，見 `docs/test-log.md`）。
4. 只有在 Squirrel 的 bundle 與 `~/Library/Rime` 都沒有 `essay.txt` 時，才把倉庫的 `essay.txt` 裝進 `~/Library/Rime`；
   完整語言模型則一律安裝到該處。
5. 建立 `default.custom.yaml`；若你已經有一個，就先備份，再把 `- schema: cangjie3_fluency` 插入你現有 `schema_list` 的
   第一項（保留縮排、換行字元與 `- {schema: x}` 的寫法）。若你的檔案沒有 `schema_list`，就不動它，並由腳本印出該加什麼。
   你的清單絕不會被覆蓋。
6. 請 Squirrel 重新部署（`Squirrel --reload`）。這只有在 Squirrel 正在執行時才送得到；否則請用選單列圖示 > Deploy。

重複執行是安全的：內容相同的檔案不會重寫、也不備份；有變動的檔案只會留下一份帶時間戳記的備份
（`name.bak-YYYYmmdd-HHMMSS`）。

**第一次安裝 Squirrel 之後，要手動加入它：** 系統設定 > 鍵盤 > 文字輸入 > 輸入方式 > 編輯… > `+` > **中文（繁體）** >
Squirrel（鼠鬚管）。在 macOS 26.5.2 上，用指令註冊（`Squirrel --register-input-source` / `--enable-input-source`）會印出
「succeeds」，但 Squirrel 並沒有出現在輸入法選單裡，所以在系統設定中手動加入才是關鍵步驟（其他 macOS 版本的選單名稱
未驗證）。Squirrel 官方 README 說，只有在第一次安裝後某些應用程式打不出字時，才需要登出再登入。

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
from, default `v0.5.1`), `--with-cangjie5`, `--no-model`, `--no-sweep` (skip Sweep Pad), `--pad-ref TAG` (Sweep Pad version, default `v0.1.0`), `--no-deploy`, `--dry-run`, `--uninstall`.

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

## Switching to it / 切換到它

在任何輸入框按 `` Ctrl+` ``（或 `F4`），選「倉頡三代整句」。（這些快捷鍵來自 Squirrel 1.1.2 內附的 default.yaml：
`Control+grave`、`Control+Shift+grave`、`F4`。）

In any text field press `` Ctrl+` `` (or `F4`) and pick 倉頡三代整句. (Those hotkeys are in the default.yaml shipped inside
Squirrel 1.1.2: `Control+grave`, `Control+Shift+grave`, `F4`.)

## Check that the language model loaded / 確認語言模型已載入

用這個方案打過一次字之後，執行下方指令。

`use grammar: zh-hant-t-essay-bgw` 表示已載入。沒有這一行：方案仍可使用，只是整句修正較弱。
glog 會緩衝記錄檔，所以這一行可能出現得很晚（要等 Squirrel 執行一陣子或結束之後）。

Type something once with the schema, then:

```
grep -h "use grammar" "${TMPDIR%/}"/rime.squirrel/* | tail -3
```

`use grammar: zh-hant-t-essay-bgw` means loaded. No such line: the schema still works, only sentence correction is weaker.
glog buffers the log, so the line can appear late (after Squirrel has run a while or quit).

## Typing notes / 打字說明

* 連續打好幾個字的字根：`mwyl` 得到 面；`dhedhkb` 在打到最後一碼時得到 板橋
  （三代碼：板 = `dhe`、橋 = `dhkb`）。繼續打，前面的字會被修正。
* **只有單一字根的字，後面要加一個空格**：中午 是 `l oj`（中 = `l`）。
* Enter 上屏整句。`,` `.` `!` `?` 會先上屏整句，再輸入全形標點。
* Backspace 退掉一個碼，Esc 清空緩衝區。同碼字（雙/隻 之類）依詞頻排序；選錯時用方向鍵或 PageDown。
* 反查：先打 `` ` `` 再打拼音。左 Shift 切換中／英文並上屏緩衝區。

**語言模型。** 我們的測試句（51 句日常句、40 句同碼困難句，共 91 句整句，另有 34 組同碼詞對，例如 手感/手怠 與
頻率/顏率），有沒有語言模型結果都相同，因為這些詞在 `essay.txt` 裡本來就有詞頻。我們還沒有找到能量測出語言模型效果的案例。
模型檔放在主倉庫中，仍會一併安裝。

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

## Known limits / 已知限制

* 已在一台真實的 Mac 上安裝並部署（用較早的安裝腳本），擁有者確認兩個詞可以打出來。方案檔與 Windows 版相同；
  `cangjie3_fluency` 在 Linux 的 librime 上以及那次 Mac 操作中測試過。
* 空緩衝區時，空格、大寫字母與符號的行為和微軟不同，與 Windows 版一樣（見主倉庫的文件）。
* 碼表是 `tables/mscj3.cin`，是 Windows 內附的修改版三代碼表，並非任何人的官方碼表。
  它是否與 Windows XP 的碼表完全相同：未驗證（只核對了 面、非、作、知/佑）。
* Squirrel 內附的 `essay.txt` 與本倉庫 `data/` 中的並非逐位元組相同，但轉換器一律使用本倉庫的那份，
  因此產生的碼表不受它影響。

* Installed and deployed on one real Mac (with the earlier installer), typing confirmed by the owner for two words. The schema files
  are the same as on Windows; `cangjie3_fluency` was tested on Linux librime and in that Mac session.
* The empty-buffer behaviour of space, upper-case letters and symbols differs from Microsoft's, as in the Windows version
  (see the main repo's docs).
* The table is `tables/mscj3.cin`, a modified 3rd generation as shipped in Windows, not an official table of anyone's.
  Whether it equals Windows XP's table exactly is unverified (面, 非, 作, 知/佑 were checked).
* Squirrel's bundled `essay.txt` is not byte-identical to the one in this repo's `data/`, but the converter always uses the repo's
  copy, so the generated table does not depend on it.

<a id="verified--unverified"></a>
## Verified / unverified / 已驗證／未驗證

在 Linux 上已驗證（2026-11-10），`tests/test_install.sh` 共 95 項檢查，bash 3.2 風格的程式碼，curl/sudo/Squirrel 用假指令（stub）取代：

* 完整包 `--offline` 安裝**沒有任何網路呼叫**（curl/wget/sudo 被換成會記錄並失敗的 stub）。
* perl 轉換器產生的 `cangjie3.base.dict.yaml`，與 python 轉換器的輸出以及直接執行 perl 的結果逐位元組相同；
  SHA-256 不符（碼表、Squirrel pkg）會使安裝停止；線上路徑只會請求
  `githubusercontent.com/githubhjs/cangjie-fluency/...`；缺少 Squirrel 時，會透過 `sudo installer` 的 stub 從內附 pkg 安裝
  （這裡從未真正執行）；`--no-deps` 會停止而不安裝。
* Squirrel 1.1.2 安裝包（sha256 `61474601...8287`）內含 `Contents/Frameworks/rime-plugins/librime-octagram.dylib`、
  `Contents/SharedSupport/essay.txt`、`luna_quanpin.schema.yaml`，以及一個 10,513,408 位元組的 `zh-hant-t-essay-bgw.gram`。
* Squirrel 的 `--reload` 會送出重新載入通知，讓執行中的程式進行部署；使用者資料夾是 `~/Library/Rime`。

在真實 Mac 上以前一版安裝腳本驗證過（macOS 26.5.2、arm64、`/bin/bash` 3.2.57、`/usr/bin/perl` 5.34.1、Squirrel 1.1.2）：
一行安裝指令執行到最後；perl 產生的碼表與 python 的逐位元組相同；部署**沒有 `E` 行**；擁有者打了 顏值 與 頻率，得到正確的字。
**不要用 `Squirrel --build`** 來部署（它會把目前所在資料夾當成共用資料夾）；請用 `--reload` 或選單列圖示 > Deploy。

仍未驗證：新安裝腳本在 Mac 上的表現（離線模式、用 `sudo installer` 從 pkg 安裝 Squirrel、`shasum` 的使用）；
Mac 上的 `use grammar` / `failed to load grammar` 記錄行（glog 有緩衝：打字後執行 `Squirrel --quit`，再執行
`grep -h -E "use grammar|failed to load grammar" "${TMPDIR%/}"/rime.squirrel/*`）；放在 `~/Library/Rime` 的 gram
是否優先於 app bundle 內的那個（假設是）；早於 1.1.2 的 Squirrel 版本；Intel Mac；其他 macOS 版本。

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

## Uninstall / 移除

下方指令只會移除本安裝腳本建立的檔案（它保留一份清單 `~/Library/Rime/.cangjie-fluency-macos.manifest`），
而且只限於你之後沒有改動過的檔案。備份檔（`*.bak-*`）會保留。Squirrel 本身不會被移除。先前就存在、且被編輯過的
`default.custom.yaml` 不會被改回去：安裝腳本會告訴你要刪掉哪幾行（或還原 `.bak-` 備份）。之後再重新部署。

```
bash install.sh --uninstall
```

removes only the files this installer created (it keeps a manifest, `~/Library/Rime/.cangjie-fluency-macos.manifest`) and
only if you have not changed them since. Backups (`*.bak-*`) are kept. Squirrel itself is not removed. A pre-existing
`default.custom.yaml` that was edited is not changed back: the installer tells you which lines to delete (or restore the `.bak-`
copy). Then redeploy.

## Releases / 發行

產生發行包的指令如下（`dist/*-full.zip` 與 `*-slim.zip`；需要主倉庫的 checkout）。

```
./make-release.sh ~/projects/cangjie-fluency v0.2.0    # dist/*-full.zip and *-slim.zip; needs the main repo checkout
```

## Credits and licensing / 致謝與授權

* 倉頡輸入法由朱邦復（Chu Bong-Foo）創製，他於 1982 年公開放棄專利權。
* [rime/rime-cangjie](https://github.com/rime/rime-cangjie)、[rime/rime-quick](https://github.com/rime/rime-quick)，以及 eight04 的
  `quick5_fluency` 原型（[rime-quick#2](https://github.com/rime/rime-quick/issues/2)）：本專案所依據的構想。
* [cangjie-system/rime-cangjie-integrated](https://github.com/cangjie-system/rime-cangjie-integrated)（MIT）為 Rime 蒐集倉頡碼表；
  它是單純的碼表輸入法，本專案則加上整句模式。
* Squirrel（GPL-3.0）由 Rime 專案開發；完整 zip 與 release `deps-v1` 中的 pkg 是未修改的上游 1.1.2 檔案，
  其授權與聲明附在 `deps/` 與該 release 中。
* 碼表、詞彙表與語言模型的來源與授權：主倉庫的 `tables/README.md` 與 `data/README.md`。
* 本倉庫：LGPL-3.0，見 `LICENSE`。

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

選項：`--offline`、`--no-deps`、`--rime-dir DIR`、`--ref TAG`（預設 `v0.5.1`）、`--with-cangjie5`、`--no-model`、`--no-sweep`、`--pad-ref TAG`（預設 `v0.1.0`）、`--no-deploy`、`--dry-run`、`--uninstall`。

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

## 鄰鍵容錯（隨附，預設不啟用）/ Adjacent-key typo tolerance (included, not the default)

安裝時會一併裝入「鄰鍵容錯」方案 `cangjie3_fuzzy`（有選五代時還有 `cangjie5_fuzzy`），排在清單第二位；預設方案仍是 `cangjie3_fluency`。打錯一個相鄰按鍵（例如把 `yhmbc` 打成 `yhmbv`）時，也會列出「顏」，正確的候選永遠排在最前面。
選項：`--no-fuzzy` 不裝；`--fuzzy-range narrow|normal|wide` 範圍；`--fuzzy-default` 讓它排第一。
想要它變成預設方案（不必按 Ctrl+` 或 F4 切換），請改用獨立專案 **cangjie-fuzzy-macos**（同樣內含完整的 cj*fluency，一行指令安裝）。依據與預設值：<https://github.com/githubhjs/cangjie-fuzzy-core/blob/main/DEFAULTS.md>

The adjacent-key schema `cangjie3_fuzzy` (and `cangjie5_fuzzy` with Cangjie 5) is installed too, listed second; `cangjie3_fluency` stays the default. When one key is wrong and it is a physical neighbour (`yhmbv` for `yhmbc`) the intended character is offered as well, and exact candidates always come first.
Options: `--no-fuzzy` skip it; `--fuzzy-range narrow|normal|wide` range; `--fuzzy-default` list it first.
To make it the default schema (no Ctrl+` / F4 needed) use the separate project **cangjie-fuzzy-macos** (it contains the full cj*fluency too; one-line install). Evidence for the defaults: the DEFAULTS.md linked above.

## Cangjie Sweep Pad / 倉頡滑行輸入板

預設會安裝倉頡滑行輸入板（Cangjie Sweep Pad，來自 [githubhjs/cangjie-fuzzy-core](https://github.com/githubhjs/cangjie-fuzzy-core) 的 release 資產 `cangjie-sweep-pad-<PadRef>.zip`）：
- 安裝位置：`~/Library/Application Support/cangjie-sweep`（包含 `cangjie_sweep_pad.py`）。
- 啟動程式：命令列啟動器 `~/.local/bin/cangjie-sweep-pad`，以及可從 Finder 雙擊執行的應用程式檔 `~/Applications/Cangjie Sweep.command`。
- Python 環境：需要 Python 3.8+ 與 `tkinter`（偏好 `/opt/homebrew/bin/python3` 或 `/usr/bin/python3`；若缺少 tkinter 請執行 `brew install python-tk`）。
- **macOS 權限要求**：macOS 需要「系統設定 > 隱私權與安全性 > 輔助使用」權限以進行按鍵模擬，請手動勾選授權執行滑行板的終端機（Terminal）或 Python，此權限無法由腳本代為開啟。
- 安裝後會自動執行 `python3 cangjie_sweep_pad.py --self-check`。
- 選項：使用 `--no-sweep` 可略過安裝滑行板；`--pad-ref TAG` 可指定下載版本。執行 `--uninstall` 會一併移除滑行板資料夾、啟動器與 `.command` 檔案。

The Cangjie Sweep Pad is installed by default (a release asset of [githubhjs/cangjie-fuzzy-core](https://github.com/githubhjs/cangjie-fuzzy-core), `cangjie-sweep-pad-<PadRef>.zip`):
- Install directory: `~/Library/Application Support/cangjie-sweep` (contains `cangjie_sweep_pad.py`).
- Launcher: command-line launcher `~/.local/bin/cangjie-sweep-pad`, plus a double-clickable `~/Applications/Cangjie Sweep.command`.
- Python: requires Python 3.8+ with `tkinter` (prefers `/opt/homebrew/bin/python3` or `/usr/bin/python3`; if tkinter is missing run `brew install python-tk`).
- **macOS Permission**: macOS requires Accessibility permission for key injection: grant permission to Terminal (or Python) in System Settings > Privacy & Security > Accessibility. This cannot be granted by script.
- Runs `python3 cangjie_sweep_pad.py --self-check` after installation to verify the environment.
- Options: pass `--no-sweep` to skip installing the pad; pass `--pad-ref TAG` to specify a release tag. Running `--uninstall` removes the pad directory, launcher, and `.command` file.

## Changelog / 更新紀錄

- **v0.4.0** — Sweep Pad added; default on, `--no-sweep` to skip. / 新增倉頡滑行輸入板；預設安裝，加 `--no-sweep` 可略過。
