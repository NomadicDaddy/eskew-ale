select
	s.[server_id],
	s.[name],
	s.[product],
	s.[provider],
	[target] = s.[data_source],
	[linked] = s.[is_linked],
	[rlogin] = s.[is_remote_login_enabled],
	[rpcout] = s.[is_rpc_out_enabled],
	[data_access] = s.[is_data_access_enabled],
	[server_dt] = s.[modify_date],
	[self] = l.[uses_self_credential],
	l.[remote_name],
	[login_dt] = l.[modify_date]
from
	sys.servers s
	left outer join sys.linked_logins [l] on s.[server_id] = l.[server_id]
order by
	s.[name] asc ;
go

select * from sys.servers
select * from sys.linked_logins
