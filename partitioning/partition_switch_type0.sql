------------------------------------------------------------------------------------------------------------------------------------------------
-- type 0: adding a new filegroup for an upcoming new year
-- useful for adding additional filegroup/file/range (not a true switch function)													(expanding)
------------------------------------------------------------------------------------------------------------------------------------------------

use [master] ;
go

-- unset read-only partitions to allow partitioning changes
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2011] read_write ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2012] read_write ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2013] read_write ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2014] read_write ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2015] read_write ;

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
alter partition function [pf_OrderTracking_parByDate] () split range ('2016-12-31 23:59:59.9999999') ;
go

-- create new filtered NCIs for new partition (was: on [fg_OrderTracking_parByDate_20XX], now: on ps)
create nonclustered index [ix_OrderTracking_parByDate_pf2016_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID] asc) where [EventDateTime] >= '2016-01-01 00:00:00.000' and [EventDateTime] <= '2016-12-31 23:59:59.9999999' on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
create nonclustered index [ix_OrderTracking_parByDate_pf2016_EventDateTime] on dbo.[OrderTracking_parByDate] ([EventDateTime] asc) where [EventDateTime] >= '2016-01-01 00:00:00.000' and [EventDateTime] <= '2016-12-31 23:59:59.9999999' on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
go

-- reset read-only partitions
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2011] read_only ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2012] read_only ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2013] read_only ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2014] read_only ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2015] read_only ;
go
