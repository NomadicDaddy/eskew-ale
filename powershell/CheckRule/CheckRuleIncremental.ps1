$MANAGEMENT_INSTANCE = 'RCHPWVMGMSQL01.prod.corpint.net\MANAGEMENT01'
$MANAGEMENT_DATABASE = 'SQLImplementations'
$IMPLEMENTATION_ROOT = '\\RCHPWVMGMSQL01.prod.corpint.net\SQLIMPLEMENTATIONS\Imp\Master'

function Import-Module-SQLPS {
	Push-Location						# Push and Pop to avoid import from changing the current directory (http://stackoverflow.com/questions/12915299/sql-server-2012-sqlps-module-changing-current-location-automatically)
	Import-Module sqlps 3>&1 | Out-Null	# 3>&1 puts warning stream to standard output stream (https://connect.microsoft.com/PowerShell/feedback/details/297055/capture-warning-verbose-debug-and-host-output-via-alternate-streams)
	Pop-Location						# Out-Null blocks that output, so we don't see the annoying warnings (https://www.codykonior.com/2015/05/30/whats-wrong-with-sqlps/)
}
if (!(Get-Module sqlps)) { Import-Module-SQLPS }

$sql = @'
select
	i.[ImpFilePath]
from
	dbo.[vw_Implementations] i
	left outer join dbo.[CheckScript] cs on i.[ImpFilePath] = cs.[ScriptPath]
where
	i.[Active] = 1
	and i.[ImpFileType] = 'sql'
	and (i.[QAReviewStateID] = 1 or cs.[CheckScriptID] is null)
order by
	i.[LastReviewed] desc,
	i.[ImpFilePath] asc ;
'@

$ToBeChecked = Invoke-SqlCmd -ServerInstance $MANAGEMENT_INSTANCE -Database $MANAGEMENT_DATABASE -Query $sql -QueryTimeout 30 -ErrorAction Stop | Select -Expand ImpFilePath

foreach ($Script in $ToBeChecked) {
	& \\RCHPWVMGMSQL01.prod.corpint.net\D\SQLImplementations\Scripts\CheckRule.ps1 -Check "$Script" -AutoQA -ShowOutput
}
