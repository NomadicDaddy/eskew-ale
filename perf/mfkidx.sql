-- find all FKs without a corresponding index
-- includes some customizations to handle the multipart keys for SubVersion

set nocount on ;
 
declare
	@curid int,
	@tSchema nvarchar(128),
	@tName nvarchar(128) ;

declare @fkeys table (
	[id] int identity(1, 1),
    [pktable_qualifier] nvarchar(128),
    [pktable_owner] nvarchar(128),
    [pktable_name] nvarchar(128),
    [pkcolumn_name] nvarchar(128),
    [fktable_qualifier] nvarchar(128),
    [fktable_owner] nvarchar(128),
    [fktable_name] nvarchar(128),
    [fkcolumn_name] nvarchar(128),
    [key_seq] int,
    [update_rule] int,
    [delete_rule] int,
    [fk_name] nvarchar(128),
    [pk_name] nvarchar(128),
    [deferrability] int
) ;

declare @midx table (
	[id] int identity(1, 1),
	[fkobj] nvarchar(128),
	[fkobjid] int,
	[sql] nvarchar(2048),
	[fkcolumn_name] nvarchar(128)
) ;

declare [tableCursor] cursor fast_forward for
select [table_schema], [table_name] from INFORMATION_SCHEMA.TABLES --where [table_name] = 'nachosForDays'
open [tableCursor] ;
fetch next from [tableCursor] into @tSchema, @tName ;
while @@fetch_status = 0
begin

    insert @fkeys
    exec dbo.[sp_fkeys] @tName, @tSchema ;
 
    fetch next from [tableCursor] into @tSchema, @tName ;
end
close [tableCursor] ;
deallocate [tableCursor] ;

insert @midx
  select
		[fkobj] = QuoteName([fktable_owner]) + '.' + QuoteName([fktable_name]),
		[fkobjid] = null,
		[sql] = 'create nonclustered index [ix_' + [fktable_owner] + '.' + [fktable_name] + '_' + [fkcolumn_name] + '] on '
		+ QuoteName([fktable_owner]) + '.' + QuoteName([fktable_name]) + ' (' + QuoteName([fkcolumn_name]) + ') ;',
		[fkcolumn_name]
	from
		@fkeys
	where
		[fkcolumn_name] <> 'SubVersionedTableId'

update @midx set [sql] = Replace([sql], '_SubVersionId]', '_SubVersion]') where 1=1 ;
update @midx set [sql] = Replace([sql], '([SubVersionId])', '([SubVersionId], [SubVersionedTableId])') where 1=1 ;
update @midx set [fkobjid] = object_id([fkobj]) where [fkobjid] is null ;

select
	m.[fkobj],
	m.[fkobjid],
	m.[fkcolumn_name],
	c.[column_id],
	m.[sql]
from
	@midx [m]
	inner join sys.columns [c] on m.[fkobjid] = c.[object_id] and m.[fkcolumn_name] = c.[name]
	left outer join sys.index_columns [ic] on c.[object_id] = ic.[object_id] and c.[column_id] = ic.[column_id]
where
	c.[is_identity] = 0 and
	ic.[column_id] is null
order by
	[fkobj] asc ;
go
