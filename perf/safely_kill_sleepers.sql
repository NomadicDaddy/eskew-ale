declare @howlong int = 360		-- 60=1h, 360=6h, 720=12h, 1440=1d
declare @kill bit = 0			-- execute or just display?

declare @sql varchar(512) ;
declare @spid int ;
declare @loginame nvarchar(128) ;
declare @program_name nvarchar(128) ;
declare sleepers cursor fast_forward for
select
	[spid],
	[loginame] = RTrim(LTrim([loginame])),
	[program_name] = RTrim(LTrim([program_name]))
from
	master..sysprocesses
where
	[spid] > 50
	and [status] = 'sleeping'
	and [net_address] <> ''
	and [loginame] not in (select [service_account] from sys.dm_server_services where [servicename] like 'SQL Server (%' or [servicename] like 'SQL Server Agent (%')
	and DateDiff(mi, [last_batch], getdate()) >= @howlong
	and spid <> @@spid ;
open sleepers ;
fetch next from sleepers into @spid, @loginame, @program_name ;
while (@@fetch_status = 0)
begin
	set @sql = 'kill ' + Convert(varchar(8), @spid) + ' ; -- ' + QuoteName(@loginame) + ' (' + @program_name + ')' ;
	raiserror(@sql, 0, 1) with nowait ;
	if (@kill = 1) exec(@sql) ;
	fetch next from sleepers into @spid, @loginame, @program_name ;
end
close sleepers ;
deallocate sleepers ;
go
