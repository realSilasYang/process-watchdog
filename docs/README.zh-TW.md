<div align="center">
  <img src="../assets/app/watchdog-logo.png" width="112" alt="程序守護小助手 Logo">

  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <strong>繁體中文（台灣）</strong> · <a href="./README.en.md">English</a> · <a href="./README.ja.md">日本語</a> · <a href="./README.vi.md">Tiếng Việt</a> · <a href="./README.ko.md">한국어</a> · <a href="./README.es.md">Español</a> · <a href="./README.fr.md">Français</a> · <a href="./README.pt-BR.md">Português</a> · <a href="./README.ru.md">Русский</a> · <a href="./README.de.md">Deutsch</a> · <a href="./README.it.md">Italiano</a></p>

  <h1>程序守護小助手</h1>

  <p><strong>持續守護重要應用程式與自動化工作，讓日常運作更穩定</strong></p>

  <p>
    <a href="https://github.com/realSilasYang/process-watchdog/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/process-watchdog?style=flat-square&amp;label=version" alt="最新版本"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/process-watchdog/total?style=flat-square&amp;label=downloads" alt="GitHub 下載次數"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/realSilasYang/process-watchdog/ci.yml?branch=main&amp;style=flat-square&amp;label=CI" alt="CI 狀態"></a>
    <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/process-watchdog?style=flat-square" alt="開放原始碼授權條款"></a>
    <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="支援 Windows 10 與 Windows 11">
  </p>

  <p>
    <a href="#介面概覽">介面概覽</a> ·
    <a href="#使用指南">使用指南</a> ·
    <a href="#3-狀態與復原">狀態說明</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/releases">版本發行</a> ·
    <a href="./CHANGELOG.en.md">更新紀錄</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/issues/new/choose">回報問題</a> ·
    <a href="#開發人員指南">開發人員指南</a>
  </p>
</div>

程序守護小助手適合需要長時間留在目前 Windows 桌面工作階段的應用程式、指令碼與捷徑。目標意外結束後，小助手會自動且審慎地恢復執行，同時區分「確認停止」與「暫時無法判斷」，避免重複或錯誤啟動。所有判斷、設定與紀錄都只留在本機；專案以 AutoHotkey v2 x64 建置，支援 Windows 10 與 Windows 11。

小助手不會只根據處理程序名稱判定目標是否正在執行，而會綜合完整路徑、處理程序建立身分、捷徑實際目標與命令列證據。證據不足時會等候下一次檢查，不會把「暫時無法確認」直接視為停止。

專案提供淺色與深色介面、自動復原、軟體更新保護、執行紀錄、復原與重做、自訂名稱與圖示，以及包含 SPDX SBOM、SHA-256 總和檢查碼與建置來源證明的 Windows x64 發行套件。

# 介面概覽

<p align="center">
  <img src="images/process-watchdog-overview.png" alt="程序守護小助手主介面" width="100%">
</p>

主視窗集中顯示守護對象的順序、應用程式圖示、名稱、權限要求與目前狀態。頂端命令列提供新增、刪除、暫停、設定、說明資訊與贊助入口；說明資訊可再開啟使用說明或執行紀錄。底部狀態列彙整執行中、復原、更新、暫停與失敗數量，異常狀態可從執行紀錄追查實際判斷依據。

## 主要功能

- 守護 EXE、AHK、Python、JavaScript、PowerShell、BAT、CMD 與 LNK。
- 使用 `Running`、`Stopped`、`Unknown` 三態探測；未知狀態不會觸發盲目重新啟動。
- 每個目標都有獨立控制器、世代與工作權杖；暫停、刪除或變更路徑後，舊回呼會立即失效。
- 可要求以系統管理員身分執行；現有執行個體權限不符時會提示，下次由守護啟動時會依設定提升權限。
- 軟體更新保護預設關閉；啟用後會綜合更新處理程序、父子關係、安裝目錄活動與檔案穩定性，決定何時暫停及恢復守護。
- 設定以不可分割方式取代；無法剖析的監控紀錄會移至 `[Recovery]`，不會無聲遺失。
- 應用程式搜尋只使用 Everything 服務，不進行內建全碟掃描，也不限制結果數量；大量結果會分批加入，避免圖示擷取長時間占用介面。
- 支援簡體中文、繁體中文（香港）、繁體中文（台灣）、英文、日文、越南文、韓文、西班牙文、法文、巴西葡萄牙文、俄文、德文與義大利文。預設跟隨 Windows 顯示語言，不支援的語言會回復為英文，也可在「一般」手動切換。語言與內容字型儲存後會在目前處理程序內立即生效，不會停止或重新初始化守護工作。
- 「跟隨語言預設」會優先使用蘋方、SF Pro Text、Harano Aji Gothic 或 Apple SD Gothic Neo；裝置未安裝時，會私有載入隨附且取得商業授權或採 OFL 的資源，再回復至對應 Noto 字型。內容字型用於本文、輸入欄、清單與「關於」資訊；按鈕、設定分頁及主視窗底部狀態列則固定使用目前語言對應的 Windows 系統 UI 粗體字型。
- 淺色與深色介面都支援子視窗獨立最小化、DPI 圖示重建、圓角按鈕與自訂圖示。
- 診斷套件只在本機產生，不會自動上傳；正式發行成品可獨立驗證來源與完整性。

## 適用範圍

適合需要在目前 Windows 桌面工作階段持續執行，並在意外結束後自動復原的一般應用程式、指令碼與捷徑。以下項目不在目前專案範圍內：

- Windows 系統服務、驅動程式、核心元件或跨使用者工作階段服務。
- Windows 7、32 位元 Windows 或非 Windows 平台。
- 硬即時系統、高可用性叢集或需要安全隔離邊界的處理程序協調。
- 把任何未知處理程序狀態強制視為停止的激進復原策略。

已記錄 Windows 11 實機 200% DPI 的完整 GUI 自動化執行，並以回歸測試覆蓋 100% 與 300% 的繪製計算；各縮放比例的人工視覺矩陣、跨螢幕連續 DPI 切換及高對比度仍未完成，不能只憑程式碼視為通過。完整證據與邊界請參閱 [GUI 驗證記錄](../tests/gui/VALIDATION-EVIDENCE.en.md)及[相容性與已知限制](en/compatibility.md)。

---

**[使用指南](#使用指南)**<br>
[安裝與首次執行](#1-安裝與首次執行) · [新增與管理項目](#2-新增與管理項目) · [狀態與復原](#3-狀態與復原) · [軟體更新保護](#4-軟體更新保護) · [設定](#5-設定) · [紀錄與診斷](#6-紀錄診斷與隱私權)

**[開發人員指南](#開發人員指南)**<br>
[目錄職責](#1-目錄與職責) · [正確性邊界](#2-正確性邊界) · [驗證](#3-驗證命令) · [發行與貢獻](#4-發行與貢獻)

# 支持專案

如果小助手替您節省了排查問題或復原程式的時間，歡迎透過下方 QR Code 贊助作者。請選擇扶貧方式：

<p align="center">
  <img src="../assets/donate/微信个人收款码.png" width="220" alt="微信支付贊助 QR Code">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="../assets/donate/支付宝个人收款码.png" width="220" alt="支付寶贊助 QR Code">
</p>

# 使用指南

## 1. 安裝與首次執行

1. 從 [Releases](https://github.com/realSilasYang/process-watchdog/releases) 選擇獨立 EXE、完整可攜式 ZIP 或完整原始碼 ZIP 其中一種版本。
2. 獨立 EXE 不需安裝 AutoHotkey，首次執行會把已驗證內容安裝到 `%LOCALAPPDATA%\ProcessWatchdog\Standalone`；可攜式 ZIP 從完整解壓縮的目錄執行；原始碼 ZIP 需要 AutoHotkey v2 x64。
3. 執行 `进程守护小助手.exe`。程式會要求系統管理員權限，並依設定顯示主視窗或靜默常駐通知區域。
4. 選擇「新增」來選取目標，也可以把支援的檔案拖曳到主視窗。
5. 開啟「紀錄」，查看小助手實際採用的身分證據、狀態檢查、復原嘗試與更新訊號。

也可以從原始碼執行：安裝 AutoHotkey v2 x64 後執行 `进程守护小助手.ahk`。透過 Git 複製專案時還必須安裝 Git LFS，並執行 `git lfs pull`，才能取得完整字型檔案而不是 LFS 指標。Release 附帶的原始碼 ZIP 已包含這些資源，不需要 Git LFS。正式發行套件已內嵌通過完整發行測試的 AutoHotkey 執行階段，一般使用者不必另行安裝。

### 版本與執行形式

| 項目 | EXE 版 | 原始碼版 |
| --- | --- | --- |
| 小助手版本 | 讀取 EXE 檔案版本；更新時取代完整發行套件 | 讀取進入點旁的 `VERSION`；透過安全的 Git 快轉或原始碼套件更新 |
| AutoHotkey | 已內嵌，隨後續的小助手完整發行套件更新 | 使用本機直譯器；小助手更新不會替使用者升級 AutoHotkey |
| Ahk2Exe | 只在正式發行時產生 EXE，不會安裝到使用者電腦 | 不需要 |

「小助手已是最新版本」與「本機 AutoHotkey 已是最新版本」是不同的判斷。每次正式發行開始時，流程會選取最新穩定版 AutoHotkey 與最新發行版 Ahk2Exe，凍結版本並完成全部測試後，才把所選 AutoHotkey 封裝到 EXE。「小助手設定 → 關於」會一併顯示小助手版本、EXE／原始碼形式與實際 AutoHotkey 版本，也可以手動檢查更新。詳情請參閱[版本、執行形式與更新責任](en/versioning.md)。

關閉主視窗只會把介面隱藏到通知區域，守護仍會繼續。若要完全結束，請使用通知區域選單中的「結束」。捷徑、排程啟動與升級方式請參閱[安裝、升級與移除](en/installation.md)。

## 2. 新增與管理項目

| 按鈕 | 用途 |
| --- | --- |
| 新增 | 選取一個目標、搜尋已安裝應用程式或匯入資料夾；資料夾預設包含子資料夾 |
| 刪除 | 移除選取的守護對象；支援多選，也可以復原 |
| 暫停／恢復 | 只改變自動守護狀態，不會關閉目前正在執行的目標；混合選取時逐項切換 |
| 設定 | 設定一般、監控與啟動、停止原則、紀錄與關於選項 |
| 說明資訊 | 選擇內建使用說明、執行紀錄或 GitHub 意見回報頁面 |
| 贊助 | 顯示微信支付與支付寶 QR Code，支持專案持續維護 |

新增項目時可設定啟動進入點、工作目錄、參數與是否要求系統管理員權限。LNK 會保留為啟動進入點，實際程式路徑則獨立用於處理程序識別，因此安裝程式建立的間接捷徑不必手動改成容易變動的內部 EXE。

在主清單中按右鍵可開啟檔案位置、結束目標執行、變更目標路徑，或設定處理程序辨識與啟動方式，也可切換管理員權限要求、設定軟體更新保護，以及自訂主視窗名稱和圖示。「結束執行」也會暫停守護，避免目標被自動重新啟動。顯示自訂不會改變目標識別、啟動進入點或更新保護；目前已是預設顯示時，「還原預設」會停用。

只有 BAT 與 CMD 項目會額外顯示「檢視批次輸出紀錄」；其他類型不會顯示這個指令。只有小助手實際啟動該批次項目並擷取其標準輸出與錯誤輸出時，才會建立獨立紀錄檔；原本已在執行的批次程序也不會自動產生此檔案。

拖曳清單列可調整順序，並會儲存到設定。`Ctrl+Z`、`Ctrl+Y` 與 `Ctrl+Shift+Z` 可復原或重做新增、刪除、排序及設定變更。最左側序號會依顯示順序重新編排，但不參與目標身分、啟動或持久化。更多範例請參閱[常見使用情境](en/quick-start.md)。

## 3. 狀態與復原

主清單狀態代表小助手目前掌握的證據與下一步動作，不應只根據圖示顏色推斷結果：

| 狀態 | 意義 |
| --- | --- |
| 執行中 | 已找到符合目標身分的執行中執行個體 |
| 執行中（權限不符） | 執行個體存在，但不符合該守護對象的系統管理員權限要求 |
| 等候處理程序狀態／疑似停止 | 證據不足或剛觀察到結束，正在複核；不會立即重複啟動 |
| 啟動／重試倒數 | 已確認需要復原，下一次嘗試會依重試序列等候 |
| 軟體更新中／確認檔案穩定 | 更新保護已暫停自動啟動，正等候活動結束與目標檔案穩定 |
| 已暫停 | 自動檢查與復原已暫停，但不會關閉目標處理程序 |
| 已停止／啟動失敗／等候逾時 | 復原未成功或需要使用者確認；請查看紀錄中的實際證據與原因 |

預設重試延遲為 1、10、60 秒。快速序列用完後會重複使用最後一個延遲，避免高速循環啟動。刪除、暫停、變更路徑或復原操作會讓舊排程工作與非同步結果失效。

## 4. 軟體更新保護

軟體更新保護預設關閉，必須逐項手動開啟：

1. 在主清單中按右鍵開啟「軟體更新保護」。
2. 勾選自動辨識更新並保護啟動流程。
3. 確認安裝足跡、結束偵測時段、檔案穩定等候與最長更新等候。
4. 儲存後讓軟體正常執行一次真正的更新。小助手會綜合更新處理程序、父子關係、安裝目錄活動、檔案通知與已學習的更新程式特徵，判斷是否開始保護。

確認更新後會暫停自動啟動；活動結束且目標檔案穩定後才恢復一般守護。偵測逾時或與實際情況不符時，可選擇「結束更新等候並恢復守護」。恢復前仍會檢查啟動進入點是否可安全使用。

更新保護不是通用安裝程式或 Windows 服務管理工具。對可攜式軟體、安裝目錄外的更新程式或特殊啟動器，請先查看執行紀錄，再調整足跡與規則。

## 5. 設定

| 分類 | 可調整項目 |
| --- | --- |
| 一般 | 桌面與開始功能表捷徑、排程自動啟動、兩項啟動行為、介面語言、介面內容字型與佈景主題 |
| 監控與啟動 | 處理程序狀態檢查間隔、意外結束後的自動重新啟動延遲序列、匯入資料夾時是否包含子資料夾 |
| 停止原則 | GUI 與 CLI 應用程式關閉逾時，以及逾時後是否允許強制終止 |
| 紀錄 | 啟動時清除、執行紀錄顯示上限、批次紀錄保留天數與儲存路徑 |
| 關於 | 軟體與執行環境版本、立即檢查更新與開放原始碼專案網址 |

設定視窗會驗證數值範圍。`watchdog.ini` 的註解放在對應區段與設定旁，建議優先透過介面修改，以免破壞編碼欄位。請參閱[設定、備份與復原](en/configuration.md)。

## 6. 紀錄、診斷與隱私權

「執行紀錄」可選取與複製文字，也可最大化及調整視窗大小；捲軸只在需要時顯示，紀錄文字本身不可編輯。

難以定位的問題可從紀錄視窗匯出本機診斷套件。內容包括應用程式、Windows、AutoHotkey、DPI、資源控制代碼、守護階段、設定警告與目前紀錄摘要，但不會自動上傳。

個人設定儲存在實際執行目錄的 `watchdog.ini`，未完成的軟體更新工作階段儲存在同一目錄的 `watchdog.maintenance.ini`。可攜式與原始碼版本使用各自進入點目錄；獨立 EXE 固定使用 `%LOCALAPPDATA%\ProcessWatchdog\Standalone`。兩個檔案都由 Git 忽略，發行套件不會攜帶或覆寫。

可攜式 EXE 與原始碼進入點只有放在同一目錄時才共用狀態；獨立 EXE 不會讀取下載啟動檔旁的設定。全域單一執行個體鎖會阻止多種形式同時執行，捷徑與排程工作會指向最後整合的實際執行形式。詳情請參閱[設定、備份與復原](en/configuration.md)與[安裝、升級與移除](en/installation.md)。

紀錄與診斷套件可能包含目標路徑、啟動參數或環境變數。公開提交前請自行檢查並移除敏感內容。一般問題請使用[結構化 Issue 表單](https://github.com/realSilasYang/process-watchdog/issues/new/choose)，尚未修正的安全性問題必須使用私密弱點回報。另請參閱[本機診斷套件](en/diagnostics.md)、[疑難排解](en/troubleshooting.md)與[取得協助](../.github/SUPPORT.en.md)。

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/process-watchdog&type=Date)](https://star-history.com/#realSilasYang/process-watchdog&Date)

# 開發人員指南

## 1. 目錄與職責

```text
process-watchdog/
├─ .github/                 Issue、工作流程與專案協作範本
├─ app/                     應用程式狀態、介面接線與各層視窗
├─ assets/                  圖示、贊助圖片與私有載入字型
├─ config/                  附就地註解的目前設定格式範例
├─ docs/                    使用、架構、多語言、圖片與治理文件
├─ src/                     設定、核心、診斷、執行、檢查、更新保護、平台、UI 與自動更新
├─ runtime/                 EXE 與原始碼共用的背景更新及替換輔助程式
├─ tests/                   核心、GUI、發行與儲存庫驗證
├─ third_party/             鎖定的執行階段 DLL、授權與相依性清單
├─ tools/                   建置、SBOM、發行驗證與工具鏈啟動程序
└─ 进程守护小助手.ahk      組合根與啟動進入點
```

根指令碼只負責組合模組、裝配相依項目與啟動應用程式。`src` 不讀取根全域 `App`、`Main` 或 `GuiModules`；`app` 負責把純核心能力接到具體視窗、紀錄與系統操作。詳情請參閱[架構與正確性邊界](en/architecture.md)。

## 2. 正確性邊界

- 目標身分、啟動進入點與主視窗自訂顯示彼此獨立；顯示設定不可改變守護判斷。
- `Running`、`Stopped`、`Unknown` 是外部證據結果；只有確認停止才可進入復原流程。
- 每個計時器、訊息回呼、檔案監看器、工作處理程序、視窗與原生資源都必須有可重複執行的清理路徑。
- 設定快照、守護對象與更新保護設定在同一交易中提交；測試不可讀取或覆寫個人 `watchdog.ini`。
- 已放棄的 GDI 螢幕擷取覆蓋式平滑捲動不得重新引入；ListView 與紀錄保留原生捲動。
- DPI、圖示、深色模式、視窗層級與協助工具聲明必須有真實 Windows 與縮放驗證證據；自動化不能取代實體顯示器矩陣。

## 3. 驗證命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-windows-integration.ps1 `
  -SoakSeconds 10
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\reproducible-build.ps1
```

`verify.ps1` 檢查相依性雜湊、AHK 剖析、靜態架構限制、核心測試、儲存庫邊界、完整 Git 歷史洩漏、工作流程語法與啟動行為。`verify-windows-integration.ps1` 會驗證完整字型、建立真正的 Windows 控制項，並檢查 13 種語言、三層視窗與 GDI／USER 控制代碼回收。`reproducible-build.ps1` 連續建置兩次三種發行版本與 SBOM，並比較校驗清單雜湊。

AutoHotkey 與 Ahk2Exe 不會預先鎖定在儲存庫中。每次手動正式發行都會重新查詢 AutoHotkey 最新穩定版與 Ahk2Exe 最新發行版，凍結同一份解析快照，再用它完成測試、兩次建置、SBOM 與封裝；actionlint 與 Gitleaks 等驗證工具仍固定版本。正式發行會保存實際版本、來源、提交與 SHA-256。第三方資料請參閱[第三方軟體聲明](project/THIRD_PARTY_NOTICES.en.md)。

## 4. 發行與貢獻

使用者可見的變更必須同步更新所有本地化 README 與更新紀錄。新增版本時使用[更新紀錄範本](en/changelog-template.md)，依使用者可觀察到的新增、改善與修正整理內容，不要直接複製提交訊息或內部類別名稱。

完整流程請參閱[發行流程](en/release-process.md)與[公開發行檢查清單](en/publication-checklist.md)。一般 Pull Request 不應建立版本標籤或改寫已發行標籤。Issue 與 Pull Request 應提供可重現問題、風險及驗證證據；涉及視窗、DPI、圖示或深色模式時，請註明實際測試的 Windows 版本與縮放比例。另請參閱[貢獻指南](../.github/CONTRIBUTING.en.md)與[專案治理](project/GOVERNANCE.en.md)。

專案程式碼採用 [MIT License](../LICENSE)。內嵌及隨附元件仍遵循各自授權；發行套件附有 AutoHotkey 授權與對應原始碼封存。PingFang、SF Pro Text 與 Apple SD Gothic Neo 依專案擁有者持有的商業再散布授權提供，不受 MIT License 規範。
