#region Declarations

# Absolute path to the directory where steamcmd.exe must be located
param([string]$targetDir = "$PSScriptRoot/SteamCMD") 

# URL for steamcmd distr download
$steamcmd_url = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"

function Install-SteamCMD {
    Write-Host "Installing steam commandline tool..."

    try {
        Write-Host "Downloading archive..."
        $client = New-Object System.Net.WebClient
        $client.DownloadFile($steamcmd_url, "$targetDir/steamcmd.zip")

        Write-Host "Unpacking archive..."
        Expand-Archive -Path "$targetDir/steamcmd.zip" -DestinationPath $targetDir -ErrorAction Stop

        Write-Host "Deleting archive..."
        Remove-Item -Path "$targetDir/steamcmd.zip" -ErrorAction Stop
    }
    catch {
        Write-Host -Object "Exception occured: $_"
        Read-Host
        exit
    }
}

#endregion

#region Script

# Check if target directory contains needed binary already
if (Test-Path -Path "$targetDir/steamcmd.exe") {
    Write-Host "SteamCMD is already installed."
}
else {
    # Ensure that the target directory exists
    if (!(Test-Path -Path "$targetDir")) {
        try {
            New-Item -Path $targetDir -ItemType "Directory" -ErrorAction Stop
        }
        catch {
            Write-Host -Object "Exception occured: $_"
            Read-Host
            exit
        }
    }
    # Install steamcmd
    Install-SteamCMD
}
exit

#endregion