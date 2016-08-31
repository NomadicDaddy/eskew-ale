set nocount on ;

declare @output table ([output] varchar(8000)) ;
insert into @output exec('xp_cmdshell ''whoami /priv''') ;
if exists (select 1 from @output where [output] like '%SeManageVolumePrivilege%' and [output] like '%Enabled%') 
	raiserror('Instant Initialization is enabled.', 0, 1) with nowait
else
	raiserror('Instant Initialization is not enabled. Missing required "Perform volume maintenance tasks" right or SE_MANAGE_VOLUME_NAME permission.', 0, 1) with nowait ; 
go
