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
.EXAMPLE
	# Display output normally to console.
	Write-Tee -String 'Some output...'
.EXAMPLE
	# Display output to console and send to file.
	Write-Tee -String 'Some output...' -OutputFile 'test.log'
.EXAMPLE
	# Display colorized output to console and plain text to file.
	Write-Tee -String 'Some output...' -OutputFile 'test.log' -ForegroundColor 'Red'
.HISTORY
	11/09/2016	pbeazley	Initial release.
.FUTURE
	- Buffering
#>
function Write-Tee {
	Param(
		[Parameter(Mandatory = $false, ValueFromPipeLine = $true, ValueFromPipeLineByPropertyName = $true, Position = 0)]
			[string]$String,
		[Parameter(Mandatory = $false, Position = 1)]
			[switch]$NoNewLine,
		[Parameter(Mandatory = $false, Position = 2)]
			#[enum]::GetValues([System.ConsoleColor])
			[ValidateSet('Black', 'DarkBlue', 'DarkGreen', 'DarkCyan', 'DarkRed', 'DarkMagenta', 'DarkYellow', 'Gray', 'DarkGray', 'Blue', 'Green', 'Cyan', 'Red', 'Magenta', 'Yellow', 'White')]
			[string]$ForegroundColor = 'Gray',
		[Parameter(Mandatory = $false, Position = 3)]
			[string]$OutputFile,
		[Parameter(Mandatory = $false, Position = 4)]
			[switch]$Timestamp,
		[Parameter(Mandatory = $false, Position = 5)]
			[string]$NoConsole
	)
	if ($NoConsole -ne $true) {
		if ($NoNewLine -eq $true) {
			Write-Host $String -ForegroundColor $ForegroundColor -NoNewLine
		} else {
			Write-Host $String -ForegroundColor $ForegroundColor
		}
	}
	if (($OutputFile -ne '') -and ((Test-Path $OutputFile -PathType 'Leaf') -eq $true)) {
		if ($Timestamp -eq $true) {
			$string = ('[{0}] $string' -f $(Get-Date))
		}
		if ($NoNewLine -eq $true) {
			Add-Content -Path $OutputFile -Encoding Ascii $String -NoNewLine
		} else {
			Add-Content -Path $OutputFile -Encoding Ascii $String
		}
	}
}

Export-ModuleMember -Function Write-Tee
