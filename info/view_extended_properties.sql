-- show all non-MS extended properties
select
	[Schema] = 
		case
			when ep.[class] = 1 then s.[name]
			when ep.[class] = 0 then db_name()
			when ep.[class] = 3 then (select [name] from sys.schemas where [schema_id] = ep.[major_id])
			when ep.[class] = 4 then (select [name] from sys.database_principals where [principal_id] = ep.[major_id])
			else s.[name]
		end,
	[Object] = 
		case
			when ep.[class] = 1 then o.[name]
			when ep.[class] = 0 then db_name()
			when ep.[class] = 3 then (select [name] from sys.schemas where [schema_id] = ep.[major_id])
			when ep.[class] = 4 then (select [name] from sys.database_principals where [principal_id] = ep.[major_id])
			else o.[name]
		end,
	ep.[class_desc],
	[Extended Property] = ep.[name],
	[Value] = ep.[value]
from
	sys.extended_properties [ep]
	left outer join sys.objects [o] on ep.[major_id] = o.[object_id]
	left outer join sys.schemas [s] on o.[schema_id] = s.[schema_id]
where
	ep.[name] not like 'MS_%'
	and ep.[name] <> 'microsoft_database_tools_support'
order by
	ep.[class] asc,
	s.[name] asc,
	o.[name] asc,
	ep.[name] asc ;
go

-- show MS extended properties
select
	[Schema] = 
		case
			when ep.[class] = 1 then s.[name]
			when ep.[class] = 0 then db_name()
			when ep.[class] = 3 then (select [name] from sys.schemas where [schema_id] = ep.[major_id])
			when ep.[class] = 4 then (select [name] from sys.database_principals where [principal_id] = ep.[major_id])
			else s.[name]
		end,
	[Object] = 
		case
			when ep.[class] = 1 then o.[name]
			when ep.[class] = 0 then db_name()
			when ep.[class] = 3 then (select [name] from sys.schemas where [schema_id] = ep.[major_id])
			when ep.[class] = 4 then (select [name] from sys.database_principals where [principal_id] = ep.[major_id])
			else o.[name]
		end,
	ep.[class_desc],
	[Extended Property] = ep.[name],
	[Value] = ep.[value]
from
	sys.extended_properties [ep]
	left outer join sys.objects [o] on ep.[major_id] = o.[object_id]
	left outer join sys.schemas [s] on o.[schema_id] = s.[schema_id]
where
	ep.[name] like 'MS_%'
	or ep.[name] = 'microsoft_database_tools_support'
order by
	ep.[class] asc,
	s.[name] asc,
	o.[name] asc,
	ep.[name] asc ;
go
