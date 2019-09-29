param([string]$installationpath = "$PSScriptRoot/SteamCMD", [string]$command = $null)

$exepath = "$installationpath/steamcmd.exe"
$archpath = "$installationpath/steamcmd.zip"

function RunCommand {
    if ($command -ne $null) {
        Start-Process -FilePath $exepath -ArgumentList $command -NoNewWindow -Wait
    }
}

function Install {

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