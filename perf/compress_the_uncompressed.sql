--select --distinct
--	[table_schema] = s.[name],
--	[table_name] = t.[name],
--	t.[object_id],
--	p.[partition_id],
--	p.[partition_number],
--	p.[data_compression],
--	p.[data_compression_desc],
--	[sqlx] = 'alter table ' + s.[name] + '.' + QuoteName(t.[name]) + ' rebuild partition = all with (data_compression = page) ;'
--from
--	sys.partitions [p]
--	inner join sys.tables [t] on p.[object_id] = t.[object_id]
--	inner join sys.schemas [s] on t.[schema_id] = s.[schema_id]
--where
--	p.[data_compression] = 0
--	and s.[name] not in ('logs', 'staging', 'cdc', 'dbo')
--order by
--	[table_schema] asc,
--	[table_name] asc ;
--go

select
	p.[rows],
	[index_name] = i.[name],
	[schema_name] = s.[name],
	[table_name] = t.[name],
	[sqlx] = 'alter index ' + QuoteName(i.[name]) + ' on ' + s.[name] + '.' + QuoteName(t.[name]) + ' rebuild partition = all with (data_compression = page) ;'
from
	sys.partitions [p]
	inner join sys.tables [t] on p.[object_id] = t.[object_id]
	inner join sys.schemas [s] on t.[schema_id] = s.[schema_id]
	inner join sys.indexes [i] on p.[object_id] = i.[object_id] and p.[index_id] = i.[index_id]
where
	p.[data_compression_desc] = 'NONE'
--	and s.[name] not in ('logs', 'staging', 'cdc', 'dbo')
order by
	s.[name] asc,
	t.[name] asc,
	p.[partition_id] asc ;
go
