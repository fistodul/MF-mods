# This script comes with the msys2-runtime and bash

$Env:SHA_CMD = 'powershell -Command "(Get-FileHash -Algorithm SHA512 $1).Hash.ToLower()"'
$Env:WGET_CMD = 'powershell -Command "Set-Variable ProgressPreference SilentlyContinue; Invoke-WebRequest $1/$2 -OutFile $target"'

$Env:MV_CMD = 'powershell -Command "Move-Item -Path $1 -Destination $2 -Force"'
$Env:SLEEP_CMD = 'powershell -Command "Start-Sleep -Seconds $1"'

New-Item -ItemType Directory -Path tmp -Force | Out-Null
$dirName = Split-Path -Leaf $pwd.Path
Set-Location ..

& $dirName\usr\bin\bash.exe -c "cd $dirName; ./updater.sh"
