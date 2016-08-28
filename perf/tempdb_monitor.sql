-- quick and dirty tempdb monitor

declare @reset bit = 0 ;

-- FROM ANOTHER SESSION:
-- select top 5 * from dbo.[tempStats] order by [id] desc ;
-- truncate table dbo.[tempStats] ;
-- drop table dbo.[tempStats] ;

-- ALT+BREAK or kill to end...

if (@reset = 1 or not exists (select 1 from INFORMATION_SCHEMA.TABLES where [table_name] = N'audit_login' and [table_type] = 'BASE TABLE'))
begin
	if exists (select 1 from INFORMATION_SCHEMA.TABLES where [table_name] = N'tempStats' and [table_type] = 'BASE TABLE')
		drop table dbo.[tempStats] ;
	create table dbo.[tempStats] (
		[id] int not null identity(1, 1),
		[dt] datetime not null constraint [df_dbo.tempStats_dt] default (getdate()),
		[user_objects_kb] int not null,
		[internal_objects_kb] int not null,
		[version_store_kb] int not null,
		[freespace_kb] int not null
	) ;
end
go

set nocount on ;

while (1 = 1)
begin

	insert into
		[tempStats]
	select
		[dt] = getdate(),
		[user_objects_kb] = Coalesce(Sum([user_object_reserved_page_count]) * 8, 0),
		[internal_objects_kb] = Coalesce(Sum([internal_object_reserved_page_count]) * 8, 0),
		[version_store_kb] = Coalesce(Sum([version_store_reserved_page_count]) * 8, 0),
		[freespace_kb] = Coalesce(Sum([unallocated_extent_page_count]) * 8, 0)
	from
		tempdb.sys.dm_db_file_space_usage ;

	waitfor delay '000:00:30' ;

end
