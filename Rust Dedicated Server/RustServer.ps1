#!/usr/bin/env pwsh

#region Usings

using namespace System.Linq
using namespace System.Management.Automation.Host
using namespace System
using namespace System.Linq
using namespace System.Text
using namespace System.Text.RegularExpressions
using namespace System.Management.Automation.Host

#endregion

#region Input parameters

[CmdletBinding(PositionalBinding, DefaultParameterSetName = 'NIA')]
param (
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [Alias('p', 'path')]
    [string]$ServerPath = './rust-ds',

    [ValidateNotNullOrEmpty()]
    [string]$SteamCmdScriptPath = './SteamCMD.ps1',
    [ValidateNotNullOrEmpty()]
    [string]$SteamCmdPath = './steamcmd',

    [ValidateNotNullOrEmpty()]
    [string]$ConfigPath = './rustserver-config.json',

    [Parameter(ParameterSetName = "IA")]
    [Alias('i')]
    [switch]$Interactive,

    [Parameter(ParameterSetName = "NIA")]
    [Alias('s')]
    [switch]$Start,
    [Parameter(ParameterSetName = "NIA")]
    [Alias('a')]
    [switch]$Autorestart,
    [Parameter(ParameterSetName = "NIA")]
    [Alias('u')]
    [switch]$Update,
    [Parameter(ParameterSetName = "NIA")]
    [Alias('us')]
    [switch]$UpdateServer,
    [Parameter(ParameterSetName = "NIA")]
    [Alias('uo')]
    [switch]$UpdateOxide,
    [Parameter(ParameterSetName = "NIA")]
    [ValidateScript( { $Update -or $UpdateServer }, ErrorMessage = 'CleanUpdate option must only be specified with -Update or -UpdateServer')]
    [Alias('c', 'clean', 'clear', 'ClearUpdate')]
    [switch]$CleanUpdate,
    [Parameter(ParameterSetName = "NIA")]
    [Alias('w')]
    [switch]$Wipe,
    
    [ValidatePattern('(?:\w+|\w+\.\w+)\s*=.+', ErrorMessage = "Config values must be provided in 'key=value' format")]
    [Alias('config')]
    [string[]]$ConfigValues,
    [ValidatePattern('(?:\w+|\w+\.\w+)\s*=.+', ErrorMessage = "Config values must be provided in 'key=value' format")]
    [Alias('servercfg')]
    [string[]]$ServerCfgValues
)

#endregion

#region Constants

$exit_codes = @{
    success                 = 0b0
    generic                 = 0b1
    configuration_load_fail = 0b10
    server_update_fail      = 0b100
    oxide_update_fail       = 0b1000
    server_wipe_fail        = 0b10000
    server_start_fail       = 0b100000
}

[ServerConfig]$script_configuration = $null

#endregion

#region Config class

class ServerConfig {
    ## Server identity folder (<server-location>/server/<identity>)
    [string]$identity = 'example-identity'
    [string]$logfile = 'logs/server.log'

    ## Server information ######################
    [string]$hostname = 'Example rust server hostname'
    [string]$description = 'Example rust server description'
    ## Server webpage
    [string]$url = 'https://example.url'
    ## Server preview image
    [string]$header_url = 'https://example.url'
    ############################################

    ## Network parameters ######################
    ## Change only if you have multiple ip addresses leading to the server machine, otherwise just leave default
    [ValidatePattern('\b(?:(?:25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(?:25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\b')]
    [string]$server_ip = '0.0.0.0'
    [ValidateRange(0, 65535)]
    [int]$server_port = 28015
    ############################################

    ## Rcon settings ######################
    [ValidateRange(0, 65535)]
    [int]$rcon_port = 28016
    [string]$rcon_password = 'changeme'
    #######################################

    ## Gameplay settings ######################
    [bool]$globalchat = $true
    [bool]$pve = $false
    [bool]$radiation = $true

    [ValidateSet('Procedural Map', 'Barren', 'CraggyIsland', 'HapisIsland', 'SavasIsland_koth')]
    [string]$map = 'Procedural Map'
    [ValidateRange(1000, 6000)]
    [int]$worldsize = 4000
    [long]$seed = 1942
    [int]$maxplayers = 1337
    ###########################################
}

#endregion

#region WELCOME SCREEN

$script_name = 'Rust dedicated server helper'
$script_author = '2CHEVSKII'
$script_version = @{
    major = 2
    minor = 2
    patch = 0
}
$script_version_formatted = "v$($script_version.major).$($script_version.minor).$($script_version.patch)"
$script_license_link = 'https://www.tldrlegal.com/l/mit'
$script_repository = 'https://github.com/2chevskii/Scripts'

Write-Host "$script_name " -NoNewline
Write-Host "$script_version_formatted " -NoNewline -ForegroundColor DarkYellow
Write-Host 'by ' -NoNewline
Write-Host $script_author -ForegroundColor Magenta
Write-Host 'Licensed under the MIT License: ' -NoNewline
Write-Host $script_license_link -ForegroundColor Blue
Write-Host 'Source repository: ' -NoNewline
Write-Host $script_repository -ForegroundColor DarkBlue

#endregion

#region Script configuration

function Update-ScriptConfiguration {
    param (
        [string]$path,
        [string[]]$values,
        [ServerConfig]$config
    )

    if (!$config) {
        Write-Host 'Loading script configuration...' -ForegroundColor Green

        if (!(Test-Path $path)) {
            Write-Host "No script configuration found at path '$path'" -ForegroundColor Yellow
        }
        else {
            try {
                $config = Read-ScriptConfiguration -path $path
            }
            catch {
                Write-Host "Error while loading script configuration: $_" -ForegroundColor Red
            }
        }
    }

    if (!$config) {
        Write-Host 'Default script configuration loaded' -ForegroundColor Yellow
        $config = [ServerConfig]::new()
    }

    if ($values -and $values.Length -gt 0) {
        Write-Host 'Updating script configuration with new values...' -ForegroundColor Yellow

        $new_values_table = ConvertFrom-CommandLineArgs -arguments $values

        [string[]]$properties = [ServerConfig].GetProperties() | Select-Object -ExpandProperty Name

        foreach ($key in $new_values_table.Keys) {
            if ($properties.Contains($key)) {
                $config.$key = $new_values_table[$key]
            }
            else {
                Write-Host "This property does not belong to script configuration: $key" -ForegroundColor Yellow
            }
        }
    }

    try {
        Write-ScriptConfiguration -path $path -object $config

        Write-Host 'Script configuration updated' -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to save script configuration: $_"
    }
}

function Read-ScriptConfiguration {
    param(
        [string]$path
    )

    Write-Host "Reading script configuration from path '$path'..." 

    $json = Get-Content -Path $path -Raw -Encoding utf8

    [ServerConfig]$object = ConvertFrom-Json $json

    return $object
}

function Write-ScriptConfiguration {
    param(
        [string]$path,
        [ServerConfig]$object
    )

    write-host "Saving script configuration at path '$path'..."

    $json = ConvertTo-Json $object

    Out-File -FilePath $path -Encoding utf8 -Force -InputObject $json
}

#endregion

#region Convert cmdline arguments

# Converts hashtable to line formatted as '+key value +key value ...'
function ConvertTo-LaunchArgs {
    param(
        [hashtable]$arguments
    )

    $keys = [Enumerable]::ToArray([object[]]$arguments.Keys)
    $strArgs = ''
    for ($i = 0; $i -lt $keys.Count; $i++) {
        $strArgs += '+' + $keys[$i] + ' ' #+ $arguments[$keys[$i]]

        $arg = $arguments[$keys[$i]]

        if ($arg.GetType() -eq [string] -and $arg.Contains(' ')) {
            $strArgs += '"' + $arg + '"'
        }
        elseif ($arg.GetType() -eq [bool]) {
            $strArgs += $arg.ToString().ToLower()
        }
        else {
            $strArgs += $arg
        }

        if ($i -ne $keys.Count - 1) {
            $strArgs += ' '
        }
    }

    return $strArgs
}

# Converts line formatted as 'key=value, key=value ...' to a hashtable
function ConvertFrom-CommandLineArgs {
    param (
        [string[]]$arguments
    )

    $tbl = @{ }

    foreach ($arg in $arguments) {
        $index = $arg.indexof('=')

        if ($index -eq -1) {
            Write-Warning "Unrecognized argument: $arg"
            continue
        }

        $k = $arg.substring(0, $index).trim()
        $v = $arg.substring($index + 1).trim(@(' ', '"', "'"))


        $tbl[$k] = $v
    }

    return $tbl
}

#endregion

#region Server.cfg update

function Read-ServerCfg {
    param (
        [string]$server_path,
        [string]$server_identity
    )

    $config_table = @{ }
    
    $servercfg_path = Join-Path -Path $server_path -ChildPath 'server' -AdditionalChildPath $server_identity, 'cfg', 'server.cfg'

    if (!(Test-Path $servercfg_path)) {
        Write-Host "No current config found at path '$servercfg_path'" -ForegroundColor DarkYellow
        return $config_table
    }

    Write-Host "Reading server '$server_identity' server.cfg file" -ForegroundColor Yellow

    $lines = Get-Content $servercfg_path

    $argument_regex = [regex]::new('^(?<cmd>(?:[a-z_]+\.)?[a-z_]+)\s+(?<arg>\b[a-z\-_:;\/\\\.,0-9]+\b|".*")\s*$', [RegexOptions]::Multiline -bor [RegexOptions]::IgnoreCase)

    foreach ($line in $lines) {
        $matcharr = $argument_regex.Matches($line)

        foreach ($match in $matcharr) {
            $k = $match.Groups['cmd'].Value
            $v = $match.Groups['arg'].Value.Trim('"')

            $config_table[$k] = $v
        }
    }

    return $config_table
}

function Write-ServerCfg {
    param (
        [string]$server_path,
        [string]$server_identity,
        [hashtable]$server_cfg
    )

    $servercfg_path = Join-Path -Path $server_path -ChildPath 'server' -AdditionalChildPath $server_identity, 'cfg', 'server.cfg'

    Write-Host "Writing updated server.cfg to '$servercfg_path'" -ForegroundColor Yellow

    if (!(Test-Path $servercfg_path)) {
        New-Item -Path $servercfg_path -ItemType File -Force
    }

    $contents_to_write = [string]::Empty

    foreach ($key in $server_cfg.Keys) {
        $value = $server_cfg[$key]

        if ($value.GetType() -eq [string] -and $value.Contains(' ')) {
            $value = "`"$value`""
        }

        $contents_to_write += "$key $value`n"
    }

    $contents_to_write | Out-File -FilePath $servercfg_path -Encoding utf8 -Force -NoNewline
}

function Update-ServerCfg {
    param(
        [string]$server_path,
        [string]$server_identity,
        [string[]]$new_values
    )

    if (!$new_values -or $new_values.Length -lt 1) {
        return
    }

    Write-Host "Updating server.cfg for '$server_identity'" -ForegroundColor Yellow

    $current_config = Read-ServerCfg -server_identity $server_identity -server_path $server_path

    $new_config = ConvertFrom-CommandLineArgs -arguments $new_values

    $merged_config = $current_config.Clone()

    foreach ($key in $new_config.keys) {
        $merged_config[$key] = $new_config[$key]
    }

    Write-Host "Old server.cfg:" -ForegroundColor Black -BackgroundColor Yellow
    $current_config | Format-Table @{Expression = { $_.Key }; Label = 'Command'; Width = 25 }, @{Expression = { $_.Value }; Label = 'Argument' }
    Write-Host "New server.cfg:" -BackgroundColor Blue -ForegroundColor Black
    $new_config | Format-Table @{Expression = { $_.Key }; Label = 'Command'; Width = 25 }, @{Expression = { $_.Value }; Label = 'Argument' }
    write-host "Merged server.cfg:" -BackgroundColor Green -ForegroundColor Black
    $merged_config | Format-Table @{Expression = { $_.Key }; Label = 'Command'; Width = 25 }, @{Expression = { $_.Value }; Label = 'Argument' }
    
    Write-ServerCfg -server_path $server_path -server_identity $server_identity -server_cfg $merged_config

    Write-host "Server.cfg updated successfully!" -ForegroundColor Green
}

#endregion

#region Oxide update checks

function Get-CurrentOxideVersion {
    param(
        [string]$path
    )

    $oxide_path = Join-Path -Path $path -ChildPath 'RustDedicated_Data' -AdditionalChildPath 'Managed', 'Oxide.Rust.dll'

    if (!(Test-Path $oxide_path)) {
        return 'NONE'
    }

    $assembly = [System.Reflection.Assembly]::LoadFile($oxide_path)

    if (!$assembly) {
        return 'NONE'
    }

    $version = $assembly.GetName().Version

    return $version
}

function Get-LatestOxideVersion {
    $api_link = 'https://umod.org/games/rust.json'

    $response = Invoke-WebRequest -Uri $api_link | Select-Object -ExpandProperty Content
    
    $object = ConvertFrom-Json $response -AsHashtable

    return [System.Version]::new($object['latest_release_version'])
}

function Test-NeedOxideUpdate {
    param (
        [string]$path
    )

    $current_version = Get-CurrentOxideVersion -path $path

    if ($current_version -eq 'NONE') {
        return $true
    }

    [System.Version]$latest_version = Get-LatestOxideVersion

    return $current_version.CompareTo($latest_version) -eq -1
}

#endregion

#region Oxide and server updates

function Update-Server {
    param (
        [string]$path,
        [string]$cmd_path,
        [string]$cmd_script_path,
        [bool]$clear
    )

    if (!(Test-Path $cmd_script_path)) {
        throw "SteamCMD script was not found! Make sure it's located at '$cmd_script_path' and try updating server again!"
    }

    $managedfolder_path = Join-Path -Path $path -ChildPath 'RustDedicated_Data' -AdditionalChildPath 'Managed'

    if ($clear -and (Test-Path $managedfolder_path)) {
        Remove-Item $managedfolder_path -Force -Recurse
    }

    &$cmd_script_path 258550 $path -validate -installpath $cmd_path
}

function Update-Oxide {
    param (
        [string]$path
    )

    if (!(Test-NeedOxideUpdate -path $path)) {
        Write-Output 'Oxide update is not necessary'
        return
    }

    $oxide_links = @{
        windows = 'https://umod.org/games/rust/download'
        linux   = 'https://umod.org/games/rust/download/develop'
    }

    $oxide_archive_path = './oxide-latest.zip'

    $managed_path = Join-Path -Path $path -ChildPath 'RustDedicated_Data' -AdditionalChildPath 'Managed'

    Invoke-WebRequest -Uri ($IsWindows ? $oxide_links.windows : $oxide_links.linux) -OutFile $oxide_archive_path

    Expand-Archive -Path $oxide_archive_path -DestinationPath $managed_path
}

#endregion

#region Start server

function Start-Server {
    param (
        [string]$path,
        [ServerConfig]$config,
        [bool]$autorestart
    )

    $launchargs = '-batchmode -nographics'

    if ($config.logfile) {
        $launchargs += " -logfile $($config.logfile)"
    }

    $config_table = @{
        'server.identity'    = $config.identity
        'server.hostname'    = $config.hostname
        'server.description' = $config.description
        'server.url'         = $config.url
        'server.headerimage' = $config.header_url
        'server.port'        = $config.server_port
        'rcon.port'          = $config.rcon_port
        'rcon.password'      = $config.rcon_password
        'server.globalchat'  = $config.globalchat
        'server.pve'         = $config.pve
        'server.radiation'   = $config.radiation
        'server.level'       = $config.map
        'server.worldsize'   = $config.worldsize
        'server.seed'        = $config.seed
        'server.maxplayers'  = $config.maxplayers
    }

    if ($config.server_ip -ne '0.0.0.0') {
        $config_table['server.ip'] = $config.server_ip
    }

    $launchargs += ' ' + (ConvertTo-LaunchArgs -arguments $config_table)

    if ($IsWindows) {
        Start-Process -FilePath 'cmd.exe' -ArgumentList "/C `"RustDedicated.exe $launchargs`"" -WorkingDirectory $path -NoNewWindow -Wait
    }
    else {
        Start-Process (Join-Path -Path $path -ChildPath 'RustDedicated') -ArgumentList $launchargs -WorkingDirectory $path -NoNewWindow -Wait
    }

    if (!$autorestart -or (Wait-WithPrompt -msg 'Restarting server, press any key to cancel' -seconds 5)) {
        Write-Output 'Server stopped'
        return
    }
    Write-Output 'Restarting server'
    Start-Server -path $path -config $config -autorestart $true
}

#endregion

#region Helper functions

function Wait-WithPrompt {
    param (
        [string]$msg,
        [float]$seconds
    )

    $dt = [datetime]::Now
    $pressed = $false
    [int]$lastseconds = 0

    while ($true) {
        $lastseconds = ([timespan]([datetime]::Now - $dt)).TotalSeconds
        $diff = $seconds - $lastseconds
        if ($diff -eq 0) {
            break
        }

        if ($Host.ui.RawUI.KeyAvailable) {
            $pressed = $true
            break
        }
        
        
        Write-Host "`r$msg ($diff s)" -NoNewline

        Start-Sleep -Milliseconds 200
    }

    Write-Host "`r"

    return $pressed
}

function Get-UserInput {
    param (
        [bool]$hidden,
        [string]$msg,
        [string[]]$autocomplete = @()
    )

    Write-Host $msg
    
    $currentinput = ''

    function writecurrentinput {
        Write-Host "`r$((' ' * ($currentinput.Length + 1)))" -NoNewline

        $str = "`r"

        if ($hidden) {
            $str += '*' * $currentinput.Length
        }
        else {
            $str += $currentinput
        }

        Write-Host $str -NoNewline
    }

    function tryautocomplete {
        $match = [Enumerable]::FirstOrDefault($autocomplete, [Func[string, bool]] {
                param(
                    $str
                )

                return $str.StartsWith($currentinput, [StringComparison]::OrdinalIgnoreCase)
            })

        if ($null -ne $match) {
            return $match
        }
        else {
            return $currentinput
        }
    }

    while ($true) {
        [KeyInfo]$key = $Host.UI.RawUI.ReadKey('NoEcho, IncludeKeyDown')

        if ($key.VirtualKeyCode -eq 13) {
            Write-Host "`n" -NoNewline
            return $currentinput
        }
        elseif ($key.VirtualKeyCode -eq 8) {
            $currentinput = $currentinput.Substring(0, [Math]::Max(0, $currentinput.Length - 1))
        }
        elseif ($key.VirtualKeyCode -eq 9) {
            $currentinput = tryautocomplete
        }
        else {
            $currentinput += $key.Character
        }

        writecurrentinput
    }
}

#endregion

#region Wipe

function Invoke-Wipe {
    param(
        [string]$path,
        [string]$identity
    )

    $identity_folder_path = Join-Path -Path $path -ChildPath 'server' -AdditionalChildPath $identity

    Write-Output "Trying to wipe server '$identity' ($identity_folder_path)"

    if (!(Test-Path $identity_folder_path)) {
        Write-Output 'No server directory found'
        return
    }

    $filesToDelete = Get-ChildItem -Path $identity_folder_path | Where-Object {
        return ($_.Name -like 'player.*.db') -or ($_.Name -like '*.map') -or ($_.Name -like '*.sav')
    }

    if ($filesToDelete.Length -lt 1) {
        Write-Output 'No persistence files found'
        return 
    }

    Write-Output "Goint to delete $($filesToDelete.Length) files:"
    $filesToDelete | Format-List | Write-Output
    
    Wait-WithPrompt -msg 'Press any key to cancel wipe' -seconds 5

    foreach ($file in $filesToDelete) {
        Write-Host "Removing file '$($file.Name)'..." -NoNewline
        $file.Delete()
        Write-Host 'Success' -ForegroundColor Green
    }

    Write-Host 'Wipe completed' -ForegroundColor Green
}

#endregion

#region Script body

if ($Update) {
    $UpdateServer = $UpdateOxide = $true
}

Update-ScriptConfiguration -path $ConfigPath -values $ConfigValues -outvariable 'script_configuration'

Update-ServerCfg -server_path $ServerPath -server_identity $script_configuration.identity -new_values $ServerCfgValues

if ($UpdateServer) {
    try {
        Update-Server -path $ServerPath -cmd_path $SteamCmdPath -cmd_script_path $SteamCmdScriptPath -clear $CleanUpdate
    }
    catch {
        Write-Host $_ -ForegroundColor Red
        exit $exit_codes.steamcmd_script_not_found
    }
}

if ($UpdateOxide) {
    Update-Oxide -path $ServerPath
}

if ($Wipe) {
    Invoke-Wipe -path $ServerPath -identity $script_configuration.identity
}

if ($Start) {
    Start-Server -path $ServerPath -config $script_configuration -autorestart $Autorestart
}

#endregion
