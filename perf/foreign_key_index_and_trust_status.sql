-- set to blank or null to see fk status for all tables

declare @Table varchar(64) = '' ;

-- foreign key index and trust status
select distinct
	[fk_name] = fk.[name],
	[referencing_schema] = s.[name],
	[referencing_table] = object_name(fk.[parent_object_id]),
	[referencing_column] = c2.[name],
	[target_schema] = s2.[name],
	[target_table] = object_name(fk.[referenced_object_id]),
	[target_column] = c.[name],
	fk.[is_not_trusted],
	[is_indexed] = case when ic.[object_id] is null then 0 else 1 end,
	[sqlx_idx] = case when ic.[object_id] is null then 'create nonclustered index [IX_' + object_name(fk.[parent_object_id]) + '_' + c.[name] + '] on ' + s.[name] + '.' + QuoteName(object_name(fk.[parent_object_id])) + '(' + QuoteName(c.[name]) + ' asc) with (data_compression = page) ;' else null end,
	[sqlx_chk] = case when fk.[is_not_trusted] = 1 then 'alter table ' + s.[name] + '.' + QuoteName(object_name(fk.[parent_object_id])) + ' with check check constraint ' + QuoteName(fk.[name]) + ' ;' else null end
from
	sys.foreign_keys [fk]
	inner join sys.schemas [s] on fk.[schema_id] = s.[schema_id]
	inner join sys.objects [o] on fk.[referenced_object_id] = o.[object_id]
	inner join sys.schemas [s2] on o.[schema_id] = s2.[schema_id]
	inner join sys.foreign_key_columns [fkc] on fkc.[constraint_object_id] = fk.[object_id]
	inner join sys.columns [c] on fkc.[parent_object_id] = c.[object_id] and fkc.[parent_column_id] = c.[column_id]
	inner join sys.columns [c2] on fkc.[referenced_object_id] = c2.[object_id] and fkc.[referenced_column_id] = c2.[column_id]
	left outer join sys.index_columns [ic] on ic.[object_id] = fkc.[parent_object_id] and ic.[column_id] = fkc.[parent_column_id] and ic.[index_column_id] = fkc.[constraint_column_id]
--	left outer join sys.index_columns [ic2] on ic2.[object_id] = fkc.[referenced_object_id] and ic2.[column_id] = fkc.[referenced_column_id] and ic2.[index_column_id] = fkc.[constraint_column_id]
where
	fk.[referenced_object_id] = (select [object_id] from sys.tables where [name] = @Table)
	or (@Table is null or @Table = '')
order by
	[referencing_table] asc,
	fk.[name] asc ;
