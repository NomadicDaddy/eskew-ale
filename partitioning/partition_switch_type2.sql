------------------------------------------------------------------------------------------------------------------------------------------------
-- switching in a new partition (e.g. reloading 2014 data)
------------------------------------------------------------------------------------------------------------------------------------------------

-- switch prep (fgs:r/w, -indexes, compression:same, check constraint:same as partitioning boundary for target)

use [master] ;
go
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2011] read_write ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2012] read_write ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2013] read_write ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2014] read_write ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2015] read_write ;
go

use [PartitionTesting] ;
go
drop index [ux_OrderTracking_parByDate_OrderTrackingID] on dbo.[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2011_OrderTrackingID] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2011_EventDateTime] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2012_OrderTrackingID] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2012_EventDateTime] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2013_OrderTrackingID] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2013_EventDateTime] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2014_OrderTrackingID] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2014_EventDateTime] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2015_OrderTrackingID] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2015_EventDateTime] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2016_OrderTrackingID] on [dbo].[OrderTracking_parByDate] ;
drop index [ix_OrderTracking_parByDate_pf2016_EventDateTime] on [dbo].[OrderTracking_parByDate] ;
go

-- create empty staging table on target filegroup to hold the data we're switching in
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2014] default ;
select * into [PartitionTesting].dbo.[OrderTracking_parByDate_staging] from [PartitionTesting].dbo.[OrderTracking_parByDate] where 1 = 0 ;
alter database [PartitionTesting] modify filegroup [PRIMARY] default ;
go

-- set compression and matching constraint
alter table dbo.[OrderTracking_parByDate_staging] add constraint [pk_OrderTracking_parByDate_staging] primary key clustered ([OrderTrackingID] asc, [EventDateTime] asc) with (data_compression = page) ;
alter table dbo.[OrderTracking_parByDate_staging] with check add constraint [matchRange] check ([EventDateTime] >= '2014-01-01 00:00:00.000' and [EventDateTime] <= '2014-12-31 23:59:59.9999999') ;
create unique nonclustered index [ux_OrderTracking_parByDate_staging] on dbo.[OrderTracking_parByDate_staging] ([OrderTrackingID]) ;
go

-- load staging table
set identity_insert [PartitionTesting].dbo.[OrderTracking_parByDate_staging] on ;
insert into [PartitionTesting].dbo.[OrderTracking_parByDate_staging] (OrderTrackingID, SalesOrderID, CarrierTrackingNumber, TrackingEventID, EventDetails, EventDateTime)
select * from AdventureWorks.Sales.[OrderTracking] where [EventDateTime] >= '2014-01-01 00:00:00.000' and [EventDateTime] < '2014-04-01 00:00:00.000' ;
set identity_insert [PartitionTesting].dbo.[OrderTracking_parByDate_staging] off ;
go

-- check counts
select [p#] = ps.[partition_number], [rc] = ps.[row_count] from sys.dm_db_partition_stats [ps] where ps.[object_id] = object_id('OrderTracking_parByDate') order by ps.[partition_number] asc ;
select [target] = Count(*) from dbo.[OrderTracking_parByDate] where [EventDateTime] >= '2014-01-01 00:00:00.000' and [EventDateTime] <= '2014-12-31 23:59:59.9999999' ;
select [source] = Count(*) from dbo.[OrderTracking_parByDate_staging] ;

-- empty target partition
delete from dbo.[OrderTracking_parByDate] where [EventDateTime] >= '2014-01-01 00:00:00.000' and [EventDateTime] <= '2014-12-31 23:59:59.9999999' ;

-- switch to target partition
alter table dbo.[OrderTracking_parByDate_staging] switch to [OrderTracking_parByDate] partition 4 ;
go

-- check counts
select [p#] = ps.[partition_number], [rc] = ps.[row_count] from sys.dm_db_partition_stats [ps] where ps.[object_id] = object_id('OrderTracking_parByDate') order by ps.[partition_number] asc ;
select [target] = Count(*) from dbo.[OrderTracking_parByDate] where [EventDateTime] >= '2014-01-01 00:00:00.000' and [EventDateTime] <= '2014-12-31 23:59:59.9999999' ;
select [source] = Count(*) from dbo.[OrderTracking_parByDate_staging] ;

-- cleanup
drop table dbo.[OrderTracking_parByDate_staging] ;
go

-- re-apply dropped indexes on target table (was: on [fg_OrderTracking_parByDate_20XX], now: on ps)
create unique nonclustered index [ux_OrderTracking_parByDate_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID]) on [PRIMARY] ;
create nonclustered index [ix_OrderTracking_parByDate_pf2011_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID] asc) where [EventDateTime] >= '2011-01-01 00:00:00.000' and [EventDateTime] <= '2011-12-31 23:59:59.9999999' on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
create nonclustered index [ix_OrderTracking_parByDate_pf2011_EventDateTime] on dbo.[OrderTracking_parByDate] ([EventDateTime] asc) where [EventDateTime] >= '2011-01-01 00:00:00.000' and [EventDateTime] <= '2011-12-31 23:59:59.9999999' on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
create nonclustered index [ix_OrderTracking_parByDate_pf2012_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID] asc) where [EventDateTime] >= '2012-01-01 00:00:00.000' and [EventDateTime] <= '2012-12-31 23:59:59.9999999' on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
create nonclustered index [ix_OrderTracking_parByDate_pf2012_EventDateTime] on dbo.[OrderTracking_parByDate] ([EventDateTime] asc) where [EventDateTime] >= '2012-01-01 00:00:00.000' and [EventDateTime] <= '2012-12-31 23:59:59.9999999' on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
create nonclustered index [ix_OrderTracking_parByDate_pf2013_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID] asc) where [EventDateTime] >= '2013-01-01 00:00:00.000' and [EventDateTime] <= '2013-12-31 23:59:59.9999999' on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
create nonclustered index [ix_OrderTracking_parByDate_pf2013_EventDateTime] on dbo.[OrderTracking_parByDate] ([EventDateTime] asc) where [EventDateTime] >= '2013-01-01 00:00:00.000' and [EventDateTime] <= '2013-12-31 23:59:59.9999999' on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
create nonclustered index [ix_OrderTracking_parByDate_pf2014_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID] asc) where [EventDateTime] >= '2014-01-01 00:00:00.000' and [EventDateTime] <= '2014-12-31 23:59:59.9999999' on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
create nonclustered index [ix_OrderTracking_parByDate_pf2014_EventDateTime] on dbo.[OrderTracking_parByDate] ([EventDateTime] asc) where [EventDateTime] >= '2014-01-01 00:00:00.000' and [EventDateTime] <= '2014-12-31 23:59:59.9999999' on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
create nonclustered index [ix_OrderTracking_parByDate_pf2015_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID] asc) where [EventDateTime] >= '2015-01-01 00:00:00.000' and [EventDateTime] <= '2015-12-31 23:59:59.9999999' on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
create nonclustered index [ix_OrderTracking_parByDate_pf2015_EventDateTime] on dbo.[OrderTracking_parByDate] ([EventDateTime] asc) where [EventDateTime] >= '2015-01-01 00:00:00.000' and [EventDateTime] <= '2015-12-31 23:59:59.9999999' on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
create nonclustered index [ix_OrderTracking_parByDate_pf2016_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID] asc) where [EventDateTime] >= '2016-01-01 00:00:00.000' and [EventDateTime] <= '2016-12-31 23:59:59.9999999' on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
create nonclustered index [ix_OrderTracking_parByDate_pf2016_EventDateTime] on dbo.[OrderTracking_parByDate] ([EventDateTime] asc) where [EventDateTime] >= '2016-01-01 00:00:00.000' and [EventDateTime] <= '2016-12-31 23:59:59.9999999' on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
go

-- re-lock previously read-only partitions
use [master] ;
go
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2011] read_only ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2012] read_only ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2013] read_only ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2014] read_only ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2015] read_only ;
go
