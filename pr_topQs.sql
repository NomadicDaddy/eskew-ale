set quoted_identifier on ;
set ansi_nulls on ;
go

if exists (select 1 from INFORMATION_SCHEMA.ROUTINES where [routine_schema] = 'dbo' and [routine_name] = 'pr_topQs')
	drop procedure dbo.[pr_topQs] ;
go

create procedure dbo.[pr_topQs] (
	@topcount int = 10,
	@type varchar(10) = 'aggio',
	@search nvarchar(256) = null,
	@since datetime = null,
	@database nvarchar(128) = null
)
as
begin

set nocount, xact_abort on ;

-----------------------------------------------------------------------------------------------------------------------
-- Procedure:	pr_topQs
-- Author:		Phillip Beazley (phillip@beazley.org)
-- Date:		02/21/2014
--
-- Purpose:		Retrieve top queries.
--
-- Notes:		@type = cpu, count, avgio or aggio
--
-- Depends:		n/a
--
-- REVISION HISTORY ---------------------------------------------------------------------------------------------------
-- 02/21/2014	lordbeazley	Initial creation.
-----------------------------------------------------------------------------------------------------------------------

if (@since is null) set @since = GetDate() - 0.1 ;

begin try
select top (@topcount)
	[creation_time],
	[last_execution_time],
	Rank() over (order by ([total_worker_time] + 0.0) / [execution_count] desc, [sql_handle], [statement_start_offset]) as [row_no],
	(Rank() over (order by ([total_worker_time] + 0.0) / [execution_count] desc, [sql_handle], [statement_start_offset])) % 2 as [l1],
	([total_worker_time] + 0.0) / 1000 as [total_worker_time],
	([total_worker_time] + 0.0) / ([execution_count] * 1000) as [AvgCPUTime],
	[total_logical_reads] as [LogicalReads],
	[total_logical_writes] as [LogicalWrites],
	[execution_count],
	[total_logical_reads] + [total_logical_writes] as [AggIO],
	([total_logical_reads] + [total_logical_writes]) / ([execution_count] + 0.0) as [AvgIO],
	case
		when [sql_handle] is null
			then ' '
	     else
			(Substring([st].[text], ([qs].[statement_start_offset] + 2) / 2, (
				case
					when [qs].[statement_end_offset] = -1
						then Len(Convert(nvarchar(max), [st].[text])) * 2
					else
						[qs].[statement_end_offset]
				end - [qs].[statement_start_offset]) / 2)
			)
	end as [query_text],
	db_name([st].[dbid]) as [db_name],
	[st].[objectid] as [object_id],
	object_name([st].[objectid]) as [objName]
from
	[sys].[dm_exec_query_stats] [qs]
	cross apply [sys].[dm_exec_sql_text](sql_handle) [st]
where
	[total_worker_time] > 0
	and [last_execution_time] > @since
	and (
		@database is null
		or @database = db_name([st].[dbid])
	)
order by
	case
		when @type = 'time'
			then [total_worker_time]
		when @type = 'cpu'
			then ([total_worker_time] + 0.0) / ([execution_count] * 1000)
		when @type = 'count'
			then ([execution_count])
		when @type = 'avgio'
			then ([total_logical_reads] + [total_logical_writes]) / ([execution_count] + 0.0)
		else
			[total_logical_reads] + [total_logical_writes]
	end desc 
end try

begin catch
select
	-100 as [row_no],
	1 as [l1],
	1 as [create_time],
	1 as [last_execution_time],
	1 as [total_worker_time],
	1 as [AvgCPUTime],
	1 as [LogicalReads],
	1 as [LogicalWrites],
	error_number() as [execution_count],
	error_severity() as [AggIO],
	error_state() as [AvgIO],
	error_message() as [query_text],
	0 as [db_name],
	0 as [object_name]
end catch

end
go
return ;

-- EXAMPLES

exec [pr_topQs]
	@topcount = 10,
	@type = 'time',
	@search = null,
	@since = '2014-02-21 15:00:00.000',
	@database = null ;
