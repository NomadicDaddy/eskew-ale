<#
.SYNOPSIS
	Check scripts for standards compliance prior to implementation or deployment.
.DESCRIPTION
	<>
.PARAMETER Check
	<filename> or <path>
.PARAMETER Log
	If specified, records results to a file-specific logfile.
.PARAMETER AutoQA
	If specified, will set scripts to preliminary QA review complete or review failed, as appropriate.
.PARAMETER ShowOutput
	If specified, will output to console even in batch mode.
.PARAMETER CheckRule
	If specified, will just check rule # specified.
.PARAMETER Hash
	If specified, will log the hash.
.EXAMPLE
	CheckRule.ps1 -Check .\01_PR_Finance_MPr_GL_pr_DailyGL_MonthlySnapshot.sql
.EXAMPLE
	CheckRule.ps1 -Check .\01_PR_Finance_MPr_GL_pr_DailyGL_MonthlySnapshot.sql -Log
.EXAMPLE
	CheckRule.ps1 -Check .\US99999 -ShowOutput
.EXAMPLE
	CheckRule.ps1 -Check \\RCHPWVMGMSQL01.prod.corpint.net\D\SQLImplementations\_ImpMaster\11858______AUTOFINANCE__PI01_R2\US70802 -ShowOutput -AutoQA
.NOTES
	11/09/2016	pbeazley	Initial release.
#>
[cmdletbinding(SupportsShouldProcess=$true)]
Param(
	[Parameter(Mandatory = $true, ValueFromPipeLine = $true, ValueFromPipeLineByPropertyName = $true, Position = 0)]
		[string]$Check,
	[Parameter(Mandatory = $false, Position = 1)]
		[Switch]$Log,
	[Parameter(Mandatory = $false, Position = 2)]
		[Switch]$AutoQA,
	[Parameter(Mandatory = $false, Position = 3)]
		[Switch]$ShowOutput,
	[Parameter(Mandatory = $false, Position = 4)]
		[int]$CheckRule,
	[Parameter(Mandatory = $false, Position = 5)]
		[string]$Hash = ''
)

$MANAGEMENT_INSTANCE = 'RCHPWVMGMSQL01.prod.corpint.net\MANAGEMENT01'
$MANAGEMENT_DATABASE = 'SQLImplementations'
$IMPLEMENTATION_ROOT = '\\RCHPWVMGMSQL01.prod.corpint.net\SQLIMPLEMENTATIONS\Imp\Master'
$ConsolidatedLog = 'C:\Temp\CheckRule.txt'

$colors = @{'Failure' = 'Red'; 'Warning' = 'Yellow'; 'Pass' = 'Green'}
$words = @{'Failure' = 'fail'; 'Warning' = 'warn'; 'Pass' = 'pass'}

# ensure path or file exists
if (($Check -ne '') -and ((Test-Path -Path $Check -PathType Any) -eq $true)) {
	$BatchMode = $true
	if ((Test-Path -Path $Check -PathType Leaf) -eq $true) {
		$BatchMode = $false
	}
} else {
	Write-Host 'Path or file not found.' -ForegroundColor $colors.Failure
	exit 1
}

function Import-Module-SQLPS {
	Push-Location						# Push and Pop to avoid import from changing the current directory (http://stackoverflow.com/questions/12915299/sql-server-2012-sqlps-module-changing-current-location-automatically)
	Import-Module sqlps 3>&1 | Out-Null	# 3>&1 puts warning stream to standard output stream (https://connect.microsoft.com/PowerShell/feedback/details/297055/capture-warning-verbose-debug-and-host-output-via-alternate-streams)
	Pop-Location						# Out-Null blocks that output, so we don't see the annoying warnings (https://www.codykonior.com/2015/05/30/whats-wrong-with-sqlps/)
}
if (!(Get-Module sqlps)) { Import-Module-SQLPS }

function Write-Tee {
	<#
	.SYNOPSIS
		Splits the output into two streams, one for the host (allowing foreground coloring) and one for a file.
	.PARAMETER String
		The string to be sent to console and file.
	.PARAMETER NoNewLine
		If specified, does not end the string with newline characters.
	.PARAMETER ForegroundColor
		If specified, will set the foreground color for console output.
	.PARAMETER OutputFile
		If specified, writes the string to the file.
	.PARAMETER Timestamp
		If specified, adds a timestamp to each entry writtten to the file.
	.PARAMETER NoConsole
		If specified, does not output anything to the console.
	#>
	Param(
		[Parameter(Mandatory = $false, ValueFromPipeLine = $true, ValueFromPipeLineByPropertyName = $true, Position = 0)]
			[String]$String,
		[Parameter(Mandatory = $false, Position = 1)]
			[Switch]$NoNewLine,
		[Parameter(Mandatory = $false, Position = 2)]
			#[enum]::GetValues([System.ConsoleColor])
			[ValidateSet('Black', 'DarkBlue', 'DarkGreen', 'DarkCyan', 'DarkRed', 'DarkMagenta', 'DarkYellow', 'Gray', 'DarkGray', 'Blue', 'Green', 'Cyan', 'Red', 'Magenta', 'Yellow', 'White')]
			[String]$ForegroundColor = 'Gray',
		[Parameter(Mandatory = $false, Position = 3)]
			[String]$OutputFile,
		[Parameter(Mandatory = $false, Position = 4)]
			[Switch]$Timestamp,
		[Parameter(Mandatory = $false, Position = 5)]
			[String]$NoConsole
	)
	if ($NoConsole -ne $true) {
		if ($NoNewLine) {
			Write-Host $String -ForegroundColor $ForegroundColor -NoNewLine
		} else {
			Write-Host $String -ForegroundColor $ForegroundColor
		}
	}
	if (($OutputFile -ne '') -and ((Test-Path $OutputFile) -eq $true)) {
		if ($Timestamp) {
			$string = ('[{0}] $string' -f $(Get-Date))
		}
		if ($NoNewLine) {
			Add-Content -Path $OutputFile -Encoding Ascii $String -NoNewLine
		} else {
			Add-Content -Path $OutputFile -Encoding Ascii $String
		}
	}
}

$BatchStart = Invoke-SqlCmd -ServerInstance $MANAGEMENT_INSTANCE -Database $MANAGEMENT_DATABASE -Query 'select [batchStart] = getdate() ;' -QueryTimeout 30 -ErrorAction Stop | Select -Expand batchStart

# load standard rules
$rules = Invoke-SqlCmd -ServerInstance $MANAGEMENT_INSTANCE -Database $MANAGEMENT_DATABASE -Query 'select [CheckRuleID], [CheckRuleName], [CheckRuleDescription], [FailScript], [IgnoreComments], [Rule1Match], [Rule1Regex], [Rule2Match], [Rule2Regex] from dbo.[CheckRule] where [Enabled] = 1 order by [CheckRuleID] asc ;' -QueryTimeout 30 -ErrorAction Stop
$RuleCount = $rules.Count

if ($BatchMode -eq $false) {
	$CheckCollection = $(Get-ChildItem -Path $Check -Filter *.sql -Name)
} else {
	$CheckCollection = $(Get-ChildItem -Path $Check -Filter *.sql -Name -Recurse)
}

foreach ($CurrentFile in $CheckCollection | Sort-Object) {

	# reset counters
	$counts = @{'Failure' = 0; 'Warning' = 0; 'Pass' = 0;}

	# get file(s)
	if ($BatchMode -eq $false) {
		$CurrentFile = Convert-Path -Path $Check
	} else {
		$CurrentFile = Convert-Path -Path ('{0}\{1}' -f $Check, $CurrentFile)
	}

	# don't score unnecessary files
	if (($CurrentFile -like '*\Archive\*') -or ($CurrentFile -like '*\Backup\*') -or ($CurrentFile -like '*\Logs\*') -or ($CurrentFile -like '*\Old*\*')) {
#		Write-Host ('-- ignore {0}' -f $CurrentFile)
		continue
	}

	$Quiet = !($ShowOutput -eq $true -or $BatchMode -eq $false)

	# normalize implementation path
	$CurrentFile = $CurrentFile -Replace '(\w{1}:\\|\\\\).+\\_ImpMaster', $IMPLEMENTATION_ROOT

	# ensure logfile exists, if needed
	if ($Log -eq $true) {
		if ($Hash -eq '') {
			$OutputFile = $CurrentFile + '.log'
			if ((Test-Path -Path $OutputFile -PathType Leaf) -eq $true) {
				Remove-Item $OutputFile -Force
			}
			New-Item -ItemType file $OutputFile | Out-Null
		} else {
			$OutputFile = $ConsolidatedLog
			if ((Test-Path -Path $OutputFile) -eq $false) {
				New-Item -ItemType file $OutputFile | Out-Null
			}
		}
	}

	# file being checked
	$sql = $(Get-Content -Path $CurrentFile -Encoding Ascii -Raw)
	if ($BatchMode -eq $false -or $Quiet -eq $false) {
		Write-Host
		Write-Host (':: {0}' -f $CurrentFile) -ForegroundColor 'Black' -BackgroundColor 'White'
		Write-Host
	}
	if ($Hash -ne '') {
		Write-Tee $("----------------------------------------------------------------------------------------------------------------------------------------------------`r`n{0}`r`n----------------------------------------------------------------------------------------------------------------------------------------------------" -f $CurrentFile) -OutputFile $OutputFile -NoConsole $Quiet
		Write-Tee ("Revision:    {0}" -f $Hash) -OutputFile $OutputFile -NoConsole $Quiet
	}
	Write-Tee ("Executed By: {0}\{1}`r`nExecuted On: {2}`r`n" -f [Environment]::UserDomainName, [Environment]::UserName, $(Get-Date)) -OutputFile $OutputFile -NoConsole $Quiet

	# remove comments
	$sqlraw = $sql
	$sqlclean = $sql -ireplace "--.*|\/\*.*\*\/", ""
	$sqlclean = $sqlclean -ireplace "\/\*(.|\s)*?\*\/", ""

	# insert placeholder for script
	$BatchID = Invoke-SqlCmd -ServerInstance $MANAGEMENT_INSTANCE -Database $MANAGEMENT_DATABASE -Query ("insert into dbo.[CheckScript] ([Revision], [ScriptPath], [CheckDate], [CheckedBy]) values ('{0}', '{1}', '{2}', '{3}\{4}') ; select [batchid] = Scope_Identity() ;" -f $Hash, $CurrentFile, $BatchStart, [Environment]::UserDomainName, [Environment]::UserName) -QueryTimeout 30 -ErrorAction Stop | Select -Expand batchid

	# loop through rules
	$ScriptPassed = 1
	$RuleNumber = 0
	foreach ($rule in $rules) {

		$CheckRuleID = $rule[0]
		[string]$CheckRuleName = $rule[1].Trim()
		[string]$CheckRuleDescription = $rule[2].Trim()
		$FailScript = $rule[3]
		$IgnoreComments = $rule[4]
		[string]$Rule1Match = $rule[5]
		[string]$Rule1Regex = $rule[6].Trim()
		[string]$Rule2Match = $rule[7]
		[string]$Rule2Regex = $rule[8]

		if ($FailScript -eq $true) {
			$FailScript = 'Failure'
		} else {
			$FailScript = 'Warning'
		}

		if ($IgnoreComments -eq $true) {
			$sql = $sqlclean
		} else {
			$sql = $sqlraw
		}

		if ($(Test-Path variable:$Rule2Match)) { $Rule2Match = '' } else { $Rule2Match = $Rule2Match.Trim() }
		if ($(Test-Path variable:$Rule2Regex)) { $Rule2Regex = '' } else { $Rule2Match = $Rule2Regex.Trim() }

		# update progress
		$RuleNumber++
		if ($CheckRuleID -ne $CheckRule -and $CheckRule -ne 0) {
#			Write-Host ('-- skipping {0}' -f $CheckRuleID)
			continue
		}

		if ($Quiet -eq $false -or $CheckRule -ne 0) {
			$PercentDone = [math]::Round(($RuleNumber / $RuleCount * 100) ,2)
			Write-Progress -Activity 'Checking rules...' -Status "Progress: $PercentDone%" -PercentComplete $PercentDone
		}
		Write-Tee ('Checking Rule #{0,2} [{1,-40}] ' -f $CheckRuleID, $CheckRuleName) -NoNewline -ForegroundColor 'White' -NoConsole $Quiet
		$RulePassed = $false

		# check rule #1
		$rule1 = $false
		if ((($Rule1Match -eq 'True') -and ($sql -imatch $Rule1Regex)) -or (($Rule1Match -eq 'False') -and -not ($sql -imatch $Rule1Regex))) {
			$rule1 = $true
		}

		# check rule #2
		$rule2 = $false
		if ((($Rule2Match -eq 'True') -and ($sql -imatch $Rule2Regex)) -or (($Rule2Match -eq 'False') -and -not ($sql -imatch $Rule2Regex)) -or ($Rule2Regex -eq '')) {
			$rule2 = $true
		}

		# logical and rule1 and rule2
		if (($rule1 -eq $true) -and ($rule2 -eq $true)) {
			$counts.$FailScript++
			Write-Tee ('{0} : {1}' -f $words.$FailScript, $CheckRuleDescription) -ForegroundColor $colors.$FailScript -NoConsole $Quiet
			$CheckResults = ('{0} : {1}' -f $words.$FailScript, $CheckRuleDescription)
		} else {
			$counts.Pass++
			$RulePassed = $true
			Write-Tee ('{0}' -f $words.Pass) -ForegroundColor $colors.Pass -NoConsole $Quiet
			$CheckResults = ('{0}' -f $words.Pass)
		}

		# set script-level pass/fail
		if ($RulePassed -eq $true) {
			$RulePassed = 1
		} else {
			$RulePassed = 0
			if ($FailScript -eq 'Failure') {
				$ScriptPassed = 0
			}
		}

		Write-Tee ('Checking Rule #{0,2} [{1,-40}] {2}' -f $CheckRuleID, $CheckRuleName, $CheckResults) -OutputFile $OutputFile -NoConsole $true

		# log status for rule
		Invoke-SqlCmd -ServerInstance $MANAGEMENT_INSTANCE -Database $MANAGEMENT_DATABASE -Query ('insert into dbo.[CheckScriptDetail] ([CheckScriptID], [CheckRuleID], [Passed]) values ({0}, {1}, {2}) ;' -f $BatchID, $CheckRuleID, $RulePassed) -QueryTimeout 30 -ErrorAction Stop

#		# show condition evaluations
#		Write-Host ("`r`n	Condition #1 : {0}" -f $rule1)
#		if (!($Rule2Regex -eq '')) { Write-Host ("{0}`r`n	Condition #2 : {1}" -f $ruleJoin, $rule2) }

	}

	# set QAReviewState as passed/failed
	if ($AutoQA -eq $true) {
		$QAReviewStateID = 998
		if ($ScriptPassed -eq 1) { $QAReviewStateID = 2 }
		Invoke-SqlCmd -ServerInstance $MANAGEMENT_INSTANCE -Database $MANAGEMENT_DATABASE -Query ("update dbo.[ImplementationDetail] set [QAReviewStateID] = {0}, [cCreatedBy] = 'CHECKRULE' where [ImpFilePath] = '{1}' and [QAReviewStateID] = 1 ;" -f $QAReviewStateID, $CurrentFile) -QueryTimeout 30 -ErrorAction SilentlyContinue
		if ($QAReviewStateID -eq 998) {
			$ImplementationDetailID = Invoke-SqlCmd -ServerInstance $MANAGEMENT_INSTANCE -Database $MANAGEMENT_DATABASE -Query ("select [ImplementationDetailID] = Max([ImplementationDetailID]) from dbo.[ImplementationDetail] where [ImpFilePath] = '{0}' ;" -f $CurrentFile) -QueryTimeout 30 -ErrorAction SilentlyContinue | Select -Expand ImplementationDetailID
			if ($ImplementationDetailID -ne '') {
				Invoke-SqlCmd -ServerInstance $MANAGEMENT_INSTANCE -Database $MANAGEMENT_DATABASE -Query ("insert into dbo.[ImplementationNotes] ([ImplementationDetailID], [Notes], [cCreatedBy], [nCurrReviewState]) values ({0}, 'See [CheckScriptDetails] for error list.', 'CHECKRULE', {1}) ;" -f $ImplementationDetailID, $QAReviewStateID) -QueryTimeout 30 -ErrorAction SilentlyContinue
			}
		}
	}

	# log status for script
	Invoke-SqlCmd -ServerInstance $MANAGEMENT_INSTANCE -Database $MANAGEMENT_DATABASE -Query ('update dbo.[CheckScript] set [Passed] = {0} where [CheckScriptID] = {1} ;' -f $ScriptPassed, $BatchID) -QueryTimeout 30 -ErrorAction Stop

	# show counts
	Write-Tee ("`r`nRules:		{0,2}" -f ($counts.Failure + $counts.Warning + $counts.Pass)) -OutputFile $OutputFile -NoConsole $Quiet
	Write-Tee ('  Failures	{0,2}' -f $counts.Failure) -ForegroundColor $colors.Failure -OutputFile $OutputFile -NoConsole $Quiet
	Write-Tee ('  Warnings	{0,2}' -f $counts.Warning) -ForegroundColor $colors.Warning -OutputFile $OutputFile -NoConsole $Quiet
	Write-Tee ('  Passed	{0,2}' -f $counts.Pass) -ForegroundColor $colors.Pass -OutputFile $OutputFile -NoConsole $Quiet
	Write-Tee '' -OutputFile $OutputFile -NoConsole $Quiet

	# standards link
	Write-Tee "Please refer to the following document for more detailed information and current review practices:`r`nhttps://scusa.app.corpint.net/sites/driveit/EDS/DBA/Public%20Documents/DB%20Standards%20and%20Best%20Practices/Code_Review_Checklist.docx`r`n" -OutputFile $OutputFile -NoConsole $Quiet

	# show final status for script
	if ($counts.Failure -gt 0) {
		Write-Tee "Script failed validation and cannot be deployed as-is. Please fix the specified issues before proceeding.`r`n" -ForegroundColor $colors.Failure -OutputFile $OutputFile -NoConsole $Quiet
		if ($BatchMode -eq $false) { exit 1 }
	} elseif ($counts.Warning -gt 0) {
		Write-Tee "Script passed validation but with minor concerns. You should fix the specified issues before proceeding.`r`n" -ForegroundColor $colors.Warning -OutputFile $OutputFile -NoConsole $Quiet
		if ($BatchMode -eq $false) { exit 0 }
	} else {
		Write-Tee "Script passed validation.`r`n" -ForegroundColor $colors.Pass -OutputFile $OutputFile -NoConsole $Quiet
		if ($BatchMode -eq $false) { exit 0 }
	}

}
