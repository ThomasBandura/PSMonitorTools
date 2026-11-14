<#
.SYNOPSIS
    Runs the Pester unit tests and the shared behavior spec (CI and local).
.DESCRIPTION
    Works on Windows PowerShell 5.1 and PowerShell 7. The CI calls it once per shell:
        pwsh -File PowerShell/Build/Invoke-CITests.ps1
        powershell -File PowerShell/Build/Invoke-CITests.ps1
    Exits with a non-zero code if a test fails. Hardware tests are not included.
.PARAMETER InstallPester
    Installs Pester 5.7.1 for the current user if it is missing (used in CI).
.PARAMETER CodeCoverage
    Collects code coverage (coverage.xml in the repository root).
#>
param(
    [switch]$InstallPester,
    [switch]$CodeCoverage
)

$ErrorActionPreference = 'Stop'
$pesterVersion = '5.7.1'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')

if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -eq $pesterVersion })) {
    if (-not $InstallPester) {
        throw "Pester $pesterVersion is not installed. Run with -InstallPester or install it manually."
    }
    if ($PSVersionTable.PSEdition -ne 'Core') {
        # Windows PowerShell 5.1 needs the NuGet provider for Install-Module
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    }
    # -SkipPublisherCheck: the inbox Pester 3.x has a different publisher
    Install-Module -Name Pester -RequiredVersion $pesterVersion -Force -SkipPublisherCheck -Scope CurrentUser
}

Import-Module Pester -RequiredVersion $pesterVersion
Write-Host "PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition)), Pester $pesterVersion"

$config = New-PesterConfiguration
$config.Run.Path = @(
    (Join-Path $repoRoot 'PowerShell\Tests\Monitor.Tests.ps1'),
    (Join-Path $repoRoot 'PowerShell\Tests\Behavior.Spec.Tests.ps1')
)
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'
if ($CodeCoverage) {
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = (Join-Path $repoRoot 'PowerShell\PSMonitorTools\*.ps*1')
    $config.CodeCoverage.OutputPath = (Join-Path $repoRoot 'coverage.xml')
}

Invoke-Pester -Configuration $config
