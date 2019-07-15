#define type for unpacking zips
Add-Type -AssemblyName System.IO.Compression.FileSystem;

#define path variable
$steamCmdDir = "$PSScriptRoot/SteamCMD";

#functions

function Download-Archive{
Write-Host "Downloading archive...";
$client = New-Object System.Net.WebClient;
$cmdUrl = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip";
$client.DownloadFile($cmdUrl, "$steamCmdDir/steamcmd.zip");
}

function Unpack-Archive{
Write-Host "Unpacking archive...";
[System.IO.Compression.ZipFile]::ExtractToDirectory("$steamCmdDir/steamcmd.zip", $steamCmdDir);
}

function Delete-Archive{
Write-Host "Deleting archive...";
Remove-Item -Path "$steamCmdDir/steamcmd.zip";
}

function Check-Path{
$exists = Test-Path $steamCmdDir;
if(!$exists){
New-Item -ItemType Directory -Path $steamCmdDir;
Write-Host "Installing steam commandline...";
Download-Archive;
Unpack-Archive;
Delete-Archive;
}
}

function Check-Or-Install{
Check-Path;
Write-Host "Check completed.";
}

#main

Write-Host "Checking steam commandline installation...";
Check-Or-Install;