-- pcb: requires udf_strSplit

set quoted_identifier on ;
set ansi_nulls on ;
go

use [master] ;
go

if exists (select 1 from INFORMATION_SCHEMA.ROUTINES where [routine_schema] = 'dbo' and [routine_name] = 'sp_getLoggedEvents')
	drop procedure dbo.[sp_getLoggedEvents] ;
go

create procedure dbo.[sp_getLoggedEvents] (
	@hours int = 24,
	@search varchar(1024),
	@important bit = 1,
	@verbose bit = 1
)
as
begin

set nocount, xact_abort on ;

-----------------------------------------------------------------------------------------------------------------------
-- Procedure:	sp_getLoggedEvents
-- Author:		Phillip Beazley (phillip@beazley.org)
-- Date:		07/18/2015
--
-- Purpose:		Searches through or just view SQL Server's error log.
--
-- Notes:		n/a
--
-- Depends:		Requires udf_strSplit.
--
-- REVISION HISTORY ---------------------------------------------------------------------------------------------------
-- 07/18/2015	lordbeazley	Last updated.
-----------------------------------------------------------------------------------------------------------------------

declare
	@log smallint,
	@earliest datetime,
	@sql nvarchar(max),
	@endTime datetime,
	@startTime datetime,
	@logCount int ;

set @log = -1 ;
set @endTime = getdate() ;
if (@hours is null)
	set @startTime = DateAdd(year, -10, @endTime) ;
else
	set @startTime = DateAdd(hour, (-1 * @hours), @endTime) ;
set @earliest = @endTime ;

declare @errors table (
	[id] int not null identity (1, 1),
	[dt] datetime not null,
	[source] varchar(50) not null,
	[line] varchar(4000) not null
) ;
declare @logs table (
	[id] int not null,
	[date] datetime not null,
	[size] int not null
) ;
insert into @logs exec sp_enumerrorlogs ;
select @logCount = Max([id]) from @logs ;

set @sql = ':: getting entries between ' + Convert(varchar, @startTime, 120) + ' and ' + Convert(varchar, @endTime, 120) ;
if (@verbose = 1) raiserror(@sql, 0, 1) with nowait ;

-- iterate through error logs and gather entries
while (@earliest > @startTime and @log < @logCount)
begin
	set @log = @log + 1 ;
	set @sql = ':: reading logfile #' + Convert(varchar, @log) ;
	if (@verbose = 1) raiserror(@sql, 0, 1) with nowait ;
	set @sql = N'exec sp_readerrorlog ' + Convert(nvarchar(3), @log) ;
	insert into @errors ([dt], [source], [line]) exec (@sql) ;
	select @earliest = Min([dt]) from @errors ;
end
if (@verbose = 1) raiserror(':: done reading', 0, 1) with nowait ;

-- purge errors outside our requested range
delete from @errors where [dt] is null or [dt] not between @startTime and @endTime ;

-- purge unimportant entries
if (@important = 1)
begin
	declare @keepers table ([word] varchar(64) not null) ;
	insert into @keepers
	select [word] = [val] from [udf_strSplit](',', 'err,errorlog,warn,kill,dead,cannot,could,or not,stop,terminate,bypass,roll,truncate,upgrade,victim,recover,taking longer,stack dump,fatal') ;
--	delete from @errors where [line] in (select distinct e.[line] from @errors [e], @keepers [i] where not PatIndex('%' + i.[word] + '%', e.[line]) > 0) ;
	select distinct e.[id], e.[dt], e.[line] from @errors [e], @keepers [i] where PatIndex('%' + i.[word] + '%', e.[line]) > 0 order by [id] asc
--	) ;
end

-- display remaining entries
select
	[id],
	[dt],
	[line]
from
	@errors
where
	@search is null
	or PatIndex('%' + @search + '%', [line]) > 0
order by
	[id] asc ;

end
go

exec sp_MS_marksystemobject 'sp_getLoggedEvents' ;
go
return ;

-- EXAMPLES

exec [sp_getLoggedEvents] @hours = 24, @search = null, @important = 1, @verbose = 1 ;
--exec [sp_getLoggedEvents] @hours = 24, @search = null, @important = 0, @verbose = 1 ;
--exec [sp_getLoggedEvents] @hours = 24, @search = 'dump', @important = 0, @verbose = 1 ;
--exec [sp_getLoggedEvents] @hours = null, @search = 'Server process ID is', @important = 0, @verbose = 1 ;
