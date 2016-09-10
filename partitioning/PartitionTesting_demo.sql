use [master] ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 1. Identify candidate table. For this demo, we're using a copy of Sales.OrderTracking from the AdentureWorks database in a test database called PartitionTesting. (~33s)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- get default database directory
declare @dfpath nvarchar(512), @lfpath nvarchar(512), @cmd nvarchar(2048) ;
exec xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', @dfpath output, no_output ;
exec xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog', @lfpath output, no_output ;

-- drop existing test database
while (exists (select 1 from sys.databases where [name] = 'PartitionTesting'))
begin
	raiserror('Attemping to shut down and drop the existing [PartitionTesting] database...', 0, 1) with nowait ;
	exec sp_sqlexec 'use [master] ; alter database [PartitionTesting] set offline with no_wait ;' ;
	exec sp_sqlexec 'use [master] ; drop database [PartitionTesting] ;' ;
	waitfor delay '000:00:01' ;
end
set @cmd = N'del /F /Q ' + Convert(nvarchar, @dfpath) + N'\PartitionTesting.mdf' ;
exec master..xp_cmdshell @cmd, no_output ;
set @cmd = N'del /F /Q ' + Convert(nvarchar, @lfpath) + N'\PartitionTesting.ldf' ;
exec xp_cmdshell @cmd, no_output ;
set @cmd = N'del /F /Q ' + Convert(nvarchar, @dfpath) + N'\PartitionTesting_OrderTracking_*.ndf' ;
exec xp_cmdshell @cmd, no_output ;

-- create testing database
set @dfpath = @dfpath + N'\PartitionTesting.mdf' ;
set @lfpath = @lfpath + N'\PartitionTesting.ldf' ;
set @cmd = N'create database [PartitionTesting] containment = none
	on primary (name = N''PartitionTesting'', filename = ' + QuoteName(@dfpath, '''') + ', size = 128MB, filegrowth = 128MB)
	log on (name = N''PartitionTesting_log'', filename = ' + QuoteName(@lfpath, '''') + ', size = 128MB, filegrowth = 128MB) ;' ;
exec sp_executesql @cmd ;
go

-- select Min([EventDateTime]), Max([EventDateTime]) from AdventureWorks.Sales.[OrderTracking] ;
-- date range present: 2011 through 2014
-- for date range, need partitions for 2011, 2012, 2013, 2014, and 2015 to start with (we'll add 2016 later in the switch demo)
-- populate tables for testing (just copying Sales.OrderTracking from AdventureWorks database) (~18s)
use [PartitionTesting] ;
select * into dbo.[OrderTracking] from AdventureWorks.Sales.[OrderTracking]  ;	-- original for comparison
select * into dbo.[OrderTracking_parByDate] from dbo.[OrderTracking] ;			-- version to be partitioned by date range (EventDateTime)
select * into dbo.[OrderTracking_parByID] from dbo.[OrderTracking] ;			-- version to be partitioned by list (last digit of OrderTrackingID)
go

-- create PKs to emulate existing tables to be modified (~14s)
alter table dbo.[OrderTracking] add constraint [pk_OrderTracking] primary key clustered ([OrderTrackingID] asc) on [PRIMARY] ;
alter table dbo.[OrderTracking_parByDate] add constraint [pk_OrderTracking_parByDate] primary key clustered ([OrderTrackingID] asc) on [PRIMARY] ;
alter table dbo.[OrderTracking_parByID] add constraint [pk_OrderTracking_parByID] primary key clustered ([OrderTrackingID] asc) on [PRIMARY] ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 2. Identify column that will be used for the partition key. We're doing two demo tables, one by date range and one by number list.
-- 3. Establish value boundaries for the partition key. We're going to partition the first one on EventDateTime year and the other on last digit of OrderTrackingId.
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- unique index on old primary key because we're going to be changing the PK... (~2s)
create unique nonclustered index [ux_OrderTracking_parByDate_OrderTrackingID] on dbo.[OrderTracking_parByDate] ([OrderTrackingID]) ;
create unique nonclustered index [ux_OrderTracking_parByID_OrderTrackingID] on dbo.[OrderTracking_parByID] ([OrderTrackingID]) ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 4. Create filegroup(s) for new partitions. (optional)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByDate_2011] ;	-- using 20xx for year-based partitions
alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByDate_2012] ;
alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByDate_2013] ;
alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByDate_2014] ;
alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByDate_2015] ;

alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByID_0] ;		-- using 0-9 for int-based partitions
alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByID_1] ;
alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByID_2] ;
alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByID_3] ;
alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByID_4] ;
alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByID_5] ;
alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByID_6] ;
alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByID_7] ;
alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByID_8] ;
alter database [PartitionTesting] add filegroup [fg_OrderTracking_parByID_9] ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 5. Create file(s) in filegroup(s) for new partitions. (optional)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

declare @dfpath nvarchar(512) ;
exec xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', @dfpath output, no_output ;

exec('alter database [PartitionTesting] add file (name = N''PartitionTesting_OrderTracking_parByDate_pf2011'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByDate_pf2011.ndf'', size = 5MB, filegrowth = 5MB) to filegroup [fg_OrderTracking_parByDate_2011] ;') ;
exec('alter database [PartitionTesting] add file (name = N''PartitionTesting_OrderTracking_parByDate_pf2012'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByDate_pf2012.ndf'', size = 5MB, filegrowth = 5MB) to filegroup [fg_OrderTracking_parByDate_2012] ;') ;
exec('alter database [PartitionTesting] add file (name = N''PartitionTesting_OrderTracking_parByDate_pf2013'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByDate_pf2013.ndf'', size = 5MB, filegrowth = 5MB) to filegroup [fg_OrderTracking_parByDate_2013] ;') ;
exec('alter database [PartitionTesting] add file (name = N''PartitionTesting_OrderTracking_parByDate_pf2014'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByDate_pf2014.ndf'', size = 5MB, filegrowth = 5MB) to filegroup [fg_OrderTracking_parByDate_2014] ;') ;
exec('alter database [PartitionTesting] add file (name = N''PartitionTesting_OrderTracking_parByDate_pf2015'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByDate_pf2015.ndf'', size = 5MB, filegrowth = 5MB) to filegroup [fg_OrderTracking_parByDate_2015] ;') ;

exec('alter database [PartitionTesting] add file (name = N''PartitionTesting_OrderTracking_parByID_pf0'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByID_pf0.ndf'', size = 5MB, filegrowth = 5MB) to filegroup [fg_OrderTracking_parByID_0] ;') ;
exec('alter database [PartitionTesting] add file (name = N''PartitionTesting_OrderTracking_parByID_pf1'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByID_pf1.ndf'', size = 5MB, filegrowth = 5MB) to filegroup [fg_OrderTracking_parByID_1] ;') ;
exec('alter database [PartitionTesting] add file (name = N''PartitionTesting_OrderTracking_parByID_pf2'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByID_pf2.ndf'', size = 5MB, filegrowth = 5MB) to filegroup [fg_OrderTracking_parByID_2] ;') ;
exec('alter database [PartitionTesting] add file (name = N''PartitionTesting_OrderTracking_parByID_pf3'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByID_pf3.ndf'', size = 5MB, filegrowth = 5MB) to filegroup [fg_OrderTracking_parByID_3] ;') ;
exec('alter database [PartitionTesting] add file (name = N''PartitionTesting_OrderTracking_parByID_pf4'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByID_pf4.ndf'', size = 5MB, filegrowth = 5MB) to filegroup [fg_OrderTracking_parByID_4] ;') ;
exec('alter database [PartitionTesting] add file (name = N''PartitionTesting_OrderTracking_parByID_pf5'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByID_pf5.ndf'', size = 5MB, filegrowth = 5MB) to filegroup [fg_OrderTracking_parByID_5] ;') ;
exec('alter database [PartitionTesting] add file (name = N''PartitionTesting_OrderTracking_parByID_pf6'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByID_pf6.ndf'', size = 5MB, filegrowth = 5MB) to filegroup [fg_OrderTracking_parByID_6] ;') ;
exec('alter database [PartitionTesting] add file (name = N''PartitionTesting_OrderTracking_parByID_pf7'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByID_pf7.ndf'', size = 5MB, filegrowth = 5MB) to filegroup [fg_OrderTracking_parByID_7] ;') ;
exec('alter database [PartitionTesting] add file (name = N''PartitionTesting_OrderTracking_parByID_pf8'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByID_pf8.ndf'', size = 5MB, filegrowth = 5MB) to filegroup [fg_OrderTracking_parByID_8] ;') ;
exec('alter database [PartitionTesting] add file (name = N''PartitionTesting_OrderTracking_parByID_pf9'', filename = N''' + @dfpath + '\PartitionTesting_OrderTracking_parByID_pf9.ndf'', size = 5MB, filegrowth = 5MB) to filegroup [fg_OrderTracking_parByID_9] ;') ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 6. Create partition function based on value boundaries of your partition key.
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- remember your starting and ending points!
-- using range right, the boundary is your starting point (first/least value and increasing to the right)
-- using range left, the boundary is your ending point (increasing from the left to the last/final value)

-- datetime range boundary: 23:59:59.997
-- datetime2 range boundary: 23:59:59.9999999

--create partition function [pf_OrderTracking_parByDate] (datetime2) as range right for values (
--	'20110101',
--	'20120101',
--	'20130101',							-- anything to the RIGHT of this (until the next boundary), so 20130101 through 20131231
--	'20140101',
--	'20150101'
--) ;
create partition function [pf_OrderTracking_parByDate] (datetime2) as range left for values (
	'2011-12-31 23:59:59.9999999',
	'2012-12-31 23:59:59.9999999',
	'2013-12-31 23:59:59.9999999',		-- anything to the LEFT of this (proceeding but not within a previous range), so after 20121231 and on or before 20131231
	'2014-12-31 23:59:59.9999999',
	'2015-12-31 23:59:59.9999999'
) ;

-- for list-based partitioning, it may not matter which you choose
-- in this case, there's never going to be another digit outside of our list (0-9)...

--create partition function [pf_OrderTracking_parByID] (int) as range right for values (0, 1, 2, 3, 4, 5, 6, 7, 8, 9) ;
create partition function [pf_OrderTracking_parByID] (int) as range left for values (0, 1, 2, 3, 4, 5, 6, 7, 8, 9) ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 7. Create partition scheme which determines the filegroups partitions live in.
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

create partition scheme [ps_OrderTracking_parByDate] as partition [pf_OrderTracking_parByDate] to (
	[fg_OrderTracking_parByDate_2011],		-- this filegroup maps to first value range in the function above
	[fg_OrderTracking_parByDate_2012],		-- and so on...
	[fg_OrderTracking_parByDate_2013],
	[fg_OrderTracking_parByDate_2014],
	[fg_OrderTracking_parByDate_2015],
	[PRIMARY]								-- must have as catch-all filegroup
) ;

create partition scheme [ps_OrderTracking_parByID] as partition [pf_OrderTracking_parByID] to (
	[fg_OrderTracking_parByID_0],			-- this filegroup maps to first value range in the function above
	[fg_OrderTracking_parByID_1],			-- and so on...
	[fg_OrderTracking_parByID_2],
	[fg_OrderTracking_parByID_3],
	[fg_OrderTracking_parByID_4],
	[fg_OrderTracking_parByID_5],
	[fg_OrderTracking_parByID_6],
	[fg_OrderTracking_parByID_7],
	[fg_OrderTracking_parByID_8],
	[fg_OrderTracking_parByID_9],
	[PRIMARY]								-- must have as catch-all filegroup
) ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 8. Recreate clustered primary key on partition scheme to move data into partitions. (~40s)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- remove existing PK
alter table dbo.[OrderTracking_parByDate] drop constraint [pk_OrderTracking_parByDate] ;
alter table dbo.[OrderTracking_parByID] drop constraint [pk_OrderTracking_parByID] ;
go

-- create hash partition key
alter table dbo.[OrderTracking_parByID] add [partkey] as [OrderTrackingID] % 10 persisted not null ;
go

-- create composite clustered key (old pk + partition key) on partition scheme (this physically moves the data into the appropriate partition filegroups)
alter table dbo.[OrderTracking_parByDate] add constraint [pk_OrderTracking_parByDate] primary key clustered ([OrderTrackingID] asc, [EventDateTime] asc) on [ps_OrderTracking_parByDate] ([EventDateTime]) ;
alter table dbo.[OrderTracking_parByID] add constraint [pk_OrderTracking_parByID] primary key clustered ([OrderTrackingID] asc, [partkey] asc) on [ps_OrderTracking_parByID] ([partkey]) ;
go

-- show the partitions now (ooooo, ahhhhh)
-- (load and execute show_partitions.sql)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 9. Add compression as applicable.
--
-- Guidelines:
--    Set to NONE if the table is actively written to.
--    Set to ROW if the table is more read than write but they do still occur.
--    Set to PAGE if the table is primarily reads or is read-only.
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- estimate space savings using compression, using partition 2 because 1 no longer holds data (~10s)
exec sp_estimate_data_compression_savings 'dbo', 'OrderTracking_parByDate', 1, 2, 'PAGE' ;
exec sp_estimate_data_compression_savings 'dbo', 'OrderTracking_parByDate', 1, 2, 'ROW' ;
exec sp_estimate_data_compression_savings 'dbo', 'OrderTracking_parByID', 1, 2, 'PAGE' ;
exec sp_estimate_data_compression_savings 'dbo', 'OrderTracking_parByID', 1, 2, 'ROW' ;
go

-- even though we could save a lot, we're not going to compress any of the OrderTracking_parByID partitions because they'll all be active

-- set compression based on filegroup activity for date-based partitioning (~21s)
alter index [pk_OrderTracking_parByDate] on dbo.[OrderTracking_parByDate] rebuild partition = all with (
	sort_in_tempdb = on,
	data_compression = page on partitions(1 to 5),		-- set inactive or locked/read-only to (page)
	data_compression = none on partitions(6)			-- set active to (none)
) ;
go

-- create filtered indexes on specific filegroups for partitions by date (was: on [fg_OrderTracking_parByDate_20XX], now: on ps) (~10s)
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
go

-- create indexes on non-date specific partitions (~6s)
create nonclustered index [ix_OrderTracking_parByID_OrderTrackingID] on dbo.[OrderTracking_parByID] ([OrderTrackingID] asc)
create nonclustered index [ix_OrderTracking_parByID_EventDateTime] on dbo.[OrderTracking_parByID] ([EventDateTime] asc)
go

-- update statistics (this is not done automatically after the partitioned index creation) (~7s)
update statistics dbo.OrderTracking_parByDate with fullscan ;
update statistics dbo.OrderTracking_parByID with fullscan ;
go

-- lock static partitions
use [master] ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2011] read_only ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2012] read_only ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2013] read_only ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2014] read_only ;
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2015] read_only ;
go

-- confirm primary partition as default on date-based partitions
use [PartitionTesting] ;
if not exists (select 1 from sys.filegroups where [name] = 'PRIMARY' and [is_default] = 1)
	alter database [PartitionTesting] modify filegroup [PRIMARY] default ;
go

-- set lock escalation to auto on the partitioned tables
alter table [OrderTracking_parByDate] set (lock_escalation = auto) ;
alter table [OrderTracking_parByID] set (lock_escalation = auto) ;
go

-- show the partitions now (ooooo, ahhhhh)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- example of partition elimination
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

declare @x bigint ;
set statistics io on ;
select @x = Count(*) from dbo.[OrderTracking] where [EventDateTime] between '2014-06-21' and '2014-12-14' ;				-- dates fall within one partition
select @x = Count(*) from dbo.[OrderTracking_parByDate] where [EventDateTime] between '2014-06-21' and '2014-12-14' ;
select @x = Count(*) from dbo.[OrderTracking] where [EventDateTime] between '2012-06-21' and '2014-12-14' ;				-- dates fall within three partitions
select @x = Count(*) from dbo.[OrderTracking_parByDate] where [EventDateTime] between '2012-06-21' and '2014-12-14' ;
set statistics io off ;
go 2

--Table 'OrderTracking'.			Scan count 1, logical reads 4430, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'OrderTracking_parByDate'.	Scan count 1, logical reads 8, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'OrderTracking'.			Scan count 1, logical reads 4430, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'OrderTracking_parByDate'.	Scan count 1, logical reads 423, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- example of insert data that falls into specific partitions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- show before counts, pay attention to the rowcount of PRIMARY (0), we're inserting something above our defined range
insert into dbo.[OrderTracking_parByDate] ([SalesOrderID], [CarrierTrackingNumber], [TrackingEventID], [EventDetails], [EventDateTime]) values (1, 1, 1, 1, '2017-02-01') ;
go
-- show after counts, pay attention to the rowcount of PRIMARY (1)

-- delete that row for demo purposes
delete from dbo.[OrderTracking_parByDate] where [SalesOrderID] = 1 and [EventDateTime] = '2017-02-01' ;
go

-- attempt to insert into a locked partition (filegroup)
-- show before counts, pay attention to the rowcount of 2011 (9614)
raiserror('The following error is intentional. You can''t insert into a table on a read-only filegroup.', 0, 1) with nowait ;
insert into dbo.[OrderTracking_parByDate] ([SalesOrderID], [CarrierTrackingNumber], [TrackingEventID], [EventDetails], [EventDateTime]) values (1, 1, 1, 1, '2011-02-01') ;
go

-- unlock partition (filegroup)
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2011] read_write ;
go

-- retry insert
insert into dbo.[OrderTracking_parByDate] ([SalesOrderID], [CarrierTrackingNumber], [TrackingEventID], [EventDetails], [EventDateTime]) values (1, 1, 1, 1, '2011-02-01') ;
go
-- show after counts, pay attention to the rowcount of 2011 (9615)

-- re-lock partition (filegroup)
alter database [PartitionTesting] modify filegroup [fg_OrderTracking_parByDate_2011] read_only ;
go

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- viewing what partition a row exists on
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

select top 5 [EventDateTime], [p#] = $partition.pf_OrderTracking_parByDate([EventDateTime]), * from dbo.[OrderTracking_parByDate] order by [OrderTrackingID] desc ;
select top 5 [partkey], [p#] = $partition.pf_OrderTracking_parByID([partkey]), * from dbo.[OrderTracking_parByID] order by [OrderTrackingID] desc ;
go
