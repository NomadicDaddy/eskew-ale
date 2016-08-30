use [msdb] ;
go

set nocount, quoted_identifier, ansi_nulls on ;

declare
	@operator nvarchar(128)				= N'DBA',
	@production bit						= 1,											-- alert on t-sql syntax errors, invalid users, pk violations (production/qa/uat environments only)
	@delay smallint						= 180,											-- seconds between alerts (180 = 3 minutes)
	@delaySpace int						= 86400,										-- seconds between drive space alerts (86400 = 1 day)
	@percFree tinyint					= 5,											-- alert if drive space falls below x%
	@cpuAlarm tinyint					= 95,											-- alert if CPU sustains > x% for @delay seconds
	@alertedErrors varchar(4096)		= '165,262,825,15113,15281,32042',				-- list of specific errors to alert on
	@alertedSeverities varchar(4096)	= '11,13,14,17,18,19,20,21,22,23,24',			-- severity levels to alert on (25 is not optional)
	@enterpriseErrors varchar(64)		= ',855,856',									-- alerts available on enterprise/dev editions only
	@nonentErrors varchar(64)			= ',832',										-- alternative events for non-enterprise/dev editions
	@prodErrors varchar(64)				= ',916,2627',									-- errors only in prod
	@prodSeverities varchar(64)			= ',15' ;										-- severities only in prod

if (ServerProperty('EngineEdition') = 3)
	set @alertedErrors = @alertedErrors + @enterpriseErrors
else
	set @alertedErrors = @alertedErrors + @nonentErrors ;

if (@production = 1)
begin
	set @alertedErrors = @alertedErrors + @prodErrors ;
	set @alertedSeverities = @alertedSeverities + @prodSeverities ;
end

--declare @msglang int ; select @msglang = [msglangid] from sys.syslanguages where [langid] = @@langid ;
--exec('select * from sys.messages where [language_id] = ' + @msglang + ' and [message_id] in (' + @alertedErrors + ') order by [message_id] asc ;') ;

-------------------------------------------------------------------------------
-- SPECIFIC SQL SERVER ERROR ALERTS
-------------------------------------------------------------------------------
-- #   165: Privilege %ls may not be granted or revoked.
-- #   262: %ls permission denied in database '%.*ls'.
-- #   825: Read retry failed twice. Run DBCC to check for corruption.
-- #   832: Page changed. Possible memory or hardware corruption/failure.
-- #   855: Uncorrectable hardware memory corruption detected.
-- #   856: Detected hardware memory corruption, but recovered the page.
-- #   916: User not valid in database.
-- #  2627: Violation of PRIMARY KEY constraint '%ls'. Cannot insert duplicate key in object '%.*ls'.
-- # 15113: Too many failed login attempts. This account has been temporarily locked as a precaution against password guessing. A system administrator can unlock this login with the UNLOCK clause of ALTER LOGIN.
-- # 15281: SQL Server blocked access to %S_MSG '%ls' of component '%.*ls' because this component is turned off as part of the security configuration for this server. A system administrator can enable the use of '%.*ls' by using sp_configure. For more information about enabling '%.*ls', see "Surface Area Configuration" in SQL Server Books Online.
-- # 32042: The alert for 'unsent log' has been raised. The current value of '%d' surpasses the threshold '%d'.

-------------------------------------------------------------------------------
-- SQL SERVER SEVERITY LEVEL ALERTS
-------------------------------------------------------------------------------
-- # 11: Indicates that the given object or entity does not exist.
-- # 13: Indicates transaction deadlock errors.
-- # 14: Indicates security-related errors, such as permission denied.
-- # 15: Indicates a T-SQL syntax error.
-- # 17: Indicates that the statement caused SQL Server to run out of resources (such as memory, locks, or disk space for the database) or to exceed some limit set by the system administrator.
-- # 18: Indicates a problem in the Database Engine software, but the statement completes execution, and the connection to the instance of the Database Engine is maintained. The system administrator should be informed every time a message with a severity level of 18 occurs.
-- # 19: Indicates that a nonconfigurable Database Engine limit has been exceeded and the current batch process has been terminated. Error messages with a severity level of 19 or higher stop the execution of the current batch. Severity level 19 errors are rare and must be corrected by the system administrator or your primary support provider. Contact your system administrator when a message with a severity level 19 is raised. Error messages with a severity level from 19 through 25 are written to the error log.
-- # 20: Indicates that a statement has encountered a problem. Because the problem has affected only the current task, it is unlikely that the database itself has been damaged.
-- # 21: Indicates that a problem has been encountered that affects all tasks in the current database, but it is unlikely that the database itself has been damaged.
-- # 22: Indicates that the table or index specified in the message has been damaged by a software or hardware problem. Severity level 22 errors occur rarely. If one occurs, run DBCC CHECKDB to determine whether other objects in the database are also damaged. The problem might be in the buffer cache only and not on the disk itself. If so, restarting the instance of the Database Engine corrects the problem. To continue working, you must reconnect to the instance of the Database Engine; otherwise, use DBCC to repair the problem. In some cases, you may have to restore the database. If restarting the instance of the Database Engine does not correct the problem, then the problem is on the disk. Sometimes destroying the object specified in the error message can solve the problem. For example, if the message reports that the instance of the Database Engine has found a row with a length of 0 in a nonclustered index, delete the index and rebuild it. 
-- # 23: Indicates that the integrity of the entire database is in question because of a hardware or software problem. Severity level 23 errors occur rarely. If one occurs, run DBCC CHECKDB to determine the extent of the damage. The problem might be in the cache only and not on the disk itself. If so, restarting the instance of the Database Engine corrects the problem. To continue working, you must reconnect to the instance of the Database Engine; otherwise, use DBCC to repair the problem. In some cases, you may have to restore the database.
-- # 24: Indicates a media failure. The system administrator may have to restore the database. You may also have to call your hardware vendor.
-- # 25: Indicates an internal fatal error.

-------------------------------------------------------------------------------
-- WMI-BASED ALERTS
-------------------------------------------------------------------------------
-- DB Mirroring State Change		: when a mirroring event occurs
-- CPU Usage (SQL Server >95%)		: when SQL Server CPU usage exceeds 95%
-- Drive Space (<5% free)			: when drive space falls below 5%

-------------------------------------------------------------------------------
-- PERFMON-BASED ALERTS
-------------------------------------------------------------------------------
-- Blocked Processes (>1)			: when there is more than one blocked process
-- Buffer Cache Hit Ratio (<95%)*	: when memory pressure is high causing disk i/o
-- Batch Requests (>500/sec)*		: needed for comparison to Compilations
-- Compilations (>50/sec)*			: when > 10% of Batch Requests/sec
-- Re-Compilations (>5/sec)*		: when > 10% of Compilations/sec
-- Deadlocks (>1)					: when there is more than one deadlocked process
-- Lock Waits (>1)					: when not able to attain resource locks
-- Failed Auto-Params (>10/sec)*	: when forced to convert non-param'd to param'd
-- Log Cache Hit Ratio (<33%)^		: when cached/logical reads dips below 33%
-- Network I/O Waits (>10)			: when waiting for large data transfers
-- Page I/O Latch Waits (>18)		: when there are excessive i/o subsystem waits

-- * denoted alerts that aren't that helpful in reality but ymmv
-- ^ these are created but initially disabled

set @alertedErrors = Replace(@alertedErrors, ',', ''',''') ;
set @alertedSeverities = Replace(@alertedSeverities, ',', ''',''') ;

declare
	@alertMsg nvarchar(1024),
	@alertName nvarchar(128),
	@wmiq nvarchar(1024),
	@curAlert int ;

-- close and deallocate cursor if it exists
if (cursor_status('global', 'alertCursor') <> -3)
begin
	if (cursor_status('global', 'alertCursor') <> -1)
		close alertCursor ;
	deallocate alertCursor ;
end

-- create list of errors
exec ('
declare alertCursor cursor fast_forward for
select distinct [error] from master..sysmessages where [error] in (''' + @alertedErrors + ''') order by [error] asc ;
') ;
open alertCursor ;
fetch next from alertCursor into @curAlert ;

-- create alert loop
while @@fetch_status = 0
begin

	set @alertName = N'SQL: Error #' + Convert(nvarchar, @curAlert) ;

	exec msdb.dbo.sp_add_alert
		@name = @alertName,
		@message_id = @curAlert,
		@enabled = 1,
		@delay_between_responses = @delay,
		@include_event_description_in = 1 ;

	exec msdb.dbo.sp_add_notification
		@alert_name = @alertName,
		@operator_name = @operator,
		@notification_method = 1 ;

	-- get next alert
	fetch next from alertCursor into @curAlert ;
end

-- close and deallocate cursor
close alertCursor ;
deallocate alertCursor ;

-- create list of severities
exec ('
declare alertCursor cursor fast_forward for
select distinct [severity] from master..sysmessages where [severity] in (''' + @alertedSeverities + ''') union select [severity] = 25 order by [severity] asc ;
') ;
open alertCursor ;
fetch next from alertCursor into @curAlert ;

-- create alert loop
while @@fetch_status = 0
begin

	set @alertName = N'SQL: Severity #' + Convert(nvarchar, @curAlert) ;

	exec msdb.dbo.sp_add_alert
		@name = @alertName,
		@severity = @curAlert,
		@enabled = 1,
		@delay_between_responses = @delay,
		@include_event_description_in = 1 ;

	exec msdb.dbo.sp_add_notification
		@alert_name = @alertName,
		@operator_name = @operator,
		@notification_method = 1 ;

	-- get next alert
	fetch next from alertCursor into @curAlert ;
end

-- close and deallocate cursor
close alertCursor ;
deallocate alertCursor ;

-- create list of errors
exec ('
declare alertCursor cursor fast_forward for
select
	[error]
from
	sys.sysmessages
where
	[severity] < 19
	and [dlevel] < 128
	and (
		[error] in (''' + @alertedErrors + ''')
		or [severity] in (''' + @alertedSeverities + ''')
	)
order by
	[dlevel] desc,
	[error] asc,
	[severity] asc ;
') ;
open alertCursor ;
fetch next from alertCursor into @curAlert ;

-- create alert loop
while @@fetch_status = 0
begin

	-- setting alert logging to true
	exec msdb.dbo.sp_altermessage @curAlert, 'WITH_LOG', 'true' ;

	-- get next alert
	fetch next from alertCursor into @curAlert ;
end

-- close and deallocate cursor
close alertCursor ;
deallocate alertCursor ;

-- update alert names to be more descriptive at a glance
exec msdb.dbo.sp_update_alert @name = N'SQL: Error #165',   @new_name = N'SQL: Error #165 - Privilege Revoked or Not Granted' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Error #262',   @new_name = N'SQL: Error #262 - Permission Denied in Database' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Error #825',   @new_name = N'SQL: Error #825 - Read Retry Failed' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Error #832',   @new_name = N'SQL: Error #832 - Page Changed (Mem/HW Corruption)' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Error #855',   @new_name = N'SQL: Error #855 - Uncorrectable Mem/HW Corruption' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Error #856',   @new_name = N'SQL: Error #856 - Corrected Mem/HW Corruption' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Error #916',   @new_name = N'SQL: Error #916 - User Not Valid in Database' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Error #2627',  @new_name = N'SQL: Error #2627 - Primary Key Violation' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Error #15113', @new_name = N'SQL: Error #15113 - Too Many Failed Login Attempts' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Error #15281', @new_name = N'SQL: Error #15281 - Blocked Access to Component' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Error #32042', @new_name = N'SQL: Error #32042 - Unsent Transaction Logs' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Severity #11', @new_name = N'SQL: Severity #11 - Specified Database Object Not Found' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Severity #13', @new_name = N'SQL: Severity #13 - User Transaction Syntax Error' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Severity #14', @new_name = N'SQL: Severity #14 - Insufficient Permission' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Severity #15', @new_name = N'SQL: Severity #15 - T-SQL Syntax Error' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Severity #17', @new_name = N'SQL: Severity #17 - Insufficient Resources' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Severity #18', @new_name = N'SQL: Severity #18 - Nonfatal Internal Error' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Severity #19', @new_name = N'SQL: Severity #19 - Fatal Error in Resource' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Severity #20', @new_name = N'SQL: Severity #20 - Fatal Error in Current Process' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Severity #21', @new_name = N'SQL: Severity #21 - Fatal Error in Database Processes' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Severity #22', @new_name = N'SQL: Severity #22 - Fatal Error: Table Intergrity Suspect' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Severity #23', @new_name = N'SQL: Severity #23 - Fatal Error: Database Intergrity Suspect' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Severity #24', @new_name = N'SQL: Severity #24 - Fatal Error: Hardware Error' ;
exec msdb.dbo.sp_update_alert @name = N'SQL: Severity #25', @new_name = N'SQL: Severity #25 - Fatal Error: Internal' ;

-- wmi

set @alertMsg = null ;
set @wmiq = N'select * from DATABASE_MIRRORING_STATE_CHANGE where State = 5' ;
exec msdb.dbo.[sp_add_alert]
	@name = N'WMI: DB Mirroring State Change',
	@enabled = 1,
	@delay_between_responses = @delay,
	@include_event_description_in = 1,
	@notification_message = @alertMsg,
	@wmi_namespace = N'\\.\root\Microsoft\SqlServer\ServerEvents\MSSQLSERVER',
	@wmi_query = @wmiq ;
exec msdb.dbo.[sp_add_notification] @alert_name = N'WMI: DB Mirroring State Change', @operator_name = @operator, @notification_method = 1 ;

set @alertMsg = N'WMI: CPU Usage (SQL) >' + Convert(nvarchar(8), @cpuAlarm) + '%' ;
set @wmiq = N'select * from __instanceModificationEvent within ' + Convert(nvarchar(8), @delay) + N' where TargetInstance ISA ''Win32_PerfFormattedData_PerfProc_Process'' and TargetInstance.Name = ''sqlservr'' and TargetInstance.PercentProcessorTime > ' + Convert(nvarchar(8), @cpuAlarm) ;
exec msdb.dbo.[sp_add_alert]
	@name = @alertMsg,
	@enabled = 1,
	@delay_between_responses = @delay,
	@include_event_description_in = 1,
	@notification_message = @alertMsg,
	@wmi_namespace = N'\\.\root\cimv2',
	@wmi_query = @wmiq ;
exec msdb.dbo.[sp_add_notification] @alert_name = @alertMsg, @operator_name = @operator, @notification_method = 1 ;

declare
	@drive varchar(2),
	@threshold bigint,
	@wmi_name nvarchar(128),
	@wmi nvarchar(2048) ;

declare	@dSpace table ([d] nvarchar(128)) ;
insert into @dSpace exec xp_cmdshell 'powershell.exe "Get-WMIObject Win32_LogicalDisk -filter "DriveType=3"| Format-Table DeviceID, Size, FreeSpace"' ;
delete from @dSpace where [d] is null or [d] like '%FreeSpace%' or [d] like '--------%' ;
update @dSpace set [d] = Replace([d], ' ', ',') ;

-- create list of drives
declare alertCursor cursor fast_forward for
with [dSpace] as (
	select
		[Drive] = SubString([d], 1, 2),
		[Size] = IIf(IsNumeric(Replace((Left((SubString([d], (PatIndex('%[0-9]%', [d])), Len([d]))), CharIndex(',', (SubString([d], (PatIndex('%[0-9]%', [d])), Len([d])))) - 1)), ',', '')) = 1, Cast(Replace((Left((SubString([d], (PatIndex('%[0-9]%', [d])), Len([d]))), CharIndex(',', (SubString([d], (PatIndex('%[0-9]%', [d])), Len([d])))) - 1)), ',', '') as bigint), 0)
	from
		@dSpace
)
select
	[Drive],
	[Threshold] = [Size] / 100 * @percFree
from
	[dSpace]
where
	[Size] > 0 ;
open alertCursor ;
fetch next from alertCursor into @drive, @threshold ;

-- create alert loop
while @@fetch_status = 0
begin

	set @wmi_name = N'WMI: Drive Space (' + @drive + N')' ;
	set @alertMsg = N'Disk space on ' + @drive + N' has fallen below ' + Convert(nvarchar(8), @percFree) + N'% on ' + Convert(nvarchar(128), serverproperty('servername')) ;
	set @wmi = N'select * from __InstanceModificationEvent within ' + Convert(nvarchar(8), @delaySpace) + N' where TargetInstance ISA ''Win32_LogicalDisk'' and TargetInstance.FreeSpace < ' + Convert(nvarchar(32), @threshold) + N' and TargetInstance.Name = ' + QuoteName(@drive, '''') ;

	-- create alert based on percentage of total drive space
	exec msdb.dbo.[sp_add_alert]
		@name = @wmi_name,
		@enabled = 1,
		@delay_between_responses = @delay,
		@include_event_description_in = 1,
		@notification_message = @alertMsg,
		@wmi_namespace = N'\\.\root\cimv2',
		@wmi_query = @wmi ;
	exec msdb.dbo.[sp_add_notification] @alert_name = @wmi_name, @operator_name = @operator, @notification_method = 1 ;

	-- get next drive
	fetch next from alertCursor into @drive, @threshold ;
end

-- close and deallocate cursor
close alertCursor ;
deallocate alertCursor ;

-- perfmon

exec msdb.dbo.[sp_add_alert] @enabled = 1, @delay_between_responses = @delay, @include_event_description_in = 1,
	@name = N'PM: Blocked Processes', @performance_condition = N'SQLServer:General Statistics|Processes Blocked||>|1' ;
exec msdb.dbo.[sp_add_notification] @alert_name = N'PM: Blocked Processes', @operator_name = @operator, @notification_method = 1 ;

exec msdb.dbo.[sp_add_alert] @enabled = 1, @delay_between_responses = @delay, @include_event_description_in = 1,
	@name = N'PM: Buffer Cache Hit Ratio', @performance_condition = N'SQLServer:Buffer Manager|Buffer Cache Hit Ratio||<|0.95' ;
exec msdb.dbo.[sp_add_notification] @alert_name = N'PM: Buffer Cache Hit Ratio', @operator_name = @operator, @notification_method = 1 ;

exec msdb.dbo.[sp_add_alert] @enabled = 1, @delay_between_responses = @delay, @include_event_description_in = 1,
	@name = N'PM: Batch Requests', @performance_condition = N'SQLServer:SQL Statistics|Batch Requests/sec||>|500' ;
exec msdb.dbo.[sp_add_notification] @alert_name = N'PM: Batch Requests', @operator_name = @operator, @notification_method = 1 ;

exec msdb.dbo.[sp_add_alert] @enabled = 1, @delay_between_responses = @delay, @include_event_description_in = 1,
	@name = N'PM: Compilations', @performance_condition = N'SQLServer:SQL Statistics|SQL Compilations/sec||>|50' ;
exec msdb.dbo.[sp_add_notification] @alert_name = N'PM: Compilations', @operator_name = @operator, @notification_method = 1 ;

exec msdb.dbo.[sp_add_alert] @enabled = 1, @delay_between_responses = @delay, @include_event_description_in = 1,
	@name = N'PM: Re-Compilations', @performance_condition = N'SQLServer:SQL Statistics|SQL Re-Compilations/sec||>|5' ;
exec msdb.dbo.[sp_add_notification] @alert_name = N'PM: Re-Compilations', @operator_name = @operator, @notification_method = 1 ;

exec msdb.dbo.[sp_add_alert] @enabled = 1, @delay_between_responses = @delay, @include_event_description_in = 1,
	@name = N'PM: Deadlocks', @performance_condition = N'SQLServer:Locks|Number of Deadlocks/sec|Database|>|1' ;
exec msdb.dbo.[sp_add_notification] @alert_name = N'PM: Deadlocks', @operator_name = @operator, @notification_method = 1 ;

exec msdb.dbo.[sp_add_alert] @enabled = 1, @delay_between_responses = @delay, @include_event_description_in = 1,
	@name = N'PM: Lock Waits', @performance_condition = N'SQLServer:Locks|Lock Waits/sec|_Total|>|1' ;
exec msdb.dbo.[sp_add_notification] @alert_name = N'PM: Lock Waits', @operator_name = @operator, @notification_method = 1 ;

exec msdb.dbo.[sp_add_alert] @enabled = 1, @delay_between_responses = @delay, @include_event_description_in = 1,
	@name = N'PM: Failed Auto-Params', @performance_condition = N'SQLServer:SQL Statistics|Failed Auto-Params/sec||>|10' ;
exec msdb.dbo.[sp_add_notification] @alert_name = N'PM: Failed Auto-Params', @operator_name = @operator, @notification_method = 1 ;

exec msdb.dbo.[sp_add_alert] @enabled = 0, @delay_between_responses = @delay, @include_event_description_in = 1,
	@name = N'PM: Log Cache Hit Ratio', @performance_condition = N'SQLServer:Databases|Log Cache Hit Ratio|_Total|<|0.33' ;
exec msdb.dbo.[sp_add_notification] @alert_name = N'PM: Log Cache Hit Ratio', @operator_name = @operator, @notification_method = 1 ;

exec msdb.dbo.[sp_add_alert] @enabled = 1, @delay_between_responses = @delay, @include_event_description_in = 1,
	@name = N'PM: Network I/O Waits', @performance_condition = N'SQLServer:Wait Statistics|Network IO waits|Waits in progress|>|10' ;
exec msdb.dbo.[sp_add_notification] @alert_name = N'PM: Network I/O Waits', @operator_name = @operator, @notification_method = 1 ;

exec msdb.dbo.[sp_add_alert] @enabled = 1, @delay_between_responses = @delay, @include_event_description_in = 1,
	@name = N'PM: Page I/O Latch Waits', @performance_condition = N'SQLServer:Wait Statistics|Page IO latch waits|Waits in progress|>|18' ;
exec msdb.dbo.[sp_add_notification] @alert_name = N'PM: Page I/O Latch Waits', @operator_name = @operator, @notification_method = 1 ;

-- these should be environment tuned and based on analysis
--	@name = N'PM: Batch Requests', @performance_condition = N'SQLServer:SQL Statistics|Batch Requests/Sec||>|???' ;
--	@name = N'PM: Latch Waits', @performance_condition = N'SQLServer:Latches|Latch Waits/sec||>|???' ;
--	@name = N'PM: Transactions', @performance_condition = N'SQLServer:General Statistics|Transactions||>|???' ;
--	@name = N'PM: User Connections', @performance_condition = N'SQLServer:General Statistics|User Connections||>|???' ;
--	@name = N'PM: User Errors', @performance_condition = N'SQLServer:SQL Errors|Errors/sec|User Errors|>|10' ;
-- select * from sys.dm_os_performance_counters order by [object_name] asc, [instance_name] asc, [counter_name] asc ;
-- exec msdb.dbo.sp_sqlagent_get_perf_counters ;
