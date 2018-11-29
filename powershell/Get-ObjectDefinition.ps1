<#
.SYNOPSIS
	Generate creation script for specified object.
.PARAMETER Instance
	SQL Server instance name. Required.
.PARAMETER Database
	Database where object to be scripted exists. Required.
.PARAMETER Schema
	Schema of object, defaults to dbo.
.PARAMETER Object
	Name of object. Required.
.EXAMPLE
	.\Get-ObjectDefinition.ps1 -Instance '(local)' -Database 'master' -Schema 'dbo' -Object 'ConnectionLog'
.NOTES
	02/13/2017	lordbeazley	Initial release.
#>
[CmdletBinding(SupportsShouldProcess = $false, PositionalBinding = $false, ConfirmImpact = 'Low')]
Param(
	[Parameter(Mandatory = $true, ValueFromPipeLine = $true, ValueFromPipeLineByPropertyName = $true, Position = 0)]
		[string]$Instance,
	[Parameter(Mandatory = $true, Position = 1)]
		[string]$Database,
	[Parameter(Mandatory = $false, Position = 2)]
		[string]$Schema = 'dbo',
	[Parameter(Mandatory = $true, Position = 3)]
		[string]$Object
)

if (-not (Get-Module sqlps)) {
	Push-Location						# Push and Pop to avoid import from changing the current directory (http://stackoverflow.com/questions/12915299/sql-server-2012-sqlps-module-changing-current-location-automatically)
	Import-Module sqlps 3>&1 | Out-Null	# 3>&1 puts warning stream to standard output stream (https://connect.microsoft.com/PowerShell/feedback/details/297055/capture-warning-verbose-debug-and-host-output-via-alternate-streams)
	Pop-Location						# Out-Null blocks that output, so we don't see the annoying warnings (https://www.codykonior.com/2015/05/30/whats-wrong-with-sqlps/)
}

$InstanceObj = New-Object Microsoft.SqlServer.Management.Smo.Server ($Instance)
$DatabaseObj = $InstanceObj.Databases[$Database]
$URNs = New-Object Microsoft.SqlServer.Management.Smo.UrnCollection

# find matching object(s)
$DatabaseObj.EnumObjects() |
	where {$_.Schema -eq $Schema -and $_.Name -eq $Object } |
	foreach {
		$URN = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.Urn($_.Urn)
		$URNs.Add($URN)
	}

if ($URNs.Count -gt 0) {

	# new script object and options
	$SMO = New-Object Microsoft.SqlServer.Management.Smo.Scripter ($InstanceObj)
	#$SMO.Options.AppendToFile = $true
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
	#$SMO.Options.FileName = "$Schema.$Name.sql"
	$SMO.Options.IncludeHeaders = $true
	#$SMO.Options.IncludeIfNotExists = $true
	$SMO.Options.Indexes = $true
	$SMO.Options.NoCollation = $true
	$SMO.Options.Permissions = $true
	$SMO.Options.SchemaQualify = $true
	$SMO.Options.ScriptBatchTerminator = $true
	#$SMO.Options.ToFileOnly = $true
	$SMO.Options.Triggers = $true

	# script out matching object(s)
	$SMO.Script($URNs)

} else {

	Write-Host ("`r`nOBJECT NOT FOUND: [{0}].[{1}].[{2}].[{3}]`r`n" -f $Instance, $Database, $Schema, $Object) -ForegroundColor 'Red'

}
