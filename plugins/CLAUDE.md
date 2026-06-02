# Dataverse Plugin Development Conventions

Applies to all files under `plugins/`.

## Plugin Fit Guidance

Use a Dataverse plugin when you need synchronous, server-side business logic:
- Hard validation before save
- Deterministic field calculations
- Post-operation cascading updates
- Sequence renumbering or integrity checks

Prefer alternatives when appropriate:
- Power Automate for non-critical asynchronous orchestration
- Client-side scripts for UX-only behavior
- Business rules for simple no-code form-level constraints

## Project and Naming Standards

- Source under `plugins/<PluginProjectName>/`
- Use `plugins/dataverse-plugin-template/` as the base scaffold for new projects
- One assembly per logical business domain — name as `<Domain>Plugin.dll`
- Name classes as `<FeatureOrEntity>Plugin`
- Use publisher-prefixed Dataverse schema names for all custom entities and columns
- Sign all plugin assemblies with an `.snk` file

```text
plugins/
└── YOUR_PLUGIN_PROJECT/
    ├── Properties/AssemblyInfo.cs
    ├── FeaturePlugin.cs
    ├── YOUR_PLUGIN_PROJECT.csproj
    ├── YOUR_PLUGIN_PROJECT.snk
    ├── packages.config
    ├── README.md
    └── FEATURE_REGISTRATION.md
```

## Technical Baseline

- Target framework: `.NET Framework 4.7.1`
- Language version: `C# 7.3`
- Core dependency: `Microsoft.CrmSdk.CoreAssemblies`
- Release builds produce deployable DLLs in `bin/Release/`

## Strong-Name Key Workflow

1. Strong-name signing is enabled by default in `.csproj` (`<SignAssembly>true</SignAssembly>`)
2. Generate the key file before first Release build: run `Generate-StrongNameKey.ps1`
3. Verify key reference and successful signed build output

## Core Plugin Architecture

Each plugin class implements `IPlugin`:

1. Resolve services from `IServiceProvider` (`ITracingService`, `IPluginExecutionContext`, `IOrganizationServiceFactory`, `IOrganizationService`)
2. Apply early exits: depth check, unsupported message/stage guard, missing target/image guard
3. Execute focused business logic
4. Trace key milestones
5. Throw `InvalidPluginExecutionException` for user-facing validation/business errors

## Pipeline Stage Guidance

- `PreValidation` — hard validation before transaction; reject invalid values with clear messages
- `PreOperation` — set/modify attributes before persistence; deterministic calculated fields
- `PostOperation` — logic needing committed record context; sequence renumbering and dependent updates

## Data Access and Attribute Handling

- Read `Target` safely from `InputParameters` using `GetAttributeValue<T>()` and `Contains()` checks
- For `Update`/`Delete` scenarios needing prior values, use pre-images
- Use narrow `ColumnSet` values; never retrieve all columns without necessity
- Use image name `PreImage` unless a strong reason exists to differ
- Validate image existence at runtime; fail with actionable registration error text when missing

## Recursion and Performance Guardrails

- Include a depth guard (`context.Depth > 2`) unless design explicitly requires deeper chaining
- Keep synchronous operations fast; avoid heavy fan-out updates
- Use filtering attributes during step registration to reduce unnecessary executions

## Tracing and Error Handling

- Trace at start/end and around major decision points
- Include message name, entity, and key decision details in trace output
- Wrap unexpected exceptions and rethrow as `InvalidPluginExecutionException` with context

## Registration Documentation Standard

Each plugin feature must have a `FEATURE_REGISTRATION.md` with exactly two sections: **Add Plugin Assembly** and **Add Steps**.

Registration documents must include only registration values and procedural steps. Do not include Purpose, Prerequisites, Validation, Troubleshooting, or explanatory narrative.

```text
# <Feature Name> Registration Steps

## Add Plugin Assembly

1. Open Plugin Registration Tool and connect.
2. Register New Assembly with:
   - Assembly path: `bin/Release/<AssemblyName>.dll`
   - Isolation Mode: Sandbox
   - Storage: Database
   - Select plugin type: `<Namespace.ClassName>`

## Add Steps

### Step 1
- Message: <Create | Update | Delete>
- Primary Entity: <schema_name>
- Stage: <PreValidation | PreOperation | PostOperation>
- Mode: <Synchronous | Asynchronous>
- Rank: <integer>
- Filtering Attributes: <comma-separated list or N/A>
```

Keep values specific and exact: schema names, class names, filtering attributes, and stage/mode settings must match the actual plugin implementation.

## Build and Verification

```powershell
msbuild YOUR_PLUGIN_PROJECT.csproj /p:Configuration=Release
```

Before handing off: verify Release build succeeds, registration docs match plugin signatures, trace output is meaningful for failure triage.

## Do / Do Not

**Do:** keep classes focused and single-purpose; use early returns for unsupported paths; keep user-facing errors clear; align schema names with project publisher prefix.

**Do not:** run long-running work in synchronous steps; rely on implicit images not documented in registration files; update unrelated attributes that trigger plugin loops; deploy unsigned assemblies.
