# SteamCMD handler

> Script designed to minimize the pain of steamcmd usage for app installation and updates

Script will automatically check if steamcmd is installed in specified path (default is `./steamcmd` , can be overriden by -SteamcmdDir switch with a value). If steamcmd is not present, it will be installed automatically into chosen directory.

> Script requires PowerShell Core version 7 or higher to run properly

## Usage example

  - `pwsh SteamCMD.ps1 258550 ./rust-ds -Validate` :: Install [RustDedicated][rust_ds_guide] into \<current directory>/rust-ds and validate it

## Parameter list

  - `-(AppID|i|id|app) [int]` :: application to download
  - `-(AppDir|d|dir|location) [string]` :: absolute or relative path for app installation :: default is '\<current directory>/app-<appid>'
  - `-(SteamcmdDir|cmd|cmddir|steamcmd) [string]` :: absolute or relative path for steamcmd installation :: default is '\<current directory>/steamcmd'
  - `-(Login|l|u|user|username) [string]` :: Steam login to use :: default is 'anonymous'
  - `-(Password|p|pass) [string]` :: Steam password to use
  - `-(SteamGuardCode|guard|code) [string]` :: Steam Guard 2FA code to use
  - `-(BranchName|b|branch) [string]` :: alternative application branch
  - `-(BranchPassword|bp|bpass) [string]` :: password to access specified alternative branch
  - `-(Validate|v)` :: adds `-validate` to steamcmd launch args
  - `-(CleanArchive|clean)` :: automatically deletes downloaded archive after steamcmd installation

[rust_ds_guide]: https://developer.valvesoftware.com/wiki/Rust_Dedicated_Server
