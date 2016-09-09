use [PartitionTesting] ;
go

-- show partitioned tables
select
	[schema] = object_schema_name(i.[object_id]),
	[table_name] = object_name(i.[object_id]),
	[index_name] = i.[name],
	[partition_scheme] = s.[name],
	[p#] = p.[partition_number],
	[filegroup] = fg.[name],
	[file] = df.[physical_name],
	[compression] = p.[data_compression_desc],
	[rows] = p.[rows],
	[pages] = au.[total_pages],
	[pages_used] = au.[used_pages],
	[mb] = Convert(decimal(12, 2), au.[total_pages] / 128.0),
	[mb_used] = Convert(decimal(12, 2), au.[used_pages] / 128.0),
	[readonly] = fg.[is_read_only],
	[partition_function] = f.[name],
	[key] = col_name(ic.[object_id], ic.[column_id]),
	[func] = iif(f.[boundary_value_on_right] = 1, '<', '<='),
	[value] = rv.[value]
from
	sys.partitions [p]
	inner join sys.indexes [i] on p.[object_id] = i.[object_id]
	inner join sys.index_columns [ic] on p.[object_id] = i.[object_id] and i.[index_id] = ic.[index_id] and p.[object_id] = ic.[object_id] and ic.[partition_ordinal] > 0
	inner join sys.partition_schemes [s] on i.[data_space_id] = s.[data_space_id]
	inner join sys.partition_functions [f] on s.[function_id] = f.[function_id]
	inner join sys.system_internals_allocation_units [au] on p.[partition_id] = au.[container_id]
	inner join sys.destination_data_spaces [ds] on ds.[partition_scheme_id] = s.[data_space_id] and p.[partition_number] = ds.[destination_id]
	inner join sys.filegroups [fg] on ds.[data_space_id] = fg.[data_space_id]
	inner join sys.database_files [df] on ds.[data_space_id] = df.[data_space_id]
	left outer join sys.partition_range_values [rv] on f.[function_id] = rv.[function_id] and p.[partition_number] = rv.[boundary_id]
where
	p.[index_id] = 1 and i.[index_id] = 1
order by
	[table_name] asc,
	p.[partition_number] asc ;
go

-- get out of the database so we're not locking our partition changes
use [master] ;
go
