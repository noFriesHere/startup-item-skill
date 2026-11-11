[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ConfigFile,
    [switch]$CheckEnvironment,
    [string]$ManagerPath
)
$ErrorActionPreference = 'Stop'
try {
    $configPath = (Resolve-Path -LiteralPath $ConfigFile).ProviderPath
    $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($field in @('id', 'enabled', 'title', 'tabColor', 'workingDirectory', 'script')) {
        if ($null -eq $config.PSObject.Properties[$field]) { throw "Config: missing field '$field'." }
    }
    if ($config.id -isnot [string] -or $config.id -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]*$') { throw 'Config: invalid id.' }
    if ($config.enabled -isnot [bool]) { throw 'Config: enabled must be a boolean.' }
    foreach ($field in @('title', 'workingDirectory', 'script')) {
        if ($config.$field -isnot [string] -or [string]::IsNullOrWhiteSpace($config.$field) -or $config.$field -match '[\r\n;"\x00]') {
            throw "Config: invalid $field."
        }
    }
    if ($config.tabColor -isnot [string] -or $config.tabColor -notmatch '^#[0-9a-fA-F]{6}$') { throw 'Config: tabColor must be #RRGGBB.' }
    if ($config.workingDirectory -notmatch '^([a-zA-Z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+)') { throw 'Config: workingDirectory must be an absolute path.' }
    $scriptPath = if ([IO.Path]::IsPathRooted($config.script)) {
        [IO.Path]::GetFullPath($config.script)
    } else { [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $configPath) $config.script)) }
    if ([IO.Path]::GetExtension($scriptPath) -ne '.ps1' -or -not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Script: .ps1 file not found: $scriptPath."
    }
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw "Script syntax: $($errors[0].Message) (line $($errors[0].Extent.StartLineNumber))." }
    if ($config.PSObject.Properties['requires']) {
        if ($config.requires -isnot [Array]) { throw 'Config: requires must be an array.' }
        foreach ($required in $config.requires) {
            if ($required -isnot [string] -or [string]::IsNullOrWhiteSpace($required)) { throw 'Config: requires entries must be program names or paths.' }
        }
    }
    Write-Output "Config and syntax OK: $($config.id)"
    if ($CheckEnvironment) {
        if (-not (Test-Path -LiteralPath $config.workingDirectory -PathType Container)) {
            throw "Environment: working directory not found: $($config.workingDirectory). Update the path or create the directory."
        }
        if ($config.PSObject.Properties['requires']) {
            foreach ($required in $config.requires) {
                $found = if ($required -match '[/\\]') {
                    $path = if ([IO.Path]::IsPathRooted($required)) { $required } else { Join-Path $config.workingDirectory $required }
                    Test-Path -LiteralPath $path -PathType Leaf
                } else { $null -ne (Get-Command $required -CommandType Application -ErrorAction SilentlyContinue) }
                if (-not $found) { throw "Environment: program not found: $required. Install it or update PATH/requires." }
            }
        }
        Write-Output "Environment OK: $($config.id)"
    }
    if ($ManagerPath) {
        $manager = (Resolve-Path -LiteralPath $ManagerPath).ProviderPath
        if ([IO.Path]::GetExtension($manager) -ne '.ps1') { throw 'ManagerPath must point to login.ps1.' }
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $manager run -Id $config.id -ConfigDirectory (Split-Path -Parent $configPath) -DryRun
        if ($LASTEXITCODE -ne 0) { throw "Manager preview failed (exit $LASTEXITCODE). Check the CLI error above." }
        Write-Output "Manager preview OK: $($config.id)"
    }
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
