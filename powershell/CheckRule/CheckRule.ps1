<#
.SYNOPSIS
	Checks the specified file for rule violations.
.DESCRIPTION
	Stuff happens.
.PARAMETER <paramName>
   -checkFile <filename>
#>
Param(
  [string]$checkFile
)

# location of output file

# TODO:
#
# - if no warnings or notices, set script to initial QA complete?
#
# - wrapper for directory level processing
#
# - log results:
#   script level pass/fail
#   script level failed check detail

# output all rule checks verbosely
$debug = $true

$colors = @{
	'Warning' = 'Red';
	'Notice' = 'Yellow';
	'Pass' = 'Green'
}
$counts = @{
	'Warning' = 0;
	'Notice' = 0;
	'Pass' = 0;
}

Write-Host ""

# make sure file exists
if ($checkFile -eq "" -or (Test-Path $checkFile) -eq $false) {
	Write-Host "File not found." -ForegroundColor $colors.warning
	break
}
$sql = Get-Content $checkFile

# file being checked
Write-Host ("Checking {0}" -f $checkFile) -ForegroundColor "Black" -BackgroundColor "White"
Write-Host ""

# load xml rules
[xml]$rulesFile = [xml](Get-Content -Path ".\stdCheck.xml")
[System.Xml.XmlElement] $root = $rulesFile.get_DocumentElement()
[System.Xml.XmlElement] $rules = $root
[System.Xml.XmlElement] $rule = $null

# loop through rules
$ruleNbr = 0
$ruleCount = $rules.CreateNavigator().Evaluate('count(/rules/rule)')
foreach ($rule in $rules.ChildNodes) {

	[string]$ruleName = $rule.name
	[string]$ruleEnabled = $rule.enabled
	[string]$ruleDescription = $rule.description
	[string]$ruleSeverity = $rule.severity
	[string]$ruleType1 = $rule.type1
	[string]$ruleRegex1 = $rule.regex1
	[string]$ruleJoin = $rule.join
	[string]$ruleType2 = $rule.type2
	[string]$ruleRegex2 = $rule.regex2

	if (!($ruleEnabled -eq 'false')) { $ruleEnabled = 'true' }
	if ($(Test-Path variable:$ruleJoin)) { $ruleJoin = 'and' }
	if ($(Test-Path variable:$ruleType2)) { $ruleType2 = '' }
	if ($(Test-Path variable:$ruleRegex2)) { $ruleRegex2 = '' }

	# update progress
	$ruleNbr++
	$percent = [math]::Round(($ruleNbr / $ruleCount * 100) ,2)
	Write-Progress -Activity "Checking rules..." -Status "Progress: $percent%" -PercentComplete $percent

	if ($ruleEnabled -eq 'true') {

		if ($debug -eq $true) { Write-Host ("Checking Rule [{1,-40}] " -f $ruleNbr, $ruleName) -NoNewline -ForegroundColor "White" }

		# check rule #1
		$rule1 = $false
		if (($ruleType1 -eq "match") -and ($sql -match $ruleRegex1)) {
			$rule1 = $true
		} elseif (($ruleType1 -eq "notmatch") -and ($sql -notmatch $ruleRegex1)) {
			$rule1 = $true
		}

		# check rule #2
		$rule2 = $false
		if (($ruleType2 -eq "match") -and ($sql -match $ruleRegex2)) {
			$rule2 = $true
		} elseif (($ruleType2 -eq "notmatch") -and ($sql -notmatch $ruleRegex2)) {
			$rule2 = $true
		}

		# handle joined rules
		if ($ruleRegex2 -eq "") {
			if ($rule1 -eq $true) {
				$counts.$ruleSeverity++
				Write-Host ("** {0}" -f $ruleDescription) -ForegroundColor $colors.$ruleSeverity
			} else {
				$counts.Pass++
				if ($debug -eq $true) { Write-Host "ok" -ForegroundColor $colors.Pass }
			}
		} else {
			if ($ruleJoin -eq "and") {
				if (($rule1 -eq $true) -and ($rule2 -eq $true)) {
					$counts.$ruleSeverity++
					Write-Host ("** {0}" -f $ruleDescription) -ForegroundColor $colors.$ruleSeverity
				} else {
					$counts.Pass++
					if ($debug -eq $true) { Write-Host "ok" -ForegroundColor $colors.Pass }
				}
			} else {
				if (($rule1 -eq $true) -or ($rule2 -eq $true)) {
					$counts.$ruleSeverity++
					Write-Host ("** {0}" -f $ruleDescription) -ForegroundColor $colors.$ruleSeverity
				} else {
					$counts.Pass++
					if ($debug -eq $true) { Write-Host "ok" -ForegroundColor $colors.Pass }
				}
			}
		}

#		# show condition evaluations
#		if ($debug -eq $true) {
#			Write-Host ""
#			Write-Host ("  Condition #1 : {0}" -f $rule1)
#			if (!($ruleRegex2 -eq "")) {
#				Write-Host $ruleJoin
#				Write-Host ("  Condition #2 : {0}" -f $rule2)
#			}
#			Write-Host ""
#		}

	}

}

# show counts
if ($debug -eq $true) {
	Write-Host ""
	Write-Host ("Rules:      {0,2}" -f ($counts.Warning + $counts.Notice + $counts.Pass))
	Write-Host ("  Warnings  {0,2}" -f $counts.Warning) -ForegroundColor $colors.Warning
	Write-Host ("  Notices   {0,2}" -f $counts.Notice) -ForegroundColor $colors.Notice
	Write-Host ("  Passed    {0,2}" -f $counts.Pass) -ForegroundColor $colors.Pass
}
Write-Host ""

$stdLink = 	("
Please refer to the following document for more detailed information and current review practices:
https://scusa.app.corpint.net/sites/driveit/EDS/DBA/Public%20Documents/DB%20Standards%20and%20Best%20Practices/Code_Review_Checklist.docx
")

# show final status for script
if ($counts.Warning -gt 0) {
	Write-Host "Script failed validation and cannot be deployed as-is. Please address the specified issues before proceeding." -ForegroundColor $colors.Warning
	Write-Host $stdLink -ForegroundColor  $colors.Warning
	exit 1
} elseif ($counts.Notice -gt 0) {
	Write-Host "Script passed validation but with minor concerns. You should address the specified issues before proceeding." -ForegroundColor $colors.Notice
	Write-Host $stdLink -ForegroundColor  $colors.Notice
} else {
	Write-Host "Script passed validation." -ForegroundColor $colors.Pass
}

exit 0
