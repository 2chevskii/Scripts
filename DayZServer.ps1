### Variables ###

$menu = @"
Choose an option:
1. Install/update dayz server
2. Start server
3. Wipe server
Or any other input to exit
"@;

$workDir = $PSScriptRoot;
$serverPath = "$workDir\dayz-ds"

# IMPORTANT : insert correct login and password of the account WITHOUT 2FA
$login = ""
$password = ""

$steamCmdSript = "$workDir/SteamCMDInstall.ps1";
$steamCmdPath = "$workDir/SteamCMD/steamcmd.exe";
$steamCmdParameters = "+login $login $password", "+force_install_dir $serverPath", "+app_update 223350 -validate", "+quit";

$missionName = "dayzOffline.chernarusplus"
$serverIndex = 1

# Server launch parameters

$config = "serverDZ.cfg"
$port = 2302
$bePath = "$serverPath\battleye"
$cpuCount = 2

$serverLaunchParameters = "-port=$port -config=$config -BEpath=$bePAth -dologs -freezecheck -cpuCount=$cpuCount"

###

### Functions ###

function Update-Or-Install {
    powershell.exe $steamCmdSript
    Start-Process $steamCmdPath -ArgumentList $steamCmdParameters -NoNewWindow

    CheckBEConfig
}

function CheckBEConfig {

    $BEcfgPath = "$serverPath\battleye\BEServer_x64.cfg"
    $exists = Test-Path -Path $BEcfgPath

    if (!$exists) {
        New-Item -Path $BEcfgPath
    }
}

function Wipe-Server { Remove-Item -Path "$serverPath\mpmissions\$missionName\storage_$serverIndex" }

function Start-Server {
    Start-Process "$serverPath\DayZServer_x64.exe" -ArgumentList $serverLaunchParameters -Wait
}


function Main {
    Write-Host $menu
    $opt = Read-Host

    switch ($opt) {
        '1' {
            Update-Or-Install
        }
        '2' {
            Start-Server
        }
        '3' {
            Wipe-Server              
        }
        Default { exit }
    }
    Main
}


Main

