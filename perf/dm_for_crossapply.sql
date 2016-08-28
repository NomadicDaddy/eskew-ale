drop function dbo.dm_db_index_physical_stats_for_crossapply ;
go

create function dbo.dm_db_index_physical_stats_for_crossapply (@db_id int, @object_id int, @index_id int, @partition_number int, @mode nvarchar(32))
returns @results table (
	[database_id] [smallint] null,
	[object_id] [int] null,
	[index_id] [int] null,
	[partition_number] [int] null,
	[index_type_desc] [nvarchar](60) null,
	[alloc_unit_type_desc] [nvarchar](60) null,
	[index_depth] [tinyint] null,
	[index_level] [tinyint] null,
	[avg_fragmentation_in_percent] [float] null,
	[fragment_count] [bigint] null,
	[avg_fragment_size_in_pages] [float] null,
	[page_count] [bigint] null,
	[avg_page_space_used_in_percent] [float] null,
	[record_count] [bigint] null,
	[ghost_record_count] [bigint] null,
	[version_ghost_record_count] [bigint] null,
	[min_record_size_in_bytes] [int] null,
	[max_record_size_in_bytes] [int] null,
	[avg_record_size_in_bytes] [float] null,
	[forwarded_record_count] [bigint] null,
	[compressed_page_count] [bigint] null
)
begin
	insert into @results select * from sys.dm_db_index_physical_stats(@db_id, @object_id, @index_id, @partition_number, @mode) ;
	return ;
end
go