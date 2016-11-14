$SourceServer = 'RCHPWVMGMSQL02.prod.corpint.net\MANAGEMENT02'
$SourceDatabase = 'SQLImplementations'
$SourceSchema = 'dbo'
$SourceObject = 'imp_exceptions'

$TargetServer = 'RCHPWVMGMSQL01.prod.corpint.net\MANAGEMENT01'
$TargetDatabase = 'SQLImplementations'
$TargetSchema = 'dbo'
$TargetObject = 'imp_exceptions'

$SourceObjectFile = 'c:\temp\SourceObjectFile.sql'
$TargetObjectFile = 'c:\temp\TargetObjectFile.sql'

$DiffCmd = 'BCompare.exe'

function Import-Module-SQLPS {
	Push-Location						# Push and Pop to avoid import from changing the current directory (http://stackoverflow.com/questions/12915299/sql-server-2012-sqlps-module-changing-current-location-automatically)
	Import-Module sqlps 3>&1 | Out-Null	# 3>&1 puts warning stream to standard output stream (https://connect.microsoft.com/PowerShell/feedback/details/297055/capture-warning-verbose-debug-and-host-output-via-alternate-streams)
	Pop-Location						# Out-Null blocks that output, so we don't see the annoying warnings (https://www.codykonior.com/2015/05/30/whats-wrong-with-sqlps/)
}
if (!(Get-Module sqlps)) { Import-Module-SQLPS }

$Source = New-Object ("Microsoft.SqlServer.Management.SMO.Scripter")
$Source.Options.AppendToFile = $false
$Source.Options.Bindings = $true
$Source.Options.ContinueScriptingOnError = $true
$Source.Options.DriAll = $true
$Source.Options.IncludeIfNotExists = $false
$Source.Options.Indexes = $true
$Source.Options.NoCollation = $true
$Source.Options.Permissions = $true
$Source.Options.SchemaQualify = $true
$Source.Options.ToFileOnly = $true
$Source.Options.Triggers = $true

#& $($DiffCmd $SourceObjectFile $TargetObjectFile)
