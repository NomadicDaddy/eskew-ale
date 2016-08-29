------------------------------------------------------------------------------------------------------------------------------------------------
-- non-partitioned table switch
------------------------------------------------------------------------------------------------------------------------------------------------

use [PartitionTesting] ;
go

-- create staging table
select * into [PartitionTesting].dbo.[GapOffer_staging] from [PartitionTesting].dbo.[GapOffer] where 1 = 0 ;

-- populate staging table
set identity_insert [PartitionTesting].dbo.[GapOffer_staging] on ;
insert into [PartitionTesting].dbo.[GapOffer_staging] (GapOfferID, ApplicationId, nTerm, nCost, nRetail, cPriceVersion, cContractNumber, dModified, ModifiedByID, CreatedByID, dCreated, dInactive, cContractFileName, cRegistrationFileName, cProgramCode, cProductCode, cPlanCode, nDeductible, nNoOfMiles, nDealerSold, nDealerCost, nDealerCommission, nLenderCost, nLenderCommission)
select * from Credit.dbo.[GapOffer] where [dCreated] between '2013-01-01 00:00:00.000' and '2013-08-01 00:00:00.000' ;
set identity_insert [PartitionTesting].dbo.[GapOffer_staging] off ;

-- create clustered pk on same filegroup as target
alter table dbo.[GapOffer_staging] add constraint [pk_GapOffer_staging] primary key clustered ([GapOfferID] asc) on [PRIMARY] ;

-- verify counts
select Count(*) from [PartitionTesting].dbo.[GapOffer] ;
select Count(*) from [PartitionTesting].dbo.[GapOffer_staging] ;

-- truncate destination
truncate table dbo.[GapOffer] ;

-- switch
alter table dbo.[GapOffer_staging] switch to dbo.[GapOffer] ;

-- verify counts
select Count(*) from [PartitionTesting].dbo.[GapOffer] ;
select Count(*) from [PartitionTesting].dbo.[GapOffer_staging] ;

-- drop staging table
drop table dbo.[GapOffer_staging] ;
go
