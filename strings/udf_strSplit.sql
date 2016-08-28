set quoted_identifier on ;
set ansi_nulls on ;
go

use [master] ;
go

if exists (select 1 from INFORMATION_SCHEMA.ROUTINES where [routine_schema] = 'dbo' and [routine_name] = 'udf_strSplit')
	drop function dbo.[udf_strSplit] ;
go

create function dbo.[udf_strSplit] (
	@delimiter varchar(32),
	@str varchar(max)
)
returns @t table ([val] varchar(32))
as
begin
	declare @xml xml ;
	set @xml = N'<root><r>' + Replace(@str, @delimiter, '</r><r>') + '</r></root>' ;
	insert into @t ([val])
	select [item] = [r].value('.', 'varchar(32)') from @xml.nodes('//root/r') as records (r)
	return
end
go

grant select on dbo.[udf_strSplit] to public ;
go
return ;

-- EXAMPLES

select * from [udf_strSplit](',', 'funky,town') ;
select * from master..udf_strSplit(':', Convert(varchar(24), getdate(), 114)) ;
go
