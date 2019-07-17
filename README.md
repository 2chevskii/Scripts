[license]: https://tldrlegal.com/license/gnu-general-public-license-v3-(gpl-3)#fulltext



# Scripts [![license](https://img.shields.io/github/license/2chevskii/Scripts.svg?style=plastic)][license] ![](https://img.shields.io/github/last-commit/2chevskii/Scripts.svg?style=plastic)

## Features
- Automatization of installation and administration for the game servers
- Now supported
    - Steamcmd installation
    - Rust server installation
    - Oxide installation
    - Rust server launch with configurable parameters

## TODO
- Rust
  - [x] Server installation
  - [x] Oxide installation
  - [x] Server wipe
  - [ ] Choose between Oxide and uMod
- Gmod
  - [ ] Server installation
- CS:GO
  - [ ] Server installation
  - [ ] Sourcemod installation
- DayZ
  - [ ] Server installation
  - [ ] Server wipe

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