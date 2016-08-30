declare @searchPath nvarchar(128) = '' ;
declare @searchContent nvarchar(2048) = '' ;

select
	[File Path] = ft.[file_stream].GetFileNamespacePath(1, 0),
	[Category] = IIf(ft.[is_directory] = 1, 'Directory', 'Files'),
	[Type] = ft.[file_type],
	[File Size (KB)] = ft.[cached_file_size] / 1024.0,
	[Created Time] = ft.[creation_time],
	ft.[Name],
	[Parent Path] = Coalesce(pt.[file_stream].GetFileNamespacePath(1, 0), 'Root Directory'),
	[Content] = Convert(nvarchar(max), ft.[file_stream])
from
	dbo.[YourFileTable] [ft]
	left outer join dbo.[YourFileTable] [pt] on ft.[path_locator].GetAncestor(1) = pt.[path_locator]
where
	(
		Coalesce(@searchPath, '') = ''
		or ft.[file_stream].GetFileNamespacePath(1, 0) like '%' + @searchPath + '%'
	)
	and
	(
		Coalesce(@searchContent, '') = ''
		or (ft.[is_directory] = 0 and Convert(nvarchar(max), ft.[file_stream]) like '%' + @searchContent + '%')
	)
order by
	ft.[File Path] asc ;
go
