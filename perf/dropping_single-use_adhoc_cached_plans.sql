-- dropping single-use ad-hoc cached plans
select
	[text],
	[mb] = Convert(real, cp.[size_in_bytes] / 1048576.0),
	[plan_handle],
	[fix] = 'dbcc freeproccache (0x' + Convert(char(88), [plan_handle], 2) + ') with no_infomsgs ;'
from
	sys.dm_exec_cached_plans [cp]
	cross apply sys.dm_exec_sql_text(plan_handle)
where
	cp.[cacheobjtype] = N'Compiled Plan'
	and cp.[objtype] = N'Adhoc'
	and cp.[usecounts] = 1
order by
	cp.[size_in_bytes] desc ;
go
