-- 客戶資料表建立範例（SQL Server / T-SQL）
-- 直接用 SSMS：檔案 -> 開啟 -> 檔案，打開本檔後按 F5 執行

IF OBJECT_ID(N'[客戶資料表]', N'U') IS NOT NULL
    DROP TABLE [客戶資料表];
GO

CREATE TABLE [客戶資料表] (
    [客戶編號] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [姓名]     NVARCHAR(50)  NOT NULL,
    [電話]     NVARCHAR(20)  NULL,
    [Email]    NVARCHAR(100) NULL,
    [地址]     NVARCHAR(200) NULL,
    [出生日期] DATE          NULL,
    [性別]     CHAR(1)       NULL CHECK ([性別] IN (N'M', N'F')),
    [信用額度] DECIMAL(10,2) NULL DEFAULT (0),
    [建立時間] DATETIME2(0)  NOT NULL DEFAULT (GETDATE())
);
GO

INSERT INTO [客戶資料表] 
    ([姓名], [電話], [Email], [地址], [出生日期], [性別], [信用額度])
VALUES 
    (N'王小明', N'0912-345-678', N'ming@example.com', N'台北市中正區', '1990-05-20', N'M', 50000.00);
GO

SELECT [客戶編號], [姓名], [電話], [Email], [信用額度]
FROM [客戶資料表];
GO
