# Startup Item Skill

把提示词、手动命令和终端输出转换为可复用的 Windows 启动项。交付 PowerShell 脚本、JSON 配置及验证结果。

Skill 根据实际流程澄清异常处理选择，例如设备未连接时等多久、Git 分叉时如何处理、已有服务是否复用；生成的错误提示包含阶段、原因和处理动作。

## 接入 Codex

在本仓库目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

安装到用户级 `~/.agents/skills/startup-item`。项目级安装可指定目录：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -SkillsDirectory 'D:\project\.agents\skills'
```

也可以把 `skills/startup-item` 整个文件夹复制到 Codex 的技能目录。安装路径和发现机制见 [OpenAI 官方技能文档](https://learn.chatgpt.com/docs/build-skills#where-codex-loads-local-skills)。Codex 会发现新技能；若未显示，重启 Codex。安装器保留已有同名目录，更新时将新的 skill 文件复制到已安装位置。

在 Codex 中输入：

```text
$startup-item
把下面的终端操作生成启动项，输出到 D:\generated\phone。
标题叫“手机投屏”，颜色 #800000。手机未连接时等 60 秒，超时则提示重连。

E:\scrcpy\scrcpy-win64-v3.3.3> adb devices
List of devices attached
fb5d62a6 device
E:\scrcpy\scrcpy-win64-v3.3.3> scrcpy -s fb5d62a6
```

也可只提供自然语言要求或一段终端记录。Skill 会就影响执行结果的缺失信息提问，明确后再完成相应逻辑。标题和颜色等展示信息可直接指定。

## 生成结果与校验

```text
output/
  workflows/phone.json
  scripts/phone.ps1
```

脚本可独立执行，JSON 描述 ID、启用状态、标签标题、颜色、目录和依赖。新增配置默认禁用。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\startup-item\scripts\Test-StartupItem.ps1 -ConfigFile 'D:\generated\phone\workflows\phone.json'
```

校验配置结构及脚本语法。加 `-CheckEnvironment` 检查目录和程序。运行时行为由 Codex 根据生成流程补充模拟测试或实际联调。

独立运行生成脚本：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'D:\generated\phone\scripts\phone.ps1'
```

## 使用管理器调试

电脑上已有 Run on Login 时，可告诉 Codex 其安装路径。Skill 使用管理器的 `run -DryRun` 预览配置；授权试跑后，用独立配置目录打开流程标签页。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\startup-item\scripts\Test-StartupItem.ps1 -ConfigFile 'D:\generated\phone\workflows\phone.json' -ManagerPath 'D:\tools\run_on_login\login.ps1'
```

具体调试命令见 [管理器调试](skills/startup-item/references/manager.md)。

## 验证与维护

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\smoke.ps1
```

自动测试覆盖安装、独立校验、语法错误、环境错误和管理器预览适配。可选传入 `-ManagerPath` 对实际管理器做预览联调。行为评估案例见 [tests/scenarios.md](tests/scenarios.md)。

此目录是独立 Git 仓库，可单独配置远程地址并分发。Skill 入口为 `skills/startup-item/SKILL.md`，支持材料随 skill 文件夹一起安装。
