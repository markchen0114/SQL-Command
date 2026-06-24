-- 記錄超過10秒的SQL執行命令
declare	@AtnCheck bit = 0;

--建立MTN執行記錄
if  object_id('msdb.dbo.tmp_MtnLog', 'U') is null
begin
	create table msdb.dbo.tmp_MtnLog
	(
		record_id	  bigint identity (1, 1) primary key not null
	   ,MtnTime		  datetime
	   ,MtnType		  varchar(50)
	   ,MtnVersion	  varchar(10)
	   ,database_name nvarchar(128)
	   ,MtnStart	  datetime
	   ,MtnFinish	  datetime
	   ,Status		  varchar(10)
	   ,MsgText		  nvarchar(max)
	)
end
;

declare	@lastVersion varchar(10) = null;

select top 1
	@lastVersion = MtnVersion
from msdb.dbo.tmp_MtnLog
where	MtnType = 'MTN_GetLongBatchLog'
order byrecord_id desc
;
if  @lastVersion = 'V1.2'
begin
	alter table dbo.tbLongBatchLog add rn tinyint not null constraint DF_tbLongBatchLog_rn default 1
	;
	drop index UIX_tbLongBatchLog on dbo.tbLongBatchLog
	;
	create unique nonclustered index UIX_tbLongBatchLog on dbo.tbLongBatchLog
	(
		StartTime,
		SessionID,
		ObjectName,
		rn
	) with (statistics_norecompute = off, ignore_dup_key = on, allow_row_locks = on, allow_page_locks = on) on [PRIMARY]
	;
end
;
go
;
declare
	@MtnType varchar(50) = 'MTN_GetLongBatchLog'
   ,@MtnVersion varchar(10) = 'V1.4'
   ,@MtnTime datetime = getdate()
   ,@Status varchar(10) = ''
   ,@MessageText nvarchar(max) = ''
   ,@DbName sysname = 'msdb'
   ,@LongBatchLogRetentionDays int = -35 --保留35天執行超時記錄
;
declare
	@DeleteDataDate datetime = dateadd(day, -7, convert(date, @MtnTime)) --保留7天MTN執行記錄
   ,@Overtime datetime = dateadd(second, -10, @MtnTime) --定義執行超時時間
;
set nocount on

;
--Insert INIT Data
insert into msdb.dbo.tmp_MtnLog
(
	MtnTime
   ,MtnType
   ,MtnVersion
   ,database_name
   ,MtnStart
   ,MtnFinish
   ,Status
   ,MsgText
)
values
(
	@MtnTime
   ,@MtnType
   ,@MtnVersion
   ,@DbName
   ,getdate()
   ,null
   ,'Unknow'
   ,'Unknow'
)
;
if  object_id('msdb.dbo.tbLongBatchLog_debug', 'U') is null
begin
	create table msdb.dbo.tbLongBatchLog_debug
	(
		pk				bigint		  identity (1, 1) not null
	   ,ObjectName		varchar(50)	  null
	   ,InstanceName	nvarchar(400) null
	   ,SessionID		smallint	  not null
	   ,UserName		nvarchar(400) null
	   ,LoginTime		datetime	  null
	   ,StartTime		datetime	  not null
	   ,Duration_Second int			  null
	   ,SessionStatus   nvarchar(400) null
	   ,ClientHostName  nvarchar(400) null
	   ,ClientPid		int			  null
	   ,ClientApp		nvarchar(400) null
	   ,OtherInfo		nvarchar(440) null
	   ,SqlData			xml			  null
	   ,rn				tinyint		  not null constraint DF_tbLongBatchLog_debug_rn default 1
	   ,constraint PK_tbLongBatchLog_debug primary key clustered
		(
		pk asc
		) on [PRIMARY]
	)
	on [PRIMARY]
end
;
if  object_id('msdb.dbo.tbLongBatchLog', 'U') is null
begin
	create table msdb.dbo.tbLongBatchLog
	(
		pk				bigint		  identity (1, 1) not null
	   ,ObjectName		varchar(50)	  null
	   ,InstanceName	nvarchar(400) null
	   ,SessionID		smallint	  not null
	   ,UserName		nvarchar(400) null
	   ,LoginTime		datetime	  null
	   ,StartTime		datetime	  not null
	   ,Duration_Second int			  null
	   ,SessionStatus   nvarchar(400) null
	   ,ClientHostName  nvarchar(400) null
	   ,ClientPid		int			  null
	   ,ClientApp		nvarchar(400) null
	   ,OtherInfo		nvarchar(440) null
	   ,SqlData			xml			  null
	   ,rn				tinyint		  not null constraint DF_tbLongBatchLog_rn default 1
	   ,constraint PK_tbLongBatchLog primary key clustered
		(
		pk asc
		) on [PRIMARY]
	)
	on [PRIMARY]
end
;
if  not exists (select * from sys.indexes where name = 'UIX_tbLongBatchLog')
begin
	create unique nonclustered index UIX_tbLongBatchLog on msdb.dbo.tbLongBatchLog
	(
		StartTime,
		SessionID,
		ObjectName,
		rn
	) with (statistics_norecompute = off, ignore_dup_key = on, allow_row_locks = on, allow_page_locks = on) on [PRIMARY]
end
;
--刪除35天前記錄
delete from msdb.dbo.tbLongBatchLog where StartTime < dateadd(day, @LongBatchLogRetentionDays, convert(date, @MtnTime))
delete from msdb.dbo.tbLongBatchLog_debug where StartTime < dateadd(day, @LongBatchLogRetentionDays, convert(date, @MtnTime))
;
drop table if exists #t
;
with v1 as
(
	--取出超時且無開啟交易的查詢資訊
	select
		'LongQuery' as ObjectName
	   ,@@servername as InstanceName
	   ,r.session_id as SessionID
	   ,rtrim(s.login_name) as UserName
	   ,s.login_time as LoginTime
	   ,r.start_time as StartTime
	   ,datediff(second, r.start_time, getdate()) as Duration_Second
	   ,rtrim(r.Status) as SessionStatus
	   ,isnull(rtrim(s.host_name), '-') as ClientHostName
	   ,isnull(s.host_process_id, 0) as ClientPid
	   ,isnull(rtrim(s.program_name), '-') as ClientApp
	   ,convert(nvarchar(440), isnull((
			select
				rtrim(r.last_wait_type) as LastWaitType
			   ,r.cpu_time as CpuTime
			   ,r.reads
			   ,r.writes
			   ,r.Row_Count as Row_Count
			   ,isnull(db_name(r.database_id), '-') as DbName
			for xml raw ('obj'), root ('objs'), elements
		), '')) as OtherInfo
	   ,convert(xml, isnull((select q.text as SqlText for xml raw ('obj'), root ('objs'), elements), '')) as SqlData
	--,q.text as SqlText
	from sys.dm_exec_requests r
	left join sys.dm_exec_sessions s on
		r.session_id = s.session_id
	cross apply sys.dm_exec_sql_text(sql_handle) q
	where
		r.start_time < @Overtime
		and
		r.session_id <> @@spid
		and
		r.open_transaction_count = 0
		and
		db_name(r.database_id) <> 'distribution'
		and
		left(q.text, 21) <> 'sp_server_diagnostics'
		and
		left(s.program_name, 23) <> 'SQLAgent - TSQL JobStep'
		and
		left(s.program_name, 14) <> 'Repl-LogReader'
),
v2 as
(
	--取出超時交易的資訊
	select
		'LongTransaction' as ObjectName
	   ,@@servername as InstanceName
	   ,DES.session_id as SessionID
	   ,DES.login_name as UserName
	   ,DES.login_time as LoginTime
	   ,DTAT.transaction_begin_time as StartTime
	   ,datediff(second, DTAT.transaction_begin_time, getdate()) as Duration_Second
	   ,DES.Status as SessionStatus
	   ,isnull(rtrim(DES.host_name), '-') as ClientHostName
	   ,isnull(DES.host_process_id, 0) as ClientPid
	   ,isnull(DES.program_name, '-') as ClientApp
	   ,convert(nvarchar(440), isnull((
			select
				case DTAT.transaction_type when 1 then N'讀取/寫入交易' when 2 then N'唯讀交易' when 3 then N'系統交易' when 4 then N'分散式交易' end as TransactionType
			   ,case DTAT.transaction_state when 0 then N'交易尚未完全初始化' when 1 then N'交易已經初始化，但尚未啟動' when 2 then N'交易在作用中' when 3 then N'交易已經結束。它只用於唯讀交易' when 4 then N'認可處理序已經在分散式交易上起始。分散式交易在作用中，但無法再進一步處理' when 5 then N'交易是在已準備的狀態，正在等候解析。' when 6 then N'已認可交易' when 7 then N'正在回復交易' when 8 then N'已回復交易' end as TransactionState
			   ,isnull(db_name(DTDT.database_id), '-') as DbName
			for xml raw ('obj'), root ('objs'), elements
		), '')) as OtherInfo
	   ,convert(xml, isnull((
			select
				isnull(DEST.text, '-') as SqlText
			for xml raw ('obj'), root ('objs'), elements
		), '')) as SqlData
	--,ISNULL(DEST.text, '-') as SqlText
	from sys.dm_tran_database_transactions DTDT
	join sys.dm_tran_session_transactions DTST on
		DTST.transaction_id = DTDT.transaction_id
	join sys.dm_tran_active_transactions DTAT on
		DTST.transaction_id = DTAT.transaction_id
	join sys.dm_exec_sessions DES on
		DES.session_id = DTST.session_id
	join sys.dm_exec_connections DEC on
		DEC.session_id = DTST.session_id
	left join sys.dm_exec_requests DER on
		DER.session_id = DTST.session_id
	cross apply sys.dm_exec_sql_text(DEC.most_recent_sql_handle) as DEST
	outer apply sys.dm_exec_query_plan(DER.plan_handle) as DEQP
	where
		DTAT.transaction_begin_time < @Overtime
		and
		DTDT.database_transaction_begin_lsn is not null
		and
		left(DES.program_name, 23) <> 'SQLAgent - TSQL JobStep'
		and
		left(DES.program_name, 14) <> 'Repl-LogReader'
),
v3 as
(
	--取出超時的Cursor
	select
		'LongCursor' as ObjectName
	   ,@@servername as InstanceName
	   ,b.session_id as SessionID
	   ,b.login_name as UserName
	   ,b.login_time as LoginTime
	   ,a.creation_time as StartTime
	   ,datediff(second, a.creation_time, getdate()) as Duration_Second
	   ,b.Status as SessionStatus
	   ,isnull(rtrim(b.host_name), '-') as ClientHostName
	   ,isnull(b.host_process_id, 0) as ClientPid
	   ,isnull(rtrim(b.program_name), '-') as ClientApp
	   ,convert(nvarchar(440), isnull((
			select
				b.cpu_time as CpuTime
			   ,b.Reads as Reads
			   ,b.Writes as Writes
			for xml raw ('obj'), root ('objs'), elements
		), '')) as OtherInfo
	   ,convert(xml, isnull((
			select
				isnull(q.text, '-') as SqlText
			for xml raw ('obj'), root ('objs'), elements
		), '')) as SqlData
	--,ISNULL(q.text, '-') as SqlText
	from sys.dm_exec_cursors(0) a
	left join sys.dm_exec_sessions b on
		a.session_id = b.session_id
	cross apply sys.dm_exec_sql_text(a.sql_handle) q
	where
		a.creation_time < @Overtime
		and
		left(b.program_name, 23) <> 'SQLAgent - TSQL JobStep'
),
v4 as
(
	select
		*
	from v1
	union all
	select
		*
	from v2
	union all
	select
		*
	from v3
)
select
	*
   ,count(*) over (partition by StartTime, SessionID, ObjectName order by OtherInfo) as rn
into #t
from v4
;
insert into msdb.dbo.tbLongBatchLog_debug
(
	ObjectName
   ,InstanceName
   ,SessionID
   ,UserName
   ,LoginTime
   ,StartTime
   ,Duration_Second
   ,SessionStatus
   ,ClientHostName
   ,ClientPid
   ,ClientApp
   ,OtherInfo
   ,SqlData
   ,rn
)
select
	ObjectName
   ,InstanceName
   ,SessionID
   ,UserName
   ,LoginTime
   ,StartTime
   ,Duration_Second
   ,SessionStatus
   ,ClientHostName
   ,ClientPid
   ,ClientApp
   ,OtherInfo
   ,SqlData
   ,rn
from #t
where
	rn > 1
;
delete from #t where rn > 1
;
merge msdb.dbo.tbLongBatchLog as t using #t as s
on s.StartTime = t.StartTime
	and s.SessionID = t.SessionID
	and s.ObjectName = t.ObjectName
	and s.rn = t.rn
when matched
	then update
		set
			t.Duration_Second = s.Duration_Second
		   ,t.SessionStatus	  = s.SessionStatus
		   ,t.OtherInfo		  = s.OtherInfo
		   ,t.rn			  = s.rn
when not matched
	then insert
		(
			ObjectName
		   ,InstanceName
		   ,SessionID
		   ,UserName
		   ,LoginTime
		   ,StartTime
		   ,Duration_Second
		   ,SessionStatus
		   ,ClientHostName
		   ,ClientPid
		   ,ClientApp
		   ,OtherInfo
		   ,SqlData
		   ,rn
		)
		values
		(
			s.ObjectName
		   ,s.InstanceName
		   ,s.SessionID
		   ,s.UserName
		   ,s.LoginTime
		   ,s.StartTime
		   ,s.Duration_Second
		   ,s.SessionStatus
		   ,s.ClientHostName
		   ,s.ClientPid
		   ,s.ClientApp
		   ,s.OtherInfo
		   ,s.SqlData
		   ,s.rn
		)
;
update msdb.dbo.tmp_MtnLog
set
	MtnFinish = getdate()
   ,Status	  = 'Success'
   ,MsgText	  = ''
where
	MtnTime = @MtnTime
	and
	MtnType = @MtnType
	and
	database_name = @DbName
;
--Delete Old data
delete from msdb.dbo.tmp_MtnLog where MtnType = @MtnType
and MtnTime < @DeleteDataDate
;
--select top 5 * from msdb.dbo.tmp_MtnLog order by record_id desc;
--select top 20 * from msdb.dbo.tbLongBatchLog order by pk desc;
