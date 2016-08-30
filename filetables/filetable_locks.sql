exec sp_filestream_force_garbage_collection @dbname = 'YourFileTableDatabase' ;
go

select
	[handle_id],
	[file_object_type_desc],
	[state_desc],
	[current_workitem_type_desc],
	[dir] = [is_directory],
	[db] = [database_directory_name],
	[table] = [table_directory_name],
	[remaining_file_name],
	[open_time],
	[flags],
	[login_name],
	[read_access],
	[write_access],
	[delete_access],
	[share_read],
	[share_write],
	[share_delete],
	[create_disposition]
from
	sys.dm_filestream_non_transacted_handles ;
go

--exec sp_kill_filestream_non_transacted_handles ;
--exec sp_kill_filestream_non_transacted_handles @handle_id = 19954194 ;
