<#
.SYNOPSIS
	Executes all .sql files in the current directory against the specified SQL Server.
.PARAMETER Instance
	SQL instance to connect to.
.PARAMETER Database
	The database to connect to.
.PARAMETER BreakOnFailure
	If specified, changes the delay between checks from 1000 milliseconds.
#>
[cmdletbinding(SupportsShouldProcess = $false)]
Param(
	[Parameter(Mandatory = $true, ValueFromPipeLine = $true, ValueFromPipeLineByPropertyName = $true, Position = 0)]
		[string]$Instance,
	[Parameter(Mandatory = $true, Position = 1)]
		[string]$Database,
	[Parameter(Mandatory = $false, Position = 2)]
		[switch]$BreakOnFailure
)

if (-not (Get-Module sqlps)) {
	Push-Location						# Push and Pop to avoid import from changing the current directory (http://stackoverflow.com/questions/12915299/sql-server-2012-sqlps-module-changing-current-location-automatically)
	Import-Module sqlps 3>&1 | Out-Null	# 3>&1 puts warning stream to standard output stream (https://connect.microsoft.com/PowerShell/feedback/details/297055/capture-warning-verbose-debug-and-host-output-via-alternate-streams)
	Pop-Location						# Out-Null blocks that output, so we don't see the annoying warnings (https://www.codykonior.com/2015/05/30/whats-wrong-with-sqlps/)
}

foreach ($script in Get-ChildItem -Filter '*.sql' | Sort-Object) {
	Write-Host ("Executing {0} on {1}..." -f $script, $Instance)
	# to abort on failure, add -ErrorAction Stop
	try {
		Invoke-SqlCmd -ServerInstance $Instance -Database $Database -InputFile $script.FullName -QueryTimeout 30
	}
	catch {
		Write-Host 'Error executing script against target server.' -ForegroundColor 'Red'
		if ($BreakOnFailure -eq $true) {
			exit 1
		}
	}
}
