use [msdb] ;
go

set nocount, quoted_identifier, ansi_nulls, xact_abort on ;

declare
	@operator nvarchar(128) = 'DBA',
	@email nvarchar(128) = 'phillip@beazley.org' ;

begin transaction ;

declare @rc int = 0 ;

-- add operator
if not exists (select 1 from msdb.dbo.sysoperators where [name] = @operator)
begin

	exec @rc = msdb.dbo.[sp_add_operator]
		@name = @operator,
		@enabled = 1,
		@weekday_pager_start_time = 0,
		@weekday_pager_end_time = 235959,
		@saturday_pager_start_time = 0,
		@saturday_pager_end_time = 235959,
		@sunday_pager_start_time = 0,
		@sunday_pager_end_time = 235959,
		@pager_days = 0,
		@pager_address = null,
		@email_address = @email,
		@category_name = N'[Uncategorized]',
		@netsend_address = null ;

	if (@@error <> 0 or @rc <> 0)
		goto abortTransaction ;
	else
		print 'Added operator ''' + @operator + '''.' ;

end
else
begin

	exec @rc = msdb.dbo.sp_update_operator
		@name = @operator,
		@enabled = 1,
		@weekday_pager_start_time = 0,
		@weekday_pager_end_time = 235959,
		@saturday_pager_start_time = 0,
		@saturday_pager_end_time = 235959,
		@sunday_pager_start_time = 0,
		@sunday_pager_end_time = 235959,
		@pager_days = 0,
		@email_address = @email,
		@pager_address = null,
		@netsend_address = null ;

	if (@@error <> 0 or @rc <> 0)
		goto abortTransaction ;
	else
		print 'Updated operator ''' + @operator + '''.' ;

end

-- set alert fail-safe address
declare @inSS nvarchar(128) ;
exec xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\\Microsoft SQL Server\\Instance Names\SQL\', N'MSSQLSERVER', @inSS output ;
declare @key nvarchar(255) = N'SOFTWARE\Microsoft\\Microsoft SQL Server\\' + @inSS + N'\SQLServerAgent' ;
exec xp_instance_regwrite N'HKEY_LOCAL_MACHINE', @key, N'AlertFailSafeEmailAddress', REG_SZ, @email ;
exec master..sp_MSsetalertinfo @failsafeoperator = @operator, @notificationmethod = 1 ;
declare @default_profile nvarchar(128) = (select sp.[name] from msdb.dbo.sysmail_profile [sp] inner join msdb.dbo.sysmail_principalprofile [pp] on sp.[profile_id] = pp.[profile_id] and pp.[is_default] = 1) ;
exec msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder = 1, @databasemail_profile = @default_profile ;

commit transaction ;
goto setupComplete1 ;

abortTransaction:
    if (@@trancount > 0)
		rollback transaction ;

setupComplete1:
