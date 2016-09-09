------------------------------------------------------------------------------------------------------------------------------------------------
-- type 1: non-partitioned table switch
-- useful for switching data into an existing non-partitioned table from a staging non-partitioned table							(refreshing)
------------------------------------------------------------------------------------------------------------------------------------------------

use [PartitionTesting] ;
go

-- create staging table
select * into [PartitionTesting].dbo.[OrderTracking_staging] from [PartitionTesting].dbo.[OrderTracking] where 1 = 0 ;

-- populate staging table
set identity_insert [PartitionTesting].dbo.[OrderTracking_staging] on ;
insert into [PartitionTesting].dbo.[OrderTracking_staging] (OrderTrackingID, SalesOrderID, CarrierTrackingNumber, TrackingEventID, EventDetails, EventDateTime)
select * from AdventureWorks.Sales.[OrderTracking] where [EventDateTime] between '2012-01-01 00:00:00.000' and '2012-08-01 00:00:00.000' ;
set identity_insert [PartitionTesting].dbo.[OrderTracking_staging] off ;

-- create clustered pk on same filegroup as target
alter table dbo.[OrderTracking_staging] add constraint [pk_OrderTracking_staging] primary key clustered ([OrderTrackingID] asc) on [PRIMARY] ;

-- verify counts
select [Target Rowcount] = Count(*) from dbo.[OrderTracking] ;
select [Source Rowcount] = Count(*) from dbo.[OrderTracking_staging] ;

-- truncate destination
truncate table dbo.[OrderTracking] ;

-- switch
alter table dbo.[OrderTracking_staging] switch to dbo.[OrderTracking] ;

-- verify counts
select [Target Rowcount] = Count(*) from dbo.[OrderTracking] ;
select [Source Rowcount] = Count(*) from dbo.[OrderTracking_staging] ;

-- drop staging table
drop table dbo.[OrderTracking_staging] ;
go
