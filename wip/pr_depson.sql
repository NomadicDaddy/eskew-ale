set quoted_identifier on ;
set ansi_nulls on ;
go

if exists (select 1 from INFORMATION_SCHEMA.ROUTINES where [routine_schema] = 'dbo' and [routine_name] = 'pr_depson')
	drop procedure dbo.[pr_depson] ;
go

create procedure dbo.[pr_depson] (
	@schema nvarchar(128) = null,
	@object nvarchar(128) = '',
	@subobj nvarchar(128) = '',
	@type nvarchar(128) = '',
	@wild bit = 1
)
as
begin

-----------------------------------------------------------------------------------------------------------------------
-- Procedure:	pr_depson
-- Author:		Phillip Beazley (phillip@beazley.org)
-- Date:		03/15/2016
--
-- Purpose:		Shows all programmatically retrievable objects that are referenced by or
--				make reference to the specified object.
--
-- Notes:		n/a
--
-- Depends:		n/a
--
-- REVISION HISTORY ---------------------------------------------------------------------------------------------------
-- 03/15/2016	lordbeazley	Initial creation.
-----------------------------------------------------------------------------------------------------------------------

set nocount on ;

select
    [rType] = ro.[type],
    [rSchema] = object_schema_name(d.[referencing_id]),
    [rName] = object_name(d.[referencing_id]),
    [|] = ' --> ',
    [dType] = Coalesce(do.[type], 'EXT'),
    [dSchema] = IIf(do.[type] is null, 'EXT', Coalesce(d.[referenced_schema_name], 'dbo')),
    [dName] = d.[referenced_entity_name],
	[dSubObj] = Coalesce(c.[Name], '')
from
    sys.sql_expression_dependencies [d]
    left outer join sys.objects [ro] on ro.[object_id] = d.[referencing_id]
    left outer join sys.objects [do] on do.[object_id] = d.[referenced_id]
	left outer join sys.columns [c] on c.[object_id] = d.[referenced_id] and c.[name] = @subobj
where
	(
		@type = ''
		or do.[type] = @type
		or ro.[type] = @type
	)
	and (
		@object = ''
		or ((object_name(d.[referencing_id]) like '%' + @object + '%' and @wild = 1) or (@object = object_name(d.[referencing_id])))
		or ((d.[referenced_entity_name] like '%' + @object + '%' and @wild = 1) or (@object = d.[referenced_entity_name]))
	)
	and (object_name(d.[referencing_id]) <> d.[referenced_entity_name])
order by
    object_name(d.[referencing_id]) asc,
    d.[referenced_schema_name] asc,
    d.[referenced_entity_name] asc ;

end
go
--return ;

-- EXAMPLES
exec [pr_depson] ;
exec [pr_depson] @object = 'account' ;
