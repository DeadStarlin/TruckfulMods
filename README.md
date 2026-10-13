# Truckful Mods

Source for four independent Truckful plugins. Install any combination:

| Folder | Plugin DLL | Purpose |
| --- | --- | --- |
| [AdditionalObjectiveMod](AdditionalObjectiveMod/README.md) | TruckfulAdditionalObjective.dll | Pass additional medal objectives while preserving basic mission requirements. |
| [CargoStickinessMod](CargoStickinessMod/README.md) | TruckfulCargoStickiness.dll | Adjust cargo friction and optionally enable permanent glue. |
| [TruckPartsMod](TruckPartsMod/README.md) | TruckfulTruckParts.dll | Unlock parts, optionally treat them as purchased, and enable passive ram/snorkel effects. |
| [EnemyTuningMod](EnemyTuningMod/README.md) | TruckfulEnemyTuning.dll | Adjust enemy truck/train speed and random encounter chance. |

## Requirements and installation

1. Close Truckful. Open its installation folder (Steam: Manage > Browse local files), containing `Truckful.exe`.
2. Install **BepInEx 6.0.0-be.788+5b766a3, Unity IL2CPP, Windows x64**, the version used by this installation. Download `BepInEx-Unity.IL2CPP-win-x64-6.0.0-be.788+5b766a3.zip` from the [official BepInEx builds page](https://builds.bepinex.dev/projects/bepinex_be). Extract its contents into the game folder. BepInEx 5, Mono and x86 packages are not compatible with these plugins.
3. Launch the game once, wait for BepInEx initialization, then close it. This generates `BepInEx/interop` assemblies and `BepInEx/LogOutput.log`. The local environment uses Unity `6000.3.25f1` and BepInEx's bundled .NET runtime `6.0.7`.
4. Build the desired plugins below, or use DLLs supplied separately with a release. This source repository does not track compiled DLLs, game assemblies or BepInEx binaries.
5. Copy each desired plugin DLL from its mod folder into `<game>/BepInEx/plugins/`. Keep only one installed copy of each plugin, including in subfolders.
6. Launch Truckful and check `BepInEx/LogOutput.log` for the plugin's loading message. Configurable mods generate their configuration files on first launch; close the game before editing them and restart afterward. See each mod's README for options and defaults.

To update, close the game and replace the corresponding installed DLL. Existing configuration remains. To uninstall, close the game and remove that DLL from `BepInEx/plugins`.

## Build

Install PowerShell 7 (`pwsh`) and a .NET SDK (`dotnet --list-sdks` must list an SDK). Compilation was checked with SDK `10.0.401`. BepInEx's bundled runtime alone is insufficient to compile. Launch BepInEx once before building to generate the game interop assemblies.

Recommended layout:

```text
Truckful/
  Truckful.exe
  BepInEx/core/
  BepInEx/interop/
  dotnet/
  TruckfulMods/
    AdditionalObjectiveMod/
    CargoStickinessMod/
    TruckPartsMod/
    EnemyTuningMod/
```

From the `TruckfulMods` repository root:

```powershell
pwsh -NoProfile -File ./AdditionalObjectiveMod/build.ps1
pwsh -NoProfile -File ./CargoStickinessMod/build.ps1
pwsh -NoProfile -File ./TruckPartsMod/build.ps1
pwsh -NoProfile -File ./EnemyTuningMod/build.ps1
```

Each script writes its DLL beside `Plugin.cs`; it does not install it. If the repository is elsewhere, pass the game directory to each build:

```powershell
pwsh -NoProfile -File ./CargoStickinessMod/build.ps1 -GameRoot 'D:\SteamLibrary\steamapps\common\Truckful'
```

Builds reference the installed game and loader assemblies directly. Rebuild after game or loader updates; compatibility with other versions has not been established.

## Tests

Run each script in a separate PowerShell 7 process to avoid duplicate test type definitions:

```powershell
pwsh -NoProfile -File ./AdditionalObjectiveMod/test.ps1
pwsh -NoProfile -File ./CargoStickinessMod/test.ps1
pwsh -NoProfile -File ./TruckPartsMod/test.ps1
pwsh -NoProfile -File ./EnemyTuningMod/test.ps1
```

Tests compile the actual plugin source with lightweight stand-ins. They verify decision logic without a running game, but do not verify native Harmony callbacks or in-game handling. Additional objectives can affect persistent medal achievements; equipping parts can persist truck configuration through the game's normal save system. See the individual READMEs before use.
