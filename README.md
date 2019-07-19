[license]: https://tldrlegal.com/license/gnu-general-public-license-v3-(gpl-3)#fulltext



# Scripts [![license](https://img.shields.io/github/license/2chevskii/Scripts.svg?style=plastic)][license] ![](https://img.shields.io/github/last-commit/2chevskii/Scripts.svg?style=plastic)

## Features
- All the scripts only support Windows and require `PowerShell 3.0+`
- Automatization of installation and administration for the game servers
- Now supported
    - Steamcmd installation
    - Rust server installation
    - Oxide installation
    - Rust server launch with configurable parameters
    - Lua language installation

## TODO
- Rust
  - [x] Server installation
  - [x] Oxide installation
  - [x] Server launch with configurable parameters
  - [x] Server wipe
  - [ ] Choose between Oxide and uMod
- Gmod
  - [ ] Server installation
  - [ ] Server launch with configurable parameters
- CS:GO
  - [ ] Server installation
  - [ ] Sourcemod installation
  - [ ] Server launch with configurable parameters
- DayZ
  - [x] Server installation
  - [ ] Server launch with configurable parameters
  - [x] Server wipe
- Lua
  - [x] Download source
  - [x] Uncompress source
  - [ ] Download gcc (now requires `tdm-gcc`)
  - [x] Compile interpreter
  - [x] Cleanup folder after installation
  - [x] Register PATH variable
  - [ ] Advanced exception handling
  - [ ] Cleanup and document code
- Insurgency
  - [ ] Server installation
  - [ ] Server launch with configurable parameters
- Insurgency: Sandstorm
  - [ ] Server installation
  - [ ] Server launch with configurable parameters
- Alt:V MP
  - [ ] Server installation with configurable packages
  - [ ] Server configuration
  - [ ] Server launch  

# RUST SERVER MANAGEMENT
- Download `SteamCMDInstallation.ps1` and `RustServer.ps1`
- Place them into root folder (In this folder all the additional folder will be created, like `rustds` and `SteamCMD`), `SteamCMD` folder, as well as `SteamCMDInstallation.ps1` script can be used later for other servers
- Launch the `RustServer.ps1` script and choose `Install/update server` option

**You can uncomment line in the `RustServer.ps1` script to make `Oxide` installation automatical**
![](https://i.imgur.com/hlwvN5C.png)

- If you want to install `Oxide` (and if it is not installed automatically leading the previous point)
- Write down any input to exit the script

All the launch parameters can be changed inside the script after the `### Server launch parameters ###` tag
![](https://i.imgur.com/i9YvTmT.png)

# Lua language installation
- Download `Lua-Install.ps1`
- Place script in the folder you want lua to be installed to
- Set wanted Lua version in the script (default is `5.3.5`) ![](https://i.imgur.com/utaZJNk.png)
- Make sure that [tdm-gcc](http://tdm-gcc.tdragon.net/download) is installed ***and registered to PATH***
- Launch the script - *Note that if the script is located in folder you do not own (`i.e. C:\Windows\ProgramFiles\`), you will need to launch script as administrator*
- Restart your PC to be able to access lua from CMD (PATH variable will be updated)

Script will automatically download source code, compile it, cleanup folder and register lua interpreter folder as PATH variable, so you could access it from console.