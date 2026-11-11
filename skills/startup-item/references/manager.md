# 使用 Run on Login 调试

先查看候选目录的 `login.ps1`、`run.cmd` 和 CLI 帮助，确认支持 `-Id`、`-ConfigDirectory`、`-DryRun`。按照实际版本选择参数。已安装的路径可从当前用户启动目录的 `RunOnLogin.lnk` 属性中读取，解析其中的 `-File` 参数后检查文件；不要直接执行快捷方式的参数字符串。

用生成结果目录隔离调试。例如管理器位于 `D:\tools\run_on_login`，输出位于 `D:\generated\demo`：

```powershell
$manager = 'D:\tools\run_on_login\login.ps1'
$configs = 'D:\generated\demo\workflows'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $manager run -Id demo -ConfigDirectory $configs -DryRun
```

预览读取配置而不运行脚本。也可使用随 skill 分发的校验工具：

```powershell
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File '<skill目录>\scripts\Test-StartupItem.ps1' -ConfigFile 'D:\generated\demo\workflows\demo.json' -ManagerPath $manager
```

在具备依赖时，用 `check -Id demo -ConfigDirectory $configs` 检查环境。用户授权试跑后，使用 `run -Id demo -ConfigDirectory $configs` 打开标签页，观察进程、退出码及提示。当前运行器捕获脚本异常后会保留标签页，因此 CLI 请求成功不能当作流程成功；关键错误路径用独立 PowerShell 子进程或模拟程序断言。

需要将结果加入现有管理目录时，按用户指定位置复制配置和脚本，或使用管理器 `add -Id ... -ScriptFile ... -NoEdit` 导入，再按生成结果填写标题、颜色、目录及 `requires`。保持新增项的启用状态与用户选择一致。调试过程使用隔离配置目录，不安装登录自启。
