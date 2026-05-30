# Dataverse Plugins

This folder contains Dataverse plugin assemblies for `AgenticIoT`.

Use plugins for synchronous server-side logic such as validation, calculated updates, and post-operation integrity processing.

## Structure

```text
plugins/
├── README.md
└── dataverse-plugin-template/      # Starter plugin project scaffold
    ├── DataversePluginTemplate.csproj
    ├── Generate-StrongNameKey.ps1
    ├── SamplePlugin.cs
    ├── Properties/AssemblyInfo.cs
    └── README.md
```

When you create a new plugin, copy `dataverse-plugin-template/` to a new folder (e.g. `plugins/andy-iot-plugin/`) and follow the template README. Each plugin project should contain:

```text
plugins/<your-plugin>/
├── Properties/AssemblyInfo.cs
├── FeaturePlugin.cs
├── <YourPlugin>.csproj
├── <YourPlugin>.snk
├── packages.config
├── README.md
└── <Feature>_REGISTRATION.md
```

## Before You Start

- Review plugin standards in `.github/instructions/plugin-development.instructions.md`.
- Use your project publisher prefix for all custom Dataverse schema names.
- Ensure strong-name signing is enabled for plugin assemblies.

## Quick Workflow

1. Create or update plugin class(es) in your plugin project.
2. Generate your strong-name key (`.\Generate-StrongNameKey.ps1`) if not already present.
3. Build Release assembly.
4. Update registration document(s) with step details.
5. Register/update steps in Plugin Registration Tool.
6. Validate positive and negative behavior in Dataverse.
7. Promote using your project deployment process.

## Build Command

From inside your plugin project folder:

```powershell
# Generate strong-name key (first time only)
.\Generate-StrongNameKey.ps1

# Build
dotnet build .\<YourPlugin>.csproj -c Release
```

Output:
- `bin/Release/net471/<YourPlugin>.dll`

## Registration and Deployment

- Keep one `*_REGISTRATION.md` file per plugin feature or step set.
- In dev/test, validate with Plugin Registration Tool before environment promotion.
- For CI/CD automation guidance, follow `.github/instructions/plugin-development.instructions.md`.

## Template Starter

Use `plugins/dataverse-plugin-template/` to bootstrap a new plugin project with:
- default signing enabled in the project file
- key-generation workflow (`Generate-StrongNameKey.ps1`)
- sample plugin execution pattern
