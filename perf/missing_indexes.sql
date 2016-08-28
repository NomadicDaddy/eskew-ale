select
	[schema] = s.[name],
	[table] = o.[name],
	[missedOps] = migs.[user_seeks] + migs.[user_scans],
	[x] = 'x',
	[impactPerOp] = migs.[avg_total_user_cost] * (migs.[avg_user_impact] / 100.0),
	[=] = '=',
	[improvement] = Round(migs.[avg_total_user_cost] * (migs.[avg_user_impact] / 100.0) * (migs.[user_seeks] + migs.[user_scans]), 2),
	[missingIndexCreator] =
		'create nonclustered index [ix_' + s.[name] + '.' + o.[name] + '_' + IsNull(Replace(Replace(Replace(mid.[equality_columns], ', ', '_'), '[', ''), ']', ''), '') + 
		case
			when mid.[equality_columns] is not null and mid.[inequality_columns] is not null then '_'
			else ''
		end +
		IsNull(Replace(Replace(Replace(mid.[inequality_columns], ', ', '_'), '[', ''), ']', ''), '') +
		IIf(mid.[included_columns] is not null, '+', '') +
		']' +
		' on ' + mid.[statement] +
		' (' + IsNull(mid.[equality_columns], '') +
		case
			when mid.[equality_columns] is not null and mid.[inequality_columns] is not null then ','
			else ''
		end +
		IsNull(mid.[inequality_columns], '') +
		')'  + IsNull(' include (' + mid.[included_columns] + ')', '')
		+ ' ;'
from
	sys.dm_db_missing_index_groups [mig]
	inner join sys.dm_db_missing_index_group_stats [migs] on mig.[index_group_handle] = migs.[group_handle]
	inner join sys.dm_db_missing_index_details [mid] on mig.[index_handle] = mid.[index_handle] and mid.[database_id] = db_id()
	inner join sys.objects [o] on mid.[object_id] = o.[object_id]
	inner join sys.schemas [s] on o.[schema_id] = s.[schema_id]
where
	migs.[avg_total_user_cost] * (migs.[avg_user_impact] / 100.0) * (migs.[user_seeks] + migs.[user_scans]) > 10
order by
	mid.[database_id] asc,
	migs.[avg_total_user_cost] * (migs.[avg_user_impact] / 100.0) * (migs.[user_seeks] + migs.[user_scans]) desc ;
go
