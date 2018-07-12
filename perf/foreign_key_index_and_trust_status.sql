-- foreign key index and trust status

declare @Table varchar(64) = '' ;	-- leave blank or null to see fk status for all tables
declare @ShowFixes bit = 1 ;		-- also create output of just fixes
declare @ShowTrusted bit = 1 ;		-- show trusted foreign keys
declare @ShowIndexed bit = 1 ;		-- show indexed foreign keys
declare @ShowNFR bit = 1 ;		-- show foreign keys identified NOT_FOR_REPLICATION

if object_id('tempdb..#fks') is not null
	drop table [#fks] ;

set nocount on ;

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
	[referencing_schema] = s1.[name],
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
	fk.[is_disabled],
	fk.[is_not_trusted],
	fk.[is_not_for_replication],
	[is_not_indexed] = case when ic.[object_id] is null then 1 else 0 end,
	[sqlx_idx] = case when ic.[object_id] is null then 'create nonclustered index [IX_' + object_name(fk.[parent_object_id]) + '_' + c.[name] + '] on ' + s1.[name] + '.' + QuoteName(object_name(fk.[parent_object_id])) + '(' + QuoteName(c.[name]) + ' asc) ' + case when ServerProperty('EngineEdition') = 3 then ' with (data_compression = page)' else null end + ' ;' else null end,
	[sqlx_chk] = case when fk.[is_not_trusted] = 1 and fk.[is_not_for_replication] = 0 then 'alter table ' + s1.[name] + '.' + QuoteName(object_name(fk.[parent_object_id])) + ' with check check constraint ' + QuoteName(fk.[name]) + ' ;' else null end,
	[sqlx_dbcc] = case when fk.[is_not_trusted] = 1 and fk.[is_not_for_replication] = 0 then 'dbcc checkconstraints (''' + s1.[name] + '.' + fk.[name] + ''') ;' else null end
into
	[#fks]
from
	sys.foreign_keys [fk]
	inner join sys.schemas [s1] on fk.[schema_id] = s1.[schema_id]
	inner join sys.objects [o] on fk.[referenced_object_id] = o.[object_id]
	inner join sys.schemas [s2] on o.[schema_id] = s2.[schema_id]
	inner join sys.foreign_key_columns [fkc] on fkc.[constraint_object_id] = fk.[object_id]
	inner join sys.columns [c] on fkc.[parent_object_id] = c.[object_id] and fkc.[parent_column_id] = c.[column_id]
	inner join sys.columns [c2] on fkc.[referenced_object_id] = c2.[object_id] and fkc.[referenced_column_id] = c2.[column_id]
	left outer join sys.index_columns [ic] on ic.[object_id] = fkc.[parent_object_id] and ic.[column_id] = fkc.[parent_column_id] and ic.[index_column_id] = fkc.[constraint_column_id]
	inner join [cte] [ts1] on s1.[name] = ts1.[schema_name] and object_name(fk.[parent_object_id]) = ts1.[table_name]
	inner join [cte] [ts2] on s2.[name] = ts2.[schema_name] and object_name(fk.[referenced_object_id]) = ts2.[table_name]
where
	(
		@Table is null
		or @Table = ''
		or fk.[referenced_object_id] = (select [object_id] from sys.tables where [name] = @Table)
	)
	and	(@ShowTrusted = 1 or fk.[is_not_trusted] = 1)
	and (@ShowIndexed = 1 or ic.[object_id] is null)
	and (@ShowNFR = 1 or fk.[is_not_for_replication] = 0)
order by
	s1.[name] asc,
	[referencing_table] asc,
	fk.[name] asc ;

select * from [#fks] ;

if (@ShowFixes = 1)
	select distinct [sqlx] = [sqlx_chk] + char(13) + char(10) + 'go', [dbcc] = [sqlx_dbcc] + char(13) + char(10) + 'go' from [#fks] where [sqlx_chk] is not null union
	select distinct [sqlx] = [sqlx_idx] + char(13) + char(10) + 'go', [dbcc] = null from [#fks] where [sqlx_idx] is not null ;
go
