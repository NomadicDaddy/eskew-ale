------------------------------------------------------------------------------------------------------------------------------------------------
-- switching partitions between partitioned tables using same partition scheme
------------------------------------------------------------------------------------------------------------------------------------------------

-- switch prep (fgs:r/w, -indexes, compression:same, check constraint:same as partitioning boundary)
use [master] ;
go
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2011] read_write ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2012] read_write ;
--alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2013] read_write ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2014] read_write ;
go
use [PartitionTesting] ;
go
drop index [ux_OrderTracking_parByDate_OrderTrackingID] on dbo.[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2011_OrderTrackingID] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2011_EventDateTime] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2012_OrderTrackingID] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2012_EventDateTime] on [dbo].[OrderTracking_parByDate] ;
--drop index [ix_OrderTracking_parByDate_pf2013_OrderTrackingID] on [dbo].[OrderTracking_parByDate] ;
--drop index [ix_OrderTracking_parByDate_pf2013_EventDateTime] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2014_OrderTrackingID] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2014_EventDateTime] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2015_OrderTrackingID] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2015_EventDateTime] on [dbo].[OrderTracking_parByDate] ;
go

-- create target partitioned table on source filegroup
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2014] default ;
select * into [PartitionTesting].dbo.[OrderTracking_parByDate2] from [PartitionTesting].dbo.[OrderTracking_parByDate] where 1 = 0 ;
alter database [PartitionTesting] modify filegroup [PRIMARY] default ;
go

-- move data to partition using same function/scheme and same compression as source
alter table dbo.[OrderTracking_parByDate2] add constraint [pk_OrderTracking_parByDate_staging] primary key clustered ([OrderTrackingID] asc, [EventDateTime] asc) with (data_compression = page) on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
go

-- check counts
select [p#] = ps.[partition_number], [rc] = ps.[row_count] from sys.dm_db_partition_stats [ps] where ps.[object_id] = object_id('OrderTracking_parByDate') order by ps.[partition_number] asc ;
select [p#] = ps.[partition_number], [rc] = ps.[row_count] from sys.dm_db_partition_stats [ps] where ps.[object_id] = object_id('OrderTracking_parByDate2') order by ps.[partition_number] asc ;
select [target] = Count(*) from dbo.[OrderTracking_parByDate] where [EventDateTime] >= '2014-01-01 00:00:00.000' and [EventDateTime] < '2015-01-01 00:00:00.000' ;
select [source] = Count(*) from dbo.[OrderTracking_parByDate2] ;

-- switch to target partition
alter table dbo.[OrderTracking_parByDate] switch partition 4 to [OrderTracking_parByDate2] partition 4 ;
go

-- check counts
select [p#] = ps.[partition_number], [rc] = ps.[row_count] from sys.dm_db_partition_stats [ps] where ps.[object_id] = object_id('OrderTracking_parByDate') order by ps.[partition_number] asc ;
select [p#] = ps.[partition_number], [rc] = ps.[row_count] from sys.dm_db_partition_stats [ps] where ps.[object_id] = object_id('OrderTracking_parByDate2') order by ps.[partition_number] asc ;
select [target] = Count(*) from dbo.[OrderTracking_parByDate] where [EventDateTime] >= '2014-01-01 00:00:00.000' and [EventDateTime] < '2015-01-01 00:00:00.000' ;
select [source] = Count(*) from dbo.[OrderTracking_parByDate2] ;

-- cleanup
drop table dbo.[OrderTracking_parByDate2] ;
go

-- re-apply dropped indexes on target table
create unique nonclustered index [ux_OrderTracking_parByDate_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID]) on [PRIMARY] ;
create nonclustered index [ix_OrderTracking_parByDate_pf2011_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID] asc) where [EventDateTime] >= '2011-01-01 00:00:00.000' and [EventDateTime] < '2012-01-01 00:00:00.000' on [fg_OrderTracking_parByDate_2011] ;
create nonclustered index [ix_OrderTracking_parByDate_pf2011_EventDateTime] on dbo.[OrderTracking_parByDate] ([EventDateTime] asc) where [EventDateTime] >= '2011-01-01 00:00:00.000' and [EventDateTime] < '2012-01-01 00:00:00.000' on [fg_OrderTracking_parByDate_2011] ;
create nonclustered index [ix_OrderTracking_parByDate_pf2012_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID] asc) where [EventDateTime] >= '2012-01-01 00:00:00.000' and [EventDateTime] < '2013-01-01 00:00:00.000' on [fg_OrderTracking_parByDate_2012] ;
create nonclustered index [ix_OrderTracking_parByDate_pf2012_EventDateTime] on dbo.[OrderTracking_parByDate] ([EventDateTime] asc) where [EventDateTime] >= '2012-01-01 00:00:00.000' and [EventDateTime] < '2013-01-01 00:00:00.000' on [fg_OrderTracking_parByDate_2012] ;
--create nonclustered index [ix_OrderTracking_parByDate_pf2013_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID] asc) where [EventDateTime] >= '2013-01-01 00:00:00.000' and [EventDateTime] < '2014-01-01 00:00:00.000' on [fg_OrderTracking_parByDate_2013] ;
--create nonclustered index [ix_OrderTracking_parByDate_pf2013_EventDateTime] on dbo.[OrderTracking_parByDate] ([EventDateTime] asc) where [EventDateTime] >= '2013-01-01 00:00:00.000' and [EventDateTime] < '2014-01-01 00:00:00.000' on [fg_OrderTracking_parByDate_2013] ;
create nonclustered index [ix_OrderTracking_parByDate_pf2014_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID] asc) where [EventDateTime] >= '2014-01-01 00:00:00.000' and [EventDateTime] < '2015-01-01 00:00:00.000' on [fg_OrderTracking_parByDate_2014] ;
create nonclustered index [ix_OrderTracking_parByDate_pf2014_EventDateTime] on dbo.[OrderTracking_parByDate] ([EventDateTime] asc) where [EventDateTime] >= '2014-01-01 00:00:00.000' and [EventDateTime] < '2015-01-01 00:00:00.000' on [fg_OrderTracking_parByDate_2014] ;
create nonclustered index [ix_OrderTracking_parByDate_pf2015_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID] asc) where [EventDateTime] >= '2015-01-01 00:00:00.000' and [EventDateTime] < '2016-01-01 00:00:00.000' on [fg_OrderTracking_parByDate_2015] ;
create nonclustered index [ix_OrderTracking_parByDate_pf2015_EventDateTime] on dbo.[OrderTracking_parByDate] ([EventDateTime] asc) where [EventDateTime] >= '2015-01-01 00:00:00.000' and [EventDateTime] < '2016-01-01 00:00:00.000' on [fg_OrderTracking_parByDate_2015] ;
go

-- re-lock previously read-only partitions
use [master] ;
go
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2011] read_only ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2012] read_only ;
--alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2013] read_only ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2014] read_only ;
go
