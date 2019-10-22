param([string]$installationpath = "$PSScriptRoot/SteamCMD", [string]$command = $null)

# Path to the steamCMD binary
$exepath = "$installationpath/steamcmd.exe"

# Path where the downloaded archive will be temporary located
$archpath = "$installationpath/steamcmd.zip"

# Download link for steamcmd tool
$steamcmd_url = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"

# Executes given commands in steamCMD while it is installed
function RunCommand {
    if ($null -ne $command -and $command.Length -gt 0) {
        Start-Process -FilePath $exepath -ArgumentList $command -WorkingDirectory $PSScriptRoot -NoNewWindow -Wait
    }
}

# Attempts to install steamCMD if it is not installed yet
function Install {

    Write-Host "Received params:`nPath: $installationpath`nCommand: $command"

    if ((Test-Path -Path $exepath) -eq $true) {
        Write-Host "SteamCMD is already installed"
    }
    else {
        Write-Host "Installing steam commandline tool..."
        
        try {
            if ((Test-Path -Path $installationpath) -ne $true) {
                Write-Host "Creating installation directory..."
                New-Item -Path $installationpath -ItemType "Directory" -ErrorAction Stop
            }

            Write-Host "Downloading archive..."
            $client = New-Object System.Net.WebClient
            $client.DownloadFile($steamcmd_url, $archpath)
    
            Write-Host "Unpacking archive..."
            Expand-Archive -Path $archpath -DestinationPath $installationpath -ErrorAction Stop
    
            Write-Host "Deleting archive..."
            Remove-Item -Path $archpath -ErrorAction Stop
            Start-Sleep -Seconds 2
        }
        catch {
            Write-Host -Object "Exception occured: $_"
            Write-Host -Object "Press any key to exit..."
            Read-Host
            exit
        }
    }
}

Install

RunCommand