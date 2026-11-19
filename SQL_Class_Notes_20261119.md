# 📝 今日課堂上課筆記：SQL 資料庫核心架構與維運實戰

* **課堂日期**：2026 年 11 月 19 日
* **課程主題**：SQL Server 管理、T-SQL 語法防呆、底層分頁儲存架構與資料型別深度解析
* **核心精神**：不只學會查資料（`SELECT`），更要學會**如何保護資料庫不被搞壞、如何避開職場上的系統大災難**。

---

## 導讀：老師今天講這些，到底是在解決什麼問題？

很多人學 SQL 以為只要會查資料就好，但老師今天花大量時間講解底層結構與維運細節，是在傳授**企業級系統開發與維運的「避坑真功夫」**：
1. **防止資料死刑**：避免中文與 Emoji 存入後變成不可逆的 **`???`** 亂碼（`NVARCHAR`、Unicode、UTF-8）。
2. **防止帳目出錯**：避免金融金額少一分錢（`DECIMAL` 精確位數）、避免手機前導 0 消失、避免 `NULL` 搞砸統計平均值。
3. **防止線上當機**：避免刪除或還原資料庫時因連線被鎖死而卡住（`SINGLE_USER`、`WITH MOVE`）。
4. **防止效能暴跌**：了解 8KB 分頁儲存機制，避免隨便設 `VARCHAR(MAX)` 吃光伺服器記憶體與硬碟。

---

## 第一單元：SSMS 管理工具操作與介面求生小技巧

### 1.1 「新增查詢 (New Query)」的主要功能
* **本質**：開啟一條獨立的連線階段（Session / SPID），提供 SQL 程式碼工作台。
* **快捷鍵**：**`Ctrl + N`**。
* **核心功用**：
  * **分段執行**：用滑鼠反白選取特定語法片段，按下 **`F5`** 即可「只執行該段」，便於測試。
  * **雙檢視面板**：下方「結果 (Results)」檢視網格資料，「訊息 (Messages)」檢視受影響筆數與報錯代碼。
  * **執行計畫 (`Ctrl + M`)**：看資料庫底層是用快速度的「索引搜尋 (Seek)」還是耗時的「全表掃描 (Scan)」。

### 1.2 物件總管不小心關掉了怎麼開？（介面復原法）
* **最速解法（快捷鍵）**：直接按鍵盤最上方的 **`F8`**。
* **選單開啟**：點擊上方功能表 `檢視 (View) ➔ 物件總管 (Object Explorer)`。
* **固定視窗（防止自動縮回）**：若滑鼠移開就縮到左側邊緣，點擊右上角的 **「小圖釘 📌」** 固定。
* **排版完全亂掉救星**：功能表 `視窗 (Window) ➔ 重設視窗配置 (Reset Window Layout)`，一鍵恢復原廠配置。

---

## 第二單元：跨系統整合與自動化（PowerShell 與 JSON API）

### 2.1 PowerShell 的革命性特色：物件管線
傳統 Shell（CMD、Linux Bash）傳遞純文字，必須寫繁瑣正則表達式篩選；PowerShell 管道傳遞的是 **.NET 實體物件**，具有屬性與方法，可直接透過小數點 `.屬性` 存取。

### 2.2 何謂「呼叫」與「JSON」？
* **呼叫 (Call / Request)**：透過 HTTP/HTTPS 向遠端伺服器發送請求（如 GET/POST）調閱資料的動作。
* **JSON**：現代網際網路跨平台傳輸最通用的輕量純文字資料交換格式（由 `{}` 物件與 `[]` 清單組成）。
* **`Invoke-RestMethod` 的威力**：
  內建「自動轉換」功能，發送請求拿到 JSON 文字後，會**自動反序列化為記憶體中的物件**，免手動解析：
  ```powershell
  # 呼叫線上 API，結果直接就是物件
  $user = Invoke-RestMethod -Uri "https://jsonplaceholder.typicode.com/users/1"
  Write-Host $user.name            # 直接取得姓名
  Write-Host $user.address.city    # 階層巢狀結構也能直接點出來
  ```

---

## 第三單元：實戰維運！檢視電腦、安全移除與還原資料庫

### 3.1 課前檢查：查詢本機電腦與連線資訊
```sql
SELECT 
    HOST_NAME()                                AS [我目前在用的本機電腦名稱],
    SYSTEM_USER                                AS [目前的登入帳號],
    DB_NAME()                                  AS [目前所在的資料庫],
    SERVERPROPERTY('MachineName')              AS [SQL伺服器主機名稱],
    @@SERVERNAME                               AS [SQL執行個體名稱],
    CONNECTIONPROPERTY('client_net_address')   AS [本機IP位址];
```

### 3.2 標準且安全的「移除練習用資料庫」腳本
* **防呆核心**：
  1. 必須先切換到 `USE master;`，不能站在屋內拆房子。
  2. 強制踢除其他連線：`SET SINGLE_USER WITH ROLLBACK IMMEDIATE`。
  3. 中文名稱前後必須加上中括號 `[練習用資料庫]`。

```sql
USE master;
GO

DECLARE @DatabaseName NVARCHAR(128) = N'練習用資料庫';

IF DB_ID(@DatabaseName) IS NOT NULL
BEGIN
    PRINT '>> 1. 偵測到 [' + @DatabaseName + '] 存在，強制中斷外部連線...';
    EXEC('ALTER DATABASE [' + @DatabaseName + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;');

    PRINT '>> 2. 正式刪除資料庫主體與實體磁碟檔案...';
    EXEC('DROP DATABASE [' + @DatabaseName + '];');

    PRINT '>> 3. 成功！資料庫已安全完整移除。';
END
ELSE
BEGIN
    PRINT '>> 提示：找不到該資料庫，未進行任何變更。';
END
GO
```

### 3.3 隨堂除錯與常見語法報錯解析（⭐ 必考重點）
* **狀況 1：只寫 `BEGIN` 卻忘了寫 `END`**
  * T-SQL 中有 `BEGIN` 就必須有配對的 `END`，否則會出現 `Incorrect syntax near...`。
* **狀況 2：反白執行時漏掉了 `DECLARE`**
  * 若只選取 `IF ...` 到 `PRINT`，沒選到宣告列，會噴錯：`必須宣告純量變數 "@DatabaseName"`。變數只在同批次內有效！
* **狀況 3：中間誤加了 `GO`**
  * `GO` 代表一個批次結束，系統會在此時消滅記憶體中的變數，因此 `DECLARE` 和後續使用之間絕不能插入 `GO`。

### 3.4 還原資料庫語言寫法（RESTORE）
* **先探路看邏輯名稱**：`RESTORE FILELISTONLY FROM DISK = 'C:\Backup\TESTDB.bak';`
* **換路徑/改名還原（最常用）**：
  ```sql
  RESTORE DATABASE [TESTDB_NEW]
  FROM DISK = 'C:\Backup\TESTDB.bak'
  WITH 
      MOVE '原邏輯資料檔名' TO 'D:\SQLData\TESTDB_NEW.mdf',
      MOVE '原邏輯日誌檔名' TO 'D:\SQLLog\TESTDB_NEW_log.ldf',
      REPLACE, RECOVERY, STATS = 10;
  ```

---

## 第四單元：資料庫底層儲存架構（分頁與範圍）

### 4.1 分頁 (Page) vs. 範圍 (Extent) 對照表
| 儲存單位 | 固定大小 | 定義與角色 | 生活比喻 |
| :--- | :--- | :--- | :--- |
| **分頁 (Page)** | **8 KB** | **資料讀寫 (I/O) 的最小單位**。讀一筆資料也是載入整張 8KB。 | 書本裡的「單一頁面」 |
| **範圍 (Extent)** | **64 KB** | **空間分配 (Allocation) 的最小單位**，由 8 個連續分頁組成。 | 8 頁裝訂成冊的一小疊活頁紙 |
* **混合範圍 (Mixed Extent)**：給不同的小資料表共用，避免浪費。
* **統一範圍 (Uniform Extent)**：整組 64KB 由同一張大資料表獨佔，效能最高。

### 4.2 底層帳本語法解讀：`size * 8 / 1024` 的數學由來
```sql
USE [練習用資料庫];
GO
SELECT name AS [邏輯檔案名稱], size * 8 / 1024 AS [變更後大小_MB]
FROM sys.database_files
WHERE type = 0; -- 0 代表資料主檔 (.mdf)，1 代表交易記錄檔 (.ldf)
```
* **解讀**：`sys.database_files` 是系統帳本；裡面的 `size` 單位是「**8KB 分頁數**」。
* **公式推導**：`分頁數 * 8` 換算為 **KB**，再 `/ 1024` 換算為 **MB**！

### 4.3 修改 mdf 檔大小為 200MB 的標準作業順序
1. 先查出檔案的「邏輯名稱」與目前大小。
2. 切換到 `USE master; GO`。
3. 若是**加大**（例如 8MB 變 200MB）：
   `ALTER DATABASE [練習用資料庫] MODIFY FILE (NAME = N'邏輯名稱', SIZE = 200MB);`
4. 若是**縮小**（例如 500MB 縮回 200MB）：不能用 `MODIFY FILE`，必須改用 `DBCC SHRINKFILE (N'邏輯名稱', 200);`。

---

## 第五單元：關鍵語法概念（ALTER、UPDATE、NULL）

### 5.1 `ALTER` 與 `UPDATE` 哪一個比較常用？
* **答案**：**`UPDATE` 遠比 `ALTER` 常用幾萬倍！**
* **本質差別**：
  * **`UPDATE` (改內容)**：天天在跑（會員改密碼、下單扣庫存）。
  * **`ALTER` (改骨架/設定)**：系統改版升級、加大欄位、維運踢連線時才偶爾用一次。
* **危險性防範**：
  * `UPDATE` 最怕漏寫 `WHERE`（整張表資料全毀）。
  * `ALTER` 執行時會鎖住整張資料表，千萬不能在熱門上班時間對大資料表下達。

### 5.2 `NULL` 的本質與三大地雷
* **意義**：代表「**未知 (Unknown)**」或「**尚未填寫**」，絕對不等於 `0`，也不等於空字串 `""`。
* **比對地雷**：絕對不能寫 `= NULL`，必須使用 **`IS NULL`** 或 **`IS NOT NULL`**。
* **運算地雷**：`100 + NULL = NULL`（跟未知做計算，結果依然是未知）。
* **統計地雷**：`AVG()` 自動忽略 NULL；若要給預設值防呆，使用 `ISNULL(欄位, 0)`。

---

## 第六單元：型別精確性與編碼（防止系統當機與亂碼）

### 6.1 精確位數：`DECIMAL(p, s)`
* **`p` (Precision, 精確位數)**：整數加小數**最多幾位數**。
* **`s` (Scale, 小數位數)**：小數點後**佔幾位**。
* **範例 `DECIMAL(5, 2)`**：整數最多 3 位，小數固定 2 位，最大容納 `999.99`。
* **金融核心**：會計與金流系統**嚴禁使用 `FLOAT`**（有浮點微小偏差），必須使用 `DECIMAL` 保證精準。

### 6.2 純時間型別：`TIME(n)`
* 專門儲存「純時間」（不含年月日），如上班打卡、營業時間。
* `(n)` 代表秒數後面的小數精確度（0 ~ 7 位數）。
  * `TIME(0)`：精確到整數秒，佔 3 Bytes（最省空間）。
  * `TIME(3)`：毫秒，佔 4 Bytes。
  * `TIME(7)`：100 奈秒，佔 5 Bytes（系統預設）。

### 6.3 字串型別重要性與 UTF-8 編碼
* **`CHAR(100)`**：固定長度，字數不足會在後面補滿空白，巨量資料時極度浪費空間。
* **`VARCHAR(100)`**：變動長度，實際存幾個字就佔幾個空間。
* **`NVARCHAR` 與大寫 `N`**：微軟標準 Unicode（UTF-16），存繁體中文、日韓文、Emoji 絕不變問號 `???`。
* **什麼是 UTF-8？**
  * 全球 98% 網頁、JSON 與 API 的通用編碼。
  * 具備「可變長度特性」：純英文只佔 1 Byte（極省空間），繁體中文佔 3 Bytes，Emoji 佔 4 Bytes。
  * SQL Server 2019+ 支援使用普通 `VARCHAR` 搭配 `_UTF8` 定序直接存 UTF-8 資料。

---

## 第七單元：宏觀架構！關聯式資料庫 (RDBMS)

### 7.1 為什麼叫「關聯」？
二維表格（Row/Column）不重複存放相同的資料，而是透過「鍵 (Key)」互相串接：
* **主鍵 (Primary Key, PK)**：每張表獨一無二的身分證（不可重複、不可為 NULL）。
* **外鍵 (Foreign Key, FK)**：用來指回另一張表主鍵的欄位，達成表格間的牽線（如訂單表中的買家編號）。

### 7.2 ACID 交易保證（金融級可靠度）
* **A (原子性)**：要嘛全部成功，要嘛完全不執行（轉帳扣款與進帳必須一氣呵成）。
* **C (一致性)**：交易完成後必須符合所有防呆規則。
* **I (隔離性)**：多筆操作同時進行時互不干擾。
* **D (持久性)**：一旦 COMMIT 確認寫入，就算立刻拔掉伺服器電源，重啟後資料依然完整。

---

## 課後重點口訣速查卡

| 知識點 | 核心口訣 / 記憶提示 |
| :--- | :--- |
| **物件總管找不到** | 按鍵盤 `F8`，排版亂掉按 `視窗 ➔ 重設視窗配置` |
| **刪除/還原資料庫** | 先切 `USE master`，再用 `SET SINGLE_USER WITH ROLLBACK IMMEDIATE` 踢人 |
| **反白執行報錯** | 檢查有沒有漏選上面的 `DECLARE`，檢查 `BEGIN` 有沒有配對 `END` |
| **分頁大小** | 1 個分頁 = **8 KB**，1 個範圍 = 8 個分頁 = **64 KB** |
| **換算 MB** | `size * 8 / 1024`（分頁數轉 KB 再轉 MB） |
| **ALTER vs UPDATE** | `ALTER` 改骨架（低頻），`UPDATE` 改內容（高頻，千萬記得寫 `WHERE`） |
| **NULL 比對** | 嚴禁用等號，必須用 `IS NULL` 或 `IS NOT NULL` |
| **金流金額** | 不用 FLOAT，指名 `DECIMAL(p, s)` |
| **中文防亂碼** | 字串用 `NVARCHAR`，程式碼給值前加 `N`（如 `N'台灣'`） |

---
*筆記整理完成於：2026-11-19 | 整理自今日課堂實戰對話全紀錄*
