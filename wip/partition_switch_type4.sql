------------------------------------------------------------------------------------------------------------------------------------------------
-- switching partitions between partitioned tables using same partition scheme
------------------------------------------------------------------------------------------------------------------------------------------------

-- switch prep (fgs:r/w, -indexes, compression:same, check constraint:same as partitioning boundary)
use [master] ;
go
alter database [PartitionTesting] modify filegroup [fg_GapOffer_parByDate_2012] read_write ;
alter database [PartitionTesting] modify filegroup [fg_GapOffer_parByDate_2013] read_write ;
--alter database [PartitionTesting] modify filegroup [fg_GapOffer_parByDate_2014] read_write ;
alter database [PartitionTesting] modify filegroup [fg_GapOffer_parByDate_2015] read_write ;
go
use [PartitionTesting] ;
go
drop index [ux_GapOffer_parByDate_GapOfferID] on dbo.[GapOffer_parByDate] ;
drop index [ix_GapOffer_parByDate_pf2012_ApplicationId] on [dbo].[GapOffer_parByDate] ;
drop index [ix_GapOffer_parByDate_pf2012_dCreated] on [dbo].[GapOffer_parByDate] ;
drop index [ix_GapOffer_parByDate_pf2013_ApplicationId] on [dbo].[GapOffer_parByDate] ;
drop index [ix_GapOffer_parByDate_pf2013_dCreated] on [dbo].[GapOffer_parByDate] ;
--drop index [ix_GapOffer_parByDate_pf2014_ApplicationId] on [dbo].[GapOffer_parByDate] ;
--drop index [ix_GapOffer_parByDate_pf2014_dCreated] on [dbo].[GapOffer_parByDate] ;
drop index [ix_GapOffer_parByDate_pf2015_ApplicationId] on [dbo].[GapOffer_parByDate] ;
drop index [ix_GapOffer_parByDate_pf2015_dCreated] on [dbo].[GapOffer_parByDate] ;
drop index [ix_GapOffer_parByDate_pf2016_ApplicationId] on [dbo].[GapOffer_parByDate] ;
drop index [ix_GapOffer_parByDate_pf2016_dCreated] on [dbo].[GapOffer_parByDate] ;
go

-- create target partitioned table on source filegroup
alter database [PartitionTesting] modify filegroup [fg_GapOffer_parByDate_2015] default ;
select * into [PartitionTesting].dbo.[GapOffer_parByDate2] from [PartitionTesting].dbo.[GapOffer_parByDate] where 1 = 0 ;
alter database [PartitionTesting] modify filegroup [PRIMARY] default ;
go

-- check counts
select [p#] = ps.[partition_number], [rc] = ps.[row_count] from sys.dm_db_partition_stats [ps] where ps.[object_id] = object_id('GapOffer_parByDate') order by ps.[partition_number] asc ;
select [p#] = ps.[partition_number], [rc] = ps.[row_count] from sys.dm_db_partition_stats [ps] where ps.[object_id] = object_id('GapOffer_parByDate2') order by ps.[partition_number] asc ;
select Count(*) from dbo.[GapOffer_parByDate] where [dCreated] >= '2015-01-01 00:00:00.000' and [dCreated] < '2016-01-01 00:00:00.000' ;
select Count(*) from dbo.[GapOffer_parByDate2] ;

-- move data to partition using same function/scheme and same compression as source
alter table dbo.[GapOffer_parByDate2] add constraint [pk_GapOffer_parByDate_staging] primary key clustered ([GapOfferID] asc, [dCreated] asc) with (data_compression = page) on [ps_GapOffer_parByDate] ([dCreated]) ;
go

-- check counts
select [p#] = ps.[partition_number], [rc] = ps.[row_count] from sys.dm_db_partition_stats [ps] where ps.[object_id] = object_id('GapOffer_parByDate') order by ps.[partition_number] asc ;
select Count(*) from dbo.[GapOffer_parByDate] where [dCreated] >= '2015-01-01 00:00:00.000' and [dCreated] < '2016-01-01 00:00:00.000' ;
select Count(*) from dbo.[GapOffer_parByDate2] ;

-- switch to target partition
alter table dbo.[GapOffer_parByDate] switch partition 4 to [GapOffer_parByDate2] partition 4 ;
go

-- check counts
select [p#] = ps.[partition_number], [rc] = ps.[row_count] from sys.dm_db_partition_stats [ps] where ps.[object_id] = object_id('GapOffer_parByDate') order by ps.[partition_number] asc ;
select [p#] = ps.[partition_number], [rc] = ps.[row_count] from sys.dm_db_partition_stats [ps] where ps.[object_id] = object_id('GapOffer_parByDate2') order by ps.[partition_number] asc ;
select Count(*) from dbo.[GapOffer_parByDate] where [dCreated] >= '2015-01-01 00:00:00.000' and [dCreated] < '2016-01-01 00:00:00.000' ;
select Count(*) from dbo.[GapOffer_parByDate2] ;

-- cleanup
drop table dbo.[GapOffer_parByDate2] ;
go

-- re-apply dropped indexes on target table
create unique nonclustered index [ux_GapOffer_parByDate_GapOfferID] on dbo.[GapOffer_parByDate] ([GapOfferID]) on [PRIMARY] ;
create nonclustered index [ix_GapOffer_parByDate_pf2012_ApplicationId] on dbo.[GapOffer_parByDate] ([ApplicationId] asc) where [dCreated] >= '2012-01-01 00:00:00.000' and [dCreated] < '2013-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2012] ;
create nonclustered index [ix_GapOffer_parByDate_pf2012_dCreated] on dbo.[GapOffer_parByDate] ([dCreated] asc) where [dCreated] >= '2012-01-01 00:00:00.000' and [dCreated] < '2013-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2012] ;
create nonclustered index [ix_GapOffer_parByDate_pf2013_ApplicationId] on dbo.[GapOffer_parByDate] ([ApplicationId] asc) where [dCreated] >= '2013-01-01 00:00:00.000' and [dCreated] < '2014-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2013] ;
create nonclustered index [ix_GapOffer_parByDate_pf2013_dCreated] on dbo.[GapOffer_parByDate] ([dCreated] asc) where [dCreated] >= '2013-01-01 00:00:00.000' and [dCreated] < '2014-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2013] ;
--create nonclustered index [ix_GapOffer_parByDate_pf2014_ApplicationId] on dbo.[GapOffer_parByDate] ([ApplicationId] asc) where [dCreated] >= '2014-01-01 00:00:00.000' and [dCreated] < '2015-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2014] ;
--create nonclustered index [ix_GapOffer_parByDate_pf2014_dCreated] on dbo.[GapOffer_parByDate] ([dCreated] asc) where [dCreated] >= '2014-01-01 00:00:00.000' and [dCreated] < '2015-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2014] ;
create nonclustered index [ix_GapOffer_parByDate_pf2015_ApplicationId] on dbo.[GapOffer_parByDate] ([ApplicationId] asc) where [dCreated] >= '2015-01-01 00:00:00.000' and [dCreated] < '2016-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2015] ;
create nonclustered index [ix_GapOffer_parByDate_pf2015_dCreated] on dbo.[GapOffer_parByDate] ([dCreated] asc) where [dCreated] >= '2015-01-01 00:00:00.000' and [dCreated] < '2016-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2015] ;
create nonclustered index [ix_GapOffer_parByDate_pf2016_ApplicationId] on dbo.[GapOffer_parByDate] ([ApplicationId] asc) where [dCreated] >= '2016-01-01 00:00:00.000' and [dCreated] < '2017-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2016] ;
create nonclustered index [ix_GapOffer_parByDate_pf2016_dCreated] on dbo.[GapOffer_parByDate] ([dCreated] asc) where [dCreated] >= '2016-01-01 00:00:00.000' and [dCreated] < '2017-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2016] ;
go

-- re-lock previously read-only partitions
use [master] ;
go
alter database [PartitionTesting] modify filegroup [fg_GapOffer_parByDate_2012] read_only ;
alter database [PartitionTesting] modify filegroup [fg_GapOffer_parByDate_2013] read_only ;
--alter database [PartitionTesting] modify filegroup [fg_GapOffer_parByDate_2014] read_only ;
alter database [PartitionTesting] modify filegroup [fg_GapOffer_parByDate_2015] read_only ;
go
