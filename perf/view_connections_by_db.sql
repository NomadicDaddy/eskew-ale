select [curConn] = Count(*), [ ] = '/', [maxConn] = @@max_connections from sys.dm_exec_sessions

select
	[total] = Count(*),
	[active] = Count(case [status] when 'sleeping' then null else 1 end),
	[database] = db_name([dbid]),
	[hostname],
	[loginame],
	[program_name]
from
	sys.sysprocesses
--where
--	[dbid] not in (0)
--	[status] <> 'sleeping'
group by
	[hostname],
	[loginame],
	[dbid],
	[program_name]
order by
	[active] desc ;
