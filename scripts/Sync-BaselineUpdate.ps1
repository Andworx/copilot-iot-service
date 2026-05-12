<#
.SYNOPSIS
    Standardized one-command baseline sync for downstream repos.
.DESCRIPTION
    Creates a dedicated update branch, fetches baseline tags, and cherry-picks
    all commits between two baseline tags in order.

    Use this to keep downstream repos aligned with template baseline releases.

    Typical usage:
      .\scripts\Sync-BaselineUpdate.ps1 -OldTag v1.1.0 -NewTag v1.2.0 -BranchName baseline-v1.2.0

    Requirements:
      - Run from a git repository
      - Clean working tree (unless -AllowDirty is set)
      - Baseline remote reachable
.PARAMETER OldTag
    Current baseline tag in the downstream repo (starting point).
.PARAMETER NewTag
    Target baseline tag to apply (ending point).
.PARAMETER BranchName
    Name of the branch to create for the update work.
.PARAMETER BaseBranch
    Branch to branch from before cherry-picking. Default: main.
.PARAMETER BaselineRemote
    Git remote name for the template baseline. Default: baseline.
.PARAMETER BaselineRemoteUrl
    URL for the baseline remote. Used only when adding a missing remote.
.PARAMETER AllowDirty
    Allow running with uncommitted local changes.
.PARAMETER DryRun
    Show what would happen without creating a branch or cherry-picking.
.EXAMPLE
    .\scripts\Sync-BaselineUpdate.ps1 -OldTag v1.1.0 -NewTag v1.2.0 -BranchName baseline-v1.2.0
    # Fetch baseline, create branch from main, and cherry-pick v1.1.0..v1.2.0
.EXAMPLE
    .\scripts\Sync-BaselineUpdate.ps1 -OldTag v1.1.0 -NewTag v1.2.0 -BranchName baseline-v1.2.0 -DryRun
    # Preview commits and checks without applying changes
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OldTag,

    [Parameter(Mandatory = $true)]
    [string]$NewTag,

    [Parameter(Mandatory = $true)]
    [string]$BranchName,

    [string]$BaseBranch = 'main',
    [string]$BaselineRemote = 'baseline',
    [string]$BaselineRemoteUrl = 'https://github.com/andworx/andworx-power-platform-starter-template.git',
    [switch]$AllowDirty,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "[BaselineSync] $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[BaselineSync] $Message" -ForegroundColor Green
}

function Write-WarnMsg {
    param([string]$Message)
    Write-Host "[BaselineSync] $Message" -ForegroundColor Yellow
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args,
        [switch]$CaptureOutput,
        [switch]$IgnoreExitCode
    )

    if ($CaptureOutput) {
        $output = & git @Args 2>&1
        $exitCode = $LASTEXITCODE
        if (-not $IgnoreExitCode -and $exitCode -ne 0) {
            throw "git $($Args -join ' ') failed: $($output -join [Environment]::NewLine)"
        }
        return $output
    }

    & git @Args
    $exitCode = $LASTEXITCODE
    if (-not $IgnoreExitCode -and $exitCode -ne 0) {
        throw "git $($Args -join ' ') failed with exit code $exitCode"
    }
}

try {
    Write-Step "Validating git repository and local state"

    Invoke-Git -Args @('rev-parse', '--is-inside-work-tree') | Out-Null

    if (-not $AllowDirty) {
        $status = Invoke-Git -Args @('status', '--porcelain') -CaptureOutput
        if ($status.Count -gt 0) {
            throw "Working tree is not clean. Commit/stash changes, or run with -AllowDirty if intentional."
        }
    }

    $remoteUrl = Invoke-Git -Args @('remote', 'get-url', $BaselineRemote) -CaptureOutput -IgnoreExitCode
    if ($LASTEXITCODE -ne 0 -or -not $remoteUrl) {
        Write-Step "Adding missing baseline remote '$BaselineRemote'"
        Invoke-Git -Args @('remote', 'add', $BaselineRemote, $BaselineRemoteUrl)
    }

    Write-Step "Fetching tags from remote '$BaselineRemote'"
    Invoke-Git -Args @('fetch', $BaselineRemote, '--tags')

    Write-Step "Validating tags '$OldTag' and '$NewTag'"
    Invoke-Git -Args @('rev-parse', '--verify', "refs/tags/$OldTag") | Out-Null
    Invoke-Git -Args @('rev-parse', '--verify', "refs/tags/$NewTag") | Out-Null

    Invoke-Git -Args @('merge-base', '--is-ancestor', $OldTag, $NewTag)

    $commits = Invoke-Git -Args @('rev-list', '--reverse', "$OldTag..$NewTag") -CaptureOutput
    if (-not $commits -or $commits.Count -eq 0) {
        Write-WarnMsg "No commits found in range $OldTag..$NewTag. Nothing to apply."
        exit 0
    }

    Write-Step "Found $($commits.Count) commit(s) to cherry-pick"

    if ($DryRun) {
        Write-Host ''
        Write-Host 'Dry run summary:' -ForegroundColor Yellow
        Write-Host "  Base branch : $BaseBranch"
        Write-Host "  New branch  : $BranchName"
        Write-Host "  Commit range: $OldTag..$NewTag"
        Write-Host '  Commits:'
        foreach ($c in $commits) {
            $subject = Invoke-Git -Args @('show', '--no-patch', '--format=%s', $c) -CaptureOutput
            Write-Host "    - $c  $($subject -join ' ')"
        }
        Write-Host ''
        Write-Ok 'Dry run complete. No changes were made.'
        exit 0
    }

    Write-Step "Switching to base branch '$BaseBranch'"
    Invoke-Git -Args @('switch', $BaseBranch)
    Invoke-Git -Args @('pull', '--ff-only', 'origin', $BaseBranch)

    $existingBranch = Invoke-Git -Args @('show-ref', '--verify', '--quiet', "refs/heads/$BranchName") -IgnoreExitCode
    if ($LASTEXITCODE -eq 0) {
        throw "Branch '$BranchName' already exists locally. Use a new branch name."
    }

    Write-Step "Creating update branch '$BranchName'"
    Invoke-Git -Args @('switch', '-c', $BranchName)

    Write-Step "Cherry-picking commits from $OldTag..$NewTag"
    foreach ($commit in $commits) {
        $subject = Invoke-Git -Args @('show', '--no-patch', '--format=%s', $commit) -CaptureOutput
        Write-Host "  -> $commit  $($subject -join ' ')" -ForegroundColor DarkGray

        $pickOutput = Invoke-Git -Args @('cherry-pick', $commit) -CaptureOutput -IgnoreExitCode
        if ($LASTEXITCODE -ne 0) {
            Write-Host ''
            Write-Host '[BaselineSync] Cherry-pick conflict encountered.' -ForegroundColor Yellow
            Write-Host "[BaselineSync] Resolve conflicts, then run: git cherry-pick --continue" -ForegroundColor Yellow
            Write-Host "[BaselineSync] Or abort this commit with: git cherry-pick --abort" -ForegroundColor Yellow
            Write-Host "[BaselineSync] Branch kept at: $BranchName" -ForegroundColor Yellow
            throw "Cherry-pick failed on commit ${commit}: $($pickOutput -join [Environment]::NewLine)"
        }
    }

    Write-Host ''
    Write-Ok "Baseline sync complete on branch '$BranchName'."
    Write-Host "[BaselineSync] Next: run tests, update BASELINE_VERSION.md, then open a PR." -ForegroundColor Green
}
catch {
    Write-Host ''
    Write-Host "[BaselineSync] Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
