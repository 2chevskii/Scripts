# SteamCMD handler

> Script designed to minimize the pain of steamcmd usage for app installation and updates

Script will automatically check if steamcmd is installed in specified path (default is `./steamcmd` , can be overriden by -SteamcmdDir parameter). If steamcmd is not present, it will be installed automatically into chosen directory.

> Script requires PowerShell Core 7+ and [PSColorizer] module

## Usage example

- `pwsh SteamCMD.ps1 258550 ./rust-ds -Validate` :: Install [RustDedicated][rust_ds_guide] into \<current directory>/rust-ds and validate it

## Parameter list

- `-(AppID|id) [int]` :: application to download
- `-(InstallDir|dir) [string]` :: absolute or relative path for app installation :: default is '\<current directory>/app-\<appid>'
- `-(SteamcmdDir|cmddir) [string]` :: absolute or relative path for steamcmd installation :: default is '\<current directory>/steamcmd'
- `-(BranchName|bn) [string]` :: alternative application branch
- `-(BranchPassword|bp) [string]` :: password to access specified alternative branch
- `-Validate` :: adds `-validate` to steamcmd launch args
- `-Cleanup` :: automatically deletes downloaded archive after steamcmd installation
- `-(Login|username) [string]` :: Steam login to use :: default is 'anonymous'
- `-Password [string]` :: Steam password to use
- `-(SteamGuardCode|guard|sgc) [string]` :: Steam Guard 2FA code to use

## Exit codes

Script provides various informational exit codes which might help you integrating it into automatization pipeline.

_See: [Exit codes](exitcodes.yml)_

[rust_ds_guide]: https://developer.valvesoftware.com/wiki/Rust_Dedicated_Server
[pscolorizer]: https://www.powershellgallery.com/packages/PSColorizer/1.0.0
