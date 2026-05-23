# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| `main` | ✅ Active |

Only the `main` branch receives security updates. No versioned releases are supported at this time.

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Please report security issues privately using one of the following methods:

1. **GitHub Private Vulnerability Reporting** (preferred)  
   Go to [Security → Report a vulnerability](../../security/advisories/new) in this repository.

2. **Email**  
   Send details to the repository maintainers. Contact information is in the repository profile.

### What to include

Please provide as much of the following as possible:

- Type of vulnerability (e.g. hardcoded credential, injection, insecure dependency)
- File path(s) and line numbers where the issue exists
- Proof-of-concept or reproduction steps (if applicable)
- Potential impact and severity assessment

### Response timeline

| Stage | Target |
|-------|--------|
| Acknowledgement | Within 3 business days |
| Initial assessment | Within 7 business days |
| Fix or mitigation | Dependent on severity |

## Secrets and Credentials

This repository **does not** store secrets, keys, or credentials. All sensitive values are:

- Loaded at runtime from environment variables or Azure Key Vault
- Documented as `<placeholder>` in README files and examples
- Excluded from source control via `.gitignore`

If you discover a committed secret or credential — even in git history — please report it immediately using the process above.

## Dependency Security

This project uses [Dependabot](.github/dependabot.yml) to monitor and auto-update dependencies.

- **npm**: `azure infrastructure/`, `power pages/iot-panel-dashboard/`
- **GitHub Actions**: `.github/workflows/`

## Scope

The following are **in scope** for security reports:

- Hardcoded secrets, tokens, or credentials in source code or git history
- Insecure GitHub Actions workflows (e.g. script injection via PR event context)
- Unprotected endpoints in the Azure Functions app
- Broken authentication or authorisation in Power Pages
- Insecure Raspberry Pi provisioning scripts

The following are **out of scope**:

- Bugs in third-party dependencies (report to the upstream maintainer)
- Issues in Microsoft Power Platform or Azure infrastructure not caused by this codebase
- Theoretical or unverifiable vulnerabilities without a clear attack path
