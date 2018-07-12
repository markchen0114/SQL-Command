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
