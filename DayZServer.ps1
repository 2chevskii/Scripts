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

###

### Functions ###

function Update-Or-Install {
    powershell.exe $steamCmdSript
    Start-Process $steamCmdPath -ArgumentList $steamCmdParameters -NoNewWindow
}

function Wipe-Server { Remove-Item -Path "$serverPath\mpmissions\$missionName\storage_$serverIndex" }

function Start-Server {
    
    


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
}


Main