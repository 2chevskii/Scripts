### Variables ###

$menu = @"
Choose an option:
1. Install/update rust server
2. Install Oxide/uMod
3. Start server
4. Wipe server
5. Exit
"@

$confirmation = @"
Are you sure?
1. Yes
2. No
"@

# Paths and links (not recommended to change unless you know, what you are doing exactly)
$server_dir = "$PSScriptRoot/rust-ds"

$steamdcmd_script_path = "$PSScriptRoot/SteamCMDInstall.ps1"
$steamcmd_path = "$PSScriptRoot/SteamCMD/steamcmd.exe"
$steamcmd_launch_args = "+login anonymous", "+force_install_dir $server_dir", "+app_update 258550 -validate", "+quit"

# Can be changed to uMod link if you want to use it instead
$oxide_url = "https://umod.org/games/rust/download"

### Server launch parameters ###

# Administrative
$server_port = 28015
$rcon_port = 28016
$rcon_password = 0000
$server_netlog = 1
$server_globalchat = 1

# General
$server_identity = "example"
$server_hostname = @"
"Multiword hostname example"
"@
$server_description = @"
"Multiword description example"
"@
$server_headerimage = ""
$server_url = ""
$server_maxplayers = 1337

$logfile_path = "Logs/Server.log"

# Map
$server_level = @"
"Procedural Map"
"@

### List of available levels ###
# Procedural Map
# Barren
# HapisIsland
# CraggyIsland
# SavasIsland_koth
################################

$server_worldsize = 2000
$server_seed = 1942
$server_radiation = 1
$server_pve = 0

# Performance
$server_tickrate = 60
# More perf parameters coming soon

$basicParams = "-batchmode -nographics -logfile $logfile_path +rcon.web 1"

# You can add parameters here
$additionalParams = "+aimanager.nav_wait 1"

$serverLaunchParams = "$basicParams +server.port $server_port +rcon.port $rcon_port +rcon.password $rcon_password +server.netlog $server_netlog +server.globalchat $server_globalchat +server.identity $server_identity +server.hostname $server_hostname +server.description $server_description +server.headerimage $server_headerimage +server.url $server_url +server.level $server_level +server.worldsize $server_worldsize +server.seed $server_seed +server.radiation $server_radiation +server.pve $server_pve +server.maxplayers $server_maxplayers +aimanager.nav_wait $aimanager_nav_wait +server.tickrate $server_tickrate $additionalParams"

### Functions ###

function Update-Oxide {
    $client = New-Object System.Net.WebClient
    Write-Host "Downloading archive..."
    $client.DownloadFile($oxide_url, "$server_dir/Oxide.Rust.zip")

    Write-Host "Extracting archive..."
    try {
        Expand-Archive -Path "$server_dir/Oxide.Rust.zip" -DestinationPath $server_dir -Force -ErrorAction Stop
        Write-Host "Oxide update completed."
    }
    catch {
        Write-Host "Could not extract Oxide properly, try running script as administrator!" -ForegroundColor ([System.ConsoleColor]::Red)
    }
    try {
        Remove-Item -Path "$server_dir/Oxide.Rust.zip" -ErrorAction Stop
    }
    catch {
        Write-Host "Could not delete the temporary archive file." -ForegroundColor ([System.ConsoleColor]::Yellow)
    }

    
    Start-Sleep -Seconds 3
}

function Update-Server {
    powershell.exe $steamdcmd_script_path
    Start-Process -FilePath $steamcmd_path -ArgumentList $steamcmd_launch_args -NoNewWindow -Wait
    # Update-Oxide # Uncomment this line to make script automatically update Oxide after server installation/update
}

function Start-Server {
    Start-Process -WorkingDirectory $server_dir -FilePath "cmd.exe" -ArgumentList "/C RustDedicated.exe $serverLaunchParams" -Wait 
    #Start-Process -FilePath "$server_dir\RustDedicated.exe" -ArgumentList $serverLaunchParams -Wait | Out-Host
}

function Wipe-Server {

    Write-Host -Object $confirmation
    
    switch (Listen-Key) {
        '1' { 
            Write-Host "Wiping the server data..."
            Start-Sleep -Milliseconds 500
            $data_path = "$server_dir/server/$server_identity"

            $bp_path = "$data_path/player.blueprints.3.db"
            $deaths_path = "$data_path/player.deaths.3.db"
            $sav_path = "$data_path/*.sav"
            $map_path = "$data_path/*.map"

            try {
                Remove-Item -Path $bp_path -ErrorAction Stop
                Write-Host -Object "Deleting blueprints..."
            }
            catch { Write-Host -Object "Blueprints data empty..." }

            try {
                Remove-Item -Path $deaths_path -ErrorAction Stop
                Write-Host -Object "Deleting deaths..."
            }
            catch { Write-Host -Object "Deaths data empty..." }

            try {
                Remove-Item -Path $sav_path -ErrorAction Stop
                Write-Host -Object "Deleting saves..."
            }
            catch { Write-Host -Object "Saves empty..." }

            try {
                Remove-Item -Path $map_path -ErrorAction Stop
                Write-Host -Object "Deleting map caches..."
            }
            catch { Write-Host -Object "Map caches empty..." }


            Start-Sleep -Seconds 3
        }
        Default {
            Write-Host "Aborted..."
            Start-Sleep -Seconds 2
        }
    }
}

function Listen-Key {
    [System.Management.Automation.Host.KeyInfo]$key = $Host.UI.RawUI.ReadKey('NoEcho, IncludeKeyDown')
    return $key.Character
}

# Menu
function Main {
    Clear-Host

    Write-Host $menu

    switch (Listen-Key) {
        '1' {
            Update-Server
        }
        '2' {
            Update-Oxide
        }
        '3' {
            Start-Server
        }
        '4' {
            Wipe-Server
        }
        '5' {
            Exit
        }
        Default {
            Write-Host -Object "There is no such option, read the menu!"
            Start-Sleep -Seconds 2
        }
    }
    
    Main
}

### Entry Point ###

Main

