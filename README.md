# PaperEye

PaperEye 是一个 Windows 桌面类纸护眼滤镜。它通过全屏透明置顶覆盖层，为屏幕叠加暖色纸感、细腻纹理和峰值亮度压暗，适合长时间阅读网页、文档和代码时使用。

## 功能特性

- 类纸护眼覆盖层：不截获鼠标点击，不影响正常操作窗口。
- 纸感强度：`0%` 到 `100%`，支持 `1%` 精细调节。
- 纹理强度：`0%` 到 `100%`，可降低低亮度环境下的颗粒或条纹感。
- 最大亮度缩限：`0%` 到 `60%`，均匀压暗全白页面，降低刺眼感。
- 开机自启动：可在界面中开启或关闭当前用户自启动。
- 多语言界面：支持中文和英文，默认中文。
- 系统托盘：关闭窗口后继续运行，可从托盘重新打开。
- 全局快捷键：无需聚焦窗口也能开关和微调强度。
- 本地保存配置：无需联网，不收集数据。

## 系统要求

- Windows 10 或 Windows 11
- Windows PowerShell 5.1
- .NET Framework WPF 运行环境

Windows 10/11 默认满足以上要求。

## 快速开始

1. 下载或克隆仓库。
2. 双击运行 `run.bat`。
3. 首次启动后会显示控制面板；关闭面板时程序会隐藏到系统托盘。

如果系统阻止脚本运行，`run.bat` 已内置：

```bat
powershell.exe -STA -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%SCRIPT_DIR%paper-eye.ps1"
```

## 使用说明

控制面板包含三项核心参数：

- `纸感强度`：控制暖色纸张底色。
- `纹理强度`：控制细腻颗粒感；暗光环境建议先尝试 `0%` 到 `20%`。
- `最大亮度缩限`：限制屏幕峰值亮度，让全白页面不那么刺眼。

偏好设置：

- `开机自启动`：写入当前用户注册表，不需要管理员权限。
- `界面语言`：中文和英文之间切换，切换后立即生效。

## 快捷键

- `Ctrl + Alt + P`：开启或暂停效果。
- `Ctrl + Alt + Up`：纸感强度增加 `1%`。
- `Ctrl + Alt + Down`：纸感强度减少 `1%`。

## 配置位置

配置文件保存到：

```text
%APPDATA%\PaperEye\settings.json
```

开机自启动写入当前用户注册表：

```text
HKCU\Software\Microsoft\Windows\CurrentVersion\Run\PaperEye
```

## 项目结构

```text
.
├── paper-eye.ps1   # 主程序：WPF 控制面板、覆盖层、托盘、快捷键
├── run.bat         # 推荐启动入口
└── README.md       # 中文发布文档
```

## 开发与验证

语法检查：

```powershell
$tokens = $null
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile('paper-eye.ps1', [ref]$tokens, [ref]$errors)
$errors
```

XAML 加载检查：

```powershell
Add-Type -AssemblyName PresentationFramework
$content = Get-Content -LiteralPath 'paper-eye.ps1' -Raw
$matches = [regex]::Matches($content, "(?s)\$[a-zA-Z]+Xaml\s*=\s*@'\r?\n(.*?)\r?\n'@")
foreach ($m in $matches) {
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$m.Groups[1].Value)
    [void][System.Windows.Markup.XamlReader]::Load($reader)
}
```

