param([string[]] $startupCommands)

Add-Type -AssemblyName "System.Net.Http"

$webclient = New-Object -TypeName "System.Net.WebClient"

$settings = @{
    server      = "$PSScriptRoot\rust-ds"
    steamcmd    = "$PSScriptRoot\SteamCMD.ps1"

    uMod_branch = "stable"
    
    config      = @{
        identity      = "myServer"
        logfile       = "logs\server.log"

        port          = 28015
        rcon_port     = 28016
        rcon_password = 0000

        worldsize     = 3500
        seed          = 00000000
        radiation     = $true
        pve           = $false
        maxplayers    = 200

        globalchat    = $true

        map           = "Procedural Map"

        hostname      = 'My server'
        description   = 'Example description'
        headerimage   = 'https://example.com'
        url           = 'https://example.com'

    }

    server_cfg  = @("aimanager.nav_wait 1", "fps.limit 60")
}

$messages = @{
    help           = @"
    Available options:
    Exit : exit / quit / ex / q
    Set installation dir (currently: '$($settings['server'])') : ch idir
    Set path to the steamcmd script (currently: '$($settings['steamcmd'])') : ch sdir
    Switch uMod branch (currently: '$($settings['uMod_branch'])') : swbranch
    Install/Update server : upd server
    Install/Update uMod : upd umod
    Revert original server files : upd server -reset
    Wipe server : wipe
    Start server : start
    Start server (with autorestart) : start -auto
    Create 'server.cfg' : scfg
    Create 'start.cmd' : strt
    Show available maps : maplist
    Dump developer info : dinfo
"@
    confirmation   = 'Are you sure? [Y/n]'
    available_maps = @'
### List of available maps ###
# Procedural Map
# Barren
# HapisIsland
# CraggyIsland
# SavasIsland_koth
################################
'@
}

# Parameters for server installation
$steamcmd_install_path = "$PSScriptRoot/SteamCMD"
$steamcmd_server_update = "`"+login anonymous +force_install_dir $($settings['server']) +app_update 258550 validate +quit`""

# Link to the stable build of the Oxide/uMod
$umod_url_stable = "https://umod.org/games/rust/download"

# Link to the develop build of the Oxide/uMod
$umod_url_dev = "https://umod.org/games/rust/download/develop"

$settingsPath = "$PSScriptRoot/rust-server-config.json"

#region Main function and command handling


function main {
    $defsettings = loadSettings

    if ($defsettings -ne $true) {
        Write-Host "Default settings were loaded, configuration file created. Change it to your preference and reload the script if needed."
    }
    else {
        Write-Host "Settings were loaded from the config file."
    }

    Write-Host "Type commands below. Use 'help' to see list of available options"
    
    waitForCommand
}

function waitForCommand {
    Write-Host -Object ">" -NoNewline
    $cmd = (Read-Host).ToLower().Trim()

    if ($cmd -eq 'exit' -or $cmd -eq 'quit' -or $cmd -eq 'q' -or $cmd -eq 'ex') {
        Write-Host "Exiting..."
        Start-Sleep -Milliseconds 300
        exit
    }

    elseif ($cmd -eq 'ch idir') {
        Write-Host "Enter new path to the server installation:"

        $newPath = Read-Host
        setNewServerPath $newPath
    }

    elseif ($cmd -eq 'ch sdir') {
        Write-Host "Enter new path to the steamCMD script:"

        $newPath = Read-Host
        
        setNewScriptPath $newPath
    }

    elseif ($cmd -eq 'maplist') {
        Write-Host "List of available maps:`n$($messages['available_maps'])"
    }

    elseif ($cmd -eq 'scfg') {
        emitServerCfg
    }

    elseif ($cmd -eq 'swbranch') {
        if ($settings['uMod_branch'].ToLower().StartsWith("stable")) {
            $settings['umod_branch'] = "dev"
            Write-Host "uMod branch switched to 'develop'"
        }
        else {
            $settings['uMod_branch'] = "stable"
            Write-Host "uMod branch switched to 'stable'"
        }
        saveSettings
    }

    elseif ($cmd -eq 'upd server -reset') {
        Write-Host "Removing modified dlls..." -NoNewline
        try {
            Remove-Item -Path "$($settings['server'])/RustDedicated_Data/Managed" -Force -Recurse
            $Host.UI.RawUI.ForegroundColor = [System.ConsoleColor]::Green
            Write-Host "success"
            $Host.UI.RawUI.ForegroundColor = [System.ConsoleColor]::White
        }
        catch {
            onException $_
        }

        updateServer
    }

    elseif ($cmd -eq 'upd server') {
        updateServer
    }

    elseif ($cmd -eq 'upd umod') {
        Write-Host $settings['uMod_branch']
        updateUMod $settings['uMod_branch']
    }

    elseif ($cmd -eq 'dinfo') {
        
    }

    elseif ($cmd -eq 'wipe') {
        Write-Host -Object $messages['confirmation']
        $confirm = (Read-Host).ToLower().Trim()

        if ($confirm -eq "y") {
            wipeServer
        }
        else {
            Write-Host "Wipe aborted"
        }
    }

    elseif ($cmd -eq 'start') {
        startServer
    }

    elseif ($cmd -eq 'start -auto') {
        startServer -autorestart $true
    }

    elseif ($cmd -eq 'help') {
        Write-Host $messages['help']
    }

    else {
        Write-Host "Command not found!"
    }

    waitForCommand
    
}


#endregion

#region Utility


function setNewServerPath {
    param (
        $newPath
    )
    $settings['server'] = $newPath

    saveSettings

    Write-Host "New path for the server intallation is: $($settings['server'])"
}

function setNewScriptPath {
    param (
        $newPath
    )
    
    $settings['steamcmd'] = $newPath

    saveSettings

    Write-Host "New path for the server intallation is: $($settings['server'])"
}

function onException {
    param (
        $ex
    )

    if ($null -eq $ex) {
        return;
    }

    $Host.UI.RawUI.ForegroundColor = [System.ConsoleColor]::Red
    Write-Host "Exception occured: $($ex.ToString())"
    $Host.UI.RawUI.ForegroundColor = [System.ConsoleColor]::White
}

function updStrings {
    $messages['help'] = @"
    Available options:
    Exit : exit / quit / ex / q
    Set installation dir (currently: '$($settings['server'])') : ch idir
    Set path to the steamcmd script (currently: '$($settings['steamcmd'])') : ch sdir
    Switch uMod branch (currently: '$($settings['uMod_branch'])') : swbranch
    Install/Update server : upd server
    Install/Update uMod : upd umod
    Revert original server files : upd server -reset
    Wipe server : wipe
    Start server : start
    Start server (with autorestart) : start -auto
    Create 'server.cfg' : scfg
    Show available maps : maplist
    Dump developer info : dinfo
"@

    ([Ref]$steamcmd_server_update).Value = "`"+login anonymous +force_install_dir $($settings['server']) +app_update 258550 validate +quit`""
    
}


#endregion

#region Script dynamic settings


function loadSettings {

    try {
        [string]$json
        if (Test-Path -Path $settingsPath) {
            [PsCustomObject]$cobj = (Get-Content -Path $settingsPath -Encoding "utf8" -Raw | ConvertFrom-Json)
            
            foreach ($prop in $cobj.psobject.properties) {
                $settings[$prop.Name] = $prop.Value
            }

            #Write-Host ($settings['config']).GetType()

            $table = @{}

            foreach ($p in ($settings['config']).psobject.properties){
                $table[$p.Name] = $p.Value
            }

            $settings['config'] = $table

            updStrings
            
            return $true # Return true if settings were loaded from the file
        }
        else {
            saveSettings
            return $false # Return false if default settings were loaded
        }
    }
    catch {
        onException $_
    }
}

function saveSettings {
    try {
        $json = ConvertTo-Json -InputObject $settings
        updStrings
        Out-File -FilePath $settingsPath -InputObject $json -Encoding "utf8"
    }
    catch {
        onException $_
    }
}


#endregion

#region Administration


function startServer {
    param (
        [bool]$autorestart = $false,
        [bool]$install = $false
    )

    $check = checkServerInstallation
    
    if ($check -eq $false) {
        if ($install -eq $false) {
            Write-Host "Looks like Rust server is not installed yet... Consider executing 'upd server' command!"
        }
        else {
            updateServer
        }
    }

    $args = "+server.identity `"$($settings['config']['identity'])`" +server.port $($settings['config']['port']) +rcon.port $($settings['config']['rcon_port']) +rcon.password `"$($settings['config']['rcon_password'])`" +server.worldsize $($settings['config']['worldsize']) +server.seed $($settings['config']['seed']) +server.radiation $($settings['config']['radiation']) +server.pve $($settings['config']['pve']) +server.maxplayers $($settings['config']['maxplayers']) +server.globalchat $($settings['config']['globalchat']) +server.level `"$($settings['config']['map'])`" +server.hostname `"$($settings['config']['hostname'])`" +server.description `"$($settings['config']['description'])`" +server.headerimage $($settings['config']['headerimage']) +server.url $($settings['config']['url'])"
    
    Start-Process -FilePath "cmd.exe" -ArgumentList "/C `"RustDedicated.exe -batchmode -nographics +rcon.web 1 $args`"" -WorkingDirectory $settings['server'] -Wait
    
    if ($autorestart -eq $true) {
        startServer -autorestart $autorestart -install $install
    }
}

function checkServerInstallation {
    $t = Join-Path -Path $settings['server'] -ChildPath "RustDedicated.exe" | Test-Path
    return $t
}

function updateServer {
    Write-Host "Initializing rust server update..."

    try {
        Start-Process -FilePath "powershell" -ArgumentList "-file $($settings['steamcmd']) -installationpath $steamcmd_install_path -command $steamcmd_server_update" -ErrorAction "stop" -NoNewWindow -Wait
    }
    catch {
        onException $_
    }
}

function updateUMod {
    param(
        [string]$branch
    )

    try {
        $link = $umod_url_stable

        if ($branch.ToLower().StartsWith("dev")) {
            $link = $umod_url_dev
        }
        $archpath = $settings['server'] + "/" + "Oxide.Rust.zip"
        $startTime = [System.DateTime]::Now

        Write-Host "Downloading '$branch' branch of Oxide/uMod from '$link'..." 
        $webclient.DownloadFile($link, $archpath)
        $endTime = [System.DateTime]::Now
        $totaltime = ($endTime - $startTime).TotalSeconds

        Write-Host "Download complete in: $($totaltime)s"

        Expand-Archive -Path $archpath -DestinationPath $settings['server'] -Force -ErrorAction "stop"

        Write-Host "Oxide/uMod fully updated!"

        Remove-Item -Path $archpath -Force
    }
    catch {
        onException $_    
    }

}

function wipeServer {
    param(
        $silent = $false
    )

    if (!$silent) {
        Write-Host "Wiping server..."   
    }

    $data_path = "$($settings['server'])/server/$($settings['config']['identity'])"

    $paths = @("$data_path/player.blueprints.3.db", "$data_path/*.sav", "$data_path/player.deaths.3.db", "$data_path/*.map")

    foreach ($item in $paths) {
        if (!$silent) {
            Write-Host -Object "Wiping '$item'..." -NoNewline
        }

        $bexists = Test-Path -Path $item

        if ($bexists) {
            if (!$silent) {
                $Host.UI.RawUI.ForegroundColor = [System.ConsoleColor]::Green
                Write-Host "success"
                $Host.UI.RawUI.ForegroundColor = [System.ConsoleColor]::White
            }
        }
        else {
            if (!$silent) {
                $Host.UI.RawUI.ForegroundColor = [System.ConsoleColor]::Red
                Write-Host "not found"
                $Host.UI.RawUI.ForegroundColor = [System.ConsoleColor]::White
            }
            continue
        }

        Remove-Item -Path $item -Force
    }
}

function emitServerCfg {
    param (
        [bool]$noConfirm = $false
    )

    $cfgPath = "$($settings['server'])/server/$($settings['config']['identity'])/cfg/server.cfg"

    $cfgExists = Test-Path -Path $cfgPath

    if ($cfgExists -eq $true -and $noConfirm -eq $false) {
        Write-Host -Object "'server.cfg' exists already, overwrite it?"
        Write-Host -Object global:['confirmation']
        $Yn = Read-Host

        $Yn = $yn.ToLower()

        if ($Yn -ne "y") {
            return;
        }
    }

    if ($cfgExists -eq $true) {
        Remove-Item -Path $cfgPath
    }

    try {
        New-Item -ItemType "Directory" -Path "$($settings['server'])/server/$($settings['config']['identity'])" -Force
    
        foreach ($line in $settings['server_cfg']) {
            $line | Out-File -FilePath $cfgPath -Encoding "utf8" -Append
        }
    
        $Host.UI.RawUI.ForegroundColor = [System.ConsoleColor]::Green
        Write-Host -Object "'server.cfg' was created successfully under '$cfgPath'"
        $Host.UI.RawUI.ForegroundColor = [System.ConsoleColor]::White
    }
    catch {
        onException $_
    }
}


#endregion

main
