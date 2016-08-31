exec master..sp_configure 'show advanced options', 1 ;
go
reconfigure with override ;
go
exec master..sp_configure 'contained database authentication', 1/0 ;
go
reconfigure with override ;
go
exec master..sp_configure 'show advanced options', 0 ;
go
reconfigure with override ;
go
