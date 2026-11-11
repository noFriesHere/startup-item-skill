[CmdletBinding()]
param([string]$ManagerPath)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$skill = Join-Path $root 'skills/startup-item'
$validator = Join-Path $skill 'scripts/Test-StartupItem.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('startup-item-skill-test-' + [guid]::NewGuid().ToString('N'))
$checks = 0
function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:checks++
}
function Invoke-Child([string]$File, [string[]]$Arguments, [int]$Expected = 0) {
    $ErrorActionPreference = 'Continue'
    $output = & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $File @Arguments 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    Assert ($code -eq $Expected) "Exit code $code (expected $Expected): $output"
    return ($output -join "`n")
}
function Write-Config {
    [IO.File]::WriteAllText($configPath, ($config | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
}
try {
    New-Item -ItemType Directory -Path (Join-Path $temp 'workflows') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $temp 'scripts') | Out-Null
    Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ps1' | ForEach-Object {
        $tokens = $null
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
        Assert ($errors.Count -eq 0) "Syntax: $($_.Name)"
    }
    $configPath = Join-Path $temp 'workflows/demo.json'
    $scriptPath = Join-Path $temp 'scripts/demo.ps1'
    $marker = Join-Path $temp 'should-not-run.txt'
    [IO.File]::WriteAllText($scriptPath, ("Set-Content -LiteralPath '" + $marker.Replace("'", "''") + "' -Value ran"))
    $config = [pscustomobject]@{ id = 'demo'; enabled = $false; title = 'Demo'; tabColor = '#800000'; workingDirectory = $temp; script = '../scripts/demo.ps1'; requires = @('powershell.exe') }
    Write-Config
    $null = Invoke-Child $validator @('-ConfigFile', $configPath)
    Assert (-not (Test-Path $marker)) 'Static validation does not execute workflow'
    $null = Invoke-Child $validator @('-ConfigFile', $configPath, '-CheckEnvironment')
    $config.workingDirectory = 'Z:\missing-directory'
    Write-Config
    $null = Invoke-Child $validator @('-ConfigFile', $configPath)
    $output = Invoke-Child $validator @('-ConfigFile', $configPath, '-CheckEnvironment') 1
    Assert ($output -match 'working\s+directory\s+not\s+found') "Missing directory error: $output"
    $config.workingDirectory = $temp
    $config.requires = @('./missing-program.exe')
    Write-Config
    $output = Invoke-Child $validator @('-ConfigFile', $configPath, '-CheckEnvironment') 1
    Assert ($output -match 'program not found') 'Missing program error'
    $config.requires = 'powershell.exe'
    Write-Config
    $null = Invoke-Child $validator @('-ConfigFile', $configPath) 1
    $config.requires = @()
    $config.enabled = 'false'
    Write-Config
    $null = Invoke-Child $validator @('-ConfigFile', $configPath) 1
    $config.enabled = $false
    $config.tabColor = 'red'
    Write-Config
    $null = Invoke-Child $validator @('-ConfigFile', $configPath) 1
    $config.tabColor = '#800000'
    $config.title = 'bad;title'
    Write-Config
    $null = Invoke-Child $validator @('-ConfigFile', $configPath) 1
    $config.title = 'Demo'
    $config.workingDirectory = 'relative/path'
    Write-Config
    $null = Invoke-Child $validator @('-ConfigFile', $configPath) 1
    $config.workingDirectory = $temp
    Write-Config
    Set-Content -LiteralPath $scriptPath -Value 'function {'
    $output = Invoke-Child $validator @('-ConfigFile', $configPath) 1
    Assert ($output -match 'Script syntax' -and $output -match 'line') 'Syntax error identifies location'
    Remove-Item -LiteralPath $scriptPath
    $null = Invoke-Child $validator @('-ConfigFile', $configPath) 1
    Set-Content -LiteralPath $scriptPath -Value "throw 'This workflow must not execute during preview.'"
    $config.script = $scriptPath
    Write-Config
    $null = Invoke-Child $validator @('-ConfigFile', $configPath)
    $config.script = '../scripts/demo.ps1'
    Write-Config

    # Capture the adapter's real command arguments in a separate PowerShell process.
    $fakeManager = Join-Path $temp 'fake-manager.ps1'
    $capture = Join-Path $temp 'preview.json'
    $fakeContent = @'
param([string]$Command, [string]$Id, [string]$ConfigDirectory, [switch]$DryRun)
if ($Command -ne 'run' -or -not $DryRun) { throw 'Expected preview.' }
[pscustomobject]@{ id = $Id; directory = $ConfigDirectory } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'preview.json')
'@
    Set-Content -LiteralPath $fakeManager -Value $fakeContent
    $null = Invoke-Child $validator @('-ConfigFile', $configPath, '-ManagerPath', $fakeManager)
    $preview = Get-Content -LiteralPath $capture -Raw | ConvertFrom-Json
    Assert ($preview.id -eq 'demo' -and $preview.directory -eq (Split-Path -Parent $configPath)) 'Manager receives isolated config directory and workflow ID'
    Set-Content -LiteralPath $fakeManager -Value 'exit 9'
    $output = Invoke-Child $validator @('-ConfigFile', $configPath, '-ManagerPath', $fakeManager) 1
    Assert ($output -match 'Manager preview failed' -and $output -match 'exit 9') 'Manager failure is reported'
    if ($ManagerPath) {
        $actualManager = (Resolve-Path -LiteralPath $ManagerPath).ProviderPath
        $null = Invoke-Child $validator @('-ConfigFile', $configPath, '-ManagerPath', $actualManager)
    }
    $skillsDirectory = Join-Path $temp 'installed-skills'
    $null = Invoke-Child (Join-Path $root 'install.ps1') @('-SkillsDirectory', $skillsDirectory)
    $installed = Join-Path $skillsDirectory 'startup-item'
    foreach ($file in Get-ChildItem -LiteralPath $skill -File -Recurse) {
        $relative = $file.FullName.Substring($skill.Length).TrimStart('\', '/')
        $copy = Join-Path $installed $relative
        Assert ((Test-Path -LiteralPath $copy) -and (Get-FileHash -LiteralPath $copy).Hash -eq (Get-FileHash -LiteralPath $file.FullName).Hash) "Installed resource: $relative"
    }
    $null = Invoke-Child (Join-Path $root 'install.ps1') @('-SkillsDirectory', $skillsDirectory) 1
    $null = Invoke-Child (Join-Path $installed 'scripts/Test-StartupItem.ps1') @('-ConfigFile', $configPath)
    Assert (-not (Test-Path $marker)) 'Installed validator remains independent and does not execute workflow'
    Write-Output "PASS: $checks assertions."
} finally {
    $resolved = [IO.Path]::GetFullPath($temp)
    $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($parent, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolved) -like 'startup-item-skill-test-*') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
