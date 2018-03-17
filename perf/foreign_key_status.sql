with [cte] as (
	select
		[schema_name] = s.[name],
		[table_name] = t.[name],
		ps.[row_count],
		[used_pages_count] = Sum(ps.[used_page_count]),
		[pages] = Sum(case when (i.[index_id] < 2) then (ps.[in_row_data_page_count] + ps.[lob_used_page_count] + ps.[row_overflow_used_page_count]) else ps.[lob_used_page_count] + ps.[row_overflow_used_page_count] end)
	from
		sys.dm_db_partition_stats [ps]
		inner join sys.tables [t] on ps.[object_id] = t.[object_id]
		inner join sys.indexes [i] on t.[object_id] = i.[object_id] and ps.[index_id] = i.[index_id]
		inner join sys.schemas [s] on t.[schema_id] = s.[schema_id]
	where
		t.[is_ms_shipped] = 0
	group by
		s.[name],
		t.[name],
		ps.[row_count]
)
select distinct
	[fk_name] = fk.[name],
	[referencing_schema] = s.[name],
	[referencing_table] = object_name(fk.[parent_object_id]),
	[referencing_column] = c2.[name],
	[referencing_row_count] = ts1.[row_count],
	[referencing_table_size_mb] = Convert(decimal(18,2), (ts1.[pages] * 8) / 1024.0),
	[referencing_index_size_mb] = Convert(decimal(18,2), (case when ts1.[used_pages_count] > ts1.[pages] then ts1.[used_pages_count] - ts1.[pages] else 0 end * 8) / 1024.0),
	[target_schema] = s2.[name],
	[target_table] = object_name(fk.[referenced_object_id]),
	[target_column] = c.[name],
	[target_row_count] = ts2.[row_count],
	[target_table_size_mb] = Convert(decimal(18,2), (ts2.[pages] * 8) / 1024.0),
	[target_index_size_mb] = Convert(decimal(18,2), (case when ts2.[used_pages_count] > ts2.[pages] then ts2.[used_pages_count] - ts2.[pages] else 0 end * 8) / 1024.0),
	fk.[is_not_trusted],
	[is_indexed] = case when ic.[object_id] is null then 0 else 1 end,
	fk.[is_system_named]
from
	sys.foreign_keys [fk]
	inner join sys.schemas [s] on fk.[schema_id] = s.[schema_id]
	inner join sys.objects [o] on fk.[referenced_object_id] = o.[object_id]
	inner join sys.schemas [s2] on o.[schema_id] = s2.[schema_id]
	inner join sys.foreign_key_columns [fkc] on fkc.[constraint_object_id] = fk.[object_id]
	inner join sys.columns [c] on fkc.[parent_object_id] = c.[object_id] and fkc.[parent_column_id] = c.[column_id]
	inner join sys.columns [c2] on fkc.[referenced_object_id] = c2.[object_id] and fkc.[referenced_column_id] = c2.[column_id]
	left outer join sys.index_columns [ic] on ic.[object_id] = fkc.[parent_object_id] and ic.[column_id] = fkc.[parent_column_id] and ic.[index_column_id] = fkc.[constraint_column_id]
	inner join [cte] [ts1] on s.[name] = ts1.[schema_name] and object_name(fk.[parent_object_id]) = ts1.[table_name]
	inner join [cte] [ts2] on s2.[name] = ts2.[schema_name] and object_name(fk.[referenced_object_id]) = ts2.[table_name] ;
