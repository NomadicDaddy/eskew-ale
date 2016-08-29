------------------------------------------------------------------------------------------------------------------------------------------------
-- adding a new filegroup for an upcoming new year
------------------------------------------------------------------------------------------------------------------------------------------------

-- do this one last (so you don't have to add 2017 to the other demos!)

use [master] ;
go

-- add new filegroup
alter database [PartitionTesting] add filegroup [fg_GapOffer_parByDate_2017] ;
go

-- add new file
alter database [PartitionTesting]
	add file (name = N'PartitionTesting_GapOffer_parByDate_pf2017', filename = N'E:\SQLData_ORIGINATIONS\PartitionTesting_GapOffer_parByDate_pf2017.ndf', size = 5MB, filegrowth = 5MB)
	to filegroup [fg_GapOffer_parByDate_2017] ;
go

use [PartitionTesting] ;
go

-- expand the scheme to include the new partition
alter partition scheme [ps_GapOffer_parByDate] next used [fg_GapOffer_parByDate_2017] ;
go

-- add new range bucket to function
alter partition function [pf_GapOffer_parByDate] () split range ('20170101') ;
go

-- create new filtered NCIs for new partition
create nonclustered index [ix_GapOffer_parByDate_pf2017_ApplicationId] on dbo.[GapOffer_parByDate] ([ApplicationId] asc) where [dCreated] >= '2017-01-01 00:00:00.000' and [dCreated] < '2018-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2017] ;
create nonclustered index [ix_GapOffer_parByDate_pf2017_dCreated] on dbo.[GapOffer_parByDate] ([dCreated] asc) where [dCreated] >= '2017-01-01 00:00:00.000' and [dCreated] < '2018-01-01 00:00:00.000' on [fg_GapOffer_parByDate_2017] ;
go
