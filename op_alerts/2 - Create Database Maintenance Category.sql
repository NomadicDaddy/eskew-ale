use [msdb] ;
go

set nocount, quoted_identifier, ansi_nulls, xact_abort on ;

begin transaction ;

declare @rc int = 0 ;

-- add maintenance category
if not exists (select 1 from msdb.dbo.syscategories where [name] = N'Database Maintenance' and [category_class] = 1)
begin

	exec @rc = msdb.dbo.[sp_add_category]
		@class = N'JOB',
		@type = N'LOCAL',
		@name = N'Database Maintenance' ;

	if (@@error <> 0 or @rc <> 0)
		goto abortTransaction ;
	else
		print 'Added job category ''Database Maintenance''.' ;

end

commit transaction ;
goto setupComplete2 ;

abortTransaction:
    if (@@trancount > 0)
		rollback transaction ;

setupComplete2:
