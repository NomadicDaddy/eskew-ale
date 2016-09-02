set quoted_identifier on ;
set ansi_nulls on ;
go

if exists (select 1 from INFORMATION_SCHEMA.ROUTINES where [routine_schema] = 'dbo' and [routine_name] = 'pr_standardize_constraints')
	drop procedure dbo.[pr_standardize_constraints] ;
go

create procedure dbo.[pr_standardize_constraints] (
	@debug bit = 1,									-- print instead of execute
	@force bit = 0,									-- force a rename even if matched
	@include varchar(14) = 'PK,IX,UX,UK,DF'			-- constraint types to rename
)
as
begin

set nocount, xact_abort on ;

-----------------------------------------------------------------------------------------------------------------------
-- Procedure:	pr_standardize_constraints
-- Author:		Phillip Beazley (phillip@beazley.org)
-- Date:		08/20/2016
--
-- Purpose:		Rename table constraints to conform to the following standard:
--
--				PK:		pk_<schema>_<table_name>
--				IX:		ix_<schema>_<table_name>_<column>{-<column>}
--				UX:		ux_<schema>_<table_name>_<column>{-<column>}
--				UK:		uk_<schema>_<table_name>_<column>{-<column>}
--				DF:		df_<schema>_<table_name>_<column>{-<column>}
--
-- Notes:		While a bad rename won't technically hurt anything, it's always best to generate the output, review
--				it thoroughly and ensure it's doing what you think it's doing before executing the output yourself.
--
-- Depends:		n/a
--
-- REVISION HISTORY ---------------------------------------------------------------------------------------------------
-- 08/20/2016	pbeazley	Created.
-----------------------------------------------------------------------------------------------------------------------

declare
	@sql nvarchar(max),
	@prev nvarchar(max) = '',
	@table nvarchar(128),
	@constraint nvarchar(128),
	@newconstraint nvarchar(1285),
	@column nvarchar(128),
	@multi nvarchar(1024) = '',
	@schema nvarchar(128) ;

-- rename default constraints
if (CharIndex('DF', @include) > 0)
begin
	declare defCursor cursor fast_forward for
	select
		[schema] = s.[name],
		[table] = t.[name],
		[column] = c.[name],
		[constraint] = dc.[name]
	from
		sys.columns [c]
		inner join sys.tables [t] on c.[object_id] = t.[object_id]
		inner join sys.schemas [s] on t.[schema_id] = s.[schema_id]
		inner join sys.default_constraints [dc] on c.[default_object_id] = dc.[object_id]
	where 
		t.[name] <> 'sysdiagrams'
		and t.[type] = 'U'
		and (@force = 1 or dc.[name] not like 'df_%' collate Latin1_General_CS_AS)
	order by
		s.[name] asc,
		t.[name] asc,
		c.[name] asc,
		dc.[name] asc ;
	open defCursor ;
	fetch next from defCursor into @schema, @table, @column, @constraint  ;
	while @@fetch_status = 0
	begin

		set @newconstraint = 'df_' + @schema + '.' + @table + '_' + @column ;
		if (@newconstraint <> @constraint or @force = 1)
		begin
			set @sql = 'exec sp_rename ''' + @schema + '.[' + @constraint + ']'', ''' + @newconstraint + ''', ''object'' ;' ;
			print @sql + char(12) + char(10) + 'go' ;
			if (@debug = 0) exec (@sql) ;
		end

		fetch next from defCursor into @schema, @table, @column, @constraint ;
	end
	close defCursor ;
	deallocate defCursor ;
end

-- rename primary keys
if (CharIndex('PK', @include) > 0)
begin
	declare indCursor cursor fast_forward for
	select
		[schema] = s.[name],
		[table] = t.[name],
		[column] = c.[name],
		[constraint] = i.[name]
	from
		sys.indexes [i]
		inner join sys.index_columns [ic] on i.[object_id] = ic.[object_id] and i.[index_id] = ic.[index_id]
		inner join sys.columns [c] on ic.[object_id] = c.[object_id] and ic.[column_id] = c.[column_id]
		inner join sys.tables [t] on i.[object_id] = t.[object_id]
		inner join sys.schemas [s] on t.[schema_id] = s.[schema_id]
	where 
		t.[name] <> 'sysdiagrams'
		and t.[type] = 'U'
		and i.[is_primary_key] = 1
		and (
				@force = 1
				or i.[name] <> 'pk_' + s.[name] + '.' + t.[name] collate Latin1_General_CS_AS
		)
	order by
		s.[name] asc,
		t.[name] asc,
		c.[name] asc,
		i.[name] asc ;
	open indCursor ;
	fetch next from indCursor into @schema, @table, @column, @constraint  ;
	while @@fetch_status = 0
	begin

		set @newconstraint = 'pk_' + @schema + '.' + @table ;
		if (@newconstraint <> @constraint or @force = 1)
		begin
			set @sql = 'exec sp_rename ''' + @schema + '.[' + @constraint + ']'', ''' + @newconstraint + ''', ''object'' ;' ;
			print @sql + char(12) + char(10) + 'go' ;
			if (@debug = 0) exec (@sql) ;
		end

		fetch next from indCursor into @schema, @table, @column, @constraint ;
	end
	close indCursor ;
	deallocate indCursor ;
end

-- rename normal indexes
if (CharIndex('IX', @include) > 0)
begin
	declare indCursor cursor fast_forward for
	select
		[schema] = s.[name],
		[table] = t.[name],
		[column] = c.[name],
		[constraint] = i.[name]
	from
		sys.indexes [i]
		inner join sys.index_columns [ic] on i.[object_id] = ic.[object_id] and i.[index_id] = ic.[index_id]
		inner join sys.columns [c] on ic.[object_id] = c.[object_id] and ic.[column_id] = c.[column_id]
		inner join sys.tables [t] on i.[object_id] = t.[object_id]
		inner join sys.schemas [s] on t.[schema_id] = s.[schema_id]
	where 
		t.[name] <> 'sysdiagrams'
		and t.[type] = 'U'
		and i.[is_primary_key] = 0
		and i.[is_unique_constraint] = 0
		and i.[is_unique] = 0
		and (
				@force = 1
				or i.[name] <> 'ix_' + s.[name] + '.' + t.[name] + '_' + c.[name] collate Latin1_General_CS_AS
		)
	order by
		s.[name] asc,
		t.[name] asc,
		ic.key_ordinal asc,
		c.[name] asc,
		i.[name] asc ;
	open indCursor ;
	fetch next from indCursor into @schema, @table, @column, @constraint  ;
	while @@fetch_status = 0
	begin

		set @multi = '' ;
		select
			@multi = @multi + c.[name] + '-'
		from
			sys.indexes [i]
			inner join sys.index_columns [ic] on i.[index_id] = ic.index_id
			inner join sys.columns [c] on ic.[object_id] = c.[object_id] and ic.column_id = c.[column_id]
		where
			ic.[object_id] = object_id(@schema + '.' + @table)
			and i.[name] = @constraint
		order by
			ic.[key_ordinal] asc ;
		if (Len(@multi) > 1)
			set @multi = Left(@multi, Len(@multi) - 1)
		else
			set @multi = @column ;

		set @newconstraint = 'ix_' + @schema + '.' + @table + '_' + @multi ;
		if (@newconstraint <> @constraint or @force = 1)
		begin
	
			set @sql = 'exec sp_rename ''' + @schema + '.' + QuoteName(@table) + '.[' + @constraint + ']'', ''' + @newconstraint + ''', ''index'' ;' ;

			if (@sql <> @prev)
			begin
				print @sql + char(13) + char(10) + 'go' ;
				if (@debug = 0) exec (@sql) ;
			end
			else print '-- skipping duplicate of ' + @prev ;

			set @prev = @sql ;
		end

		fetch next from indCursor into @schema, @table, @column, @constraint ;
	end
	close indCursor ;
	deallocate indCursor ;
end

-- rename unique indexes
if (CharIndex('UX', @include) > 0)
begin
	declare indCursor cursor fast_forward for
	select
		[schema] = s.[name],
		[table] = t.[name],
		[column] = c.[name],
		[constraint] = i.[name]
	from
		sys.indexes [i]
		inner join sys.index_columns [ic] on i.[object_id] = ic.[object_id] and i.[index_id] = ic.[index_id]
		inner join sys.columns [c] on ic.[object_id] = c.[object_id] and ic.[column_id] = c.[column_id]
		inner join sys.tables [t] on i.[object_id] = t.[object_id]
		inner join sys.schemas [s] on t.[schema_id] = s.[schema_id]
	where 
		t.[name] <> 'sysdiagrams'
		and t.[type] = 'U'
		and i.[is_primary_key] = 0
		and i.[is_unique_constraint] = 0
		and i.[is_unique] = 1
		and (
				@force = 1
				or i.[name] <> 'ux_' + s.[name] + '.' + t.[name] + '_' + c.[name] collate Latin1_General_CS_AS
		)
	order by
		s.[name] asc,
		t.[name] asc,
		c.[name] asc,
		i.[name] asc ;
	open indCursor ;
	fetch next from indCursor into @schema, @table, @column, @constraint  ;
	while @@fetch_status = 0
	begin

		set @multi = '' ;
		select
			@multi = @multi + c.[name] + '-'
		from
			sys.indexes [i]
			inner join sys.index_columns [ic] on i.[index_id] = ic.index_id
			inner join sys.columns [c] on ic.[object_id] = c.[object_id] and ic.column_id = c.[column_id]
		where
			ic.[object_id] = object_id(@schema + '.' + @table)
			and i.[name] = @constraint
		order by
			ic.[key_ordinal] asc ;
		if (Len(@multi) > 1)
			set @multi = Left(@multi, Len(@multi) - 1)
		else
			set @multi = @column ;

		set @newconstraint = 'ux_' + @schema + '.' + @table + '_' + @multi ;
		if (@newconstraint <> @constraint or @force = 1)
		begin

			set @sql = 'exec sp_rename ''' + @schema + '.' + QuoteName(@table) + '.[' + @constraint + ']'', ''' + @newconstraint + ''', ''index'' ;' ;

			if (@sql <> @prev)
			begin
				print @sql + char(13) + char(10) + 'go' ;
				if (@debug = 0) exec (@sql) ;
			end
			else print '-- skipping duplicate of ' + @prev ;

			set @prev = @sql ;
		end

		fetch next from indCursor into @schema, @table, @column, @constraint ;
	end
	close indCursor ;
	deallocate indCursor ;
end

-- rename unique constraints
if (CharIndex('UK', @include) > 0)
begin
	declare indCursor cursor fast_forward for
	select
		[schema] = s.[name],
		[table] = t.[name],
		[column] = c.[name],
		[constraint] = i.[name]
	from
		sys.indexes [i]
		inner join sys.index_columns [ic] on i.[object_id] = ic.[object_id] and i.[index_id] = ic.[index_id]
		inner join sys.columns [c] on ic.[object_id] = c.[object_id] and ic.[column_id] = c.[column_id]
		inner join sys.tables [t] on i.[object_id] = t.[object_id]
		inner join sys.schemas [s] on t.[schema_id] = s.[schema_id]
	where 
		t.[name] <> 'sysdiagrams'
		and t.[type] = 'U'
		and i.[is_primary_key] = 0
		and i.[is_unique_constraint] = 1
		and i.[is_unique] = 1
		and (
				@force = 1
				or i.[name] <> 'uk_' + s.[name] + '.' + t.[name] + '_' + c.[name] collate Latin1_General_CS_AS
		)
	order by
		s.[name] asc,
		t.[name] asc,
		c.[name] asc,
		i.[name] asc ;
	open indCursor ;
	fetch next from indCursor into @schema, @table, @column, @constraint  ;
	while @@fetch_status = 0
	begin

		set @multi = '' ;
		select
			@multi = @multi + c.[name] + '-'
		from
			sys.indexes [i]
			inner join sys.index_columns [ic] on i.[index_id] = ic.index_id
			inner join sys.columns [c] on ic.[object_id] = c.[object_id] and ic.column_id = c.[column_id]
		where
			ic.[object_id] = object_id(@schema + '.' + @table)
			and i.[name] = @constraint
		order by
			ic.[key_ordinal] asc ;
		if (Len(@multi) > 1)
			set @multi = Left(@multi, Len(@multi) - 1)
		else
			set @multi = @column ;

		set @newconstraint = 'uk_' + @schema + '.' + @table + '_' + @multi ;
		if (@newconstraint <> @constraint or @force = 1)
		begin

			set @sql = 'exec sp_rename ''' + @schema + '.' + QuoteName(@table) + '.[' + @constraint + ']'', ''' + @newconstraint + ''', ''index'' ;' ;

			if (@sql <> @prev)
			begin
				print @sql + char(13) + char(10) + 'go' ;
				if (@debug = 0) exec (@sql) ;
			end
			else print '-- skipping duplicate of ' + @prev ;

			set @prev = @sql ;
		end

		fetch next from indCursor into @schema, @table, @column, @constraint ;
	end
	close indCursor ;
	deallocate indCursor ;
end

end
go
return ;

-- EXAMPLES

exec dbo.[pr_standardize_constraints] @debug = 1, @force = 1, @include = 'PK,IX,UX,UK,DF' ;
