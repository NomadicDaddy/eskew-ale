-- get service account sql is running as
declare @service_account nvarchar(128) ;
if (Convert(nvarchar(128), serverproperty('servername')) like '%\%')
	set @service_account = 'MSSQL$' + Right(Convert(nvarchar(128), serverproperty('servername')), Len(Convert(nvarchar(128), serverproperty('servername'))) - CharIndex('\', Convert(nvarchar(128), serverproperty('servername')), 1)) ;
else
	set @service_account = 'MSSQLSERVER' ;
declare @kv nvarchar(128) = 'SYSTEM\CurrentControlSet\Services\' + @service_account ;
exec master..xp_regread 'HKEY_LOCAL_MACHINE', @kv, 'ObjectName', @service_account output ;
select [service_account] = @service_account ;

-- or --

select [service_account] from sys.dm_server_services where [servicename] = 'SQL Server (MSSQLSERVER)' ;
