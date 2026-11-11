[CmdletBinding()]
param([string]$SkillsDirectory)
$ErrorActionPreference = 'Stop'
try {
    if (-not $SkillsDirectory) { $SkillsDirectory = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.agents/skills' }
    $source = Join-Path $PSScriptRoot 'skills/startup-item'
    $destination = [IO.Path]::GetFullPath((Join-Path $SkillsDirectory 'startup-item'))
    $sourceFull = [IO.Path]::GetFullPath($source)
    if ($destination -eq $sourceFull -or $destination.StartsWith($sourceFull.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Install destination must be outside the source skill directory.'
    }
    if (Test-Path -LiteralPath $destination) { throw "Skill already exists: $destination. Choose another skills directory or update the installed files." }
    if (-not (Test-Path -LiteralPath $SkillsDirectory)) { New-Item -ItemType Directory -Path $SkillsDirectory -Force | Out-Null }
    Copy-Item -LiteralPath $source -Destination $destination -Recurse
    Write-Output "Installed: $destination"
    Write-Output 'Invoke in Codex: $startup-item'
} catch {
    [Console]::Error.WriteLine("Install failed: $($_.Exception.Message)")
    exit 1
}
