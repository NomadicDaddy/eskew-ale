function Import-Module-SQLPS {
	Push-Location						# Push and Pop to avoid import from changing the current directory (http://stackoverflow.com/questions/12915299/sql-server-2012-sqlps-module-changing-current-location-automatically)
	Import-Module sqlps 3>&1 | Out-Null	# 3>&1 puts warning stream to standard output stream (https://connect.microsoft.com/PowerShell/feedback/details/297055/capture-warning-verbose-debug-and-host-output-via-alternate-streams)
	Pop-Location						# Out-Null blocks that output, so we don't see the annoying warnings (https://www.codykonior.com/2015/05/30/whats-wrong-with-sqlps/)
}
if (!(Get-Module sqlps)) { Import-Module-SQLPS }

$rows = Invoke-SqlCmd -ServerInstance '(local)' -Database 'master' -Query 'select [ServerName] = @@servername, [Version] = @@version ;' -QueryTimeout 30 -ErrorAction Stop

foreach ($row in $rows) {
	Write-Host ("`r`n{0}`r`n{1}" -f $row.ServerName, $row.Version)
#	Invoke-Expression $($row[0])
}
