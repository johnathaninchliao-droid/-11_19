# OpenCode 下午對話紀錄整理（2026-11-19）

> 整理自 OpenCode 工作階段 `ses_e0d274751ffehjjKMnhF11xbwE`（開始於 2026-11-19 16:07）。
> 本檔只保留對話重點與可重用的指令，已省略工具執行細節；原始紀錄可透過 OpenCode API 再次取得。

---

## 目錄
1. [資料庫條件約束（Constraint）](#一資料庫條件約束constraint)
2. [取得另一個代理的對話紀錄](#二取得另一個代理的對話紀錄)
3. [本次任務與待辦](#三本次任務與待辦)
4. [客戶資料表建立與 SQL 除錯](#四客戶資料表建立與-sql-除錯後續問答)
5. [輸入法與打字防呆快捷鍵](#五輸入法與打字防呆快捷鍵)

---

## 一、資料庫條件約束（Constraint）

### 1.1 定義
**條件約束**是資料庫中用來限制資料必須符合的規則，用來確保資料的正確性、完整性與一致性。它定義在資料表或欄位上；當執行 `INSERT`、`UPDATE`、`DELETE` 時，DBMS 會自動檢查，違反規則就直接拒絕操作。

簡單說：它是資料庫內建的「守門員」，防止髒資料進來。

### 1.2 六種常見條件約束

| 類型 | 語法 | 說明 | 常見範例 |
| :--- | :--- | :--- | :--- |
| 主鍵約束 | `PRIMARY KEY` | 唯一識別每筆資料；不可重複、不可為 `NULL` | 學號、訂單編號 |
| 唯一約束 | `UNIQUE` | 欄位值不可重複（是否可為 `NULL` 視 DBMS 而定） | 身分證號、Email |
| 非空約束 | `NOT NULL` | 欄位一定要有值 | 姓名不可空白 |
| 外鍵約束 | `FOREIGN KEY` | 維持資料表之間的參考完整性 | 訂單的客戶編號必須存在於客戶表 |
| 檢查約束 | `CHECK` | 自訂條件必須成立 | `年齡 >= 0`、性別只能是 `M`/`F` |
| 預設值 | `DEFAULT` | 沒給值時自動帶入 | 狀態預設為 `啟用` |

### 1.3 SQL 範例

```sql
CREATE TABLE 學生 (
    學號   INT PRIMARY KEY,              -- 主鍵約束
    姓名   VARCHAR(50) NOT NULL,         -- 非空約束
    Email  VARCHAR(100) UNIQUE,          -- 唯一約束
    年齡   INT CHECK (年齡 >= 0),         -- 檢查約束
    科系編號 INT,
    FOREIGN KEY (科系編號) REFERENCES 科系(編號)  -- 外鍵約束
);

-- 這筆會被拒絕：違反 CHECK (年齡 >= 0)
INSERT INTO 學生 VALUES (1, '小明', 'a@x.com', -5, 1);
```

### 1.4 為什麼需要條件約束
1. **資料完整性**：避免無效資料（例如負數年齡）。
2. **一致性**：外鍵避免跨表資料變成孤兒。
3. **減少應用程式負擔**：規則寫在資料庫，不必每個程式重複檢查。
4. **語意清楚**：Schema 本身就是商業規則的文件。

> 補充：條件約束是宣告式、由 DBMS 自動檢查，優先使用；觸發程序（Trigger）適用於更複雜的程序式邏輯，但較難維護。

---

## 二、取得另一個代理的對話紀錄

### 2.1 關鍵觀念
- **代理（agent）本身不持有對話紀錄；訊息是存放在工作階段（session）裡。**
- 子代理（`subagent`，如 `explore`、`general`、自訂 reviewer）會在**獨立的子工作階段**執行（帶有 `parentID`），context 是全新的。
- 父代理預設只會在子代理完成每一輪後收到一份 `<subagent>` 報告，**不會自動拿到完整逐字紀錄**。
- 另一個 primary agent 的工作階段也彼此獨立，不會自動共享。

結論：**代理之間預設看不到彼此的完整對話，但可以透過 API 明確讀出來。**

### 2.2 用 API 取得（最完整）

```bash
# 列出工作階段（可用 parentID 找子代理、search 搜尋）
opencode api get "/api/session?limit=100"

# 找某個父工作階段底下的子工作階段
opencode api get "/api/session?parentID=<父sessionID>"

# 讀取某個工作階段的訊息（支援 order / limit / cursor / type 過濾）
opencode api get "/api/session/<sessionID>/message?order=asc&limit=100"

# 讀完整事件日誌（含工具呼叫、推理等，SSE 串流）
opencode api get "/api/experimental/session/<sessionID>/log"

# 匯出整個工作階段（建議加 sanitize 遮罩敏感資料）
opencode api get "/api/experimental/session/<sessionID>/export?sanitize=true"
```

### 2.3 用 TUI 取得
- `/sessions` 或 `Ctrl+X` → `L` 切換到既有工作階段，即可看到該階段的畫面紀錄。
- 子代理的回報會自動出現在父工作階段中，但完整過程仍要到子工作階段查看。

### 2.4 限制與注意事項
- 只能讀到**同一個 OpenCode 背景服務 / location** 看得到的工作階段；不同服務或機器需要對應連線與驗證。
- `opencode api` 會沿用 TUI 的驗證上下文，一般不需要另外帶 token。
- `/message` 是投影後的訊息；想要更底層的事件（工具輸入、成功/失敗、token 用量）要用 `/log`。
- 紀錄可能包含 API key、程式碼或敏感資料，分享前建議先遮罩。

### 2.5 參考文件
- OpenCode API：<https://opencode.ai/docs/api/>
- Agents / subagent：<https://opencode.ai/docs/agents/>
- TUI sessions：<https://opencode.ai/docs/cli/tui/>

---

## 三、本次任務與待辦

### 3.1 已完成的盤點
- 目標 repo：`https://github.com/johnathaninchliao-droid/-11_19.git`
  - 遠端 `main` 分支原本只有一個 commit（`1c0ac62`）。
  - 目前已包含：`README.md`、`SQL_Class_Notes_20261119.md`、`SQL_Database_Complete_Guide.md`（Antigravity 整理）、`OpenCode_Conversation_20261119.md`（本檔）、`SQL_客戶資料表範例.md`、`SQL_Customer_Table_Example.sql`。
- 本機 `C:\Users\User\Documents\多重代理` 的 `origin` 是另一個 repo（`agents_test_doc.git`），因此另外 clone 目標 repo 到暫存目錄再加入檔案，避免混到不同專案的歷史。

### 3.2 待辦
- [x] 整理 OpenCode 下午對話紀錄並加入目標 repo。
- [x] 使用者提供實際 SQL 語法後，逐條修正並整理成問題清單（詳見第四節）。
- [x] 補充中英文輸入法切換說明（詳見第五節）。

---

## 四、客戶資料表建立與 SQL 除錯（後續問答）

### 4.1 使用者貼出的原始語法

```sql
--check條件約束
drop table 客戶
go
create table 客戶(
    客戶編號 nchar(3) primary key,
    名稱 nvarchar(30),
    身分證號 nchar(10) unique ,
    電話 nvarchar(10),
    地址 nvarchar(50),
)
```

### 4.2 問題對照表

| # | 問題 | 影響 | 修正 |
| :-- | :--- | :--- | :--- |
| 1 | 最後一個欄位多逗號 `地址 nvarchar(50),` | `訊息 102 ... ',' 附近有語法錯誤` | 去掉最後那個 `,` |
| 2 | 註解寫 `--check條件約束`，但沒有 `CHECK` | 老師要的檢查約束根本沒建立 | 補一段 `CHECK (...)` |
| 3 | `DROP TABLE 客戶` 沒先檢查存在 | 第一次執行會報「物件名稱 '客戶' 無效」 | 用 `IF OBJECT_ID(...) IS NOT NULL` 包起來 |
| 4 | 條件約束沒有命名 | 日後不易查找與修改 | 用 `CONSTRAINT [名稱]` 命名 |

### 4.3 修正版（可直接執行）

```sql
-- check 條件約束：客戶編號必須是 1 個英文字 + 2 個數字，例如 C01
IF OBJECT_ID(N'[客戶]', N'U') IS NOT NULL
    DROP TABLE [客戶];
GO

CREATE TABLE [客戶] (
    [客戶編號] NCHAR(3)      NOT NULL,
    [名稱]     NVARCHAR(30) NOT NULL,
    [身分證號] NCHAR(10)     NOT NULL,
    [電話]     NVARCHAR(10) NULL,
    [地址]     NVARCHAR(50) NULL,

    CONSTRAINT [PK_客戶] PRIMARY KEY ([客戶編號]),
    CONSTRAINT [UQ_客戶_身分證號] UNIQUE ([身分證號]),
    CONSTRAINT [CK_客戶_客戶編號] CHECK ([客戶編號] LIKE N'[A-Z][0-9][0-9]')
);
GO
```

若老師要求檢查的是**電話格式**，把 CHECK 那行換成：

```sql
CONSTRAINT [CK_客戶_電話] 
CHECK ([電話] LIKE N'[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
```

### 4.4 測試插入

```sql
INSERT INTO [客戶] ([客戶編號], [名稱], [身分證號], [電話], [地址])
VALUES (N'C01', N'王小明', N'A123456789', N'0912345678', N'台北市');
GO

SELECT * FROM [客戶];
GO
```

若改成插入 `N'C1'`，會被 `CK_客戶_客戶編號` 擋下來，代表 CHECK 有作用。

---

## 五、輸入法與打字防呆快捷鍵

### 5.1 快捷鍵對照

| 快捷鍵 | 作用 | 打 SQL 時 |
| :--- | :--- | :--- |
| `Shift`（單鍵） | 在目前輸入法裡切換「中文 ↔ 英文」 | 按一下，看到右下角從「中」變成「英」再打 |
| `Ctrl + Space` | 直接**關閉/開啟**輸入法（關掉就是純英文） | 最穩，建議進 SSMS 先按這個 |
| `Win + Space` | 切換已安裝的輸入法/語言 | 電腦有很多輸入法時用 |
| `Shift + Space` | 切換**全形/半形** | ⚠️ **不要按**，這就是全形英文字的來源 |
| `Alt + Shift` | 舊版 Windows 切換輸入法 | 新版多半已改成 `Win + Space` |

### 5.2 實際操作流程

1. 在 SSMS 把游標放到查詢視窗。
2. 按一下 `Ctrl + Space`，讓輸入法關掉（右下角顯示 `ENG` 或「英」）。
3. 開始打 `CREATE TABLE...`。
4. 若不小心按到 `Shift + Space`，`SELECT` 會變成 `ＳＥＬＥＣＴ`，再按一次 `Shift + Space` 切回半形。

### 5.3 全形 / 半形常見錯誤

| 很可能打到 | 正確應該是 |
| :--- | :--- |
| `（ ）` | `( )` |
| `，` | `,` |
| `‘ ’` / `“ ”` | `'` / `"` |
| `＠` | `@` |
| `＝` | `=` |
| `ＳＥＬＥＣＴ` | `SELECT` |

詳細對照表另見 [`SQL_客戶資料表範例.md`](./SQL_客戶資料表範例.md)。

---

*最後更新於 2026-11-19 | 來源：OpenCode 工作階段「資料庫條件約束」*
