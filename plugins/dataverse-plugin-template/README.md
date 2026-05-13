# Dataverse Plugin Template Project

This project is a starter template for building Dataverse plugins in Power Platform solutions.

Use it when you need to create a new plugin assembly with the baseline structure already in place:
- plugin class implementing `IPlugin`
- tracing and exception handling pattern
- recursion protection via depth check
- strong-name signing enabled by default
- .NET Framework-compatible class library setup

## What This Is Used For

- Bootstrapping a new plugin project quickly
- Keeping plugin projects consistent across Power Platform implementations
- Reducing setup time before adding business-specific plugin logic

## How To Use

1. Copy this folder to `plugins/<YourPluginProjectName>/`.
2. Rename files and namespaces:
   - `DataversePluginTemplate.csproj`
   - `DataversePluginTemplate` namespace
   - `SamplePlugin.cs` class name
3. Run `./Generate-StrongNameKey.ps1` once to create your `.snk` file.
4. Replace placeholder schema names (for example `andy_name`).
5. Create registration documentation (`*_REGISTRATION.md`) with two sections only: **Add Plugin Assembly** and **Add Steps**. See `.github/instructions/plugin-development.instructions.md` for the minimal template structure.
6. Build and register in your Dataverse environment.

## Build

```powershell
.\Generate-StrongNameKey.ps1
dotnet build .\DataversePluginTemplate.csproj -c Release
```

## If PRT Shows 'No Plugins Selected'

Root cause:
- The plugin class was not compiled into the assembly.

Fix:
- Ensure the project file has explicit compile includes for `SamplePlugin.cs` and `Properties\AssemblyInfo.cs`.
- Rebuild in Release and load the assembly from `bin/Release/net471`.

Verification:
- Confirm the output DLL contains at least one type implementing `Microsoft.Xrm.Sdk.IPlugin` before opening Plugin Registration Tool.

## Notes

- Follow repository standards in `.github/instructions/plugin-development.instructions.md`.
- Keep `.snk` handling aligned with your team's security and secret-management policies.
