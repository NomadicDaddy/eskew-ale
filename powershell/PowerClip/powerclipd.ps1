<#
.SYNOPSIS
	Monitors and stores text clipboard entries.
.PARAMETER Path
	Path to powerclip store. Defaults to homepath.
.PARAMETER Limit
	Clips to store. Defaults to 20.
#>
[cmdletbinding(SupportsShouldProcess=$true)]
Param(
	[Parameter(Mandatory = $false, Position = 0)]
		[string]$Path = "$env:HOMEPATH",
	[Parameter(Mandatory = $false, Position = 1)]
		[int]$Limit = 20
)

$ClipStore = "$Path/powerclip.psd1"
$ClipArray = @()

# import clips from persisted storage
if (Test-Path -Path $ClipStore) {
	$ClipArray = Get-Content -Path $ClipStore
}

# monitor clipboard forever
while($true) {

	# check for clipboard changes
	if (-not $PreviousClip) { $PreviousClip = '' }
	if ($CurrentClip -and $ClipArray -notcontains $CurrentClip) {

		# add current clipboard contents, retain up to cliplimit
		$ClipArray += $CurrentClip
		if ($ClipArray.Count -ge $Limit) {
			$ClipArray = $ClipArray[1..$Limit]
		}

		# write clips to persistent storage
		$ClipArray | Out-File -FilePath $ClipStore

	}

	# pause before cycling
	Start-Sleep -Milliseconds 500

	# get current clipboard contents
	$PreviousClip = $CurrentClip
	try {
		$CurrentClip = Get-Clipboard -Format Text -TextFormatType Text
		$CurrentClip = $CurrentClip.TrimEnd()
	}
	catch {
		$CurrentClip = Get-Clipboard -Format FileDropList
	}
	finally {
		$CurrentClip = ConvertTo-Json -InputObject $CurrentClip -Compress
	}

}
