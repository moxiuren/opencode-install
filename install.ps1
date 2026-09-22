$ErrorActionPreference='Stop'
Write-Host ("PowerShell " + $PSVersionTable.PSVersion)
try {
  $os = Get-WmiObject Win32_OperatingSystem
  Write-Host ("Windows " + $os.Caption + " build " + $os.BuildNumber)
  $global:WinBuild = [int]$os.BuildNumber
} catch { Write-Host ("OS check skipped: " + $_.Exception.Message); $global:WinBuild = 0 }
try {
  $rel = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction Stop).Release
  Write-Host (".NET 4.x release " + $rel + " (need >= 378389 for TLS1.2)")
} catch { Write-Host ".NET 4.5+ not detected, will use Shell unzip fallback." }
try { [Net.ServicePointManager]::SecurityProtocol = 3072 } catch {}
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
if ([IntPtr]::Size -eq 4) { Write-Host "32-bit Windows detected, opencode needs 64-bit."; exit 1 }
$arch='x64'
if ($env:PROCESSOR_ARCHITECTURE -like '*ARM*') { $arch='arm64' }
$dest="$env:LOCALAPPDATA\opencode\bin"
if ([String]::IsNullOrEmpty($env:LOCALAPPDATA)) { $dest="$env:USERPROFILE\opencode\bin" }
$zip="$env:TEMP\opencode.zip"
if ([String]::IsNullOrEmpty($env:TEMP)) { $zip="$dest\opencode.zip" }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
function Get-Opencode($variant) {
  $u="https://github.com/sst/opencode/releases/latest/download/opencode-windows-$arch-$variant.zip"
  if ($variant -eq "std") { $u="https://github.com/sst/opencode/releases/latest/download/opencode-windows-$arch.zip" }
  Write-Host ("Downloading " + $u)
  (New-Object Net.WebClient).DownloadFile($u, $zip)
  Write-Host "Extracting..."
  $ok=$false
  try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)
    $ok=$true
  } catch { Write-Host ("Net unzip failed, fallback Shell: " + $_.Exception.Message) }
  if (-not $ok) {
    $sh=New-Object -ComObject Shell.Application
    $sh.NameSpace($dest).CopyHere($sh.NameSpace($zip).Items(), 20)
    Start-Sleep -Seconds 5
  }
  Remove-Item $zip -Force -ErrorAction SilentlyContinue
  $e=Get-ChildItem $dest -Recurse -Filter opencode.exe | Select-Object -First 1
  if (-not $e) { Write-Host "opencode.exe not found after extract."; exit 1 }
  if ($e.DirectoryName -ne $dest) { Move-Item $e.FullName "$dest\opencode.exe" -Force }
}
function Test-Opencode {
  try { & "$dest\opencode.exe" --version; return $true } catch { Write-Host ("Run failed: " + $_.Exception.Message); return $false }
}
Get-Opencode "std"
if (-not (Test-Opencode)) {
  if ($arch -eq "x64") {
    Write-Host "Standard build won't start, trying baseline build for older CPUs..."
    Get-Opencode "baseline"
    if (-not (Test-Opencode)) {
      Write-Host "Baseline also fails. Likely Windows build too old (opencode needs Win10 1903+/build 18362+)."
      Write-Host "Fix: Windows Update to 22H2, then rerun this script."
      exit 1
    }
  } else {
    Write-Host "opencode.exe won't start. Likely Windows build too old, run Windows Update then retry."
    exit 1
  }
}
try {
  if ($global:WinBuild -ge 18362 -and (Get-Command winget -ErrorAction Stop)) {
    Write-Host "Trying Windows Terminal install (optional, best effort)..."
    & winget install --id Microsoft.WindowsTerminal -e --silent --accept-package-agreements --accept-source-agreements
  } else {
    Write-Host "Skip Windows Terminal (needs Win10 build 18362+, built-in console works fine)."
  }
} catch { Write-Host ("Terminal install skipped: " + $_.Exception.Message) }
$p=[Environment]::GetEnvironmentVariable('Path','User')
if ($p -notlike ("*"+$dest+"*")) { [Environment]::SetEnvironmentVariable('Path',($p+";"+$dest),'User'); $env:Path+=(";" + $dest) }
Write-Host ("Installed to " + $dest + ". Reopen terminal, then run: opencode auth login")
