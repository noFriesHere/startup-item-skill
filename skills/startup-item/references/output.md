# 输出格式

一个输出目录包含：

```text
output/
  workflows/example.json
  scripts/example.ps1
```

```json
{
  "id": "example",
  "enabled": false,
  "title": "示例任务",
  "tabColor": "#800000",
  "workingDirectory": "D:\\project",
  "script": "../scripts/example.ps1",
  "requires": ["git.exe"]
}
```

| 字段 | 含义 |
| --- | --- |
| `id` | 唯一标识，以字母或数字开头，包含字母、数字、下划线、连字符 |
| `enabled` | 是否参与批量启动 |
| `title` | 标签页标题 |
| `tabColor` | 标签页颜色，格式 `#RRGGBB` |
| `workingDirectory` | 绝对工作目录 |
| `script` | 相对配置文件的 `.ps1` 路径 |
| `requires` | 可选，PATH 中的程序名或相对工作目录的程序路径 |

标题及路径需满足管理器参数约束：不含换行、双引号、分号或空字符。JSON 使用 UTF-8，含非 ASCII 字符的 PowerShell 脚本使用 UTF-8 BOM，以兼容 Windows PowerShell 5.1。

脚本独立入口读取配套 JSON，以其中的 `workingDirectory` 为准设置目录并检查依赖，确保配置修改能生效。默认配置路径根据 `$PSScriptRoot` 定位，也可提供 `-ConfigFile` 参数。例如以下错误处理形态，按实际流程填写配置名、程序、参数和提示：

```powershell
param([string]$ConfigFile)
$ErrorActionPreference = 'Stop'
if (-not $ConfigFile) { $ConfigFile = Join-Path $PSScriptRoot '../workflows/example.json' }
if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) {
    throw "Configuration not found: $ConfigFile. Provide -ConfigFile or restore the JSON file."
}
try { $config = Get-Content -LiteralPath $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json }
catch { throw "Read configuration failed: $($_.Exception.Message). Check the JSON file." }
$workDirectory = $config.workingDirectory
if ([string]::IsNullOrWhiteSpace($workDirectory)) { throw 'Configuration: workingDirectory is required.' }
if (-not (Test-Path -LiteralPath $workDirectory -PathType Container)) {
    throw "Working directory not found: $workDirectory. Update the configured path."
}
Set-Location -LiteralPath $workDirectory
$tool = Get-Command 'git.exe' -ErrorAction SilentlyContinue
if (-not $tool) { throw 'Git not found. Install Git or add it to PATH.' }
& $tool.Source @('status', '--short')
if ($LASTEXITCODE -ne 0) {
    throw "Read repository status failed (exit $LASTEXITCODE). Check the Git error above."
}
```

每次生成时根据所选行为补齐前置检查、退出码和清理逻辑，使用清晰的阶段名称。直接执行脚本失败应返回非零退出码；被管理器调用时，通过 `throw` 将错误交给运行器，不在脚本中使用 `exit` 关闭宿主。

复用已有启动项时检查 ID、文件名和引用关系，避免覆盖其他流程。修改共用脚本会影响所有引用者；需要独立行为时生成新脚本。
