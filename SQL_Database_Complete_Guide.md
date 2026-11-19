# SQL 資料庫與系統維運完全學習手冊

> 本手冊整合了從 SQL 管理工具、PowerShell 自動化、資料庫生命週期維護腳本，到底層儲存架構與資料型態設計的實務精華，適合做為日常開發與資料庫管理的速查參考指南。

---

## 目錄
1. [SQL Management 與 SSMS 工具操作](#1-sql-management-與-ssms-工具操作)
2. [PowerShell 自動化與 RESTful API / JSON](#2-powershell-自動化與-restful-api--json)
3. [資料庫生命週期管理：安全移除與還原 (T-SQL 實戰)](#3-資料庫生命週期管理安全移除與還原-t-sql-實戰)
4. [資料庫儲存架構：8KB 分頁 (Page) 與 64KB 範圍 (Extent)](#4-資料庫儲存架構8kb-分頁-page-與-64kb-範圍-extent)
5. [核心語法拆解：DECLARE、ALTER vs UPDATE、NULL 的本質](#5-核心語法拆解declarealter-vs-updatenull-的本質)
6. [資料型別與字串編碼精確性：DECIMAL、TIME、NVARCHAR 與 UTF-8](#6-資料型別與字串編碼精確性decimaltimenvarchar-與-utf-8)
7. [關聯式資料庫 (RDBMS) 核心架構與設計概念](#7-關聯式資料庫-rdbms-核心架構與設計概念)

---

## 1. SQL Management 與 SSMS 工具操作

### 1.1 什麼是 SQL Management？
* **工具面向**：通常指微軟官方推出的 **SQL Server Management Studio (SSMS)**，是管理 Microsoft SQL Server 與 Azure SQL Database 的整合圖形化用戶端。
* **領域面向**：泛指**關聯式資料庫管理（Database Management）**，包含結構定義（DDL）、效能調校、索引維護、備份復原（HA/DR）與權限控管。

### 1.2 「新增查詢 (New Query)」的核心功能
「新增查詢」（快捷鍵 `Ctrl + N`）會開啟一個獨立連線階段（Session / SPID）的工作台：
* **撰寫與執行**：撰寫 DQL/DML/DDL 語法，按 `F5` 可執行整份腳本或只執行反白選取的片段。
* **雙反饋面板**：
  * **結果 (Results)**：以網格表格（Grid）呈現查詢出的數據。
  * **訊息 (Messages)**：顯示執行時間、影響行數或錯誤代碼。
* **執行計畫 (Execution Plan)**：按 `Ctrl + M` 可診斷查詢底層是進行「索引尋找 (Index Seek)」還是「全表掃描 (Table Scan)」。

### 1.3 SSMS 常用快捷鍵與排版復原
* **`F8`**：快速開啟／切換到左側「物件總管 (Object Explorer)」。
* **`F5`**：執行目前查詢視窗中的語法。
* **`Ctrl + R`**：顯示或隱藏下方的查詢結果網格。
* **固定物件總管**：點選視窗右上角的「小圖釘 📌」圖示防止自動縮回。
* **排版混亂復原**：點擊功能表 `視窗 (Window) ➔ 重設視窗配置 (Reset Window Layout)`。

---

## 2. PowerShell 自動化與 RESTful API / JSON

### 2.1 為什麼選擇 PowerShell？
與傳統 Shell（CMD、Bash）傳遞「純文字字串」不同，PowerShell 的管道傳遞的是 **.NET 實體物件**。屬性與數值可以直接點選存取，不需要依賴 `grep` 或 `awk` 切割文字。

### 2.2 呼叫（Call）與 JSON 的自動轉換
* **呼叫 (Call / HTTP Request)**：向遠端 API 伺服器發送請求（GET、POST 等）並等待回傳。
* **JSON**：現代網際網路跨平台傳輸最主流的輕量純文字資料交換格式。
* **`Invoke-RestMethod` 的威力**：
  一鍵發送 HTTP 請求，並**自動將回傳的 JSON 字串反序列化為 PowerShell 自訂物件**，省去手動解析步驟。

```powershell
# 一行發送請求並自動轉為物件
$user = Invoke-RestMethod -Uri "https://jsonplaceholder.typicode.com/users/1"

# 直接透過物件屬性讀取階層資料
Write-Host $user.name            # 輸出名稱
Write-Host $user.address.city    # 直接讀取巢狀結構
```

---

## 3. 資料庫生命週期管理：安全移除與還原 (T-SQL 實戰)

### 3.1 檢查本機電腦與連線環境資訊
在執行敏感操作前，先確認自己所在的環境與當前連線：

```sql
SELECT 
    HOST_NAME()                                AS [本機電腦名稱],
    SYSTEM_USER                                AS [目前登入帳號],
    DB_NAME()                                  AS [目前停留資料庫],
    SERVERPROPERTY('MachineName')              AS [SQL主機名稱],
    @@SERVERNAME                               AS [SQL執行個體名稱],
    CONNECTIONPROPERTY('client_net_address')   AS [用戶端IP位址];
```

### 3.2 標準且安全的「移除資料庫」腳本
避免因「有人正連線佔用」或「自己站在屋內拆房子」導致 `Msg 3702` 錯誤：

```sql
-- 1. 切換至 master，避免自身鎖定目標資料庫
USE master;
GO

-- 2. 宣告欲刪除的資料庫名稱
DECLARE @DatabaseName NVARCHAR(128) = N'練習用資料庫';

-- 3. 檢查資料庫是否存在
IF DB_ID(@DatabaseName) IS NOT NULL
BEGIN
    PRINT '>> 1. 偵測到 [' + @DatabaseName + '] 存在，正在中斷連線...';

    -- 4. 強制踢除所有外部連線並復原未完成交易
    EXEC('ALTER DATABASE [' + @DatabaseName + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;');
    PRINT '>> 2. 已切斷所有外部連線。';

    -- 5. 正式自磁碟抹除資料庫主體與檔案
    EXEC('DROP DATABASE [' + @DatabaseName + '];');
    PRINT '>> 3. 成功！資料庫 [' + @DatabaseName + '] 已完整移除。';
END
ELSE
BEGIN
    PRINT '>> 提示：系統中找不到名為 [' + @DatabaseName + '] 的資料庫。';
END
GO
```

### 3.3 資料庫還原：標準覆蓋 vs 指定路徑改名 (WITH MOVE)
還原前建議先檢查備份檔內的邏輯檔案名稱：
```sql
RESTORE FILELISTONLY FROM DISK = 'C:\Backup\TESTDB.bak';
```

#### 業界最推薦寫法：使用 `WITH MOVE` 進行改名或換硬碟還原
```sql
USE master;
GO

RESTORE DATABASE [TESTDB_NEW]                          -- 還原後的新資料庫名稱
FROM DISK = 'C:\Backup\TESTDB.bak'                     -- 備份檔所在實體路徑
WITH 
    MOVE 'TESTDB'     TO 'D:\SQLData\TESTDB_NEW.mdf',  -- 資料主檔邏輯映射
    MOVE 'TESTDB_log' TO 'D:\SQLLog\TESTDB_NEW_log.ldf', -- 交易記錄檔邏輯映射
    REPLACE,                                           -- 允許覆蓋
    RECOVERY,                                          -- 進入就緒可用狀態
    STATS = 10;                                        -- 每 10% 回報一次進度
GO
```

---

## 4. 資料庫儲存架構：8KB 分頁 (Page) 與 64KB 範圍 (Extent)

### 4.1 分頁與範圍的官方架構
* **分頁 (Page，8 KB)**：SQL Server 進行**讀寫與記憶體 I/O 的最小單位**。無論讀取多少筆資料，系統每次至少從硬碟載入整張 8KB 分頁。
* **範圍 (Extent，64 KB)**：**硬碟空間分配的最小單位**，由 8 個連續的分頁組成。
  * **混合範圍 (Mixed Extent)**：供多個小資料表共用，節省空間。
  * **統一範圍 (Uniform Extent)**：整疊 64KB 完全專屬於單一資料表，效能最佳。

### 4.2 查詢底層帳本與換算公式解析
```sql
USE [練習用資料庫];
GO

SELECT 
    name AS [邏輯檔案名稱],
    size * 8 / 1024 AS [大小_MB]
FROM sys.database_files
WHERE type = 0; -- 0 代表主要資料主檔 (.mdf)，1 代表交易記錄檔 (.ldf)
```
* **為什麼 `size * 8 / 1024`？**
  * `sys.database_files.size` 記錄的是**分頁數量**。
  * `size * 8` = 總容量 (KB)。
  * `KB / 1024` = 總容量 (MB)。

### 4.3 調整資料主檔 (.mdf) 大小至 200MB 的順序
1. **查邏輯名稱**：查出 `type = 0` 的 `name`。
2. **切換到 master**：`USE master; GO`。
3. **加大檔案**：
   ```sql
   ALTER DATABASE [練習用資料庫]
   MODIFY FILE (NAME = N'練習用資料庫', SIZE = 200MB);
   ```
   > ⚠️ 若是要從更大容量**縮小**回 200MB，不可用 `MODIFY FILE`，必須改用 `DBCC SHRINKFILE (N'練習用資料庫', 200);`。

---

## 5. 核心語法拆解：DECLARE、ALTER vs UPDATE、NULL 的本質

### 5.1 `DECLARE @DatabaseName NVARCHAR(128) = N'練習用資料庫';` 拆解
* **`DECLARE`**：向記憶體申請宣告區域變數。
* **`@`**：自訂變數開頭標記（雙 `@` 為系統內建函數/變數）。
* **`NVARCHAR(128)`**：支援 Unicode 的變動長度字串；長度設為 128 是因為 SQL Server 系統物件名稱上限即為 128 個字元。
* **`N'...'`**：字串前加 `N` 強制指定以 Unicode 編碼處理，防止中文或特殊字元變亂碼。
* **注意批次範圍**：變數在同一個批次內有效，若中途加入 `GO`，變數會立刻被消滅釋放。

### 5.2 ALTER 與 UPDATE 的關鍵區別

| 比較維度 | **ALTER** (改骨架/結構) | **UPDATE** (改內容/資料) |
| :--- | :--- | :--- |
| **分類等級** | DDL (資料定義語言) | DML (資料操作語言) |
| **操作對象** | 資料表欄位、資料庫設定、物件結構 | 表格內已儲存的一筆筆資料列 |
| **執行頻率** | 極低（系統版本升級、架構調整時） | **極高**（隨使用者點擊、下單隨時執行） |
| **危險防範** | 易產生架構鎖定（Locking），線上機需避開尖峰時段 | **務必加 `WHERE` 條件**，否則會更新整張資料表 |

### 5.3 NULL 的本質與運算地雷
* `NULL` 代表**「未知 (Unknown)」**或**「尚未填寫」**，不等於 `0`，也不等於空字串 `""`。
* **比對語法**：必須使用 `IS NULL` 或 `IS NOT NULL`，絕對不可使用 `= NULL`。
* **運算特性**：
  * 任何數值與 `NULL` 做數學運算，結果必定為 `NULL`（`100 + NULL = NULL`）。
  * 聚合函數（如 `AVG()`）會自動略過 `NULL`，不參與平均計算。
  * 替換預設值可用 `ISNULL(欄位, 0)`。

---

## 6. 資料型別與字串編碼精確性：DECIMAL、TIME、NVARCHAR 與 UTF-8

### 6.1 精確位數：`DECIMAL(p, s)`
* **`p` (Precision, 精確位數)**：整數加小數的**總位數上限**。
* **`s` (Scale, 小數位數)**：小數點右邊固定佔幾位。
* **範例 `DECIMAL(5, 2)`**：整數最多 3 位，小數固定 2 位，極限值為 `999.99`。
* **重要性**：金融會計系統絕不可使用 `FLOAT`（二進位近似值會有小數浮點偏差），必須使用 `DECIMAL` 保證每一分錢絕對精準。

### 6.2 純時間型態：`TIME(n)`
* 專門儲存「純時間」（不帶年月日），適用於營業時間、排班表。
* **`(n)`**：秒數後面保留的小數精確度（0 ~ 7 位數）。
  * `TIME(0)`：精確到整數秒，佔 3 Bytes（最省空間）。
  * `TIME(3)`：精確到毫秒（千分之一秒），佔 4 Bytes。
  * `TIME(7)`：精確到 100 奈秒，佔 5 Bytes（預設值）。

### 6.3 字串型別選用與 UTF-8 編碼
* **`CHAR` vs `VARCHAR`**：`CHAR` 存不滿會補空白浪費空間；`VARCHAR` 長度彈性變動。
* **`NVARCHAR` (滿足 UTF-16)**：微軟原生支援多國語言與中文字串的標準型態，避免 `???` 亂碼首選。
* **UTF-8 的意義**：全球通用標準編碼，具備「可變長度特性」（英文 1 Byte、繁體中文 3 Bytes、Emoji 4 Bytes），相容傳統 ASCII 且省空間。
  * SQL Server 2019+ 支援普通 `VARCHAR` 搭配 `_UTF8` 定序直接儲存 UTF-8 資料。

---

## 7. 關聯式資料庫 (RDBMS) 核心架構與設計概念

### 7.1 核心精髓：什麼是「關聯」？
關聯式資料庫將資料以二維表格（Row/Column）存放，並**透過鍵（Key）將多個表格相互串接**，避免資料重複存放（正規化）：
* **主鍵 (Primary Key, PK)**：表格中每筆資料唯一的身分證，不可重複、不可為 `NULL`。
* **外鍵 (Foreign Key, FK)**：子表格中用來對應父表格主鍵的欄位，建立跨表關聯。

### 7.2 核心優勢
1. **資料一致性 (Data Integrity)**：修改客戶資料只需更新一處，關聯訂單自動同步最新資訊。
2. **ACID 交易保證**：
   * **A (原子性)**：整筆交易要嘛全做，要嘛完全不做（轉帳扣款與入帳必須同時成功）。
   * **C (一致性)**：交易前後資料庫必須符合所有約束規則。
   * **I (隔離性)**：多筆併發交易彼此互不干擾。
   * **D (持久性)**：交易確認寫入（COMMIT）後，即便斷電重啟資料也不會遺失。
3. **標準化語言**：全世界通用 SQL 語法，跨資料庫引擎（SQL Server、PostgreSQL、MySQL、Oracle）邏輯皆相通。

---
*文件產生時間：2026-11-19 | 適用環境：Microsoft SQL Server 2016+ / SSMS / PowerShell*
