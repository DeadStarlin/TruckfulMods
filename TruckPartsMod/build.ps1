param([string]$GameRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent))
$ErrorActionPreference = 'Stop'
if (!(Test-Path (Join-Path $GameRoot 'Truckful.exe'))) { throw 'GameRoot must point to the Truckful installation containing Truckful.exe.' }
$sdk = (& dotnet --list-sdks | Select-Object -Last 1)
if ($sdk -notmatch '^([^ ]+) \[(.+)\]$') { throw 'A .NET SDK is required to compile the plugin.' }
$compiler = Join-Path $Matches[2] "$($Matches[1])\Roslyn\bincore\csc.dll"
$output = Join-Path $PSScriptRoot 'TruckfulTruckParts.dll'
$references = @(
    'dotnet\System.Private.CoreLib.dll',
    'dotnet\System.Runtime.dll',
    'dotnet\System.Collections.dll',
    'dotnet\netstandard.dll',
    'BepInEx\core\BepInEx.Core.dll',
    'BepInEx\core\BepInEx.Unity.IL2CPP.dll',
    'BepInEx\core\Il2CppInterop.Runtime.dll',
    'BepInEx\core\0Harmony.dll',
    'BepInEx\interop\Il2Cppmscorlib.dll',
    'BepInEx\interop\UnityEngine.CoreModule.dll',
    'BepInEx\interop\UnityEngine.PhysicsModule.dll',
    'BepInEx\interop\UnityEngine.UI.dll',
    'BepInEx\interop\UnityEngine.UIModule.dll',
    'BepInEx\interop\Unity.InputSystem.dll',
    'BepInEx\interop\TruckfulCore.dll',
    'BepInEx\interop\Assembly-CSharp.dll'
)
$compilerArgs = @('/nologo', '/noconfig', '/nostdlib+', '/target:library', '/optimize+', "/out:$output")
$compilerArgs += $references | ForEach-Object { '/reference:' + (Join-Path $gameRoot $_) }
& dotnet $compiler @compilerArgs (Join-Path $PSScriptRoot 'Plugin.cs')
if ($LASTEXITCODE -ne 0) { throw 'Plugin compilation failed.' }
Write-Output "Built $output"
