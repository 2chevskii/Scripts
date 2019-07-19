### Variables ###

$menu = @"
Choose an option:
1. Install/update rust server
2. Install Oxide/uMod
3. Start server
4. Wipe server
Or any other input to exit
"@


# Paths and links (not recommended to change unless you know, what you are doing exactly)
$serverPath = "$PSScriptRoot/RustDS"

$steamCmdSript = "$PSScriptRoot/SteamCMDInstall.ps1"
$steamCmdPath = "$PSScriptRoot/SteamCMD/steamcmd.exe"
$steamCmdParameters = "+login anonymous", "+force_install_dir $serverPath", "+app_update 258550 -validate", "+quit"

# Can be changed to uMod link if you want to use it instead
$oxideLink = "https://umod.org/games/rust/download"

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

$logfile = "Logs/Server.log"

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

$basicParams = "-batchmode -nographics -logfile $logfile +rcon.web 1"

# You can add parameters here
$additionalParams = "+aimanager.nav_wait 1"

$serverLaunchParams = "$basicParams +server.port $server_port +rcon.port $rcon_port +rcon.password $rcon_password +server.netlog $server_netlog +server.globalchat $server_globalchat +server.identity $server_identity +server.hostname $server_hostname +server.description $server_description +server.headerimage $server_headerimage +server.url $server_url +server.level $server_level +server.worldsize $server_worldsize +server.seed $server_seed +server.radiation $server_radiation +server.pve $server_pve +server.maxplayers $server_maxplayers +aimanager.nav_wait $aimanager_nav_wait +server.tickrate $server_tickrate $additionalParams"

### Functions ###

function Update-Oxide {
    [System.Net.WebClient]$webClient = New-Object System.Net.WebClient
    Write-Host "Downloading archive..."
    $webClient.DownloadFile($oxideLink, "$serverPath/Oxide.Rust.zip")
    Write-Host "Extracting archive..."
    Expand-Archive -Path "$serverPath/Oxide.Rust.zip" -DestinationPath $serverPath -Force
    Remove-Item "$serverPath/Oxide.Rust.zip" -Force
}

function Update-Or-Install {
    powershell $steamCmdSript
    Start-Process -FilePath $steamCmdPath -ArgumentList $steamCmdParameters -NoNewWindow
    # Update-Oxide; # Uncomment this line to make script automatically update Oxide after server installation/update
}

function Start-Server {
    #Start-Process -WorkingDirectory $serverPath -FilePath "cmd.exe" -ArgumentList "/C RustDedicated.exe $serverLaunchParams" -Wait
    Start-Process -FilePath "$serverPath\RustDedicated.exe" -ArgumentList $serverLaunchParams -NoNewWindow
}

# TODO: ADD wipe feature
function Wipe-Server {
    Write-Host "Wiping the server data..."
    $dataPath = "$serverPath/server/$server_identity"
    Remove-Item -Path "$dataPath/player.blueprints.3.db"
    Remove-Item -Path "$dataPath/player.deaths.3.db"
    Remove-Item -Path "$dataPath/*.sav"
    Remove-Item -Path "$dataPath/*.map"
}

# Menu
function Main {
    Clear-Host
    Write-Host $menu
    $menuoption = Read-Host

    switch ($menuoption) {
        '1' {
            Update-Or-Install
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
        Default { exit }
    }
    Main
}

### Entry Point ###

Main