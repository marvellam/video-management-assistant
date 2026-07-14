[CmdletBinding()]
param(
    [ValidateRange(1, 8)]
    [int]$Jobs = 2,
    [switch]$SkipChecks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
$env:PATH = "$cargoBin;$env:PATH"
$env:CARGO_BUILD_JOBS = [string]$Jobs
$env:CARGO_INCREMENTAL = '0'

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command 执行失败，退出码：$LASTEXITCODE"
    }
}

Push-Location $projectRoot
try {
    Invoke-Checked -Command 'npm.cmd' -Arguments @('ci')

    if (-not $SkipChecks) {
        Invoke-Checked -Command 'npm.cmd' -Arguments @('run', 'typecheck')
        Invoke-Checked -Command 'cargo.exe' -Arguments @('fmt', '--manifest-path', '.\src-tauri\Cargo.toml', '--', '--check')
        Invoke-Checked -Command 'cargo.exe' -Arguments @('test', '--manifest-path', '.\src-tauri\Cargo.toml', '-j', [string]$Jobs)
        Invoke-Checked -Command 'cargo.exe' -Arguments @('clippy', '--manifest-path', '.\src-tauri\Cargo.toml', '--all-targets', '-j', [string]$Jobs, '--', '-D', 'warnings')
    }

    Invoke-Checked -Command 'npm.cmd' -Arguments @('run', 'tauri', '--', 'build', '--no-bundle')

    $source = Join-Path $projectRoot 'src-tauri\target\release\video-management-assistant.exe'
    $releaseRoot = Join-Path $projectRoot 'release'
    $output = Join-Path $releaseRoot '视频管理助手.exe'
    if (-not (Test-Path -LiteralPath $releaseRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $releaseRoot | Out-Null
    }
    Copy-Item -LiteralPath $source -Destination $output -Force

    $hash = Get-FileHash -LiteralPath $output -Algorithm SHA256
    $hashLine = "$($hash.Hash)  $([IO.Path]::GetFileName($output))"
    Set-Content -LiteralPath (Join-Path $releaseRoot 'SHA256SUMS.txt') -Value $hashLine -Encoding UTF8

    $file = Get-Item -LiteralPath $output
    Write-Output ([pscustomobject]@{
        OutputPath = $file.FullName
        SizeMB = [Math]::Round($file.Length / 1MB, 2)
        SHA256 = $hash.Hash
        Jobs = $Jobs
    })
}
finally {
    Pop-Location
}


