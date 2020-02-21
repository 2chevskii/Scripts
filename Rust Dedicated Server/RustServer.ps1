
using namespace System.Linq


class ServerConfig {

    ## Location of the server folder
    [string]$server_path = './rust-ds'
    ## Server identity folder (<server-location>/server/<identity>)
    [string]$server_identity = 'example-identity'
    [string]$logfile = 'logs/server.log'

    ## Server information ######################
    [string]$hostname = 'Example rust server hostname'
    [string]$description = 'Example rust server description'
    [string]$url = 'https://example.url'
    [string]$header_url = 'https://example.url'
    ############################################

    ## Change only if you have multiple ip addresses leading to the server machine, otherwise just leave default
    [ValidatePattern('\b(?:(?:2[0-5][0-5]|1?[0-9]?[0-9])\.){3}(?:2[0-5][0-5]|1?[0-9]?[0-9])\b')]
    [string]$server_ip = '0.0.0.0'
    [ValidateRange(0, 65535)]
    [int]$server_port = 28015

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



function Start-Server {
    param (
        [string]$server_path,
        [hashtable]$arguments,
        [bool]$autorestart,
        [hashtable]$server_cfg
    )

    
}

#region Convert cmdline arguments

# Converts hashtable to line formatted as '+key value +key value ...'
function ConvertTo-LaunchArgs {
    param(
        [hashtable]$arguments
    )

    $keys = [Enumerable]::ToArray([object[]]$arguments.Keys)
    $strArgs = ''
    for ($i = 0; $i -lt $keys.Count; $i++) {
        $strArgs += '+' + $keys[$i] + ' ' + $arguments[$keys[$i]]

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
    param(
        [string]$server_path,
        [string]$server_identity
    )

    $servercfg_path = Join-Path -Path $server_path -ChildPath 'server' -AdditionalChildPath $server_identity, 'cfg', 'server.cfg'

    Write-Output "Reading server.cfg from $servercfg_path"

    $tbl = @{ }

    if (!(Test-Path $servercfg_path)) {
        return $tbl
    }

    $content = Get-Content -Path $servercfg_path -Encoding utf8

    foreach ($line in $content) {
        $arr = $line.Split(' ').Where( { ![string]::IsNullOrEmpty($_) })

        if ($arr.Length -lt 2) {
            continue
        }

        $k = $arr[0].Trim()
        $v = $arr[1].Trim()

        if ($v.StartsWith('"') -and $v.EndsWith('"')) {
            $v = $v.Trim('"')
        }

        $tbl[$k] = $v
    }

    return $tbl
}

function Write-ServerCfg {
    param(
        [string]$server_path,
        [string]$server_identity,
        [hashtable]$values
    )

    $servercfg_path = Join-Path -Path $server_path -ChildPath 'server' -AdditionalChildPath $server_identity, 'cfg', 'server.cfg'

    Write-Output "Writing server.cfg at $servercfg_path"

    $strValues = ''

    foreach ($key in $values) {
        $strValue = "$key $($values[$key])"

        $strValues += $strValue + "`n"
    }

    Out-File -FilePath $servercfg_path -Encoding utf8 -InputObject $strValues -Force
}

function Update-ServerCfg {
    param (
        [string]$server_path,
        [string]$server_identity,
        [hashtable]$values
    )

    Write-Output 'Updating server.cfg...'

    [hashtable]$oldcfg = Read-ServerCfg -server_path $server_path -server_identity $server_identity

    foreach ($key in $oldcfg.Keys) {
        $values[$key] = $oldcfg[$key]
    }

    Write-ServerCfg -server_path $server_path -server_identity $server_identity -values $values

    Write-Output 'Server.cfg updated!'
}

#endregion
