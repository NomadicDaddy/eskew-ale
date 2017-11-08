use [PartitionTesting] ;
go

--select * from sys.indexes where [name] like 'pk%' or [name] like 'ux%'  or [name] like 'ix%' ;
--select * from sys.filegroups ;
--select * from sys.partition_schemes ;
--select * from sys.destination_data_spaces ;

--:connect ud
--use [DM_Insight] ;
--go

-- WITH C AS ( SELECT ps.data_space_id
--, f.name
--, d.physical_name
--FROM sys.filegroups f
--JOIN sys.database_files d ON d.data_space_id = f.data_space_id
--JOIN sys.destination_data_spaces dds ON dds.data_space_id = f.data_space_id
--JOIN sys.partition_schemes ps ON ps.data_space_id = dds.partition_scheme_id
--UNION
--SELECT f.data_space_id
--, f.name
--, d.physical_name
--FROM sys.filegroups f
--JOIN sys.database_files d ON d.data_space_id = f.data_space_id
--)
--SELECT [ObjectName] = OBJECT_NAME(i.[object_id])
--, [IndexID] = i.[index_id]
--, [IndexName] = i.[name]
--, [IndexType] = i.[type_desc]
--, [Partitioned] = CASE WHEN ps.data_space_id IS NULL THEN 'No'
--ELSE 'Yes'
--END
--, [StorageName] = ISNULL(ps.name, f.name)
--, [FileGroupPaths] = CAST(( SELECT name AS "FileGroup", physical_name AS "DatabaseFile" FROM C WHERE i.data_space_id = c.data_space_id FOR XML PATH('') ) AS XML)
--FROM [sys].[indexes] i
--LEFT JOIN sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
--LEFT JOIN sys.filegroups f ON f.data_space_id = i.data_space_id
--WHERE OBJECTPROPERTY(i.[object_id], 'IsUserTable') = 1
--ORDER BY [ObjectName], [IndexName] ;
--go

with [df] as (
	select
		ps.[data_space_id],
		fg.[name],
		df.[physical_name]
	from
		sys.filegroups [fg]
		inner join sys.database_files [df] on fg.[data_space_id] = df.[data_space_id]
		inner join sys.destination_data_spaces [dds] on fg.[data_space_id] = dds.[data_space_id]
		inner join sys.partition_schemes [ps] on dds.[partition_scheme_id] = ps.[data_space_id]
	union
	select
		fg.[data_space_id],
		fg.[name],
		df.[physical_name]
	from
		sys.filegroups [fg]
		inner join sys.database_files [df] on fg.[data_space_id] = df.[data_space_id]
)
select
	[schema] = object_schema_name(i.[object_id]),
	[table_name] = object_name(i.[object_id]),
	[index_id] = i.[index_id],
	[index_name] = i.[name],
	[index_type] = i.[type_desc],
	[partitioned] = case when ps.[data_space_id] is null then 'no' else 'yes' end,
	df.[data_space_id],
	[data_space_id] = case when ps.[data_space_id] is null then df.[data_space_id] else ps.[data_space_id] end,
	[filename] = case when ps.[data_space_id] is null then df.[name] else ps.[name] end,
	[file] = df.[physical_name]
from
	sys.indexes [i]
	left outer join sys.partition_schemes [ps] on i.[data_space_id] = ps.[data_space_id]
	left outer join sys.filegroups [fg] on i.[data_space_id] = fg.[data_space_id]
	left outer join [df] on fg.[data_space_id] = df.[data_space_id]
	left outer join sys.database_files [dbf] on ps.[data_space_id] = dbf.[data_space_id]
where
	ObjectProperty(i.[object_id], 'IsUserTable') = 1
--	and df.[data_space_id] = Coalesce(ps.[data_space_id], fg.[data_space_id])
order by
--	df.[name] asc,
	object_name(i.[object_id]) asc,
	i.[name] asc
--	i.[data_space_id] asc ;
go

use [master] ;
go

