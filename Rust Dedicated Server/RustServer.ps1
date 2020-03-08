using namespace System
using namespace System.Text.RegularExpressions
using namespace System.Diagnostics.CodeAnalysis

[CmdletBinding(DefaultParameterSetName = 'NIA')]
param (
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [Alias('p', 'path')]
    [string]$ServerPath,

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

#region Fields

$script_info = @{
    name           = 'RustDS HELPER'
    author         = '2CHEVSKII'
    version        = @{
        major = 2
        minor = 2
        patch = 1
    }
    license        = 'MIT LICENSE'
    'license-link' = 'https://www.tldrlegal.com/l/mit'
    repository     = 'https://github.com/2chevskii/Automation'
}

$constants = @{
    oxide_link         = @{
        windows = 'https://umod.org/games/rust/download'
        linux   = 'https://umod.org/games/rust/download/develop'
        api     = 'https://umod.org/games/rust.json'
    }
    app_id             = 258550
    oxide_archive_name = 'oxide-latest.zip'
    managed_path       = 'RustDedicated_Data/Managed'
}

[Configuration]$configuration

#endregion

#region Helpers

function Update-ConfigurationValues {
    param(
        [string[]]$new_values
    )

    Write-Console "<yellow>Updating configuration with new values:</yellow>`n$(Join-String -Separator ', ' -SingleQuote -InputObject $new_values)"

    $new_values_table = ($new_values | ConvertFrom-CommandLineArgs)

    [string[]]$props = [Configuration].GetProperties() | Select-Object -ExpandProperty Name

    $updatedprops = 0

    foreach ($key in $new_values_table.Keys) {
        if ($props.Contains($key)) {
            $configuration.$key = $new_values_table[$key]
            Write-Console "Updated property $key"
            $updatedprops++
        } else {
            Write-Console "<yellow>This property does not belong to script configuration: $key</yellow>"
        }
    }

    if ($updatedprops -gt 0) {
        Write-Console "<green>Total properties updated: $updatedprops</green>"
        Save-Configuration
    } else {
        Write-Console '<yellow>No configuration properties were updated</yellow>'
    }
}

function Load-Configuration {
    [SuppressMessageAttribute('PSUseApprovedVerbs' , '')]
    param()

    if (!(Test-Path -Path $ConfigPath)) {
        Write-Console 'No configuration file found!'

        Load-DefaultConfiguration
    } else {
        try {
            Write-Console "<yellow>Loading configuration from file $ConfigPath</yellow>"

            $configuration = [Configuration](Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json)

            Write-Console '<green>Configuration loaded!</green>'
        } catch {
            Write-Console "Failed to load configuration from file:`n$_"
            Load-DefaultConfiguration
        }
    }
}

function Load-DefaultConfiguration {
    [SuppressMessageAttribute('PSUseApprovedVerbs' , '')]
    param()

    Write-Console '<yellow>Loading default configuration...</yellow>'

    $configuration = [Configuration]::new()

    Write-Console '<green>Default configuration loaded!<green>'

    Save-Configuration
}

function Save-Configuration {

    Write-Console "<yellow>Saving configuration file at $ConfigPath</yellow>"

    try {
        $configuration | ConvertTo-Json | Out-File -FilePath $path -Encoding utf8 -Force

        Write-Console '<green>Configuration saved</green>'
    } catch {
        Write-Console "<red>Failed to write configuration file:`n$_</red>"
    }
}

function Wait-WithPrompt {
    [SuppressMessageAttribute('PsAvoidUsingWriteHost', '')]
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

        [Console]::Write("`r$msg ($diff s)")

        Start-Sleep -Milliseconds 200
    }

    [Console]::WriteLine("`r")

    return $pressed
}

function Write-Console {
    [SuppressMessageAttribute('PsAvoidUsingWriteHost', '')]
    param(
        [Alias('m', 'msg', 'text')]
        [Parameter(Position = 0, ValueFromPipeline, Mandatory)]
        [string]$message
    )

    $default_color = [Console]::ForegroundColor

    $color_regex_pattern = '(?:<([a-z]+)>((?:(?!<\/\1>).)*)<\/\1>)|((?:(?!<([a-z]+)>.*<\/\4>).)+)'

    $color_regex = [regex]::new($color_regex_pattern, [RegexOptions]::IgnoreCase)

    $mtchs = $color_regex.Matches($message)

    if ($mtchs.Count -gt 0) {

        $colored = @()

        foreach ($match in $mtchs) {
            $color = $default_color
            $msg = $null
            if ($match.Groups[3].Length -gt 0) {
                $msg = $match.Groups[3].Value
            } else {
                $color = $match.Groups[1].Value
                $msg = $match.Groups[2].Value
            }

            $colored += @{
                color   = $color
                message = $msg
            }
        }

        foreach ($colored_message in $colored) {
            if ($colored_message.color) {
                [Console]::ForegroundColor = $colored_message.color
            }

            [Console]::Write($colored_message.message)

            [Console]::ForegroundColor = $default_color
        }

        [Console]::Write("`n")
    } else {
        [Console]::WriteLine($message)
    }
}

function Get-ASCIIBanner {
    param(
        [string]$text
    )

    $request_uri = "http://artii.herokuapp.com/make?text=$($text.Replace(' ', '+'))"

    Invoke-WebRequest -Uri $request_uri | Select-Object -ExpandProperty Content | Out-String
}

function Get-LatestOxideVersion {
    try {
        $response = Invoke-WebRequest -Uri $constants.oxide_link.api | Select-Object -ExpandProperty Content

        $response_object = ConvertFrom-Json -AsHashtable -InputObject $response

        return [version]::new($response_object['latest_release_version'] + '.0')
    } catch {
        return $null
    }
}

function Get-CurrentOxideVersion {
    param(
        [string]$server_path
    )

    $oxide_rust_path = Join-Path -Path $server_path -ChildPath $constants.managed_path -AdditionalChildPath 'Oxide.Rust.dll'
    try {
        $assembly = [Reflection.Assembly]::LoadFile($oxide_rust_path)

        return $assembly.GetName().Version
    } catch {
        return $null
    }
}

function Test-NeedOxideUpdate {
    param(
        [string]$server_path
    )

    $current_version = Get-CurrentOxideVersion -server_path $server_path

    if (!$current_version) {
        Write-Console '<darkgray>Oxide is not installed</darkgray>'
        return $true
    }

    $latest_version = Get-LatestOxideVersion

    if (!$latest_version) {
        Write-Console '<yellow>Could not fetch latest oxide version!</yellow>'
        return $true
    }

    $compare_result = $current_version.CompareTo($latest_version)

    switch ($compare_result) {
        -1 {
            Write-Console '<yellow>Current Oxide version is older than latest</yellow>'
            return $true
        }
        0 {
            Write-Console '<green>Current Oxide version is up-to-date</green>'
        }
        1 {
            Write-Console '<red>Current Oxide version is higher than latest... WTF?</red>'
        }
    }

    return $false
}

# Converts hashtable to string formatted as '+key value +key value ...'
function ConvertTo-LaunchArgs {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [hashtable]$arguments
    )

    $strArgs = ''

    for ($i = 0; $i -lt $arguments.Count; $i++) {
        $k = ([object[]]$arguments.Keys)[$i]
        $v = ([object[]]$arguments.Values)[$i]

        if ($v.GetType() -eq [string] -and $v.Contains(' ')) {
            $v = "`"$v`""
        } elseif ($v.GetType() -eq [bool]) {
            $v = $v.tostring().tolower()
        }

        $strArgs += "+$k $v"

        if ($i -lt $arguments.Count - 1) {
            $strArgs += ' '
        }
    }

    return $strArgs
}

# Converts line formatted as 'key=value, key=value ...' to a hashtable
function ConvertFrom-CommandLineArgs {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
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

#region Core

class Configuration {
    ## Server identity folder (<server-location>/server/<identity>)
    [string]$identity = 'example-identity'
    [string]$logfile = 'logs/example-identity.log'

    ## Server information ######################
    [string]$hostname = 'Example rust server hostname'
    [string]$description = 'Example rust server description'
    ## Server webpage
    [string]$server_url = 'https://example.url'
    ## Server preview image
    [string]$header_url = 'https://example.url'
    ############################################

    ## Network parameters ######################
    ## Change only if you have multiple ip addresses leading to the server machine AND YOU KNOW WHAT YOU ARE DOING, otherwise just leave default
    [ValidatePattern('\b(?:(?:25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(?:25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\b')]
    [string]$server_ip = '0.0.0.0'
    [ValidateRange(0, 65535)]
    [int]$server_port = 28015
    ############################################

    ## Rcon settings ######################
    ## Change only if you have multiple ip addresses leading to the server machine AND YOU KNOW WHAT YOU ARE DOING, otherwise just leave default
    [ValidatePattern('\b(?:(?:25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(?:25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\b')]
    [string]$rcon_ip = '0.0.0.0'
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

function Update-Server {
    param (
        [string]$dir,
        [string]$cmd_path,
        [string]$cmd_script_path,
        [bool]$clear
    )

    try {
        Write-Console '<yellow>[---] Preparing for Rust server update</yellow>'

        if ($clear) {
            Write-Console '<yellow>[---] Cleaning up old files in the Managed directory</yellow>'
            Remove-Item -Path "$(Join-Path -Path $dir -ChildPath $constants.managed_path)/*" -ErrorAction SilentlyContinue
            Write-Console '<darkgreen>[10%] Old files removed</darkgreen>'
        }

        Write-Console "<yellow>[---] Installing RustDedicatedServer into $dir</yellow>"
        &$cmd_script_path -i $constants.app_id -d $dir -cmd $cmd_path -clean -v
        Write-Console "<darkgreen>[99%] Installation finished</darkgreen>"

        Write-Console '<green>[ x ] Rust server updated</green>'

    } catch {
        Write-Console '<red>Server update failed with error:</red>'
        Write-Console "<red>$($_.Exception.Message)</red>"
    }
}

function Update-Oxide {
    param (
        [string]$dir
    )

    Write-Console '<yellow>[---] Preparing for Oxide update</yellow>'
    Write-Console '<yellow>[---] Checking Oxide versions</yellow>'
    if (Test-NeedOxideUpdate -server_path $dir) {
        try {
            Write-Console '<yellow>[---] Started Oxide update</yellow>'

            ## Download build
            $download_link = ($IsWindows ? $constants.oxide_link.windows : $constants.oxide_link.linux)
            Write-Console "<darkgray>[---] Downloading latest version of Oxide from</darkgray> <blue>$download_link</blue>"
            $archive_path = Join-Path -Path $dir -ChildPath $constants.oxide_archive_name
            Invoke-WebRequest -Uri $download_link -OutFile $archive_path
            Write-Console "<darkgreen>[50%]Latest Oxide build downloaded into</darkgreen> <blue>$archive_path</blue>"
            $managed_dir = Join-Path -Path $dir -ChildPath $constants.managed_path

            ## Extract archive
            Write-Console "<darkgray>[---]Extracting Oxide archive into</darkgray> $managed_dir"
            Expand-Archive -Path $archive_path -DestinationPath $managed_dir -Force
            Write-Console "<darkgreen>[99%]Oxide archive upzipped</darkgreen>"

            # ## Maybe cleanup files? Not sure if necessary, gonna leave it commented out for now
            # Write-Console 'Cleaning up temp files'
            # Remove-Item $archive_path
            # Write-Console 'Temp files removed'

            Write-Console '<green>[ x ] Oxide update completed!</green>'
        } catch {
            Write-Console '<red>Oxide update failed with error:</red>'
            Write-Console "<red>$($_.Exception.Message)</red>"
            return $false
        }
    } else {
        Write-Console '<green>[ x ] Oxide update is not necessary</green>'
    }

    return $true
}

function Wipe-Server {
    [SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    param(
        [string]$server_path,
        [string]$server_identity,
        [bool]$force
    )

    if (!$force) {
        Wait-WithPrompt -msg 'Wiping server, press any key to cancel' -seconds 5
    }

    $folder_path = Join-Path -Path $server_path -ChildPath 'server' -AdditionalChildPath $server_identity

    if (!(Test-Path -Path $folder_path)) {
        Write-Console "<yellow>No server folder found ($folder_path)</yellow>"
        return
    }

    Write-Console "<yellow>Wiping server $folder_path</yellow>"

    $file_list = Get-ChildItem -Path $folder_path | Where-Object { ($_.Name -like 'player.*.db') -or ($_.Name -like '*.map') -or ($_.Name -like '*.sav') }

    foreach ($file in $file_list) {
        try {
            Remove-Item -Path $file.FullName
            Write-Console "<darkgreen>Deleted file '$($file.Name)'</darkgreen>"
        } catch {
            Write-Console "<red>Failed to delete file '$($file.Name)'! Error:</red>"
            Write-Console "<red>$($_.Exception.Message)</red>"
        }
    }

    Write-Console '<green>Wipe finished</green>'
}

function Start-Server {
    param (
        [Configuration]$config,
        [string]$dir,
        [bool]$autorestart
    )

    $executable_name = $IsWindows ? 'RustDedicated.exe' : 'RustDedicated'

    $launchargs = "-batchmode -nographics -logfile $($config.logfile) " + (@{
            'server.identity'    = $config.identity
            'server.hostname'    = $config.hostname
            'server.description' = $config.description
            'server.url'         = $config.server_url
            'server.headerimage' = $config.header_url
            'server.port'        = $config.server_port
            'rcon.ip'            = $config.rcon_ip
            'rcon.port'          = $config.rcon_port
            'rcon.password'      = $config.rcon_password
            'server.globalchat'  = $config.globalchat
            'server.pve'         = $config.pve
            'server.radiation'   = $config.radiation
            'server.level'       = $config.map
            'server.worldsize'   = $config.worldsize
            'server.seed'        = $config.seed
            'server.maxplayers'  = $config.maxplayers
        } | ConvertTo-LaunchArgs)

    Write-Console "<yellow>Starting server $($config.identity) in $executable_path</yellow>"
    Write-Console "Startup arguments: $launchargs"

    if (!(Test-Path $config.logfile)) {
        New-Item $config.logfile
    }

    if ($IsWindows) {
        Start-Process -FilePath 'cmd.exe' -ArgumentList "/C RustDedicated.exe `"$launchargs`"" -WorkingDirectory $dir -Wait
    } else {
        Start-Process -FilePath (Join-Path -Path $dir -ChildPath 'RustDedicated') -WorkingDirectory $dir -ArgumentList $launchargs -NoNewWindow -Wait
    }

    if (!$autorestart -or (Wait-WithPrompt -msg 'Restarting server, press any key to cancel' -seconds 5)) {
        Write-Console '<green>Server stopped</green>'
        return
    }

    Write-Console '<yellow>Restarting server...</yellow>'
    Start-Server $config $dir $autorestart
}

#endregion

#### WELCOME SCREEN

$Host.UI.RawUI.WindowTitle = $script_info['name']
Get-ASCIIBanner -text $script_info['name']
Write-Console "Author                         -> <magenta>$($script_info['author'])</magenta>"
Write-Console "Version                        -> <darkyellow>$($script_info.version.major).$($script_info.version.minor).$($script_info.version.patch)</darkyellow>"
Write-Console "Licensed under the <darkred>$($script_info['license'])</darkred> -> <blue>$($script_info['license-link'])</blue>"
Write-Console "Repository                     -> <blue>$($script_info['repository'])</blue>"

###################
