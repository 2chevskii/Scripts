### Variables ###

$menu = @"
Choose an option:
1. Install/update dayz server
2. Start server
3. Wipe server
4. Exit
"@;

$confirmation = @"
Are you sure?
1. Yes
2. No
"@

$server_dir = "$PSScriptRoot\dayz-ds"

# IMPORTANT : insert correct login and password for an account WITHOUT 2FA
$login = ""
$password = ""

$steamCmdSript = "$PSScriptRoot/SteamCMDInstall.ps1";
$steamCmdPath = "$PSScriptRoot/SteamCMD/steamcmd.exe";
$steamCmdParameters = "+login $login $password", "+force_install_dir $server_dir", "+app_update 223350 -validate", "+quit";

$missionName = "dayzOffline.chernarusplus"
$serverIndex = 1

# Server launch parameters

$config = "serverDZ.cfg"
$port = 2302
$battleeye_dir = "$server_dir\battleye"
$cpuCount = 2

$serverLaunchParameters = "-port=$port -config=$config -BEpath=$battleeye_dir -dologs -freezecheck -cpuCount=$cpuCount"

###

### Functions ###

function Listen-Key {
    [System.Management.Automation.Host.KeyInfo]$key = $Host.UI.RawUI.ReadKey('NoEcho, IncludeKeyDown')
    return $key.Character
}

function Update-Or-Install {
    powershell.exe $steamCmdSript
    Start-Process $steamCmdPath -ArgumentList $steamCmdParameters -NoNewWindow -Wait
    CheckBEConfig
}

function CheckBEConfig {

    $BEcfgPath = "$battleeye_dir\BEServer_x64.cfg"
    $exists = Test-Path -Path $BEcfgPath

    if (!$exists) {
        New-Item -Path $BEcfgPath
    }
}

function Wipe-Server { 

    Write-Host $confirmation
    
    switch (Listen-Key) {
        '1' { 
            try {
                Remove-Item -Path "$server_dir\mpmissions\$missionName\storage_$serverIndex" -Recurse -ErrorAction Stop
                Write-Host "Wipe completed."
            }
            catch {
                Write-Host "Database empty..."
            }
        }
        Default {
            Write-Host "Aborted..."
        }
    }
    Start-Sleep -Seconds 3
}

function Start-Server {
    Start-Process "$server_dir\DayZServer_x64.exe" -ArgumentList $serverLaunchParameters -NoNewWindow -Wait
}

function Main {

    Clear-Host
    Write-Host $menu

    switch (Listen-Key) {
        '1' {
            Update-Or-Install
        }
        '2' {
            Start-Server
        }
        '3' {
            Wipe-Server
        }
        '4'{
            Exit
        }
        Default { 
            Write-Host "There is no such option, try again!" -ForegroundColor ([System.ConsoleColor]::Yellow)
            Start-Sleep -Seconds 3
         }
    }
    Main
}

### Entry point ###

Main