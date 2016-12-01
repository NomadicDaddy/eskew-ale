#.\eskew-ale\powershell\sqltail.ps1 -Instance 'RCHPWVMGMSQL02.prod.corpint.net\MANAGEMENT02' -Database 'SQLImplementations' -Table 'CheckScript' -LoopMS 2000 -RowsBack 1
#.\eskew-ale\powershell\sqltail.ps1 -Instance 'RCHPWVMGMSQL01.prod.corpint.net\MANAGEMENT01' -Database 'SQLImplementations' -Table 'foplog' -LoopMS 2500 -RowsBack 1

<#
.SYNOPSIS
	Provides tail monitoring functionality on a table.
.DESCRIPTION
	Stuff happens.
.PARAMETER Instance
	SQL instance to connect to.
.PARAMETER Database
	The database to connect to.
.PARAMETER Table
	The table to monitor.
.PARAMETER RowsBack
	If specified, changes the initial rows to output from 5.
.PARAMETER LoopMS
	If specified, changes the delay between checks from 1000 milliseconds.
.LINK
	Nachos?
#>
[cmdletbinding(SupportsShouldProcess=$true)]
Param(
	[Parameter(Mandatory = $true, ValueFromPipeLine = $true, ValueFromPipeLineByPropertyName = $true, Position = 0)]
		[string]$Instance,
	[Parameter(Mandatory = $true, Position = 1)]
		[string]$Database,
	[Parameter(Mandatory = $true, Position = 2)]
		[string]$Table,
	[Parameter(Mandatory = $false, Position = 3)]
		[int]$RowsBack = 5,
	[Parameter(Mandatory = $false, Position = 4)]
		[int]$LoopMS = 1000
)

# todo:
# - modes (new rows, state change)
# - filtered option on new rows mode

function Import-Module-SQLPS {
	Push-Location						# Push and Pop to avoid import from changing the current directory (http://stackoverflow.com/questions/12915299/sql-server-2012-sqlps-module-changing-current-location-automatically)
	Import-Module sqlps 3>&1 | Out-Null	# 3>&1 puts warning stream to standard output stream (https://connect.microsoft.com/PowerShell/feedback/details/297055/capture-warning-verbose-debug-and-host-output-via-alternate-streams)
	Pop-Location						# Out-Null blocks that output, so we don't see the annoying warnings (https://www.codykonior.com/2015/05/30/whats-wrong-with-sqlps/)
}
if (!(Get-Module sqlps)) { Import-Module-SQLPS }

# get primary key column for tracking
try {
	$PK = Invoke-SqlCmd -ServerInstance $INSTANCE -Database $DATABASE -Query ("use [{0}] ; select [column_name] from information_schema.table_constraints [tc] inner join information_schema.constraint_column_usage [ccu] on tc.[constraint_name] = ccu.[constraint_name] and tc.[constraint_type] = 'Primary Key' where tc.[table_name] = '{1}' ;" -f $DATABASE, $TABLE) -QueryTimeout 5 -ErrorAction Stop | Select -Expand column_name
} catch {
	Write-Host 'Could not determine primary key of specified table. This is required for row tracking.' -ForegroundColor 'Red'
	exit 1
}

# get current max key
try {
	$MaxKey = Invoke-SqlCmd -ServerInstance $INSTANCE -Database $DATABASE -Query ('select Coalesce(Max([{0}]), 0) as [MaxKey] from [{1}] ;' -f $PK, $TABLE) -QueryTimeout 30 -ErrorAction Stop | Select -Expand MaxKey
} catch {
	Write-Host 'Unable to obtain the max key from specified table. Are you sure it exists?' -ForegroundColor 'Red'
	exit 1
}

# this isn't guaranteed to grab X rows (gaps may exist in sequence) - a windowing function could be helpful here
$PrevKey = $MaxKey - $RowsBack

while($true) {

	$StartTime = Get-Date

	try {
		$MaxKey = Invoke-SqlCmd -ServerInstance $INSTANCE -Database $DATABASE -Query ('select Coalesce(Max([{0}]), 0) as [MaxKey] from [{1}] ;' -f $PK, $TABLE) -QueryTimeout 30 -ErrorAction Stop | Select -Expand MaxKey
	} catch {
		Write-Host 'Unable to obtain the max key from specified table. Are you sure it exists?' -ForegroundColor 'Red'
		exit 1
	}

	if ($MaxKey -gt $PrevKey) {
		try {
			Invoke-SqlCmd -ServerInstance $INSTANCE -Database $DATABASE -Query ('select * from [{0}] where [{1}] > {2} order by {1} asc ;' -f $TABLE, $PK, $PrevKey) -QueryTimeout 30 -ErrorAction Stop
		} catch {
			Write-Host 'Unable to obtain new rows.' -ForegroundColor 'Red'
			exit 1
		}
		foreach ($row in $rows) {
			Write-Host $($row[0])
		}
		$PrevKey = $MaxKey
	}

	$EndTime = Get-Date

	$Delay = $LoopMS - ($EndTime - $StartTime).TotalMilliseconds
	if ($Delay -gt 0) {
		Start-Sleep -Milliseconds $Delay
	}

}
