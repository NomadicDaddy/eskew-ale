with [z] as (
	select [id] from syscomments where Convert(nvarchar(max), [text]) like '%WITH (INDEX%' union
	select [id] from syscomments where Convert(nvarchar(max), [text]) like '%WITH ( INDEX%' union
	select [id] from syscomments where Convert(nvarchar(max), [text]) like '%WITH(INDEX%' union
	select [id] from syscomments where Convert(nvarchar(max), [text]) like '%WITH( INDEX%'
)
select distinct
	z.[id],
	[name] = object_name(z.[id])
from
	[z]
	inner join syscomments [c] on z.[id] = c.[id]
order by
	[name] asc ;
