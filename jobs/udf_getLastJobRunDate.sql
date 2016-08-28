if exists (select 1 from INFORMATION_SCHEMA.routines where [routine_schema] = 'dbo' and [routine_name] = 'udf_getLastJobRunDate')
	drop function dbo.[udf_getLastJobRunDate] ;
go

create function dbo.[udf_getLastJobRunDate] (
	@jobName sysname
) returns datetime
as
begin

declare
	@dtLastRun datetime ;

-- get the date of the last successful execution of specified job
select top 1
	@dtLastRun =
		Cast(Cast(sjh.[run_date] as char(8))
		+ ' '
		+ Stuff(Stuff(Right('000000' + Cast(sjh.[run_time] as varchar(6)), 6), 3, 0, ':'), 6, 0, ':') as datetime)
from
	msdb.dbo.[sysjobs] [sj]
	inner join msdb.dbo.[sysjobhistory] [sjh] on sj.[job_id] = sjh.[job_id]
where
	sjh.[run_status] = 1
	and sj.[name] = @jobName
order by
	sjh.[run_date] desc,
	sjh.[run_time] desc ;

return @dtLastRun ;

end
go
return ;

-- EXAMPLES

select [LastRun] = dbo.[udf_getLastJobRunDate]('DBA: Daily Full Backup') ;
go
