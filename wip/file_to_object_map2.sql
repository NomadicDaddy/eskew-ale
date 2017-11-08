use [PartitionTesting] ;
go

--select * from sys.indexes where [name] like 'pk%' or [name] like 'ux%'  or [name] like 'ix%' ;
--select * from sys.filegroups ;
--select * from sys.partition_schemes ;
--select * from sys.destination_data_spaces ;
--select * from sys.database_files ;

select
	dds.*,
	df.*
from
	sys.database_files df
	left outer join sys.destination_data_spaces dds on df.[data_space_id] = dds.[data_space_id]

--:connect ud
--use [DM_Insight] ;
--go

--with [df] as (
--	select
--		ps.[data_space_id],
--		fg.[name],
--		df.[physical_name]
--	from
--		sys.filegroups [fg]
--		inner join sys.database_files [df] on fg.[data_space_id] = df.[data_space_id]
--		inner join sys.destination_data_spaces [dds] on fg.[data_space_id] = dds.[data_space_id]
--		inner join sys.partition_schemes [ps] on dds.[partition_scheme_id] = ps.[data_space_id]
--	union
--	select
--		fg.[data_space_id],
--		fg.[name],
--		df.[physical_name]
--	from
--		sys.filegroups [fg]
--		inner join sys.database_files [df] on fg.[data_space_id] = df.[data_space_id]
--)
select
	[schema] = object_schema_name(i.[object_id]),
	[table_name] = object_name(i.[object_id]),
	[index_id] = i.[index_id],
	[index_name] = i.[name],
	[index_type] = i.[type_desc],
	[partitioned] = case when ps.[data_space_id] is null then 'no' else 'yes' end,
	[data_space_id] = Coalesce(ps.[data_space_id], fg.[data_space_id]),
	[filename] = case when ps.[data_space_id] is null then df.[name] else ps.[name] end,
	[file] = (select [physical_name] from sys.database_files where [data_space_id] = Coalesce(ps.[data_space_id], fg.[data_space_id]))
from
	sys.indexes [i]
	left outer join sys.partition_schemes [ps] on i.[data_space_id] = ps.[data_space_id]
	left outer join sys.filegroups [fg] on i.[data_space_id] = fg.[data_space_id]
	left outer join sys.database_files [df] on fg.[data_space_id] = df.[data_space_id]
--	left outer join [df] on fg.[data_space_id] = df.[data_space_id]
where
	ObjectProperty(i.[object_id], 'IsUserTable') = 1
--	and df.[data_space_id] = Coalesce(ps.[data_space_id], fg.[data_space_id])
order by
--	df.[name] asc,
	object_name(i.[object_id]) asc,
	i.[name] asc
--	i.[data_space_id] asc ;
go

--use [master] ;
--go

