with [objs] as (
	select
		o.[name],
		o.[type_desc],
		[principal_id] = Coalesce(o.[principal_id], s.[principal_id]),
		[schema] = s.[name]
	from
		sys.objects [o]
		inner join sys.schemas [s] on o.[schema_id] = s.[schema_id]
	where
		o.[is_ms_shipped] = 0
)
select
    [object] = o.[name],
    [type] = o.[type_desc],
    [owner] = dp.[name],
	[schema] = o.[schema],
	[fix] = 'alter schema [dbo] transfer ' + QuoteName(o.[schema]) + '.' + QuoteName(o.[name]) + ' ;'
from
	objs [o]
	inner join sys.database_principals [dp] on o.[principal_id] = dp.[principal_id]
where
	dp.[name] <> 'dbo'
order by
	dp.[name] asc,
	o.[name] asc ;
go
