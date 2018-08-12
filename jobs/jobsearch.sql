declare @str varchar(256) = '%backup%' ;
 
select
	[condition] = 'matched command',
    j.[name],
    j.[enabled],
    j.[date_created],
    j.[date_modified],
    s.[step_id],
    s.[step_name],
    s.[subsystem],
    s.[command],
    s.[output_file_name]
from
    msdb.dbo.[sysjobs] [j]
    inner join msdb.dbo.[sysjobsteps] [s] on j.[job_id] = s.[job_id]
where
    s.[command] like @str

union

select
	[condition] = 'matched name',
    j.[name],
    j.[enabled],
    j.[date_created],
    j.[date_modified],
    s.[step_id],
    s.[step_name],
    s.[subsystem],
    s.[command],
    s.[output_file_name]
from
    msdb.dbo.[sysjobs] [j]
    inner join msdb.dbo.[sysjobsteps] [s] on j.[job_id] = s.[job_id]
where
    j.[name] like @str
	or s.[step_name] like @str

union

select
    [condition] = 'matched output path',
    j.[name],
    j.[enabled],
    j.[date_created],
    j.[date_modified],
    s.[step_id],
    s.[step_name],
    s.[subsystem],
    s.[command],
	s.[output_file_name]
from
    msdb.dbo.[sysjobs] [j]
    inner join msdb.dbo.[sysjobsteps] [s] on j.[job_id] = s.[job_id]
where
    s.[output_file_name] like @str

order by
    j.[name] asc,
    s.[step_id] asc ;
