declare @searchPath nvarchar(128) = '' ;

select
	[File Path] = ft.[file_stream].GetFileNamespacePath(1, 0),
	[Category] = IIf(ft.[is_directory] = 1, 'Directory', 'Files'),
	[Type] = ft.[file_type],
	[File Size (KB)] = ft.[cached_file_size] / 1024.0,
	[Created Time] = ft.[creation_time],
	ft.[Name],
	[Parent Path] = Coalesce(pt.[file_stream].GetFileNamespacePath(1, 0), 'Root Directory')
from
	dbo.[YourFileTable] [ft]
	left outer join dbo.[YourFileTable] [pt] on ft.[path_locator].GetAncestor(1) = pt.[path_locator]
where
	(
		Coalesce(@searchPath, '') = ''
		or ft.[file_stream].GetFileNamespacePath(1, 0) like '%' + @searchPath + '%'
	)
order by
	ft.[File Path] asc ;
go
