## SteamCMD.ps1 - steamcmd handling script
Designed to minimize the pain of steamcmd usage for app installation and updates.

### **WARNING**
This script was only tested on Windows and Linux local installation (no -RepoInstall switch), it might behave different across multiple OS distros.

### Script already contains shebang line -> `#!/usr/bin/pwsh`, so you can set it as executable and call from outside of powershell interface

Script will automatically check if steamcmd is installed in specified path (default is ./steamcmd, can be overriden by -SCMDPath switch with a value), or as a command (if -RepoInstall is specified)
If steamcmd is not present, it will be installed automatically into chosen directory or from the repository.

### General usage

*Optional values are located in '[]'*

- `SteamCMD.ps1 [-SCMDPath ... | -RepoInstall]` :: Will only install the steamcmd to the -SCMDPath option value (default is './steamcmd'), or from the repository (linux only)
- `SteamCMD.ps1 [-AppID] <appid> [[-AppDir] <appdir>] [-Validate]` :: Install app \<appid> into \<appdir> (default is 'app-\<appid>'), also can validate installation.

### Parameter list

- `-AppID [int]` (positional 1) :: application to download
- `-AppDir [string]` (positional 2) :: absolute or relative path for app installation :: default is './app-\<appid>'
- `-Branch [string]` :: branch name to download
- `-BranchPass [string]` :: password to the specified branch
- `-Login [string]` :: steam login for apps requiring it :: default is 'anonymous'
- `-Password [string]` :: steam password
- `-SteamGuardCode [string]` :: steam 2FA code
- `-SCMDPath [string]` :: custom path to steamcmd directory :: default is './steamcmd'
- `-RepoInstall [switch]` :: perform search and installation of steamcmd from the repository instead of local folder
- `-Validate [switch]` :: add 'validate' to the steamcmd call
