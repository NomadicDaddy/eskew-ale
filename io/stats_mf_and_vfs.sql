select
	[database] = db_name(mf.[database_id]),
	mf.[name],
	mf.[physical_name],
	[size_mb] = mf.[size] / 128,
	vfs.[TimeStamp],
	vfs.[BytesRead],
	vfs.[BytesWritten],
	vfs.[IoStallMS],
	vfs.[IoStallReadMS],
	vfs.[IoStallWriteMS],
	vfs.[NumberReads],
	vfs.[NumberWrites]
from
	fn_virtualfilestats(null, null) [vfs]
	inner join sys.master_files [mf] on vfs.[dbid] = mf.[database_id]
		and vfs.[fileid] = mf.[file_id]
order by
	[database] asc,
	mf.[name] asc ;