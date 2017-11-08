<#
.SYNOPSIS
	Generate temporary creation scripts for object comparision and then launches compare app.
.PARAMETER SourceInstance
	SOURCE SQL Server instance name. Required.
.PARAMETER SourceDatabase
	Database where SOURCE object to be scripted exists. Required.
.PARAMETER SourceSchema
	Schema of SOURCE object, defaults to dbo.
.PARAMETER SourceObject
	Name of SOURCE object. Required.
.PARAMETER TargetInstance
	TARGET SQL Server instance name. Required.
.PARAMETER TargetDatabase
	Database where TARGET object to be scripted exists. Required.
.PARAMETER TargetSchema
	Schema of TARGET object, defaults to dbo.
.PARAMETER TargetObject
	Name of TARGET object. Required.
.EXAMPLE
	.\Compare-DatabaseObject.ps1 -SourceInstance '(local)' -SourceDatabase 'db1' -SourceSchema 'dbo' -SourceObject 'pr_test' -TargetInstance 'OTHERSVR' -TargetDatabase 'db1' -TargetSchema 'dbo' -TargetObject 'pr_test'
.NOTES
	02/28/2017	pbeazley	Initial release.
#>
[CmdletBinding(SupportsShouldProcess = $false)]
Param(
	[Parameter(Mandatory = $true, ValueFromPipeLine = $true, ValueFromPipeLineByPropertyName = $true, Position = 0)]
		[string]$SourceInstance,
	[Parameter(Mandatory = $true, Position = 1)]
		[string]$SourceDatabase,
	[Parameter(Mandatory = $false, Position = 2)]
		[string]$SourceSchema = 'dbo',
	[Parameter(Mandatory = $true, Position = 3)]
		[string]$SourceObject,
	[Parameter(Mandatory = $true, Position = 4)]
		[string]$TargetInstance,
	[Parameter(Mandatory = $true, Position = 5)]
		[string]$TargetDatabase,
	[Parameter(Mandatory = $false, Position = 6)]
		[string]$TargetSchema = 'dbo',
	[Parameter(Mandatory = $true, Position = 7)]
		[string]$TargetObject
)

$SourceObjectFile = "$env:TEMP\SourceObjectFile.sql"
$TargetObjectFile = "$env:TEMP\TargetObjectFile.sql"

$DiffCmd = 'C:\Program Files\Beyond Compare 4\BCompare.exe'

if (-not (Get-Module sqlps)) {
	Push-Location						# Push and Pop to avoid import from changing the current directory (http://stackoverflow.com/questions/12915299/sql-server-2012-sqlps-module-changing-current-location-automatically)
	Import-Module sqlps 3>&1 | Out-Null	# 3>&1 puts warning stream to standard output stream (https://connect.microsoft.com/PowerShell/feedback/details/297055/capture-warning-verbose-debug-and-host-output-via-alternate-streams)
	Pop-Location						# Out-Null blocks that output, so we don't see the annoying warnings (https://www.codykonior.com/2015/05/30/whats-wrong-with-sqlps/)
}

# SOURCE

$SourceInstanceObj = New-Object Microsoft.SqlServer.Management.Smo.Server ($SourceInstance)
$SourceDatabaseObj = $SourceInstanceObj.Databases[$SourceDatabase]
$SourceURNs = New-Object Microsoft.SqlServer.Management.Smo.UrnCollection

# find matching object(s)
$SourceDatabaseObj.EnumObjects() |
	where {$_.Schema -eq $SourceSchema -and $_.Name -eq $SourceObject } |
	foreach {
		$SourceURN = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.Urn($_.Urn)
		$SourceURNs.Add($SourceURN)
	}

if ($SourceURNs.Count -gt 0) {

	# new script object and options
	$SMO = New-Object Microsoft.SqlServer.Management.Smo.Scripter ($SourceInstanceObj)
	$SMO.Options.AppendToFile = $false
	$SMO.Options.Bindings = $true
	$SMO.Options.ContinueScriptingOnError = $true
	$SMO.Options.DriAll = $true
	$SMO.Options.DriAllKeys = $true
	$SMO.Options.DriChecks = $true
	$SMO.Options.DriClustered = $true
	$SMO.Options.DriDefaults = $true
	$SMO.Options.DriForeignKeys = $true
	$SMO.Options.DriIndexes = $true
	$SMO.Options.DriNonClustered = $true
	$SMO.Options.DriPrimaryKey = $true
	$SMO.Options.DriUniqueKeys = $true
	$SMO.Options.DriWithNocheck = $true
	$SMO.Options.FileName = $SourceObjectFile
	$SMO.Options.IncludeHeaders = $true
	#$SMO.Options.IncludeIfNotExists = $true
	$SMO.Options.Indexes = $true
	$SMO.Options.NoCollation = $true
	$SMO.Options.Permissions = $true
	$SMO.Options.SchemaQualify = $true
	$SMO.Options.ScriptBatchTerminator = $true
	$SMO.Options.ToFileOnly = $true
	$SMO.Options.Triggers = $true

	# script out matching object(s)
	$SMO.Script($SourceURNs)

} else {

	Write-Host ("`r`nOBJECT NOT FOUND: [{0}].[{1}].[{2}].[{3}]`r`n" -f $SourceInstance, $SourceDatabase, $SourceSchema, $SourceObject) -ForegroundColor 'Red'

}

# TARGET

$TargetInstanceObj = New-Object Microsoft.SqlServer.Management.Smo.Server ($TargetInstance)
$TargetDatabaseObj = $TargetInstanceObj.Databases[$TargetDatabase]
$TargetURNs = New-Object Microsoft.SqlServer.Management.Smo.UrnCollection

# find matching object(s)
$TargetDatabaseObj.EnumObjects() |
	where {$_.Schema -eq $TargetSchema -and $_.Name -eq $TargetObject } |
	foreach {
		$TargetURN = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.Urn($_.Urn)
		$TargetURNs.Add($TargetURN)
	}

if ($TargetURNs.Count -gt 0) {

	# new script object and options
	$SMO = New-Object Microsoft.SqlServer.Management.Smo.Scripter ($TargetInstanceObj)
	$SMO.Options.AppendToFile = $false
	$SMO.Options.Bindings = $true
	$SMO.Options.ContinueScriptingOnError = $true
	$SMO.Options.DriAll = $true
	$SMO.Options.DriAllKeys = $true
	$SMO.Options.DriChecks = $true
	$SMO.Options.DriClustered = $true
	$SMO.Options.DriDefaults = $true
	$SMO.Options.DriForeignKeys = $true
	$SMO.Options.DriIndexes = $true
	$SMO.Options.DriNonClustered = $true
	$SMO.Options.DriPrimaryKey = $true
	$SMO.Options.DriUniqueKeys = $true
	$SMO.Options.DriWithNocheck = $true
	$SMO.Options.FileName = $TargetObjectFile
	$SMO.Options.IncludeHeaders = $true
	#$SMO.Options.IncludeIfNotExists = $true
	$SMO.Options.Indexes = $true
	$SMO.Options.NoCollation = $true
	$SMO.Options.Permissions = $true
	$SMO.Options.SchemaQualify = $true
	$SMO.Options.ScriptBatchTerminator = $true
	$SMO.Options.ToFileOnly = $true
	$SMO.Options.Triggers = $true

	# script out matching object(s)
	$SMO.Script($TargetURNs)

} else {

	Write-Host ("`r`nOBJECT NOT FOUND: [{0}].[{1}].[{2}].[{3}]`r`n" -f $TargetInstance, $TargetDatabase, $TargetSchema, $TargetObject) -ForegroundColor 'Red'

}

& $($DiffCmd) "$SourceObjectFile" "$TargetObjectFile"
