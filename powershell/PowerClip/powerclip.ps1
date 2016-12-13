<#
.SYNOPSIS
	Retrieves stored text clipboard entries.
.PARAMETER Path
	Path to powerclip store. Defaults to homepath.
#>
[cmdletbinding(SupportsShouldProcess=$true)]
Param(
	[Parameter(Mandatory = $false, Position = 0)]
		[string]$Path = "$env:HOMEPATH"
)

$ClipStore = "$Path/powerclip.psd1"
$ClipArray = @()

# import clips from persisted storage
if (Test-Path -Path $ClipStore) {
	$ClipArray = Get-Content -Path $ClipStore
	if ($ClipArray) {
		$Export = @()
		$ClipArray | Out-GridView -Title 'Select a clip...' -PassThru | foreach {
			# add selected clip(s) to stack
			$Export += (ConvertFrom-Json -InputObject $_)
		}
		# export stack to clipboard
		$Export | clip
	}
} else {
	Write-Host 'No powerclip store found. Have you run powerclipd?' -ForegroundColor 'Red'
}

#$ClipCount = $ClipArray.Count
#for($i = 0; $i -lt $ClipCount; $i++) {
#	Write-Output ("{0}: '{1}'" -f $i, $ClipArray[$i])
#}
