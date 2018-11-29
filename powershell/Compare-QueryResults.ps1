<#
.SYNOPSIS
	Compares the results of two queries (or the same query on two different instances or databases or both) using BeyondCopmare to handle the comparison.
.DESCRIPTION
	Executes the query (or queries) against the source and target instance and database.
.EXAMPLE
	Compare-QueryResults -SourceQuery (Get-Content myfile.sql) -TargetQuery (Get-Content otherfile.sql) -SourceInstance m1
.EXAMPLE
	Compare-QueryResults -SourceQuery 'select @@version ;' -SourceInstance m1 -SourceInstance m2
.NOTES
	06/19/2017	lordbeazley	Initial release.
#>
[CmdletBinding(SupportsShouldProcess = $false, PositionalBinding = $false, ConfirmImpact = 'Low')]
Param(
	[Parameter(Mandatory = $false, Position = 0)]
		[string]$DiffCmd = 'C:\Program Files\Beyond Compare 4\BCompare.exe'
)

$SourceOutput = "$env:TEMP\SourceOutput.sql"
$TargetOutput = "$env:TEMP\TargetOutput.sql"

if (-not (Test-Path -LiteralPath $DiffCmd -PathType Leaf)) {
	$DiffCmd = 'C:\Program Files (x86)\Beyond Compare 4\BCompare.exe'
}
if (-not (Test-Path -LiteralPath $DiffCmd -PathType Leaf)) {
	$DiffCmd = 'C:\Program Files\Beyond Compare 2\BC2.exe'
}
if (-not (Test-Path -LiteralPath $DiffCmd -PathType Leaf)) {
	$DiffCmd = 'C:\Program Files (x86)\Beyond Compare 2\BC2.exe'
}
if (-not (Test-Path -LiteralPath $DiffCmd -PathType Leaf)) {
	Write-Output ("Please supply your text comparison program path/filename using -DiffCmd. ""{0}"" cannot be found.`r`n" -f $DiffCmd)
	exit 1
}

if (-not (Get-Module sqlps)) {
	Push-Location						# Push and Pop to avoid import from changing the current directory (http://stackoverflow.com/questions/12915299/sql-server-2012-sqlps-module-changing-current-location-automatically)
	Import-Module sqlps 3>&1 | Out-Null	# 3>&1 puts warning stream to standard output stream (https://connect.microsoft.com/PowerShell/feedback/details/297055/capture-warning-verbose-debug-and-host-output-via-alternate-streams)
	Pop-Location						# Out-Null blocks that output, so we don't see the annoying warnings (https://www.codykonior.com/2015/05/30/whats-wrong-with-sqlps/)
}

# SOURCE
$SourceQuery = @"
"@

# TARGET
$TargetQuery = @"
"@

# OUTPUT
Invoke-SqlCmd -ServerInstance '(local)' -Database 'master' -Query $SourceQuery -QueryTimeout 60 -ErrorAction Stop | Format-Table | Out-File -FilePath $SourceOutput
Invoke-SqlCmd -ServerInstance '(local)' -Database 'master' -Query $TargetQuery -QueryTimeout 60 -ErrorAction Stop | Format-Table | Out-File -FilePath $TargetOutput

# COMPARE
& $($DiffCmd) "$SourceOutput" "$TargetOutput"
