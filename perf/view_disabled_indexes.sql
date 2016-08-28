exec sp_msforeachdb 'use [?] ; select [database] = ''[?]'', [table] = QuoteName(object_name([object_id])), * from sys.indexes where is_disabled = 1 ;' ;
