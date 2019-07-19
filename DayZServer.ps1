






$steamCmdSript = "$PSScriptRoot/SteamCMDInstall.ps1";
$steamCmdPath = "$PSScriptRoot/SteamCMD/steamcmd.exe";
$steamCmdParameters = "+login anonymous", "+force_install_dir $serverPath", "+app_update 258550 -validate", "+quit";