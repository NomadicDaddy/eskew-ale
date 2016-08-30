------------------------------------------------------------------------------------------------------------------------------------------------
-- adding a new filegroup for an upcoming new year
------------------------------------------------------------------------------------------------------------------------------------------------

-- do this one last (so you don't have to add 2016 to the other demos!)

use [master] ;
go

-- add new filegroup
alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByDate_2016] ;
go

-- add new file
declare @dfpath nvarchar(512) ;
exec xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', @dfpath output, no_output ;
exec('
alter database [PartitionTesting]
	add file (name = N''PartitionTesting_OrderTracking_parByDate_pf2016'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByDate_pf2016.ndf'', size = 5MB, filegrowth = 5MB)
	to filegroup [fg_OrderTracking_parByDate_2016] ;') ;
go

use [PartitionTesting] ;
go

-- expand the scheme to include the new partition
alter partition scheme [ps_OrderTracking_parByDate] next used [fg_OrderTracking_parByDate_2016] ;
go

-- add new range bucket to function
alter partition function [pf_OrderTracking_parByDate] () split range ('20160101') ;
go

-- create new filtered NCIs for new partition
create nonclustered index [ix_OrderTracking_parByDate_pf2016_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID] asc) where [EventDateTime] >= '2016-01-01 00:00:00.000' and [EventDateTime] < '2017-01-01 00:00:00.000' on [fg_OrderTracking_parByDate_2016] ;
create nonclustered index [ix_OrderTracking_parByDate_pf2016_EventDateTime] on dbo.[OrderTracking_parByDate] ([EventDateTime] asc) where [EventDateTime] >= '2016-01-01 00:00:00.000' and [EventDateTime] < '2017-01-01 00:00:00.000' on [fg_OrderTracking_parByDate_2016] ;
go
