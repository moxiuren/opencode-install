$ErrorActionPreference='Stop'
Write-Host ("PowerShell " + $PSVersionTable.PSVersion)
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
$url="https://github.com/sst/opencode/releases/latest/download/opencode-windows-$arch.zip"
Write-Host ("Downloading " + $url)
(New-Object Net.WebClient).DownloadFile($url, $zip)
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
$exe=Get-ChildItem $dest -Recurse -Filter opencode.exe | Select-Object -First 1
if (-not $exe) { Write-Host "opencode.exe not found after extract."; exit 1 }
if ($exe.DirectoryName -ne $dest) { Move-Item $exe.FullName "$dest\opencode.exe" -Force }
$p=[Environment]::GetEnvironmentVariable('Path','User')
if ($p -notlike ("*"+$dest+"*")) { [Environment]::SetEnvironmentVariable('Path',($p+";"+$dest),'User'); $env:Path+=(";" + $dest) }
Write-Host "Installed to $dest"
& "$dest\opencode.exe" --version
