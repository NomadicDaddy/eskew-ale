set quoted_identifier on ;
set ansi_nulls on ;
go

use [master] ;
go

if exists (select 1 from INFORMATION_SCHEMA.ROUTINES where [routine_schema] = 'dbo' and [routine_name] = 'sp_what')
	drop procedure dbo.[sp_what] ;
go

create procedure dbo.[sp_what] (
	@all bit = 0,
	@sleeping bit = 1,
	@sort varchar(6) = 'spid',
	@filter nvarchar(256) = null
)
as
begin

set nocount, xact_abort on ;

-----------------------------------------------------------------------------------------------------------------------
-- Procedure:	sp_what
-- Author:		Phillip Beazley (phillip@beazley.org)
-- Date:		04/19/2016
--
-- Purpose:		Provides a better view of what's currently running including blocks and waits.
--
-- Notes:		Sort options are: spid, hpid, login, host, db, ip, reads, waits, io, cpu, time.
--				Filter is usable for spid, hpid, login, host, db, and ip.
--
-- Depends:		Uses DMVs and is therefore 2005+ only.
--
-- REVISION HISTORY ---------------------------------------------------------------------------------------------------
-- 02/01/2013	lordbeazley	Release refresh.
-- 12/23/2013	lordbeazley	Corrected percentage done error.
--							Added login_time.
--							Changed system processing filtering.
-- 12/26/2013	lordbeazley	No longer dynamic.
-- 02/28/2014	lordbeazley	Sort by spid (default), login or host. #mobetta
-- 08/07/2015	lordbeazley	Added current database and physical i/o output.
--							Added db, ip, reads, io, waits sort options.
--							Added filtering (spid, login, host, db, ip). Ah yeeeeeah.
-- 08/17/2015	lordbeazley	Added option to show/hide sleeping tasks (all includes system tasks).
-- 08/18/2015	lordbeazley	Added sort by time option.
-- 08/20/2015	lordbeazley	Added filter and sort by hpid.
-- 04/19/2016	lordbeazley	Fixed datediff overflow for really old spids.
-----------------------------------------------------------------------------------------------------------------------

if (@filter is not null and @sort not in ('spid', 'hpid', 'login', 'host', 'db', 'ip')) set @filter = null ;

with [c] as (
	select [session_id], [net_transport], [auth_scheme], [client_net_address], [net_packet_size] from sys.dm_exec_connections
)
select
	[spid] = s.[session_id],
	[hpid] = s.[host_process_id],
	[blocker] =
		case
			when r.[session_id] = r.[blocking_session_id] then '='
			when r.[blocking_session_id] = 0 then null
			else r.[blocking_session_id]
		end,
	[hostname] = s.[host_name],
	[ip] = c.[client_net_address],
	[loginname] = s.[login_name],
	[db] = db_name(spx.[dbid]),
	[connected] = Convert(char(19), s.[login_time], 0),
	[batch_started] =
		case
			when s.[last_request_start_time] = '1900-01-01 00:00:00.000' then '--  starting up  --'
			else Convert(char(19), s.[last_request_start_time], 0)
		end,
	s.[status],
	[active] = case when s.[status] <> 'sleeping' then 1 else 0 end,
	[%] =
		case
			when r.[percent_complete] is null or Convert(varchar(5), Round(r.[percent_complete], 2)) = '0' then '--'
			else Convert(varchar(5), Round(r.[percent_complete], 2)) + '%'
		end,
	[duration] =
		case
			when DateDiff(s, s.[last_request_start_time], getdate()) = 0
			then Convert(varchar(32), DateAdd(ms, 0, 0), 114)
			when DateDiff(day, s.[last_request_start_time], getdate()) > 0
			then Convert(varchar(3), DateDiff(day, s.[last_request_start_time], getdate())) + 'd ' + Convert(varchar(32), DateAdd(ms, DateDiff(ms, s.[last_request_start_time], getdate() - DateDiff(day, s.[last_request_start_time], getdate())), 0), 114)
			else Convert(varchar(32), DateAdd(ms, DateDiff(ms, s.[last_request_start_time], getdate()), 0), 114)
		end,
	[cpu] = Convert(varchar(32), DateAdd(ms, spx.[cpu], 0), 114),
	[waiting] =
		case
			when r.[wait_type] is null then ''
			else Convert(varchar(32), DateAdd(ms, r.[wait_time], 0), 114)
		end,
	[waittype] = Coalesce(r.[wait_type], ''),
	spx.[waitresource],
	[tx] = Coalesce(r.[open_transaction_count], 0),
	[io] = spx.[physical_io],
	[logicalreads] = s.[logical_reads],
	[application] = s.[program_name],
	[db_execute] = db_name(r.[database_id]),
	[command] = r.[command],
	[statement] = t.[text],
	[user_process] = s.[is_user_process],
	[transport] = c.[net_transport],
	[auth_by] = c.[auth_scheme],
	[packet_size] = c.[net_packet_size],
	[queryplan] = p.[query_plan]
from
	sys.dm_exec_sessions [s]
	left outer join [c] on s.[session_id] = c.[session_id]
	left outer join sys.dm_exec_requests [r] on s.[session_id] = r.[session_id]
	outer apply sys.dm_exec_sql_text(sql_handle) [t]
	outer apply sys.dm_exec_query_plan(plan_handle) [p]
	left outer join sys.sysprocesses [spx] on s.[session_id] = spx.[spid]
where
	(
		@all = 1
		or s.[is_user_process] = 1
		or (
			(
				r.[blocking_session_id] is not null
				and r.[blocking_session_id] <> 0
			)
			and (
				s.[status] not in ('sleeping', 'background')
				and Coalesce(r.[command], '') not in ('awaiting command', 'mirror handler', 'lazy writer', 'checkpoint sleep', 'ra manager', 'task manager')
				or r.[session_id] = r.[blocking_session_id]
			)
		)
	)
	and (
		(@filter is null or Coalesce(@filter, '') = '')
		or case
			when @sort = 'spid' and s.[session_id] = Convert(int, @filter) then 1
			when @sort = 'hpid' and s.[host_process_id] = Convert(int, @filter) then 1
			when @sort = 'login' and s.[login_name] like '%' + @filter + '%' then 1
			when @sort = 'host' and s.[host_name] like '%' + @filter + '%' then 1
			when @sort = 'db' and db_name(spx.[dbid]) like '%' + @filter + '%' then 1
			when @sort = 'ip' and c.[client_net_address] like '%' + @filter + '%' then 1
			when @sort = 'app' and s.[program_name] like '%' + @filter + '%' then 1
			else 0
		end = 1
	)
	and (@sleeping = 1 or (@sleeping = 0 and s.[status] <> 'sleeping'))
	and spx.[spid] <> @@SPID
order by
	[blocker] desc,
	[active] desc,
	case when @sort = 'spid' then s.[session_id] end asc,
	case when @sort = 'hpid' then s.[host_process_id] end asc,
	case when @sort = 'login' then s.[login_name] end asc,
	case when @sort = 'host' then s.[host_name] end asc,
	case when @sort = 'db' then db_name(spx.[dbid]) end asc,
	case when @sort = 'ip' then c.[client_net_address] end asc,
	case when @sort = 'app' then s.[program_name] end asc,
	case when @sort = 'reads' then s.[logical_reads] end desc,
	case when @sort = 'waits' then r.[wait_time] end desc,
	case when @sort = 'io' then spx.[physical_io] end desc,
	case when @sort = 'cpu' then spx.[cpu] end desc,
	case when @sort = 'time' then DateDiff(s, s.[last_request_start_time], getdate()) end desc,
	case when @sort = 'age' then s.[last_request_start_time] end asc,
	s.[session_id] asc,
	s.[login_name] asc,
	s.[login_time] asc
end
go

exec sp_MS_marksystemobject 'sp_what' ;
go
return ;

-- EXAMPLES

exec [sp_what] ;
--exec [sp_what] @sort = 'login' ;
--exec [sp_what] @sort = 'reads' ;
--exec [sp_what] @all = 1 ;
