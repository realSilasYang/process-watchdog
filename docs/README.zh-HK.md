<div align="center">
  <img src="../assets/app/watchdog-logo.png" width="112" height="112" alt="程序守護小助手 Logo">

  <p><a href="../README.md">简体中文</a> · <strong>繁體中文（香港）</strong> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <a href="./README.en.md">English</a> · <a href="./README.ja.md">日本語</a> · <a href="./README.vi.md">Tiếng Việt</a> · <a href="./README.ko.md">한국어</a> · <a href="./README.es.md">Español</a> · <a href="./README.fr.md">Français</a> · <a href="./README.pt-BR.md">Português</a> · <a href="./README.ru.md">Русский</a> · <a href="./README.de.md">Deutsch</a> · <a href="./README.it.md">Italiano</a></p>

  <h1>程序守護小助手</h1>

  <p><strong>持續守護重要程式與自動化工作，讓日常運作保持穩定</strong></p>

  <p>
    <a href="https://github.com/realSilasYang/process-watchdog/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/process-watchdog?style=flat-square&amp;label=version" alt="最新版本"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/process-watchdog/total?style=flat-square&amp;label=downloads" alt="GitHub 下載次數"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/realSilasYang/process-watchdog/ci.yml?branch=main&amp;style=flat-square&amp;label=CI" alt="CI 狀態"></a>
    <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/process-watchdog?style=flat-square" alt="開源授權條款"></a>
    <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="支援 Windows 10 及 Windows 11">
  </p>

  <p>
    <a href="#介面概覽">介面概覽</a> ·
    <a href="#使用指南">使用指南</a> ·
    <a href="#3-狀態與恢復">狀態說明</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/releases">版本發佈</a> ·
    <a href="./CHANGELOG.en.md">更新記錄</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/issues/new/choose">回報問題</a> ·
    <a href="#開發者指南">開發者指南</a>
  </p>
</div>

程序守護小助手適合需要長時間留在目前 Windows 桌面工作階段的程式、指令稿和捷徑。目標意外結束後，小助手會自動而審慎地恢復執行，同時區分「確認停止」與「暫時無法判斷」，避免重複或錯誤啟動。所有判斷、設定與記錄均留在本機；專案以 AutoHotkey v2 x64 建構，支援 Windows 10 和 Windows 11。

小助手不會只憑程序名稱判定目標是否正在執行，而會綜合完整路徑、程序建立身分、捷徑實際目標及命令列證據。證據不足時會等待下一次檢查，不會把「暫時無法確認」直接當成停止。

專案提供淺色與深色介面、自動恢復、軟件更新保護、執行記錄、復原與重做、自訂名稱及圖示，以及附有 SPDX SBOM、SHA-256 校驗和與建構溯源資料的 Windows x64 發行套件。

# 介面概覽

<p align="center">
  <img src="images/process-watchdog-overview.png" alt="程序守護小助手主介面" width="100%">
</p>

主視窗集中顯示守護項目的次序、應用程式圖示、名稱、權限要求及目前狀態。頂部指令列提供加入、刪除、暫停、設定、幫助資訊與捐贈入口；幫助資訊可再開啟使用說明或執行記錄。底部狀態列彙總執行中、恢復、更新、暫停和失敗數量，異常狀態可從執行記錄追查具體判斷依據。

## 主要功能

- 守護 EXE、AHK、Python、JavaScript、PowerShell、BAT、CMD 和 LNK。
- 使用 `Running`、`Stopped`、`Unknown` 三態探測；未知狀態不會觸發盲目重新啟動。
- 每個目標均有獨立控制器、世代及工作權杖；暫停、刪除或更改路徑後，舊回呼立即失效。
- 可要求以系統管理員身分執行；現有實例權限不符時會提示，手動重新啟動則按設定提升權限。
- 軟件更新保護預設關閉；啟用後會綜合更新程序、父子關係、安裝目錄活動及檔案穩定性，決定何時暫停與恢復守護。
- 設定以不可分割方式取代；無法解析的監控記錄會移至 `[Recovery]`，不會無提示遺失。
- 程式搜尋只使用 Everything 服務，不進行本機全碟掃描，也不限制結果數量；大量結果會分批加入，避免圖示擷取長時間佔用介面。
- 支援簡體中文、繁體中文（香港）、繁體中文（台灣）、英文、日文、越南文、韓文、西班牙文、法文、巴西葡萄牙文、俄文、德文和意大利文。預設跟隨 Windows 介面語言，不支援的語言會回退至英文，亦可在「一般」手動切換。語言與內容字型儲存後即時生效，不會停止或重新初始化守護工作。
- 「跟隨語言預設」會優先使用苹方、SF Pro Text、Harano Aji Gothic 或 Apple SD Gothic Neo；裝置未安裝時，會私有載入隨附且獲商業授權或採用 OFL 的資源，再回退至對應 Noto 字型。內容字型適用於正文、輸入欄、清單及「關於」資訊；按鈕、設定分頁及主視窗底部狀態列則固定使用目前語言對應的 Windows 系統 UI 粗體字型。
- 淺色與深色介面均支援子視窗獨立最小化、DPI 圖示重建、圓角按鈕及自訂圖示。
- 診斷套件只在本機產生，不會自動上載；正式發行物可獨立核實來源與完整性。

## 適用範圍

適合需要在目前 Windows 桌面工作階段持續執行，並於意外結束後自動恢復的一般程式、指令稿和捷徑。以下項目不在目前專案範圍內：

- Windows 系統服務、驅動程式、核心元件或跨使用者工作階段服務。
- Windows 7、32 位元 Windows 或非 Windows 平台。
- 硬即時系統、高可用叢集或需要安全隔離邊界的程序編排。
- 把任何未知程序狀態強制視為停止的進取恢復策略。

已記錄 Windows 11 實機 200% DPI 的完整 GUI 自動化執行，並以回歸測試覆蓋 100% 與 300% 的繪製計算；各縮放比例的人工視覺矩陣、跨顯示器連續 DPI 切換及高對比度仍未完成，不能只憑程式碼視為通過。完整證據與邊界請參閱 [GUI 驗證記錄](../tests/gui/VALIDATION-EVIDENCE.en.md)及[相容性與已知限制](en/compatibility.md)。

---

**[使用指南](#使用指南)**<br>
[安裝與首次執行](#1-安裝與首次執行) · [加入與管理項目](#2-加入與管理項目) · [狀態與恢復](#3-狀態與恢復) · [軟件更新保護](#4-軟件更新保護) · [設定](#5-設定) · [記錄與診斷](#6-記錄診斷與私隱)

**[開發者指南](#開發者指南)**<br>
[目錄職責](#1-目錄與職責) · [正確性邊界](#2-正確性邊界) · [驗證](#3-驗證指令) · [發佈與貢獻](#4-發佈與貢獻)

# 支持專案

程序守護小助手會持續保持開源。專案的長期維護有賴您的支持與鼓勵；如果小助手為您節省了排查故障或恢復程式的時間，歡迎透過下方二維碼自願捐贈。您的支持會用於持續維護、相容性驗證和版本發佈。

<p align="center">
  <img src="../assets/donate/微信个人收款码.png" width="220" alt="微信支付捐贈二維碼">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="../assets/donate/支付宝个人收款码.png" width="220" alt="支付寶捐贈二維碼">
</p>

# 使用指南

## 1. 安裝與首次執行

1. 從 [Releases](https://github.com/realSilasYang/process-watchdog/releases) 選擇獨立 EXE、完整可攜式 ZIP 或完整原始碼 ZIP 其中一種版本。
2. 獨立 EXE 無需安裝 AutoHotkey，首次執行會把已驗證內容安裝至 `%LOCALAPPDATA%\ProcessWatchdog\Standalone`；可攜式 ZIP 在完整解壓的目錄執行；原始碼 ZIP 需要 AutoHotkey v2 x64。
3. 執行 `进程守护小助手.exe`。程式會要求系統管理員權限，並按設定顯示主視窗或靜默留在系統匣。
4. 選擇「加入」以選取目標，亦可把支援的檔案拖入主視窗。
5. 開啟「記錄」，查看小助手實際採用的身分證據、狀態檢查、恢復嘗試及更新訊號。

亦可從原始碼執行：安裝 AutoHotkey v2 x64 後執行 `进程守护小助手.ahk`。透過 Git 複製專案時還須安裝 Git LFS，並執行 `git lfs pull`，以取得完整字型檔案而非 LFS 指標。Release 附帶的原始碼 ZIP 已包含這些資源，無需 Git LFS。正式發行套件已內嵌通過完整發行測試的 AutoHotkey 執行階段，一般使用者無需另行安裝。

### 版本與執行形態

| 項目 | EXE 版 | 原始碼版 |
| --- | --- | --- |
| 小助手版本 | 讀取 EXE 檔案版本；更新時取代完整發行套件 | 讀取入口旁的 `VERSION`；透過安全的 Git 快轉或原始碼套件更新 |
| AutoHotkey | 已內嵌，隨日後的小助手完整發行套件更新 | 使用本機解譯器；小助手更新不會替使用者升級 AutoHotkey |
| Ahk2Exe | 只在正式發佈時產生 EXE，不會安裝到使用者電腦 | 不需要 |

「小助手已是最新版本」與「本機 AutoHotkey 已是最新版本」是兩件事。每次正式發佈開始時，流程會選取最新穩定版 AutoHotkey 及最新發佈版 Ahk2Exe，凍結版本並完成全部測試後，才把所選 AutoHotkey 封裝至 EXE。「小助手設定 → 關於」會同時顯示小助手版本、EXE／原始碼形態及實際 AutoHotkey 版本，亦可手動檢查更新。詳情請參閱[版本、執行形態與更新責任](en/versioning.md)。

關閉主視窗只會將介面隱藏至系統匣，守護仍會繼續。要完全退出，請使用系統匣選單的「退出」。捷徑、排程啟動和升級方式請參閱[安裝、升級與移除](en/installation.md)。

## 2. 加入與管理項目

| 按鈕 | 用途 |
| --- | --- |
| 加入 | 選取一個目標、搜尋已安裝程式或匯入資料夾；資料夾預設包含子資料夾 |
| 刪除 | 移除選取的守護項目；支援多選，亦可復原 |
| 暫停／恢復 | 只改變自動守護狀態，不會關閉目前正在執行的目標；混合選取時逐項切換 |
| 設定 | 設定一般、監控與啟動、停止策略、記錄及關於選項 |
| 幫助資訊 | 選擇內置使用說明、執行記錄或 GitHub 意見回報頁面 |
| 捐贈 | 顯示微信支付及支付寶二維碼，支持專案持續維護 |

加入項目時可設定啟動入口、工作目錄、參數及是否要求系統管理員權限。LNK 會保留為啟動入口，實際程式路徑則獨立用於程序識別，因此安裝程式建立的間接捷徑無需手動改成容易變動的內部 EXE。

在主清單中按右鍵可開啟檔案位置、重新啟動、更改目標路徑，或設定程序識別與啟動方式，也可切換管理員權限要求、設定軟件更新保護，以及自訂主視窗名稱和圖示。顯示自訂不會改變目標識別、啟動入口或更新保護；目前已是預設顯示時，「恢復預設」會停用。

只有 BAT 及 CMD 項目會額外顯示「查看批次輸出記錄」；其他類型不會顯示此指令。只有小助手實際啟動該批次項目並接管其標準輸出及錯誤輸出時，才會建立獨立記錄檔；已在執行的批次程序亦不會自動產生此檔案。

拖曳清單列可調整次序，並會儲存至設定。`Ctrl+Z`、`Ctrl+Y` 和 `Ctrl+Shift+Z` 可復原或重做加入、刪除、排序及設定變更。最左側序號會跟隨顯示次序重新編排，但不參與目標身分、啟動或持久化。更多例子請參閱[常見使用情境](en/quick-start.md)。

## 3. 狀態與恢復

主清單狀態代表小助手目前掌握的證據及下一步行動，不應只按圖示顏色推斷結果：

| 狀態 | 含義 |
| --- | --- |
| 執行中 | 已找到符合目標身分的執行中實例 |
| 執行中（權限不符） | 實例存在，但不符合該項目的系統管理員權限要求 |
| 等待程序狀態／疑似停止 | 證據不足或剛觀察到結束，正在覆核；不會立即重複啟動 |
| 啟動／重試倒數 | 已確認需要恢復，下一次嘗試按重試序列等候 |
| 軟件更新中／確認檔案穩定 | 更新保護已暫停自動啟動，正等待活動結束及目標檔案穩定 |
| 已暫停 | 自動檢查和恢復已暫停，但不會關閉目標程序 |
| 已停止／啟動失敗／等待逾時 | 恢復未成功或需要使用者確認；請查看記錄中的具體證據和原因 |

預設重試延遲為 1、10、60 秒。快速序列用完後會重用最後一個延遲，避免高速循環啟動。刪除、暫停、更改路徑或復原操作會令舊排程工作及非同步結果失效。

## 4. 軟件更新保護

軟件更新保護預設關閉，必須逐項手動開啟：

1. 在主清單中用右鍵開啟「軟件更新保護」。
2. 選取自動識別更新並保護啟動流程。
3. 核對安裝足跡、結束偵測時段、檔案穩定等待及最長更新等待。
4. 儲存後讓軟件正常執行一次真實更新。小助手會綜合更新程序、父子關係、安裝目錄活動、檔案通知和已學習的更新程式特徵，判斷是否開始保護。

確認更新後會暫停自動啟動；活動結束且目標檔案穩定後才恢復一般守護。偵測逾時或與實際情況不符時，可選擇「結束更新等待並恢復守護」。恢復前仍會檢查啟動入口是否可安全使用。

更新保護不是通用安裝程式或 Windows 服務管理器。對便攜程式、安裝目錄外的更新程式或特殊啟動器，請先查看執行記錄，再調整足跡與規則。

## 5. 設定

| 分類 | 可調整項目 |
| --- | --- |
| 一般 | 桌面及開始功能表捷徑、排程自動啟動、兩項啟動行為、介面語言、介面內容字型及主題 |
| 監控與啟動 | 程序狀態檢查間隔、意外結束後的自動重新啟動延遲序列、匯入資料夾時是否包含子資料夾 |
| 停止策略 | GUI 及 CLI 程式關閉逾時，以及逾時後是否允許強制終止 |
| 記錄 | 啟動時清除、執行記錄顯示上限、批次記錄保留天數及儲存路徑 |
| 關於 | 軟件與執行環境版本、立即檢查更新及開源地址 |

設定視窗會驗證數值範圍。`watchdog.ini` 的註解放在對應區段和設定旁，建議優先透過介面修改，以免破壞編碼欄位。請參閱[設定、備份與恢復](en/configuration.md)。

## 6. 記錄、診斷與私隱

「執行記錄」可選取和複製文字，亦可最大化及調整視窗大小；捲軸只在需要時顯示，記錄文字本身不可編輯。

難以定位的問題可從記錄視窗匯出本機診斷套件。當中包括應用程式、Windows、AutoHotkey、DPI、資源控制代碼、守護階段、設定警告及目前記錄摘要，但不會自動上載。

個人設定儲存在實際執行目錄的 `watchdog.ini`，未完成的軟件更新工作階段儲存在同一目錄的 `watchdog.maintenance.ini`。可攜式與原始碼版本使用各自入口目錄；獨立 EXE 固定使用 `%LOCALAPPDATA%\ProcessWatchdog\Standalone`。兩個檔案均由 Git 忽略，發行套件不會攜帶或覆寫。

可攜式 EXE 與原始碼入口只有放在同一目錄時才共用狀態；獨立 EXE 不會讀取下載啟動檔旁的設定。全域單一實例鎖會阻止多種形態同時執行，捷徑和排程工作會指向最後整合的實際執行形態。詳情請參閱[設定、備份與恢復](en/configuration.md)和[安裝、升級與移除](en/installation.md)。

記錄和診斷套件可能包含目標路徑、啟動參數或環境變數。公開提交前請自行檢查並移除敏感內容。一般問題請使用[結構化 Issue 表單](https://github.com/realSilasYang/process-watchdog/issues/new/choose)，未修復的保安問題必須使用私密漏洞回報。另見[本機診斷套件](en/diagnostics.md)、[疑難排解](en/troubleshooting.md)及[取得協助](../.github/SUPPORT.en.md)。

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/process-watchdog&type=Date)](https://star-history.com/#realSilasYang/process-watchdog&Date)

# 開發者指南

## 1. 目錄與職責

```text
process-watchdog/
├─ .github/                 Issue、工作流程及專案協作範本
├─ app/                     應用程式狀態、介面接線及各級視窗
├─ assets/                  圖示、捐贈圖片及私有載入字型
├─ config/                  附原位註解的目前設定格式範例
├─ docs/                    使用、架構、多語言、圖片及治理文件
├─ src/                     設定、核心、診斷、執行、探測、更新保護、平台、UI 及自動更新
├─ runtime/                 EXE 與原始碼共用的背景更新及取代助手
├─ tests/                   核心、GUI、發行及倉庫驗證
├─ third_party/             鎖定的執行階段 DLL、授權及相依清單
├─ tools/                   建構、SBOM、發行驗證及工具鏈引導
└─ 进程守护小助手.ahk      組合根與啟動入口
```

根指令稿只負責組合模組、裝配相依項目和啟動應用程式。`src` 不讀取根全域 `App`、`Main` 或 `GuiModules`；`app` 負責把純核心能力接入具體視窗、記錄及系統操作。詳情請參閱[架構與正確性邊界](en/architecture.md)。

## 2. 正確性邊界

- 目標身分、啟動入口和主視窗自訂顯示彼此獨立；顯示設定不可改變守護判斷。
- `Running`、`Stopped`、`Unknown` 是外部證據結果；只有確認停止才可進入恢復流程。
- 每個計時器、訊息回呼、檔案監察器、工作程序、視窗及原生資源均須有可重複執行的清理路徑。
- 設定快照、守護項目和更新保護設定在同一交易中提交；測試不可讀取或覆寫個人 `watchdog.ini`。
- 已放棄的 GDI 截圖覆蓋式平滑捲動不得重新引入；ListView 和記錄保留原生捲動。
- DPI、圖示、深色模式、視窗層級及輔助使用聲明必須有真實 Windows 與縮放驗證證據；自動化不能取代實體顯示器矩陣。

## 3. 驗證指令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-windows-integration.ps1 `
  -SoakSeconds 10
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\reproducible-build.ps1
```

`verify.ps1` 檢查相依雜湊、AHK 剖析、靜態架構約束、核心測試、倉庫邊界、完整 Git 歷史洩漏、工作流程語法及啟動行為。`verify-windows-integration.ps1` 會驗證完整字型、建立真實 Windows 控制項，並檢查 13 種語言、三級視窗及 GDI／USER 控制代碼回收。`reproducible-build.ps1` 連續建構兩次三種發行版本和 SBOM，並比較校驗清單雜湊。

AutoHotkey 和 Ahk2Exe 不會預先鎖定於倉庫。每次手動正式發佈都重新查詢 AutoHotkey 最新穩定版及 Ahk2Exe 最新發佈版，凍結同一份解析快照，再用它完成測試、兩次建構、SBOM 及封裝；actionlint 和 Gitleaks 等驗證工具仍固定版本。正式發行會保存實際版本、來源、提交和 SHA-256。第三方資料請參閱[第三方軟件聲明](project/THIRD_PARTY_NOTICES.en.md)。

## 4. 發佈與貢獻

使用者可見的變更必須同步更新所有本地化 README 及更新記錄。新增版本時使用[更新記錄範本](en/changelog-template.md)，按使用者可觀察到的新增、優化和修正整理內容，不要直接複製提交訊息或內部類別名稱。

完整流程請參閱[發佈流程](en/release-process.md)和[公開發佈清單](en/publication-checklist.md)。一般 Pull Request 不應建立版本標籤或改寫已發佈標籤。Issue 和 Pull Request 應提供可重現問題、風險與驗證證據；涉及視窗、DPI、圖示或深色模式時，請註明實際測試的 Windows 版本和縮放比例。另見[貢獻指南](../.github/CONTRIBUTING.en.md)和[專案治理](project/GOVERNANCE.en.md)。

專案程式碼採用 [MIT License](../LICENSE)。內嵌及隨附元件仍遵從各自授權；發行套件附有 AutoHotkey 授權及對應原始碼封存。PingFang、SF Pro Text 和 Apple SD Gothic Neo 依專案擁有者持有的商業再分發授權提供，不受 MIT License 規管。
