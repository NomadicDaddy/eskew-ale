-- dupe delete w/ ids
delete
from
	[table]
where
	[id] not in
	(
		select Max([id])
		from [table]
		group by [dupeCol1], [dupeCol2]
	) ;
