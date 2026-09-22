$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$arch=if($env:PROCESSOR_ARCHITECTURE -like '*ARM*'){'arm64'}else{'x64'}
$dest="$env:LOCALAPPDATA\opencode\bin"; $zip="$env:TEMP\opencode.zip"
New-Item -ItemType Directory -Force -Path $dest|Out-Null
Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/sst/opencode/releases/latest/download/opencode-windows-$arch.zip" -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $dest -Force; Remove-Item $zip -Force
$exe=Get-ChildItem $dest -Recurse -Filter opencode.exe|Select-Object -First 1
if($exe.DirectoryName -ne $dest){Move-Item $exe.FullName "$dest\opencode.exe" -Force}
$p=[Environment]::GetEnvironmentVariable('Path','User')
if($p -notlike "*$dest*"){[Environment]::SetEnvironmentVariable('Path',"$p;$dest",'User');$env:Path+=";$dest"}
& "$dest\opencode.exe" --version
