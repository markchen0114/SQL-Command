
-- 查看audit file
SELECT TOP 100 
    event_time,
    action_id,
    succeeded,
    session_server_principal_name AS [登入帳號],
    client_ip AS [來源IP],
    application_name AS [應用程式名稱],
    additional_information AS [詳細錯誤訊息]
FROM sys.fn_get_audit_file ('F:\TC\logs\audit\*.sqlaudit', DEFAULT, DEFAULT)
ORDER BY event_time DESC;

-- 將該步驟的伺服器連線目標，明確指定為本機共用記憶體 (lpc: 代表 Local Procedure Call)
USE [msdb];
GO
EXEC dbo.sp_update_jobstep 
    @job_name = N'_MTN_GetLongBatchLog', 
    @step_id = 1, 
    @server = N'lpc:(local)';
GO
