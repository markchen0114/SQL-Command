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
