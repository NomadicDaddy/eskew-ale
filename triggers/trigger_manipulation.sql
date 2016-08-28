:connect [target] ;

-- expect errors for offline or innaccessible databases and tables

-- find all disabled triggers on CURRENT INSTANCE
--exec sp_msforeachdb 'use [?] ; select [instance] = @@SERVERNAME, [database] = ''?'', [table] = QuoteName(object_name([parent_id])), * from sys.triggers where [is_disabled] = 1 ;' ;

-- find all enabled triggers on CURRENT INSTANCE
--exec sp_msforeachdb 'use [?] ; select [instance] = @@SERVERNAME, [database] = ''?'', [table] = QuoteName(object_name([parent_id])), * from sys.triggers where [is_disabled] = 0 ;' ;


-- find all disabled triggers on CURRENT DATABASE
--select [table] = QuoteName(object_name([parent_id])), * from sys.triggers where [is_disabled] = 1 ;

-- find all enabled triggers on CURRENT DATABASE
--select [table] = QuoteName(object_name([parent_id])), * from sys.triggers where [is_disabled] = 0 ;


-- enable all triggers on CURRENT INSTANCE
--exec sp_msforeachdb 'use [?] ; exec sp_msforeachtable ''alter table ? enable trigger all ;''' ;

-- disable all triggers on CURRENT INSTANCE
--exec sp_msforeachdb 'use [?] ; exec sp_msforeachtable ''alter table ? disable trigger all ;''' ;


-- enable all triggers on CURRENT DATABASE
--exec sp_msforeachtable 'alter table ? enable trigger all ;' ;

-- disable all triggers on CURRENT DATABASE
--exec sp_msforeachtable 'alter table ? disable trigger all ;' ;
