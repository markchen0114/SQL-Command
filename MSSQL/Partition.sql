-- Create Table & Insert Test Data
DROP TABLE IF EXISTS TestParti..Dep_Mst
GO
SELECT *
INTO TestParti..Dep_Mst
FROM agilitycp..Dep_Mst
GO
ALTER TABLE TestParti.dbo.Dep_Mst ADD CONSTRAINT
	PK_Dep_Mst PRIMARY KEY CLUSTERED 
	(
	DepUID
	) WITH( STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

DROP TABLE IF EXISTS TestParti..Con_Shp
GO
SELECT *
INTO TestParti..Con_Shp
FROM (
SELECT TOP 10 *
FROM agilitycp..Con_Shp
WHERE JobConfirmDate between '20180101' and '20181231'
UNION
SELECT TOP 10 *
FROM agilitycp..Con_Shp
WHERE JobConfirmDate between '20190101' and '20191231'
UNION
SELECT TOP 10 *
FROM agilitycp..Con_Shp
WHERE JobConfirmDate between '20200101' and '20201231'
) ConShp
GO
ALTER TABLE TestParti.dbo.Con_Shp ADD CONSTRAINT
	PK_Con_Shp PRIMARY KEY CLUSTERED 
	(
	QVSHPTUID
	) WITH( STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

select * from dep_mst
select * from con_shp


-- ----------------------
-- 建立 PartitionInfo 函式  (from 參考文件 2..)
-- ----------------------
-- 目的: 列出傳入 Table名稱 的各 Partition 的切割臨界值 / 所佔Size / 資料筆數 
-- 呼叫範例:
-- SELECT * FROM PartitionInfo('TestParti..Con_Shp');
-- SELECT * FROM PartitionInfo('TestParti..Dep_Mst');
DROP FUNCTION IF EXISTS PartitionInfo
GO
 
CREATE FUNCTION PartitionInfo( @tablename sysname ) RETURNS table
AS RETURN
 SELECT
 OBJECT_NAME(p.object_id) as TableName
 ,p.partition_number as PartitionNumber
 ,prv_left.value as LowerBoundary
 ,prv_right.value as  UpperBoundary
 ,ps.name as PartitionScheme
 ,pf.name as PartitionFunction
 ,fg.name as FileGroupName
 ,CAST(p.used_page_count * 8.0 / 1024 AS NUMERIC(18,2)) AS UsedPages_MB
 ,p.row_count as Rows
 FROM  sys.dm_db_partition_stats p
 INNER JOIN sys.indexes i ON i.object_id = p.object_id AND i.index_id = p.index_id
 INNER JOIN sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
 INNER JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
 INNER JOIN sys.destination_data_spaces dds ON dds.partition_scheme_id = ps.data_space_id AND dds.destination_id = p.partition_number
 INNER JOIN sys.filegroups fg ON fg.data_space_id = dds.data_space_id
 LEFT  JOIN sys.partition_range_values prv_right ON prv_right.function_id = ps.function_id AND prv_right.boundary_id = p.partition_number
 LEFT  JOIN sys.partition_range_values prv_left  ON prv_left.function_id = ps.function_id AND prv_left.boundary_id = p.partition_number - 1
 WHERE
 p.object_id = OBJECT_ID(@tablename) and p.index_id < 2
GO

-- ----------------------
-- 建立輔助函式 IndexInfo (from 參考文件 8..)
-- ----------------------
-- 目的: 列出傳入 Table名稱 各個 Index 所在的 File Group 及資料筆數
-- 呼叫範例:
-- SELECT * FROM IndexInfo('Orders');
-- SELECT * FROM IndexInfo('OrdersP');
DROP FUNCTION IF EXISTS IndexInfo
GO
 
CREATE FUNCTION IndexInfo( @tablename sysname ) RETURNS table
AS RETURN
 SELECT OBJECT_SCHEMA_NAME(t.object_id) AS schema_name
 ,t.name AS table_name
 ,i.index_id
 ,i.name AS index_name
 ,p.partition_number
 ,fg.name AS filegroup_name
 ,FORMAT(p.rows, '#,###') AS rows
 FROM sys.tables t
 INNER JOIN sys.indexes i ON t.object_id = i.object_id
 INNER JOIN sys.partitions p ON i.object_id=p.object_id AND i.index_id=p.index_id
 LEFT OUTER JOIN sys.partition_schemes ps ON i.data_space_id=ps.data_space_id
 LEFT OUTER JOIN sys.destination_data_spaces dds ON ps.data_space_id=dds.partition_scheme_id AND p.partition_number=dds.destination_id
 INNER JOIN sys.filegroups fg ON COALESCE(dds.data_space_id, i.data_space_id)=fg.data_space_id
 WHERE t.name = @tablename
GO

IF EXISTS (SELECT * FROM sys.partition_functions  
    WHERE name = 'P_Func_Year')  
    DROP PARTITION FUNCTION P_Func_Year;  
GO
 
CREATE PARTITION FUNCTION P_Func_Year(datetime)
AS RANGE RIGHT
FOR VALUES ('2018/01/01', '2019/01/01');
GO
/*
這個範例使用三個 datetime 型別的值來間隔分割區。
       2018/1/1    2019/1/1    2020/1/1 
   r1     ↓    r2    ↓    r3    ↓    r4
----------。----------。----------。----------
RIGHT 數字表示間隔值本身包含在右邊區間，所以四個區間的範圍如下：
  
PartitionNumber Partition Range
=============== ===================================
1                              range1 < 2018/01/01
2               2018/01/01 <=  range2 < 2019/01/01
3               2019/01/01 <=  range3 < 2020/01/01
4               2020/01/01 <=  range4 
*/

-- Create FILEGROUP
alter database [TestParti] add filegroup [TestParti2017];
alter database [TestParti] add filegroup [TestParti2018];
alter database [TestParti] add filegroup [TestParti2019];
GO

-- Create File and mapping to FILEGROUP
ALTER DATABASE [TestParti] ADD FILE ( NAME = N'TestParti2017', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQL2016\MSSQL\DATA\TestParti2017.mdf' , SIZE = 8192KB , FILEGROWTH = 65536KB ) TO FILEGROUP [TestParti2017]
ALTER DATABASE [TestParti] ADD FILE ( NAME = N'TestParti2018', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQL2016\MSSQL\DATA\TestParti2018.mdf' , SIZE = 8192KB , FILEGROWTH = 65536KB ) TO FILEGROUP [TestParti2018]
ALTER DATABASE [TestParti] ADD FILE ( NAME = N'TestParti2019', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQL2016\MSSQL\DATA\TestParti2019.mdf' , SIZE = 8192KB , FILEGROWTH = 65536KB ) TO FILEGROUP [TestParti2019]


-- 每個分割都使用不同的檔案群組
IF EXISTS (SELECT * FROM sys.partition_schemes
    WHERE name = 'P_Scheme_Year')  
    DROP PARTITION SCHEME P_Scheme_Year;  
GO
 
CREATE PARTITION SCHEME P_Scheme_Year
AS PARTITION P_Func_Year TO (TestParti2017, TestParti2018, TestParti2019);
GO

-- 分割Table
ALTER TABLE [dbo].[Con_Shp] DROP CONSTRAINT [PK_Con_Shp] WITH ( ONLINE = OFF )
ALTER TABLE [dbo].[Con_Shp] ADD  CONSTRAINT [PK_Con_Shp] PRIMARY KEY NONCLUSTERED 
(
	[QVSHPTUID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

CREATE CLUSTERED INDEX [ClusteredIndex_on_P_Scheme_Year_637170319678235314] ON [dbo].[Con_Shp]
(
	[JobConfirmDate]
)WITH (SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF) ON [P_Scheme_Year]([JobConfirmDate])
DROP INDEX [ClusteredIndex_on_P_Scheme_Year_637170319678235314] ON [dbo].[Con_Shp]
GO

-- Add FILEGROUP & FILE for 2020
alter database [TestParti] add filegroup [TestParti2020];
GO
ALTER DATABASE [TestParti] ADD FILE ( NAME = N'TestParti2020', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQL2016\MSSQL\DATA\TestParti2020.mdf' , SIZE = 8192KB , FILEGROWTH = 65536KB ) TO FILEGROUP [TestParti2020]
GO
-- 建立新的分割區
ALTER PARTITION SCHEME P_Scheme_Year NEXT USED [TestParti2020];      --指定下個新分割區要使用的檔案群組
ALTER PARTITION FUNCTION P_Func_Year() SPLIT RANGE ('2020/01/01');   --新分割區
GO

-- Insert Data again
SET IDENTITY_INSERT TestParti..Con_Shp ON
insert TestParti..Con_Shp(QVSHPTUID,HAWB,JobConfirmDate,Status,CreateBy,CreateDate,GRFRT,GRUSD,NRUSD,NR_FrtValue,IsGitC,HasCharge,IsColoader,HasBattery,IsShipA,HasQMNo,SrcFrom)
SELECT top 300 CONVERT(int,QVSHPTUID),HAWB,JobConfirmDate,Status,CreateBy,CreateDate,GRFRT,GRUSD,NRUSD,NR_FrtValue,IsGitC,HasCharge,IsColoader,HasBattery,IsShipA,HasQMNo,SrcFrom
FROM agilitycp..Con_Shp (NOLOCK)
WHERE JobConfirmDate > '20180201'
  and QVSHPTUID not in (select QVSHPTUID from TestParti..Con_Shp)
SET IDENTITY_INSERT TestParti..Con_Shp OFF


SELECT * FROM PartitionInfo('Con_Shp');
SELECT * FROM PartitionInfo('Con_Shp_S');
SELECT * FROM PartitionInfo('Dep_Mst');

SELECT * FROM IndexInfo('Con_Shp');
SELECT * FROM IndexInfo('Dep_Mst');

select * from Con_Shp where year(jobconfirmdate)=2019
select * from Dep_Mst



select * from con_shp where cast(JobConfirmDate as date) between '2019-01-01' and '2020-12-31'
select * from con_shp_s where cast(JobConfirmDate as date) between '2019-01-01' and '2020-12-31'


