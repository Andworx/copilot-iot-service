---
description: "Use when creating or modifying Dataverse plugin assemblies in plugins/. Covers architecture, coding standards, registration, testing, and deployment automation guidance."
applyTo: "plugins/**"
---
# Dataverse Plugin Development Conventions

## Scope

Apply these rules whenever creating or updating Dataverse plugin projects under `plugins/`, including:
- C# plugin classes (`*.cs`)
- Plugin project files (`*.csproj`, `packages.config`)
- Plugin registration documentation (`*_REGISTRATION.md`)
- Plugin project README files

## Plugin Fit Guidance

Use a Dataverse plugin when you need synchronous, server-side business logic in the event pipeline, such as:
- hard validation before save
- deterministic field calculations
- post-operation cascading updates
- sequence renumbering or integrity checks

Prefer other options when appropriate:
- use Power Automate for non-critical asynchronous orchestration
- use client-side scripts for UX-only behavior
- use business rules for simple no-code form-level constraints

## Project and Naming Standards

- Keep plugin source under `plugins/<PluginProjectName>/`.
- Use `plugins/dataverse-plugin-template/` as the base scaffold for new plugin projects.
- Use one assembly per logical business domain.
- Name assembly as `<Domain>Plugin.dll`.
- Name classes as `<FeatureOrEntity>Plugin`.
- Use publisher-prefixed Dataverse schema names for all custom entities and columns.
- Sign all plugin assemblies with an `.snk` file.

Suggested layout:

```text
plugins/
└── YOUR_PLUGIN_PROJECT/
    ├── Properties/
    │   └── AssemblyInfo.cs
    ├── FeaturePlugin.cs
    ├── AnotherFeaturePlugin.cs
    ├── YOUR_PLUGIN_PROJECT.csproj
    ├── YOUR_PLUGIN_PROJECT.snk
    ├── packages.config
    ├── README.md
    ├── FEATURE_REGISTRATION.md
    └── ANOTHER_FEATURE_REGISTRATION.md
```

## Technical Baseline

- Target framework: `.NET Framework 4.7.1` unless solution-specific constraints require otherwise.
- Language version: `C# 7.3` for compatibility with existing plugin runtime/tooling.
- Core dependency: `Microsoft.CrmSdk.CoreAssemblies`.
- Build configuration: Release builds produce deployable DLLs in `bin/Release/`.

## Strong-Name Key Workflow (Default)

For new plugin projects copied from the template:

1. Strong-name signing is enabled by default in the `.csproj`:
  - `<SignAssembly>true</SignAssembly>`
  - `<AssemblyOriginatorKeyFile>...</AssemblyOriginatorKeyFile>`
2. Generate the key file before first Release build:
  - run `Generate-StrongNameKey.ps1`
3. Verify key reference and successful signed build output.

If key generation fails due to missing tooling, install Visual Studio Build Tools (or Visual Studio) with .NET Framework tooling and rerun.

## Core Plugin Architecture

Each plugin class implements `IPlugin` with this standard execution shape:

1. Resolve services from `IServiceProvider`:
   - `ITracingService`
   - `IPluginExecutionContext`
   - `IOrganizationServiceFactory`
   - `IOrganizationService`
2. Apply early exits:
   - depth check to prevent recursion
   - unsupported message/stage guard
   - missing target/image guard
3. Execute focused business logic.
4. Trace key milestones.
5. Throw `InvalidPluginExecutionException` for user-facing validation/business errors.

## Pipeline Stage and Message Guidance

- `PreValidation`:
  - Use for hard validation before transaction processing.
  - Good for rejecting invalid values with clear error messages.
- `PreOperation`:
  - Use for setting or modifying attributes before persistence.
  - Good for deterministic calculated/default fields.
- `PostOperation`:
  - Use when logic needs committed record context or related updates.
  - Good for sequence renumbering and dependent updates.

Supported messages should be explicit and minimal (`Create`, `Update`, `Delete` as needed).

## Data Access and Attribute Handling

- Read `Target` safely from `InputParameters`.
- Use `GetAttributeValue<T>()` and `Contains()` checks.
- For `Update`/`Delete` scenarios that need prior values, use pre-images.
- Use narrow `ColumnSet` values; never retrieve all columns without necessity.
- Filter updates to only changed/required fields when possible.

## Pre/Post Image Conventions

- Use image name `PreImage` unless a strong reason exists to differ.
- Document required image attributes in each registration document.
- Validate image existence at runtime and fail with actionable registration error text when missing.

## Recursion and Performance Guardrails

- Include a depth guard (`context.Depth > 2`) unless design explicitly requires deeper chaining.
- Keep synchronous operations fast; avoid heavy fan-out updates.
- Query only needed rows and columns.
- Use filtering attributes during step registration to reduce unnecessary executions.

## Tracing and Error Handling

- Trace at start/end and around major decision points.
- Include message name, entity, and key decision details in trace output.
- For validation failures, throw clear user-facing messages.
- Wrap unexpected exceptions and rethrow as `InvalidPluginExecutionException` with context.

## Registration Documentation Standard

Each plugin feature must include a registration document (for example `FEATURE_REGISTRATION.md`) with exactly two sections: **Add Plugin Assembly** and **Add Steps**.

Registration documents must include only registration values and procedural steps. Do not include Purpose, Prerequisites, Validation, Troubleshooting, or explanatory narrative.

Use this minimal template structure:

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
- Message: <Message (Create | Update | Delete)>
- Primary Entity: <schema_name>
- Stage: <PreValidation | PreOperation | PostOperation>
- Mode: <Synchronous | Asynchronous>
- Rank: <integer>
- Filtering Attributes: <comma-separated list or N/A>

### Step N (if applicable)
- Message: <Message>
- Primary Entity: <schema_name>
- Stage: <Stage>
- Mode: <Mode>
- Rank: <Rank>
- Filtering Attributes: <comma-separated list or N/A>
```

Keep values specific and exact: schema names, class names, filtering attributes, and stage/mode settings must match the actual plugin implementation. Do not include images, test procedures, or diagnostic content in registration docs.

## Build and Local Verification

Build command example:

```powershell
msbuild YOUR_PLUGIN_PROJECT.csproj /p:Configuration=Release
```

Expected output:
- `bin/Release/YOUR_PLUGIN_PROJECT.dll`

Before handing off for deployment:
- verify build succeeds in Release
- verify registration docs match current plugin signatures
- verify trace output is meaningful for failure triage

## Deployment and Automation Guidance

Use a two-lane approach:

1. Manual lane (required baseline)
- Register DLL and steps with Plugin Registration Tool in dev/test.
- Validate behavior with controlled create/update/delete scenarios.
- Export and document final step configuration.

2. Automated lane (recommended for ALM)
- Treat plugin assembly and registration metadata as deployment artifacts.
- Use CI/CD to build and version assemblies consistently.
- Use environment-aware deployment automation for promoting plugin updates across dev, test, and prod.
- Ensure deployment pipeline includes:
  - pre-deploy validation
  - idempotent step update strategy
  - rollback/version fallback plan

If a project introduces scripted registration, keep script conventions aligned with `scripts/**/*.ps1` guidance in this repo.

## Testing Expectations

Minimum validation after registration/deployment:

1. Positive path for each supported message.
2. Negative validation path (expected user-facing error).
3. Update path with and without changed filtered attributes.
4. Image-required path to confirm registration correctness.
5. Regression check for recursion and unintended updates.

## Do and Do Not

Do:
- keep plugin classes focused and single-purpose
- use early returns for unsupported paths
- keep user-facing errors clear and actionable
- align schema names with project publisher prefix

Do not:
- run long-running or high-latency work in synchronous steps
- rely on implicit images not documented in registration files
- update unrelated attributes that trigger avoidable plugin loops
- deploy unsigned assemblies
