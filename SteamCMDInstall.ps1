### Fields ###

$steamcmd_dir = "$PSScriptRoot/SteamCMD"
$steamcmd_url = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"

###

### Functions ###

function Install-SteamCMD {
    Write-Host "Installing steam commandline..."
        
    Write-Host "Downloading archive..."
    $client = New-Object System.Net.WebClient
    $client.DownloadFile($steamcmd_url, "$steamcmd_dir/steamcmd.zip")

    Write-Host "Unpacking archive..."
    Expand-Archive -Path "$steamcmd_dir/steamcmd.zip" -DestinationPath $steamcmd_dir

    Write-Host "Deleting archive..."
    Remove-Item -Path "$steamcmd_dir/steamcmd.zip"
}

function Validate-Installation {
    if (!(Test-Path -Path $steamcmd_dir)) {
        New-Item -ItemType Directory -Path $steamcmd_dir
        Install-SteamCMD
    }
    else {
        Write-Host "SteamCMD is already installed."
    }

    exit
}

###

### Entry point ###

Validate-Installation

###