-- Get queries waiting status
select * from sys.dm_os_wait_stats

-- Finding blocking/locking queries
SELECT * 
FROM sys.dm_exec_requests
WHERE DB_NAME(database_id) = 'agilitycp' 
AND blocking_session_id <> 0

/* Rebuild Index for all table --begin-- */
use <DatabaseName>
GO

Declare
  @ls_TableName varchar(100),   /*table name*/
  @ls_Command   varchar(800)    /*sql command*/

-- loop : get all table name
declare lo_Cursor insensitive cursor for
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME

Open lo_Cursor
fetch lo_Cursor into @ls_TableName
while @@FETCH_STATUS = 0
begin
  --
  set @ls_Command = ''
  print 'Table: ' + @ls_TableName + ' processing ... '
  if REPLACE(@@VERSION,'  ',' ') like '%Server 2000%' begin
    /* SQL 2000 */
    set @ls_Command = @ls_Command + 'DBCC DBREINDEX (['+@ls_TableName+'], '''') '
  end else begin
    /* SQL 2015 or above */
    set @ls_Command = @ls_Command + 'ALTER INDEX ALL ON ['+@ls_TableName+'] REBUILD '
  end
  --
  exec (@ls_Command)
  --
  fetch lo_Cursor into @ls_TableName
end
close lo_Cursor
deallocate lo_Cursor
/* Rebuild Index for all table --end-- */


/*清除交易紀錄*/
BACKUP LOG CienveAccount WITH TRUNCATE_ONLY
/*檢視資料庫檔案大小*/
exec SP_HELPDB 'CienveAccount';
/*重整資料庫檔案*/
Use CienveAccount
DBCC SHRINKFILE   ( CienveAccount_log , TRUNCATEONLY )
/*再次檢查資料庫檔案大小*/ 
exec SP_HELPDB 'CienveAccount';


-- 開啟 xp_cmdshell
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;

-- 關閉 xp_cmdshell
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;


--設置資料庫為SINGLE_USER模式, 避免其他使用者使用
ALTER DATABASE DBNAME SET SINGLE_USER WITH ROLLBACK IMMEDIATE

--設定資料庫允許SNAPSHOT TRANSACTION
ALTER DATABASE DBNAME SET ALLOW_SNAPSHOT_ISOLATION ON
ALTER DATABASE DBNAME SET READ_COMMITTED_SNAPSHOT ON

--設置資料庫為MULTI_USER模式
ALTER DATABASE DBNAME SET MULTI_USER

/* Disk usage of tables --begin-- */
set nocount on
create table #spaceused (
  name nvarchar(120),
  rows int,
  reserved varchar(18),
  data varchar(18),
  index_size varchar(18),
  unused varchar(18)
)

declare Tables cursor for
  select name
  from sysobjects where type='U'
  order by name asc

OPEN Tables
DECLARE @table varchar(128)

FETCH NEXT FROM Tables INTO @table

WHILE @@FETCH_STATUS = 0
BEGIN
  insert into #spaceused exec sp_spaceused @table
  FETCH NEXT FROM Tables INTO @table
END

CLOSE Tables
DEALLOCATE Tables 

select * from #spaceused order by rows desc
drop table #spaceused

exec sp_spaceused
/* Disk usage of tables --end-- */

--查詢資料庫狀態
select name,user_access,user_access_desc,
	snapshot_isolation_state,snapshot_isolation_state_desc,
	is_read_committed_snapshot_on
from sys.databases

--目前各資料庫連線數
SELECT 
DB_NAME(dbid) as DBName, 
COUNT(dbid) as NumberOfConnections,
loginame as LoginName
FROM sys.sysprocesses
WHERE dbid > 0
GROUP BY dbid, loginame

--資料庫CPU Pressure
SELECT scheduler_id,
       cpu_id,
       current_tasks_count,
       runnable_tasks_count,
       current_workers_count,
       active_workers_count,
       work_queue_count
FROM   sys.dm_os_schedulers
WHERE  scheduler_id < 255;

--更改db owner (非加入db_owner群組中)
EXEC sp_changedbowner 'sa';

--重新設定使用者權限
use HappyRecome;
GO
IF  EXISTS (SELECT * FROM sys.database_principals WHERE name = N'HRAPI')
  DROP USER [HRAPI]
IF  EXISTS (SELECT * FROM sys.database_principals WHERE name = N'HRERP')
  DROP USER [HRERP]
IF  EXISTS (SELECT * FROM sys.database_principals WHERE name = N'ActWeisKernel')
  DROP USER [ActWeisKernel]
GO
CREATE USER [HRAPI] FROM LOGIN [HRAPI];
CREATE USER [HRERP] FROM LOGIN [HRERP];
GO
ALTER ROLE [db_datareader] ADD MEMBER [HRAPI]
ALTER ROLE [db_owner] ADD MEMBER [HRERP]
GO


* OPENROWSET configuration
USE [master]
GO
EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0' , N'AllowInProcess' , 1
GO
EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0' , N'DynamicParameters' , 1
GO


EXEC sp_configure 'show advanced options', 1 
GO 
RECONFIGURE 
GO 
EXEC sp_configure 'Ad Hoc Distributed Queries', 1 
GO 
RECONFIGURE


-- Check the size of tables in SYSTEM DB
SELECT sc.name + '.' + t.NAME AS TableName,
       p.[Rows],
       ( SUM(a.total_pages) * 8 ) / 1024 AS TotalReservedSpaceMB,
       ( SUM(a.used_pages) * 8 ) / 1024 AS UsedDataSpaceMB,
       ( SUM(a.data_pages) * 8 ) / 1024 AS FreeUnusedSpaceMB
FROM msdb.sys.tables t
       INNER JOIN msdb.sys.schemas sc ON sc.schema_id = t.schema_id
       INNER JOIN msdb.sys.indexes i ON t.OBJECT_ID = i.object_id
       INNER JOIN msdb.sys.partitions p ON i.object_id = p.OBJECT_ID
                  AND i.index_id = p.index_id
       INNER JOIN msdb.sys.allocation_units a ON p.partition_id = a.container_id
WHERE t.type_desc = 'USER_TABLE'
      AND i.index_id <= 1  --- Heap\ CLUSTERED
GROUP BY sc.name + '.' + t.NAME,
      i.[object_id],i.index_id, i.name, p.[Rows]
ORDER BY ( SUM(a.total_pages) * 8 ) / 1024 DESC


BACKUP DATABASE GICDB TO DISK = N'D:\DB_Backup\GICDB.bak' WITH  INIT ,  NOUNLOAD ,  NAME = N'DB backup',  NOSKIP ,  STATS = 10,  NOFORMAT

-- CTE
; with cte as (
  select convert(datetime,'20200728') [Date]
  union all
  select [Date] + 1 from cte where [Date] < '20200801'
)
select * from cte
OPTION(MAXRECURSION 0) -- 0: no limit

-- update all view with new column
EXEC sp_RefreshView


/*
MSSQL DB 擴充事件
1. Error_Report 建議Error_Level 10以上的收錄
2. block: 要先設定sp_config 'block .. threshold (s)'
3. xml_dead_lock
*/
