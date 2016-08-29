set quoted_identifier on ;
set ansi_nulls on ;
go

use [master] ;
go

if exists (select 1 from INFORMATION_SCHEMA.ROUTINES where [routine_schema] = 'dbo' and [routine_name] = 'sp_gradShrink')
	drop procedure dbo.[sp_gradShrink] ;
go

create procedure dbo.[sp_gradShrink] (
	@maxChunkSize int = 256,
	@targetFile nvarchar(128) = null
)
as
begin

set nocount, xact_abort on ;

-----------------------------------------------------------------------------------------------------------------------
-- Procedure:	sp_gradShrink
-- Author:		Phillip Beazley (phillip@beazley.org)
-- Date:		08/26/2016
--
-- Purpose:		Gradually shrinks the target file to minimize blocking and contention.
--
-- Notes:		n/a
--
-- Depends:		n/a
--
-- REVISION HISTORY ---------------------------------------------------------------------------------------------------
-- 08/26/2016	lordbeazley	Initial release.
-----------------------------------------------------------------------------------------------------------------------

if (@targetFile is null)
	select @targetFile = [name] from sys.database_files where [type] = 0 and [data_space_id] = 1 ;

declare @currentSize int = (select [size] / 128 from sys.database_files where [name] = @targetFile) ;
declare @targetSize int = (select Convert(int, fileproperty([name], 'SpaceUsed')) / 128 from sys.database_files where [name] = @targetFile) ;
declare @diff int = @currentSize - @targetSize ;
declare @chunkSize int = IIf((@diff / 4) > @maxChunkSize, @maxChunkSize, @diff / 4) ;
declare @try tinyint = 0 ;
declare @sql varchar(max) ;

raiserror ('   START SIZE : %6i', 0, 1, @currentSize) with nowait ;
raiserror ('  TARGET SIZE : %6i', 0, 1, @targetSize) with nowait ;
while (@currentSize > @targetSize and @currentSize - @chunkSize > 0 and @try < 4)
begin
	if (@try = 0)
	begin
		raiserror ('    CURRENTLY : %6i', 0, 1, @currentSize) with nowait ;
		set @sql = 'dbcc shrinkfile(' + QuoteName(@targetFile, '''') + ', 0, truncateonly) with no_infomsgs ;' ;
		raiserror ('!   EXECUTING : %s', 0, 1, @sql) with nowait ;
		exec sp_sqlexec @sql ;
		select @currentSize = [size] / 128 from sys.database_files where [name] = @targetFile ;
		set @try = 1 ;
	end
	raiserror ('    CURRENTLY : %6i', 0, 1, @currentSize) with nowait ;
	set @diff = @currentSize - @targetSize ;
	set @chunkSize = IIf((@diff / 4) > @maxChunkSize, @maxChunkSize, @diff / 4) ;
	if (@currentSize < @chunkSize or @chunkSize = 0) set @chunkSize = 1 ;
	raiserror ('         DIFF : %6i', 0, 1, @diff) with nowait ;
	raiserror ('    CHUNKSIZE : %6i', 0, 1, @chunkSize) with nowait ;
	set @sql = 'dbcc shrinkfile(' + QuoteName(@targetFile, '''') + ', ' + Convert(varchar, @currentSize - @chunkSize) + ') with no_infomsgs ;' ;
	if (@try > 1) raiserror ('        TRY # : %6i', 0, 1, @try) with nowait ;
	raiserror ('!   EXECUTING : %s', 0, 1, @sql) with nowait ;
	exec sp_sqlexec @sql ;
	if (@currentSize = (select [size] / 128 from sys.database_files where [name] = @targetFile))
		set @try = @try + 1
	else
		set @try = 1 ;
	select @currentSize = [size] / 128 from sys.database_files where [name] = @targetFile ;
end
raiserror ('   FINAL SIZE : %6i', 0, 1, @currentSize) with nowait ;

end
go

exec sp_MS_marksystemobject 'sp_gradShrink' ;
go
return ;

-- EXAMPLES

--exec [sp_gradShrink] ;
--exec [sp_gradShrink] @targetFile = 'thisdb_log' ;
--exec [sp_gradShrink] @maxChunkSize = 2048 ;
