# PowerShell 3+

function Zip-Files ($ZipFile, $SourceDirectory) {
	Add-Type -Assembly System.IO.Compression.FileSystem
	$CompressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
	[System.IO.Compression.ZipFile]::CreateFromDirectory($SourceDirectory, $ZipFile, $CompressionLevel, $false)
}

function UnZip-Files ($ZipFile, $DestinationDirectory) {
	[System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $DestinationDirectory)
}

# PowerShell 5+

# create zip file with the contents of directory
Compress-Archive -Path $SourceDirectory -DestinationPath $ZipFile

# add to/update zip file with the contents of directory
Compress-Archive -Path $SourceDirectory -Update -DestinationPath $ZipFile

# extract zip file to directory
Expand-Archive -Path $ZipFile -DestinationPath $DestinationDirectory
