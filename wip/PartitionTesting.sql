use [master] ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 1. Identify candidate table. For this demo, we're using a copy of GapOffer from the Credit database in a newly created test database (PartitionTesting). (~33s)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- drop existing test database
while (exists (select 1 from sys.databases where [name] = 'PartitionTesting'))
begin
	exec sp_sqlexec 'use [master] ; alter database [PartitionTesting] set offline with no_wait ;' ;
	exec sp_sqlexec 'use [master] ; drop database [PartitionTesting] ;' ;
end
exec xp_cmdshell 'del /F /Q E:\SQLData_ORIGINATIONS\PartitionTesting.mdf', no_output ;
exec xp_cmdshell 'del /F /Q D:\SQLLogs_ORIGINATIONS\PartitionTesting.ldf', no_output ;
exec xp_cmdshell 'del /F /Q E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_*.ndf', no_output ;
go

-- create testing database
create database [PartitionTesting] containment = none
	on primary (name = N'PartitionTesting', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting.mdf', size = 2048MB, filegrowth = 512MB)
	log on (name = N'PartitionTesting_log', filename = N'D:\SQLLogs_ORIGINATIONS\PartitionTesting.ldf', size = 128MB, filegrowth = 128MB) ;
go

-- populate tables for testing (just copying GapOffer from Credit database)
use [PartitionTesting] ;
select * into dbo.[GapOffer] from Credit.dbo.[GapOffer]  ;		-- original for comparison
select * into dbo.[GapOffer_parByDate] from dbo.[GapOffer] ;	-- version to be partitioned by date range (dCreated)
select * into dbo.[GapOffer_parByID] from dbo.[GapOffer] ;		-- version to be partitioned by list (last digit of GapOfferID)
go

-- fix dCreated date (just makes [dCreated] not nullable - partitioning column cannot contain nulls)
:r "C:\Users\pbeazley\Desktop\Partitioning\PartitionTesting_fixdate.sql"
go

-- create PKs to emulate existing tables to be modified
alter table dbo.[GapOffer] add constraint [pk_GapOffer] primary key clustered ([GapOfferID] asc) on [PRIMARY] ;
alter table dbo.[GapOffer_parByDate] add constraint [pk_GapOffer_parByDate] primary key clustered ([GapOfferID] asc) on [PRIMARY] ;
alter table dbo.[GapOffer_parByID] add constraint [pk_GapOffer_parByID] primary key clustered ([GapOfferID] asc) on [PRIMARY] ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 2. Identify column that will be used for the partition key. We're doing two demo tables, one by date range and one by number list.
-- 3. Establish value boundaries for the partition key. We're going to partition the first one on dCreated year and the other on last digit of GapOfferId.
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- unique index on old primary key because we're going to be changing the PK...
create unique nonclustered index [ux_GapOffer_parByDate_GapOfferID] on dbo.[GapOffer_parByDate] ([GapOfferID]) ;
create unique nonclustered index [ux_GapOffer_parByID_GapOfferID] on dbo.[GapOffer_parByID] ([GapOfferID]) ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 4. Create filegroup(s) for new partitions. (optional)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

alter database [PartitionTesting] add filegroup [fg_GapOffer_parByDate_2012] ;	-- using 200x for year-based partitions
alter database [PartitionTesting] add filegroup [fg_GapOffer_parByDate_2013] ;
alter database [PartitionTesting] add filegroup [fg_GapOffer_parByDate_2014] ;
alter database [PartitionTesting] add filegroup [fg_GapOffer_parByDate_2015] ;
alter database [PartitionTesting] add filegroup [fg_GapOffer_parByDate_2016] ;

alter database [PartitionTesting] add filegroup [fg_GapOffer_parByID_0] ;		-- using 0-9 for int-based partitions
alter database [PartitionTesting] add filegroup [fg_GapOffer_parByID_1] ;
alter database [PartitionTesting] add filegroup [fg_GapOffer_parByID_2] ;
alter database [PartitionTesting] add filegroup [fg_GapOffer_parByID_3] ;
alter database [PartitionTesting] add filegroup [fg_GapOffer_parByID_4] ;
alter database [PartitionTesting] add filegroup [fg_GapOffer_parByID_5] ;
alter database [PartitionTesting] add filegroup [fg_GapOffer_parByID_6] ;
alter database [PartitionTesting] add filegroup [fg_GapOffer_parByID_7] ;
alter database [PartitionTesting] add filegroup [fg_GapOffer_parByID_8] ;
alter database [PartitionTesting] add filegroup [fg_GapOffer_parByID_9] ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 5. Create file(s) in filegroup(s) for new partitions. (optional)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

alter database [PartitionTesting] add file (name = N'PartitionTesting_GapOffer_parByDate_pf2012', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByDate_pf2012.ndf', size = 30MB, filegrowth = 5MB) to filegroup [fg_GapOffer_parByDate_2012] ;
alter database [PartitionTesting] add file (name = N'PartitionTesting_GapOffer_parByDate_pf2013', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByDate_pf2013.ndf', size = 150MB, filegrowth = 5MB) to filegroup [fg_GapOffer_parByDate_2013] ;
alter database [PartitionTesting] add file (name = N'PartitionTesting_GapOffer_parByDate_pf2014', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByDate_pf2014.ndf', size = 125MB, filegrowth = 5MB) to filegroup [fg_GapOffer_parByDate_2014] ;
alter database [PartitionTesting] add file (name = N'PartitionTesting_GapOffer_parByDate_pf2015', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByDate_pf2015.ndf', size = 180MB, filegrowth = 5MB) to filegroup [fg_GapOffer_parByDate_2015] ;
alter database [PartitionTesting] add file (name = N'PartitionTesting_GapOffer_parByDate_pf2016', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByDate_pf2016.ndf', size = 75MB, filegrowth = 5MB) to filegroup [fg_GapOffer_parByDate_2016] ;

alter database [PartitionTesting] add file (name = N'PartitionTesting_GapOffer_parByID_pf0', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByID_pf0.ndf', size = 45MB, filegrowth = 5MB) to filegroup [fg_GapOffer_parByID_0] ;
alter database [PartitionTesting] add file (name = N'PartitionTesting_GapOffer_parByID_pf1', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByID_pf1.ndf', size = 45MB, filegrowth = 5MB) to filegroup [fg_GapOffer_parByID_1] ;
alter database [PartitionTesting] add file (name = N'PartitionTesting_GapOffer_parByID_pf2', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByID_pf2.ndf', size = 45MB, filegrowth = 5MB) to filegroup [fg_GapOffer_parByID_2] ;
alter database [PartitionTesting] add file (name = N'PartitionTesting_GapOffer_parByID_pf3', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByID_pf3.ndf', size = 45MB, filegrowth = 5MB) to filegroup [fg_GapOffer_parByID_3] ;
alter database [PartitionTesting] add file (name = N'PartitionTesting_GapOffer_parByID_pf4', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByID_pf4.ndf', size = 45MB, filegrowth = 5MB) to filegroup [fg_GapOffer_parByID_4] ;
alter database [PartitionTesting] add file (name = N'PartitionTesting_GapOffer_parByID_pf5', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByID_pf5.ndf', size = 45MB, filegrowth = 5MB) to filegroup [fg_GapOffer_parByID_5] ;
alter database [PartitionTesting] add file (name = N'PartitionTesting_GapOffer_parByID_pf6', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByID_pf6.ndf', size = 45MB, filegrowth = 5MB) to filegroup [fg_GapOffer_parByID_6] ;
alter database [PartitionTesting] add file (name = N'PartitionTesting_GapOffer_parByID_pf7', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByID_pf7.ndf', size = 45MB, filegrowth = 5MB) to filegroup [fg_GapOffer_parByID_7] ;
alter database [PartitionTesting] add file (name = N'PartitionTesting_GapOffer_parByID_pf8', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByID_pf8.ndf', size = 45MB, filegrowth = 5MB) to filegroup [fg_GapOffer_parByID_8] ;
alter database [PartitionTesting] add file (name = N'PartitionTesting_GapOffer_parByID_pf9', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByID_pf9.ndf', size = 45MB, filegrowth = 5MB) to filegroup [fg_GapOffer_parByID_9] ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 6. Create partition function based on value boundaries of your partition key.
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

create partition function [pf_GapOffer_parByDate] (datetime) as range right for values ('20120101', '20130101', '20140101', '20150101', '20160101') ;
create partition function [pf_GapOffer_parByID] (int) as range right for values (0, 1, 2, 3, 4, 5, 6, 7, 8, 9) ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 7. Create partition scheme which determines the filegroups partitions live in.
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

create partition scheme [ps_GapOffer_parByDate] as partition [pf_GapOffer_parByDate] to ([PRIMARY], [fg_GapOffer_parByDate_2012], [fg_GapOffer_parByDate_2013], [fg_GapOffer_parByDate_2014], [fg_GapOffer_parByDate_2015], [fg_GapOffer_parByDate_2016], [PRIMARY]) ;
create partition scheme [ps_GapOffer_parByID] as partition [pf_GapOffer_parByID] to ([PRIMARY], [fg_GapOffer_parByID_0], [fg_GapOffer_parByID_1], [fg_GapOffer_parByID_2], [fg_GapOffer_parByID_3], [fg_GapOffer_parByID_4], [fg_GapOffer_parByID_5], [fg_GapOffer_parByID_6], [fg_GapOffer_parByID_7], [fg_GapOffer_parByID_8], [fg_GapOffer_parByID_9]) ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 8. Recreate clustered primary key on partition scheme to move data into partitions. (~40s)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- remove existing PK
alter table dbo.[GapOffer_parByDate] drop constraint [pk_GapOffer_parByDate] ;
alter table dbo.[GapOffer_parByID] drop constraint [pk_GapOffer_parByID] ;
go

-- create hash partition key
alter table dbo.[GapOffer_parByID] add [partkey] as [GapOfferID] % 10 persisted not null ;
go

-- create composite clustered key on partition scheme (this physically moves the data into the appropriate partition filegroups)
alter table dbo.[GapOffer_parByDate] add constraint [pk_GapOffer_parByDate] primary key clustered ([GapOfferID] asc, [dCreated] asc) on [ps_GapOffer_parByDate] ([dCreated]) ;
alter table dbo.[GapOffer_parByID] add constraint [pk_GapOffer_parByID] primary key clustered ([GapOfferID] asc, [partkey] asc) on [ps_GapOffer_parByID] ([partkey]) ;
go

-- show the partitions now (ooooo, ahhhhh)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 9. Add compression as applicable.
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- estimate space savings using compression, using partition 2 because 1 no longer holds data (~10s)
exec sp_estimate_data_compression_savings 'dbo', 'GapOffer_parByDate', 1, 2, 'PAGE' ;
exec sp_estimate_data_compression_savings 'dbo', 'GapOffer_parByDate', 1, 2, 'ROW' ;
exec sp_estimate_data_compression_savings 'dbo', 'GapOffer_parByID', 1, 2, 'PAGE' ;
exec sp_estimate_data_compression_savings 'dbo', 'GapOffer_parByID', 1, 2, 'ROW' ;
go

-- even though we could save a lot, we're not going to compress any of the GapOffer_parByID partitions because they'll all be active

-- set compression based on filegroup activity for date-based partitioning (~20s)
alter index [pk_GapOffer_parByDate] on dbo.[GapOffer_parByDate] rebuild partition = all with (
	sort_in_tempdb = on,
	data_compression = row on partitions(1),			-- set minimally active to (row)
	data_compression = page on partitions(2 to 5),		-- set inactive or locked/read-only to (page)
	data_compression = none on partitions(6)			-- set active to (none)
) ;
go

-- create filtered indexes on specific filegroups for partitions by date (~10s)
create nonclustered index [ix_GapOffer_parByDate_pf2012_ApplicationId] on dbo.[GapOffer_parByDate] ([ApplicationId] asc) where [dCreated] >= '2012-01-01 00:00:00.000' and [dCreated] < '2013-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2012] ;
create nonclustered index [ix_GapOffer_parByDate_pf2012_dCreated] on dbo.[GapOffer_parByDate] ([dCreated] asc) where [dCreated] >= '2012-01-01 00:00:00.000' and [dCreated] < '2013-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2012] ;
create nonclustered index [ix_GapOffer_parByDate_pf2013_ApplicationId] on dbo.[GapOffer_parByDate] ([ApplicationId] asc) where [dCreated] >= '2013-01-01 00:00:00.000' and [dCreated] < '2014-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2013] ;
create nonclustered index [ix_GapOffer_parByDate_pf2013_dCreated] on dbo.[GapOffer_parByDate] ([dCreated] asc) where [dCreated] >= '2013-01-01 00:00:00.000' and [dCreated] < '2014-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2013] ;
create nonclustered index [ix_GapOffer_parByDate_pf2014_ApplicationId] on dbo.[GapOffer_parByDate] ([ApplicationId] asc) where [dCreated] >= '2014-01-01 00:00:00.000' and [dCreated] < '2015-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2014] ;
create nonclustered index [ix_GapOffer_parByDate_pf2014_dCreated] on dbo.[GapOffer_parByDate] ([dCreated] asc) where [dCreated] >= '2014-01-01 00:00:00.000' and [dCreated] < '2015-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2014] ;
create nonclustered index [ix_GapOffer_parByDate_pf2015_ApplicationId] on dbo.[GapOffer_parByDate] ([ApplicationId] asc) where [dCreated] >= '2015-01-01 00:00:00.000' and [dCreated] < '2016-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2015] ;
create nonclustered index [ix_GapOffer_parByDate_pf2015_dCreated] on dbo.[GapOffer_parByDate] ([dCreated] asc) where [dCreated] >= '2015-01-01 00:00:00.000' and [dCreated] < '2016-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2015] ;
create nonclustered index [ix_GapOffer_parByDate_pf2016_ApplicationId] on dbo.[GapOffer_parByDate] ([ApplicationId] asc) where [dCreated] >= '2016-01-01 00:00:00.000' and [dCreated] < '2017-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2016] ;
create nonclustered index [ix_GapOffer_parByDate_pf2016_dCreated] on dbo.[GapOffer_parByDate] ([dCreated] asc) where [dCreated] >= '2016-01-01 00:00:00.000' and [dCreated] < '2017-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2016] ;
go

-- create indexes on non-date specific partitions (~4s)
create nonclustered index [ix_GapOffer_parByID_ApplicationId] on dbo.[GapOffer_parByID] ([ApplicationId] asc)
create nonclustered index [ix_GapOffer_parByID_dCreated] on dbo.[GapOffer_parByID] ([dCreated] asc)
go

-- update statistics (this is not done automatically after the partitioned index creation) (~7s)
update statistics dbo.GapOffer_parByDate with fullscan ;
update statistics dbo.GapOffer_parByID with fullscan ;
go

-- lock static partitions
alter database [PartitionTesting] modify filegroup [fg_GapOffer_parByDate_2012] read_only ;
alter database [PartitionTesting] modify filegroup [fg_GapOffer_parByDate_2013] read_only ;
alter database [PartitionTesting] modify filegroup [fg_GapOffer_parByDate_2014] read_only ;
alter database [PartitionTesting] modify filegroup [fg_GapOffer_parByDate_2015] read_only ;
go

-- confirm primary partition as default on date-based partitions
if not exists (select 1 from sys.filegroups where [name] = 'PRIMARY' and [is_default] = 1)
	alter database [PartitionTesting] modify filegroup [PRIMARY] default ;
go

-- set lock escalation to auto on the partitioned tables
alter table [GapOffer_parByDate] set (lock_escalation = auto) ;
alter table [GapOffer_parByID] set (lock_escalation = auto) ;
go

-- show the partitions now (ooooo, ahhhhh)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- example of partition elimination
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

declare @x bigint ;
set statistics io on ;
select @x = Count(*) from dbo.[GapOffer] where [dCreated] between '2015-06-21' and '2015-12-14' ;
select @x = Count(*) from dbo.[GapOffer_parByDate] where [dCreated] between '2015-06-21' and '2015-12-14' ;
select @x = Count(*) from dbo.[GapOffer] where [dCreated] between '2013-06-21' and '2015-12-14' ;
select @x = Count(*) from dbo.[GapOffer_parByDate] where [dCreated] between '2013-06-21' and '2015-12-14' ;
set statistics io off ;
go 2

--Table 'GapOffer'.				Scan count 1, logical reads 37598, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'GapOffer_parByDate'.	Scan count 1, logical reads   475, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'GapOffer'.				Scan count 1, logical reads 37598, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'GapOffer_parByDate'.	Scan count 1, logical reads  3325, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- example of insert data that falls into specific partitions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- show before counts, pay attention to the rowcount of PRIMARY (0), we're inserting something at the bottom of our range
insert into dbo.[GapOffer_parByDate] ([ApplicationId], [nTerm], [nCost], [nRetail], [nDealerSold], [dCreated]) values (1, 1, 1, 1, 1, '2011-02-01') ;
-- show after counts, pay attention to the rowcount of PRIMARY (1)

-- attempt to insert into a locked partition (filegroup)
-- show before counts, pay attention to the rowcount of 2012 (83506)
insert into dbo.[GapOffer_parByDate] ([ApplicationId], [nTerm], [nCost], [nRetail], [nDealerSold], [dCreated]) values (1, 1, 1, 1, 1, '2012-02-01') ;

-- unlock partition (filegroup)
alter database [PartitionTesting] modify filegroup [fg_GapOffer_parByDate_2012] read_write ;

-- retry insert
insert into dbo.[GapOffer_parByDate] ([ApplicationId], [nTerm], [nCost], [nRetail], [nDealerSold], [dCreated]) values (1, 1, 1, 1, 1, '2012-02-01') ;
-- show after counts, pay attention to the rowcount of 2012 (83507)

-- re-lock partition (filegroup)
alter database [PartitionTesting] modify filegroup [fg_GapOffer_parByDate_2012] read_only ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- viewing what partition a row exists on
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

select top 5 * from dbo.[GapOffer_parByDate] order by [GapOfferID] desc ;
select top 5 * from dbo.[GapOffer_parByID] order by [GapOfferID] desc ;
go

select top 5 [partkey], [p#] = $partition.pf_GapOffer_parByID([partkey]), * from dbo.[GapOffer_parByDate] order by [GapOfferID] desc ;
select top 5 [partkey], [p#] = $partition.pf_GapOffer_parByID([partkey]), * from dbo.[GapOffer_parByID] order by [GapOfferID] desc ;
go
