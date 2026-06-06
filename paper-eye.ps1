[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class Win32
{
    [StructLayout(LayoutKind.Sequential)]
    public struct MAGCOLOREFFECT
    {
        [MarshalAs(UnmanagedType.ByValArray, SizeConst=25)]
        public float[] transform;
    }

    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_TRANSPARENT = 0x20;
    public const int WS_EX_TOOLWINDOW = 0x80;
    public const int WS_EX_NOACTIVATE = 0x08000000;
    public const int WM_HOTKEY = 0x0312;
    public const int WM_DISPLAYCHANGE = 0x007E;
    public const int WM_SETTINGCHANGE = 0x001A;
    public const int WM_DPICHANGED = 0x02E0;

    public const int SM_XVIRTUALSCREEN = 76;
    public const int SM_YVIRTUALSCREEN = 77;
    public const int SM_CXVIRTUALSCREEN = 78;
    public const int SM_CYVIRTUALSCREEN = 79;

    public const uint SWP_NOACTIVATE = 0x0010;
    public const uint SWP_SHOWWINDOW = 0x0040;

    public const uint MOD_ALT = 0x0001;
    public const uint MOD_CONTROL = 0x0002;
    public const uint MOD_SHIFT = 0x0004;

    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public static readonly IntPtr DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = new IntPtr(-4);

    [DllImport("user32.dll", EntryPoint="GetWindowLongPtr", SetLastError=true)]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint="SetWindowLongPtr", SetLastError=true)]
    private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    [DllImport("user32.dll", EntryPoint="GetWindowLong", SetLastError=true)]
    private static extern IntPtr GetWindowLong32(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint="SetWindowLong", SetLastError=true)]
    private static extern IntPtr SetWindowLong32(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern int GetSystemMetrics(int nIndex);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetProcessDpiAwarenessContext(IntPtr dpiContext);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetProcessDPIAware();

    [DllImport("Magnification.dll", SetLastError=true)]
    public static extern bool MagInitialize();

    [DllImport("Magnification.dll", SetLastError=true)]
    public static extern bool MagUninitialize();

    [DllImport("Magnification.dll", SetLastError=true)]
    public static extern bool MagSetFullscreenColorEffect(ref MAGCOLOREFFECT pEffect);

    public static IntPtr GetWindowLongAuto(IntPtr hWnd, int nIndex)
    {
        return IntPtr.Size == 8 ? GetWindowLongPtr64(hWnd, nIndex) : GetWindowLong32(hWnd, nIndex);
    }

    public static IntPtr SetWindowLongAuto(IntPtr hWnd, int nIndex, IntPtr dwNewLong)
    {
        return IntPtr.Size == 8 ? SetWindowLongPtr64(hWnd, nIndex, dwNewLong) : SetWindowLong32(hWnd, nIndex, dwNewLong);
    }
}
"@

function Enable-PerMonitorDpiAwareness {
    try {
        if ([Win32]::SetProcessDpiAwarenessContext([Win32]::DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)) {
            return
        }
    }
    catch {
    }

    try {
        [void][Win32]::SetProcessDPIAware()
    }
    catch {
    }
}

Enable-PerMonitorDpiAwareness

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, System.Windows.Forms

$script:AppName = 'PaperEye'
$script:ConfigDir = Join-Path ([Environment]::GetFolderPath('ApplicationData')) $script:AppName
$script:ConfigPath = Join-Path $script:ConfigDir 'settings.json'
$script:ScriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($script:ScriptPath)) {
    $script:ScriptPath = $PSCommandPath
}
$script:StartupRegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$script:StartupValueName = $script:AppName

if (-not (Test-Path -LiteralPath $script:ConfigDir)) {
    [void](New-Item -ItemType Directory -Path $script:ConfigDir -Force)
}

$script:State = $null
$script:App = $null
$script:MainWindow = $null
$script:MainHwndSource = $null
$script:HotkeyHook = $null
$script:OverlayWindow = $null
$script:OverlayTintLayer = $null
$script:OverlayNoiseLayer = $null
$script:OverlayWhiteCapLayer = $null
$script:HeroSubtitleText = $null
$script:HeroBadgeText = $null
$script:StatusText = $null
$script:IntensityTitleText = $null
$script:IntensityDescText = $null
$script:IntensityValueText = $null
$script:IntensitySlider = $null
$script:TextureTitleText = $null
$script:TextureDescText = $null
$script:TextureValueText = $null
$script:TextureSlider = $null
$script:WhiteCapTitleText = $null
$script:WhiteCapDescText = $null
$script:WhiteCapValueText = $null
$script:WhiteCapSlider = $null
$script:ColorKeepTitleText = $null
$script:ColorKeepDescText = $null
$script:ColorKeepValueText = $null
$script:ColorKeepSlider = $null
$script:TextContrastTitleText = $null
$script:TextContrastDescText = $null
$script:TextContrastValueText = $null
$script:TextContrastSlider = $null
$script:SettingsTitleText = $null
$script:StartupCheckBox = $null
$script:StartupHintText = $null
$script:LanguageTitleText = $null
$script:LanguageHintText = $null
$script:LanguageCombo = $null
$script:LanguageZhItem = $null
$script:LanguageEnItem = $null
$script:HotkeysText = $null
$script:ToggleButton = $null
$script:HideButton = $null
$script:ExitButton = $null
$script:TrayIcon = $null
$script:MenuOpen = $null
$script:MenuToggle = $null
$script:MenuExit = $null
$script:NoiseBrush = $null
$script:OverlayHwndSource = $null
$script:OverlayHook = $null
$script:DisplaySettingsHandler = $null
$script:MagnificationInitialized = $false
$script:UiUpdating = $false
$script:ShuttingDown = $false

function Clamp-Int {
    param(
        [Parameter(Mandatory)]
        [int]$Value,
        [Parameter(Mandatory)]
        [int]$Min,
        [Parameter(Mandatory)]
        [int]$Max
    )

    if ($Value -lt $Min) {
        return $Min
    }

    if ($Value -gt $Max) {
        return $Max
    }

    return $Value
}

function Normalize-Language {
    param(
        [string]$Language
    )

    if ($Language -eq 'en-US') {
        return 'en-US'
    }

    return 'zh-CN'
}

function Decode-Utf8Base64 {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
}

$script:TextCatalog = @{
    'en-US' = @{
        HeroSubtitle  = 'Paper-like eye-care filter that softens white-heavy screens'
        HeroBadge     = 'Local only'
        StatusOn      = 'Status: On | Paper {0}% | Texture {1}% | Highlight {2}% | Keep {3}% | Text {4}%'
        StatusIdle    = 'Status: On | Paper 0% | Highlight 0%'
        StatusOff     = 'Status: Off | Last paper {0}%'
        PaperTitle    = 'Paper feel'
        PaperDesc     = 'Warm paper tint for long reading sessions.'
        TextureTitle  = 'Texture intensity'
        TextureDesc   = 'Dense paper noise with a few uneven speckles, fading in smoothly at low paper levels.'
        WhiteCapTitle = 'Highlight compression'
        WhiteCapDesc  = 'Softly compresses bright whites; color retention is controlled by a separate slider.'
        ColorKeepTitle = 'Color retention'
        ColorKeepDesc  = 'Separately controls how much nearby color detail is preserved during highlight compression.'
        TextContrastTitle = 'Text contrast'
        TextContrastDesc  = 'Improves separation between dark text and light backgrounds for reading pages and documents.'
        SettingsTitle = 'Preferences'
        StartupTitle  = 'Start with Windows'
        StartupDesc   = 'Launch PaperEye in the tray after you sign in.'
        LanguageTitle = 'Language'
        LanguageDesc  = 'Applies immediately and is saved to settings.'
        ToggleOn      = 'Pause effect'
        ToggleOff     = 'Enable effect'
        Hide          = 'Hide to tray'
        Exit          = 'Exit app'
        Hotkeys       = 'Hotkeys: Ctrl+Alt+P toggles the effect. Ctrl+Alt+Up/Down adjust paper feel by 1%. Right click the tray icon to reopen the panel.'
        MenuOpen      = 'Open panel'
        MenuToggle    = 'Toggle effect'
        MenuExit      = 'Exit app'
        LanguageZh    = 'Chinese'
        LanguageEn    = 'English'
    }
    'zh-CN' = @{
        HeroSubtitle  = (Decode-Utf8Base64 '57G757q45oqk55y85ruk6ZWc77yM6ZmN5L2O5bGP5bmV55m95YWJ5Yi65r+A')
        HeroBadge     = (Decode-Utf8Base64 '5pys5Zyw6L+Q6KGM')
        StatusOn      = (Decode-Utf8Base64 '54q25oCB77ya5bey5byA5ZCvIHwg57q45oSfIHswfSUgfCDnurnnkIYgezF9JSB8IOmrmOWFiSB7Mn0lIHwg5L+d55WZIHszfSUgfCDmloflrZcgezR9JQ==')
        StatusIdle    = (Decode-Utf8Base64 '54q25oCB77ya5bey5byA5ZCvIHwg57q45oSfIDAlIHwg6auY5YWJIDAl')
        StatusOff     = (Decode-Utf8Base64 '54q25oCB77ya5bey5YWz6ZetIHwg5LiK5qyh57q45oSfIHswfSU=')
        PaperTitle    = (Decode-Utf8Base64 '57q45oSf5by65bqm')
        PaperDesc     = (Decode-Utf8Base64 '5o6n5Yi25pqW6Imy57q45byg5bqV6Imy77yM6YCC5ZCI6ZW/5pe26Ze06ZiF6K+744CC')
        TextureTitle  = (Decode-Utf8Base64 '57q555CG5by65bqm')
        TextureDesc   = (Decode-Utf8Base64 '5o6n5Yi257uG5a+G57q46Z2i5Zmq5aOw5ZKM5bCR6YeP5LiN5Z2H5YyA5Zmq54K577yM5L2O57q45oSf5pe25Lya5bmz5ruR5reh5YWl44CC')
        WhiteCapTitle = (Decode-Utf8Base64 '6auY5YWJ5Y6L57yp')
        WhiteCapDesc  = (Decode-Utf8Base64 '5p+U5ZKM5Y6L57yp6auY5Lqu55m96Imy77yb5ZGo5Zu06aKc6Imy5L+d55WZ55Sx5Y2V54us5ruR5p2h5o6n5Yi244CC')
        ColorKeepTitle = (Decode-Utf8Base64 '6aKc6Imy5L+d55WZ')
        ColorKeepDesc  = (Decode-Utf8Base64 '5Y2V54us5o6n5Yi26auY5YWJ5Y6L57yp5pe25ZGo5Zu06aKc6Imy5bGC5qyh55qE5L+d55WZ56iL5bqm44CC')
        TextContrastTitle = (Decode-Utf8Base64 '5paH5a2X5a+55q+U')
        TextContrastDesc  = (Decode-Utf8Base64 '5o+Q5Y2H5rex6Imy5paH5a2X5ZKM5rWF6Imy6IOM5pmv55qE5Yy65YiG5bqm77yM6YCC5ZCI6ZiF6K+7572R6aG15ZKM5paH5qGj44CC')
        SettingsTitle = (Decode-Utf8Base64 '5YGP5aW96K6+572u')
        StartupTitle  = (Decode-Utf8Base64 '5byA5py66Ieq5ZCv5Yqo')
        StartupDesc   = (Decode-Utf8Base64 '55m75b2VIFdpbmRvd3Mg5ZCO6Ieq5Yqo5Zyo5omY55uY6L+Q6KGM44CC')
        LanguageTitle = (Decode-Utf8Base64 '55WM6Z2i6K+t6KiA')
        LanguageDesc  = (Decode-Utf8Base64 '5YiH5o2i5ZCO56uL5Y2z55Sf5pWI77yM5bm25YaZ5YWl6YWN572u44CC')
        ToggleOn      = (Decode-Utf8Base64 '5pqC5YGc5pWI5p6c')
        ToggleOff     = (Decode-Utf8Base64 '5byA5ZCv5pWI5p6c')
        Hide          = (Decode-Utf8Base64 '5pyA5bCP5YyW5Yiw5omY55uY')
        Exit          = (Decode-Utf8Base64 '6YCA5Ye65bqU55So')
        Hotkeys       = (Decode-Utf8Base64 '5b+r5o236ZSu77yaQ3RybCtBbHQrUCDlvIDlhbPmlYjmnpzvvIxDdHJsK0FsdCtVcC9Eb3duIOS7pSAxJSDosIPmlbTnurjmhJ/jgILlj7PplK7miZjnm5jlm77moIflj6/ph43mlrDmiZPlvIDpnaLmnb/jgII=')
        MenuOpen      = (Decode-Utf8Base64 '5omT5byA6Z2i5p2/')
        MenuToggle    = (Decode-Utf8Base64 '5byA5YWz5pWI5p6c')
        MenuExit      = (Decode-Utf8Base64 '6YCA5Ye65bqU55So')
        LanguageZh    = (Decode-Utf8Base64 '5Lit5paH')
        LanguageEn    = (Decode-Utf8Base64 'RW5nbGlzaA==')
    }
}

function Get-Text {
    param(
        [Parameter(Mandatory)]
        [string]$Key
    )

    $language = 'zh-CN'
    if ($script:State) {
        $language = Normalize-Language -Language $script:State.Language
    }

    if ($script:TextCatalog.ContainsKey($language) -and $script:TextCatalog[$language].ContainsKey($Key)) {
        return $script:TextCatalog[$language][$Key]
    }

    if ($script:TextCatalog['en-US'].ContainsKey($Key)) {
        return $script:TextCatalog['en-US'][$Key]
    }

    return $Key
}

function Format-Text {
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        [Parameter(Mandatory)]
        [object[]]$Args
    )

    return [string]::Format((Get-Text -Key $Key), $Args)
}

function Get-ObjectPropertyValue {
    param(
        [Parameter(Mandatory)]
        [object]$Object,
        [Parameter(Mandatory)]
        [string]$Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function New-DefaultState {
    [pscustomobject]@{
        Enabled          = $true
        Intensity        = 35
        LastIntensity    = 35
        TextureIntensity = 30
        WhiteCap         = 10
        ColorKeep        = 70
        TextContrast     = 0
        StartOnBoot      = $false
        Language         = 'zh-CN'
    }
}

function Load-State {
    $state = New-DefaultState

    if (-not (Test-Path -LiteralPath $script:ConfigPath)) {
        return $state
    }

    try {
        $raw = Get-Content -LiteralPath $script:ConfigPath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $state
        }

        $loaded = $raw | ConvertFrom-Json

        $loadedValue = Get-ObjectPropertyValue -Object $loaded -Name 'Enabled'
        if ($null -ne $loadedValue) {
            $state.Enabled = [bool]$loadedValue
        }

        $loadedValue = Get-ObjectPropertyValue -Object $loaded -Name 'Intensity'
        if ($null -ne $loadedValue) {
            $state.Intensity = Clamp-Int -Value ([int]$loadedValue) -Min 0 -Max 100
        }

        $loadedValue = Get-ObjectPropertyValue -Object $loaded -Name 'LastIntensity'
        if ($null -ne $loadedValue) {
            $state.LastIntensity = Clamp-Int -Value ([int]$loadedValue) -Min 1 -Max 100
        }

        $loadedValue = Get-ObjectPropertyValue -Object $loaded -Name 'TextureIntensity'
        if ($null -ne $loadedValue) {
            $state.TextureIntensity = Clamp-Int -Value ([int]$loadedValue) -Min 0 -Max 100
        }

        $loadedValue = Get-ObjectPropertyValue -Object $loaded -Name 'WhiteCap'
        if ($null -ne $loadedValue) {
            $state.WhiteCap = Clamp-Int -Value ([int]$loadedValue) -Min 0 -Max 60
        }

        $loadedValue = Get-ObjectPropertyValue -Object $loaded -Name 'ColorKeep'
        if ($null -ne $loadedValue) {
            $state.ColorKeep = Clamp-Int -Value ([int]$loadedValue) -Min 0 -Max 100
        }

        $loadedValue = Get-ObjectPropertyValue -Object $loaded -Name 'TextContrast'
        if ($null -ne $loadedValue) {
            $state.TextContrast = Clamp-Int -Value ([int]$loadedValue) -Min 0 -Max 100
        }

        $loadedValue = Get-ObjectPropertyValue -Object $loaded -Name 'StartOnBoot'
        if ($null -ne $loadedValue) {
            $state.StartOnBoot = [bool]$loadedValue
        }

        $loadedValue = Get-ObjectPropertyValue -Object $loaded -Name 'Language'
        if ($null -ne $loadedValue) {
            $state.Language = Normalize-Language -Language ([string]$loadedValue)
        }

        if ($state.Intensity -gt 0) {
            $state.LastIntensity = $state.Intensity
        }
        elseif ($state.LastIntensity -le 0) {
            $state.LastIntensity = 35
        }
    }
    catch {
    }

    return $state
}

function Save-State {
    try {
        $payload = [pscustomobject]@{
            Enabled          = [bool]$script:State.Enabled
            Intensity        = [int]$script:State.Intensity
            LastIntensity    = [int]$script:State.LastIntensity
            TextureIntensity = [int]$script:State.TextureIntensity
            WhiteCap         = [int]$script:State.WhiteCap
            ColorKeep        = [int]$script:State.ColorKeep
            TextContrast     = [int]$script:State.TextContrast
            StartOnBoot      = [bool]$script:State.StartOnBoot
            Language         = [string](Normalize-Language -Language $script:State.Language)
        }

        $payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:ConfigPath -Encoding UTF8
    }
    catch {
    }
}

function Get-AutoStartCommand {
    $powerShellPath = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powerShellPath)) {
        $powerShellPath = 'powershell.exe'
    }

    return '"' + $powerShellPath + '" -STA -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $script:ScriptPath + '"'
}

function Get-AutoStartEnabled {
    try {
        $property = Get-ItemProperty -Path $script:StartupRegPath -Name $script:StartupValueName -ErrorAction SilentlyContinue
        if ($null -eq $property) {
            return $false
        }

        $member = $property.PSObject.Properties[$script:StartupValueName]
        return ($null -ne $member -and -not [string]::IsNullOrWhiteSpace([string]$member.Value))
    }
    catch {
        return $false
    }
}

function Set-AutoStart {
    param(
        [Parameter(Mandatory)]
        [bool]$Enabled
    )

    try {
        if ($Enabled) {
            if (-not (Test-Path -LiteralPath $script:StartupRegPath)) {
                [void](New-Item -Path $script:StartupRegPath -Force)
            }

            Set-ItemProperty -Path $script:StartupRegPath -Name $script:StartupValueName -Value (Get-AutoStartCommand)
        }
        else {
            Remove-ItemProperty -Path $script:StartupRegPath -Name $script:StartupValueName -ErrorAction SilentlyContinue
        }

        return $true
    }
    catch {
        return $false
    }
}

function Sync-AutoStartState {
    if (-not $script:State) {
        return
    }

    if ($script:State.StartOnBoot) {
        [void](Set-AutoStart -Enabled $true)
    }

    $script:State.StartOnBoot = Get-AutoStartEnabled
}

function New-NoiseBrush {
    param(
        [int]$PixelSize = 512,
        [int]$Contrast = 34,
        [double]$SpeckleRate = 0.018
    )

    $bytes = New-Object byte[] ($PixelSize * $PixelSize * 4)
    $random = [System.Random]::new()

    for ($y = 0; $y -lt $PixelSize; $y++) {
        $fiber = [Math]::Sin($y / 11.0) * 2.0

        for ($x = 0; $x -lt $PixelSize; $x++) {
            $index = (($y * $PixelSize) + $x) * 4
            $fine = ($random.NextDouble() + $random.NextDouble() + $random.NextDouble() - 1.5) * $Contrast
            $speckleRoll = $random.NextDouble()
            if ($speckleRoll -lt $SpeckleRate) {
                if ($random.NextDouble() -lt 0.68) {
                    $direction = -1.0
                }
                else {
                    $direction = 1.0
                }

                $speckle = $direction * ($Contrast * (1.8 + ($random.NextDouble() * 2.4)))
            }
            elseif ($speckleRoll -lt 0.08) {
                $speckle = ($random.NextDouble() - 0.5) * $Contrast * 1.4
            }
            else {
                $speckle = 0.0
            }

            $value = [int][Math]::Round(132 + $fiber + $fine + $speckle)

            if ($value -lt 0) {
                $value = 0
            }

            if ($value -gt 255) {
                $value = 255
            }

            if ($value -lt 132) {
                $red = 72
                $green = 69
                $blue = 62
                $alpha = 132 - $value
            }
            else {
                $red = 255
                $green = 252
                $blue = 240
                $alpha = $value - 132
            }

            $bytes[$index + 0] = [byte]$blue
            $bytes[$index + 1] = [byte]$green
            $bytes[$index + 2] = [byte]$red
            $bytes[$index + 3] = [byte][Math]::Min(64, $alpha)
        }
    }

    $bitmap = [System.Windows.Media.Imaging.BitmapSource]::Create(
        $PixelSize,
        $PixelSize,
        96,
        96,
        [System.Windows.Media.PixelFormats]::Bgra32,
        $null,
        $bytes,
        $PixelSize * 4
    )
    $bitmap.Freeze()

    $brush = [System.Windows.Media.ImageBrush]::new($bitmap)
    $brush.TileMode = [System.Windows.Media.TileMode]::Tile
    $brush.ViewportUnits = [System.Windows.Media.BrushMappingMode]::Absolute
    $brush.Viewport = [System.Windows.Rect]::new(0, 0, $PixelSize, $PixelSize)
    $brush.Stretch = [System.Windows.Media.Stretch]::Fill
    $brush.AlignmentX = [System.Windows.Media.AlignmentX]::Center
    $brush.AlignmentY = [System.Windows.Media.AlignmentY]::Center
    $brush.Freeze()

    return $brush
}

function New-WhiteCapBrush {
    param(
        [Parameter(Mandatory)]
        [int]$Value,
        [int]$ColorKeep = 70
    )

    $normalized = [Math]::Max(0.0, [Math]::Min(1.0, $Value / 60.0))
    if ($normalized -le 0.0) {
        $brush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(0, 0, 0, 0))
        $brush.Freeze()
        return $brush
    }

    # Start from zero opacity so the first few slider steps do not pop in as a visible veil.
    $eased = [Math]::Pow($normalized, 1.55)
    $keepLevel = [Math]::Max(0.0, [Math]::Min(1.0, $ColorKeep / 100.0))
    $opacity = (0.42 - (0.12 * $keepLevel)) * $eased

    if ($opacity -gt 0.42) {
        $opacity = 0.42
    }

    $alpha = [byte]([Math]::Round(255 * $opacity))
    $red = [byte][Math]::Round(42 + (74 * $keepLevel))
    $green = [byte][Math]::Round(42 + (58 * $keepLevel))
    $blue = [byte][Math]::Round(42 + (34 * $keepLevel))
    $color = [System.Windows.Media.Color]::FromArgb($alpha, $red, $green, $blue)
    $brush = [System.Windows.Media.SolidColorBrush]::new($color)
    $brush.Freeze()

    return $brush
}

function New-MagColorEffect {
    param(
        [Parameter(Mandatory)]
        [float[]]$Values
    )

    $effect = [Win32+MAGCOLOREFFECT]::new()
    $effect.transform = New-Object float[] 25

    for ($index = 0; $index -lt 25; $index++) {
        $effect.transform[$index] = $Values[$index]
    }

    return $effect
}

function Reset-TextContrast {
    if (-not $script:MagnificationInitialized) {
        return
    }

    try {
        $identity = New-MagColorEffect -Values @(
            1, 0, 0, 0, 0,
            0, 1, 0, 0, 0,
            0, 0, 1, 0, 0,
            0, 0, 0, 1, 0,
            0, 0, 0, 0, 1
        )
        [void][Win32]::MagSetFullscreenColorEffect([ref]$identity)
    }
    catch {
    }
}

function Apply-TextContrast {
    param(
        [Parameter(Mandatory)]
        [int]$Value
    )

    $level = [Math]::Max(0.0, [Math]::Min(1.0, $Value / 100.0))

    if ($level -le 0.0) {
        Reset-TextContrast
        return
    }

    if (-not $script:MagnificationInitialized) {
        try {
            $script:MagnificationInitialized = [Win32]::MagInitialize()
        }
        catch {
            $script:MagnificationInitialized = $false
        }
    }

    if (-not $script:MagnificationInitialized) {
        return
    }

    $contrast = 1.0 + (0.34 * $level)
    $offset = (1.0 - $contrast) / 2.0

    try {
        $effect = New-MagColorEffect -Values @(
            $contrast, 0, 0, 0, 0,
            0, $contrast, 0, 0, 0,
            0, 0, $contrast, 0, 0,
            0, 0, 0, 1, 0,
            $offset, $offset, $offset, 0, 1
        )
        [void][Win32]::MagSetFullscreenColorEffect([ref]$effect)
    }
    catch {
    }
}

function Update-OverlayBounds {
    if (-not $script:OverlayWindow) {
        return
    }

    $left = [Win32]::GetSystemMetrics([Win32]::SM_XVIRTUALSCREEN)
    $top = [Win32]::GetSystemMetrics([Win32]::SM_YVIRTUALSCREEN)
    $width = [Win32]::GetSystemMetrics([Win32]::SM_CXVIRTUALSCREEN)
    $height = [Win32]::GetSystemMetrics([Win32]::SM_CYVIRTUALSCREEN)

    if ($width -le 0 -or $height -le 0) {
        return
    }

    $helper = [System.Windows.Interop.WindowInteropHelper]::new($script:OverlayWindow)
    $handle = $helper.Handle

    if ($handle -ne [IntPtr]::Zero) {
        [void][Win32]::SetWindowPos(
            $handle,
            [Win32]::HWND_TOPMOST,
            $left,
            $top,
            $width,
            $height,
            [Win32]::SWP_NOACTIVATE -bor [Win32]::SWP_SHOWWINDOW
        )
        return
    }

    $script:OverlayWindow.Left = $left
    $script:OverlayWindow.Top = $top
    $script:OverlayWindow.Width = $width
    $script:OverlayWindow.Height = $height
}

function Set-ClickThrough {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Window]$Window
    )

    $helper = [System.Windows.Interop.WindowInteropHelper]::new($Window)
    $handle = $helper.Handle

    if ($handle -eq [IntPtr]::Zero) {
        return
    }

    $current = [Win32]::GetWindowLongAuto($handle, [Win32]::GWL_EXSTYLE)
    $style = [int64]$current.ToInt64()
    $style = $style -bor [Win32]::WS_EX_TRANSPARENT -bor [Win32]::WS_EX_TOOLWINDOW -bor [Win32]::WS_EX_NOACTIVATE
    [void][Win32]::SetWindowLongAuto($handle, [Win32]::GWL_EXSTYLE, [IntPtr]::new($style))
}

function Queue-OverlayBoundsUpdate {
    if (-not $script:OverlayWindow) {
        return
    }

    [void]$script:OverlayWindow.Dispatcher.BeginInvoke(
        [Action]{
            Update-OverlayBounds
        },
        [System.Windows.Threading.DispatcherPriority]::ApplicationIdle
    )
}

function Register-OverlaySystemHooks {
    if (-not $script:OverlayWindow) {
        return
    }

    $helper = [System.Windows.Interop.WindowInteropHelper]::new($script:OverlayWindow)
    if ($helper.Handle -eq [IntPtr]::Zero) {
        return
    }

    $script:OverlayHwndSource = [System.Windows.Interop.HwndSource]::FromHwnd($helper.Handle)
    $script:OverlayHook = [System.Windows.Interop.HwndSourceHook]{
        param(
            [IntPtr]$hwnd,
            [int]$msg,
            [IntPtr]$wParam,
            [IntPtr]$lParam,
            [ref]$handled
        )

        if ($msg -eq [Win32]::WM_DPICHANGED -or
            $msg -eq [Win32]::WM_DISPLAYCHANGE -or
            $msg -eq [Win32]::WM_SETTINGCHANGE) {
            Queue-OverlayBoundsUpdate
        }

        return [IntPtr]::Zero
    }

    if ($script:OverlayHwndSource) {
        $script:OverlayHwndSource.AddHook($script:OverlayHook)
    }

    $script:DisplaySettingsHandler = [System.EventHandler]{
        param($sender, $eventArgs)

        Queue-OverlayBoundsUpdate
    }
    [Microsoft.Win32.SystemEvents]::add_DisplaySettingsChanged($script:DisplaySettingsHandler)
}

function Unregister-OverlaySystemHooks {
    try {
        if ($script:OverlayHwndSource -and $script:OverlayHook) {
            $script:OverlayHwndSource.RemoveHook($script:OverlayHook)
        }
    }
    catch {
    }

    try {
        if ($script:DisplaySettingsHandler) {
            [Microsoft.Win32.SystemEvents]::remove_DisplaySettingsChanged($script:DisplaySettingsHandler)
        }
    }
    catch {
    }

    $script:OverlayHwndSource = $null
    $script:OverlayHook = $null
    $script:DisplaySettingsHandler = $null
}

function Register-HotKeys {
    if (-not $script:MainWindow) {
        return
    }

    $helper = [System.Windows.Interop.WindowInteropHelper]::new($script:MainWindow)
    $handle = $helper.Handle

    [void][Win32]::RegisterHotKey($handle, 1, [Win32]::MOD_CONTROL -bor [Win32]::MOD_ALT, 0x50)
    [void][Win32]::RegisterHotKey($handle, 2, [Win32]::MOD_CONTROL -bor [Win32]::MOD_ALT, 0x26)
    [void][Win32]::RegisterHotKey($handle, 3, [Win32]::MOD_CONTROL -bor [Win32]::MOD_ALT, 0x28)
}

function Unregister-HotKeys {
    if (-not $script:MainWindow) {
        return
    }

    $helper = [System.Windows.Interop.WindowInteropHelper]::new($script:MainWindow)
    $handle = $helper.Handle

    [void][Win32]::UnregisterHotKey($handle, 1)
    [void][Win32]::UnregisterHotKey($handle, 2)
    [void][Win32]::UnregisterHotKey($handle, 3)
}

function Handle-HotKeyMessage {
    param(
        [Parameter(Mandatory)]
        [IntPtr]$WParam
    )

    switch ($WParam.ToInt32()) {
        1 {
            Toggle-Effect
            return $true
        }
        2 {
            Adjust-Intensity -Delta 1
            return $true
        }
        3 {
            Adjust-Intensity -Delta -1
            return $true
        }
        default {
            return $false
        }
    }
}

function Apply-Language {
    $language = 'zh-CN'
    if ($script:State) {
        $language = Normalize-Language -Language $script:State.Language
        $script:State.Language = $language
    }

    if ($script:HeroSubtitleText) {
        $script:HeroSubtitleText.Text = Get-Text -Key 'HeroSubtitle'
    }

    if ($script:HeroBadgeText) {
        $script:HeroBadgeText.Text = Get-Text -Key 'HeroBadge'
    }

    if ($script:IntensityTitleText) {
        $script:IntensityTitleText.Text = Get-Text -Key 'PaperTitle'
    }

    if ($script:IntensityDescText) {
        $script:IntensityDescText.Text = Get-Text -Key 'PaperDesc'
    }

    if ($script:TextureTitleText) {
        $script:TextureTitleText.Text = Get-Text -Key 'TextureTitle'
    }

    if ($script:TextureDescText) {
        $script:TextureDescText.Text = Get-Text -Key 'TextureDesc'
    }

    if ($script:WhiteCapTitleText) {
        $script:WhiteCapTitleText.Text = Get-Text -Key 'WhiteCapTitle'
    }

    if ($script:WhiteCapDescText) {
        $script:WhiteCapDescText.Text = Get-Text -Key 'WhiteCapDesc'
    }

    if ($script:ColorKeepTitleText) {
        $script:ColorKeepTitleText.Text = Get-Text -Key 'ColorKeepTitle'
    }

    if ($script:ColorKeepDescText) {
        $script:ColorKeepDescText.Text = Get-Text -Key 'ColorKeepDesc'
    }

    if ($script:TextContrastTitleText) {
        $script:TextContrastTitleText.Text = Get-Text -Key 'TextContrastTitle'
    }

    if ($script:TextContrastDescText) {
        $script:TextContrastDescText.Text = Get-Text -Key 'TextContrastDesc'
    }

    if ($script:SettingsTitleText) {
        $script:SettingsTitleText.Text = Get-Text -Key 'SettingsTitle'
    }

    if ($script:StartupCheckBox) {
        $script:StartupCheckBox.Content = Get-Text -Key 'StartupTitle'
    }

    if ($script:StartupHintText) {
        $script:StartupHintText.Text = Get-Text -Key 'StartupDesc'
    }

    if ($script:LanguageTitleText) {
        $script:LanguageTitleText.Text = Get-Text -Key 'LanguageTitle'
    }

    if ($script:LanguageHintText) {
        $script:LanguageHintText.Text = Get-Text -Key 'LanguageDesc'
    }

    if ($script:LanguageZhItem) {
        $script:LanguageZhItem.Content = Get-Text -Key 'LanguageZh'
    }

    if ($script:LanguageEnItem) {
        $script:LanguageEnItem.Content = Get-Text -Key 'LanguageEn'
    }

    if ($script:LanguageCombo) {
        if ($language -eq 'en-US') {
            $targetItem = $script:LanguageEnItem
        }
        else {
            $targetItem = $script:LanguageZhItem
        }

        if ($script:LanguageCombo.SelectedItem -ne $targetItem) {
            $script:LanguageCombo.SelectedItem = $targetItem
        }
    }

    if ($script:HideButton) {
        $script:HideButton.Content = Get-Text -Key 'Hide'
    }

    if ($script:ExitButton) {
        $script:ExitButton.Content = Get-Text -Key 'Exit'
    }

    if ($script:HotkeysText) {
        $script:HotkeysText.Text = Get-Text -Key 'Hotkeys'
    }

    if ($script:MenuOpen) {
        $script:MenuOpen.Text = Get-Text -Key 'MenuOpen'
    }

    if ($script:MenuToggle) {
        $script:MenuToggle.Text = Get-Text -Key 'MenuToggle'
    }

    if ($script:MenuExit) {
        $script:MenuExit.Text = Get-Text -Key 'MenuExit'
    }
}

function Update-TrayText {
    if (-not $script:TrayIcon -or -not $script:State) {
        return
    }

    $paperOn = [bool]($script:State.Enabled -and $script:State.Intensity -gt 0)
    $capOn = [bool]($script:State.Enabled -and $script:State.WhiteCap -gt 0)

    if ($paperOn -or $capOn) {
        $mode = 'On'
    }
    elseif ($script:State.Enabled) {
        $mode = 'On 0%'
    }
    else {
        $mode = 'Off'
    }

    $script:TrayIcon.Text = "PaperEye $mode P$($script:State.Intensity)% T$($script:State.TextureIntensity)% H$($script:State.WhiteCap)% C$($script:State.TextContrast)%"
}

function Update-VisualState {
    $script:UiUpdating = $true

    try {
        if (-not $script:State) {
            return
        }

        $intensity = Clamp-Int -Value ([int]$script:State.Intensity) -Min 0 -Max 100
        $script:State.Intensity = $intensity
        $textureIntensity = Clamp-Int -Value ([int]$script:State.TextureIntensity) -Min 0 -Max 100
        $whiteCap = Clamp-Int -Value ([int]$script:State.WhiteCap) -Min 0 -Max 60
        $colorKeep = Clamp-Int -Value ([int]$script:State.ColorKeep) -Min 0 -Max 100
        $textContrast = Clamp-Int -Value ([int]$script:State.TextContrast) -Min 0 -Max 100
        $script:State.TextureIntensity = $textureIntensity
        $script:State.WhiteCap = $whiteCap
        $script:State.ColorKeep = $colorKeep
        $script:State.TextContrast = $textContrast

        if ($intensity -gt 0) {
            $script:State.LastIntensity = $intensity
        }

        $level = $intensity / 100.0
        if ($level -gt 0.0) {
            $paperRamp = [Math]::Pow($level, 1.45)
        }
        else {
            $paperRamp = 0.0
        }

        $textureLevel = $textureIntensity / 100.0
        if ($level -gt 0.0) {
            $textureRamp = [Math]::Pow([Math]::Min(1.0, $level / 0.18), 1.65)
        }
        else {
            $textureRamp = 0.0
        }

        $paperActive = [bool]($script:State.Enabled -and $intensity -gt 0)
        $capActive = [bool]($script:State.Enabled -and $whiteCap -gt 0)
        $textContrastActive = [bool]($script:State.Enabled -and $textContrast -gt 0)
        $overlayActive = [bool]($paperActive -or $capActive)
        $active = [bool]($overlayActive -or $textContrastActive)
        $uniformMode = $level -lt 0.22
        if ($paperActive) {
            $paperBaseAlpha = [byte]([Math]::Round(1 + (51 * $paperRamp)))
        }
        else {
            $paperBaseAlpha = [byte]0
        }

        Apply-Language

        if ($script:MainWindow) {
            if ($paperActive -or $capActive) {
                $script:MainWindow.Title = "PaperEye P$intensity% H$whiteCap%"
            }
            elseif ($script:State.Enabled) {
                $script:MainWindow.Title = 'PaperEye 0%'
            }
            else {
                $script:MainWindow.Title = 'PaperEye Off'
            }
        }

        if ($script:StatusText) {
            if ($active) {
                $script:StatusText.Text = Format-Text -Key 'StatusOn' -Args @($intensity, $textureIntensity, $whiteCap, $colorKeep, $textContrast)
            }
            elseif ($script:State.Enabled) {
                $script:StatusText.Text = Get-Text -Key 'StatusIdle'
            }
            else {
                $script:StatusText.Text = Format-Text -Key 'StatusOff' -Args @($script:State.LastIntensity)
            }
        }

        if ($script:IntensityValueText) {
            $script:IntensityValueText.Text = "$intensity%"
        }

        if ($script:TextureValueText) {
            $script:TextureValueText.Text = "$textureIntensity%"
        }

        if ($script:WhiteCapValueText) {
            $script:WhiteCapValueText.Text = "$whiteCap%"
        }

        if ($script:ColorKeepValueText) {
            $script:ColorKeepValueText.Text = "$colorKeep%"
        }

        if ($script:TextContrastValueText) {
            $script:TextContrastValueText.Text = "$textContrast%"
        }

        if ($script:ToggleButton) {
            if ($script:State.Enabled) {
                $script:ToggleButton.Content = Get-Text -Key 'ToggleOn'
            }
            else {
                $script:ToggleButton.Content = Get-Text -Key 'ToggleOff'
            }
        }

        if ($script:IntensitySlider) {
            $sliderValue = [int][Math]::Round($script:IntensitySlider.Value)
            if ($sliderValue -ne $intensity) {
                $script:IntensitySlider.Value = $intensity
            }
        }

        if ($script:TextureSlider) {
            $sliderValue = [int][Math]::Round($script:TextureSlider.Value)
            if ($sliderValue -ne $textureIntensity) {
                $script:TextureSlider.Value = $textureIntensity
            }
        }

        if ($script:WhiteCapSlider) {
            $sliderValue = [int][Math]::Round($script:WhiteCapSlider.Value)
            if ($sliderValue -ne $whiteCap) {
                $script:WhiteCapSlider.Value = $whiteCap
            }
        }

        if ($script:ColorKeepSlider) {
            $sliderValue = [int][Math]::Round($script:ColorKeepSlider.Value)
            if ($sliderValue -ne $colorKeep) {
                $script:ColorKeepSlider.Value = $colorKeep
            }
        }

        if ($script:TextContrastSlider) {
            $sliderValue = [int][Math]::Round($script:TextContrastSlider.Value)
            if ($sliderValue -ne $textContrast) {
                $script:TextContrastSlider.Value = $textContrast
            }
        }

        if ($textContrastActive) {
            Apply-TextContrast -Value $textContrast
        }
        else {
            Reset-TextContrast
        }

        if ($script:StartupCheckBox) {
            $checked = [bool]$script:StartupCheckBox.IsChecked
            if ($checked -ne [bool]$script:State.StartOnBoot) {
                $script:StartupCheckBox.IsChecked = [bool]$script:State.StartOnBoot
            }
        }

        if ($script:OverlayWindow) {
            if ($overlayActive) {
                Update-OverlayBounds

                if (-not $script:OverlayWindow.IsVisible) {
                    $script:OverlayWindow.Show()
                }

                if ($paperActive) {
                    if ($uniformMode) {
                        $flatColor = [System.Windows.Media.Color]::FromArgb($paperBaseAlpha, 250, 246, 238)
                        $flatBrush = [System.Windows.Media.SolidColorBrush]::new($flatColor)
                        $flatBrush.Freeze()

                        if ($script:OverlayTintLayer) {
                            $script:OverlayTintLayer.Fill = $flatBrush
                        }

                        if ($script:OverlayNoiseLayer) {
                            $script:OverlayNoiseLayer.Fill = $script:NoiseBrush
                            $script:OverlayNoiseLayer.Opacity = 0.22 * $textureLevel * $textureRamp
                        }
                    }
                    else {
                        $topAlpha = [byte]([Math]::Round($paperBaseAlpha + 2))
                        $bottomAlpha = [byte]([Math]::Round($paperBaseAlpha + 6))

                        if ($topAlpha -gt 90) {
                            $topAlpha = 90
                        }

                        if ($bottomAlpha -gt 110) {
                            $bottomAlpha = 110
                        }

                        $topColor = [System.Windows.Media.Color]::FromArgb($topAlpha, 252, 248, 240)
                        $bottomColor = [System.Windows.Media.Color]::FromArgb($bottomAlpha, 242, 232, 220)

                        $gradient = [System.Windows.Media.LinearGradientBrush]::new()
                        $gradient.StartPoint = [System.Windows.Point]::new(0, 0)
                        $gradient.EndPoint = [System.Windows.Point]::new(0, 1)
                        [void]$gradient.GradientStops.Add([System.Windows.Media.GradientStop]::new($topColor, 0.0))
                        [void]$gradient.GradientStops.Add([System.Windows.Media.GradientStop]::new($bottomColor, 1.0))
                        $gradient.Freeze()

                        if ($script:OverlayTintLayer) {
                            $script:OverlayTintLayer.Fill = $gradient
                        }

                        if ($script:OverlayNoiseLayer) {
                            $script:OverlayNoiseLayer.Fill = $script:NoiseBrush
                            $grainLevel = [Math]::Max(0.0, [Math]::Min(1.0, ($level - 0.22) / 0.78))
                            $script:OverlayNoiseLayer.Opacity = (0.18 + (0.18 * [Math]::Pow($grainLevel, 1.05))) * $textureLevel
                        }
                    }
                }
                else {
                    $clearBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Colors]::Transparent)
                    $clearBrush.Freeze()

                    if ($script:OverlayTintLayer) {
                        $script:OverlayTintLayer.Fill = $clearBrush
                    }

                    if ($script:OverlayNoiseLayer) {
                        $script:OverlayNoiseLayer.Opacity = 0
                    }
                }

                if ($script:OverlayWhiteCapLayer) {
                    if ($capActive) {
                        $whiteCapBrushValue = $whiteCap
                    }
                    else {
                        $whiteCapBrushValue = 0
                    }

                    $script:OverlayWhiteCapLayer.Fill = New-WhiteCapBrush -Value $whiteCapBrushValue -ColorKeep $colorKeep
                }

                $script:OverlayWindow.Visibility = [System.Windows.Visibility]::Visible
            }
            else {
                $script:OverlayWindow.Visibility = [System.Windows.Visibility]::Hidden
            }
        }

        Update-TrayText
    }
    finally {
        $script:UiUpdating = $false
    }

    Save-State
}

function Set-Intensity {
    param(
        [Parameter(Mandatory)]
        [int]$Value
    )

    $script:State.Intensity = Clamp-Int -Value $Value -Min 0 -Max 100

    if ($script:State.Intensity -gt 0) {
        $script:State.LastIntensity = $script:State.Intensity
    }

    Update-VisualState
}

function Adjust-Intensity {
    param(
        [Parameter(Mandatory)]
        [int]$Delta
    )

    if (-not $script:State.Enabled) {
        $script:State.Enabled = $true
    }

    Set-Intensity -Value ($script:State.Intensity + $Delta)
}

function Get-RestoreIntensity {
    if ($script:State.LastIntensity -gt 0) {
        return $script:State.LastIntensity
    }

    return 35
}

function Toggle-Effect {
    $script:State.Enabled = -not [bool]$script:State.Enabled

    if ($script:State.Enabled -and $script:State.Intensity -eq 0 -and $script:State.WhiteCap -eq 0) {
        $script:State.Intensity = Get-RestoreIntensity
    }

    Update-VisualState
}

function Show-ControlPanel {
    if (-not $script:MainWindow) {
        return
    }

    if (-not $script:MainWindow.IsVisible) {
        $script:MainWindow.Show()
    }

    if ($script:MainWindow.WindowState -eq [System.Windows.WindowState]::Minimized) {
        $script:MainWindow.WindowState = [System.Windows.WindowState]::Normal
    }

    $script:MainWindow.Topmost = $true
    [void]$script:MainWindow.Activate()
}

function Request-Shutdown {
    $script:ShuttingDown = $true
    Save-State

    try {
        Unregister-HotKeys
    }
    catch {
    }

    try {
        Unregister-OverlaySystemHooks
    }
    catch {
    }

    try {
        Reset-TextContrast
        if ($script:MagnificationInitialized) {
            [void][Win32]::MagUninitialize()
            $script:MagnificationInitialized = $false
        }
    }
    catch {
    }

    try {
        if ($script:TrayIcon) {
            $script:TrayIcon.Visible = $false
            $script:TrayIcon.Dispose()
            $script:TrayIcon = $null
        }
    }
    catch {
    }

    try {
        if ($script:OverlayWindow) {
            $script:OverlayWindow.Hide()
        }
    }
    catch {
    }

    if ($script:App) {
        $script:App.Shutdown()
    }
}

$script:State = Load-State
Sync-AutoStartState
$script:NoiseBrush = New-NoiseBrush -PixelSize 512 -Contrast 34 -SpeckleRate 0.018

$overlayXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PaperEye Overlay"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        Topmost="True"
        ShowActivated="False"
        ShowInTaskbar="False"
        ResizeMode="NoResize"
        Focusable="False"
        WindowStartupLocation="Manual"
        SnapsToDevicePixels="True"
        UseLayoutRounding="True">
    <Grid Background="Transparent" IsHitTestVisible="False">
        <Rectangle x:Name="OverlayTintLayer" Fill="#10FCF8F0" />
        <Rectangle x:Name="OverlayNoiseLayer" Opacity="0.02" />
        <Rectangle x:Name="OverlayWhiteCapLayer" Fill="#00000000" />
    </Grid>
</Window>
'@

$mainXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PaperEye"
        Width="560"
        Height="720"
        MinWidth="540"
        MinHeight="620"
        WindowStyle="ToolWindow"
        ResizeMode="CanResizeWithGrip"
        ShowInTaskbar="False"
        Topmost="True"
        Background="#FFF1E9DC"
        FontFamily="Microsoft YaHei UI, Segoe UI"
        FontSize="13"
        TextOptions.TextFormattingMode="Ideal"
        SnapsToDevicePixels="True"
        UseLayoutRounding="True"
        WindowStartupLocation="CenterScreen">
    <Window.Resources>
        <Style x:Key="CardBorder" TargetType="{x:Type Border}">
            <Setter Property="Background" Value="#FFFFFBF4" />
            <Setter Property="BorderBrush" Value="#E7D7C1" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="CornerRadius" Value="18" />
            <Setter Property="Padding" Value="16" />
            <Setter Property="Margin" Value="0,0,0,14" />
        </Style>
        <Style TargetType="{x:Type Button}">
            <Setter Property="Height" Value="42" />
            <Setter Property="Padding" Value="12,8" />
            <Setter Property="BorderThickness" Value="0" />
            <Setter Property="FontWeight" Value="SemiBold" />
            <Setter Property="Cursor" Value="Hand" />
        </Style>
        <Style TargetType="{x:Type Slider}">
            <Setter Property="Height" Value="30" />
        </Style>
    </Window.Resources>

    <Grid Background="#FFF1E9DC">
        <Border Margin="14"
                Background="#FFFFFAF2"
                BorderBrush="#D9C7AC"
                BorderThickness="1"
                CornerRadius="26">
            <Border.Effect>
                <DropShadowEffect BlurRadius="28" ShadowDepth="8" Opacity="0.18" Color="#5C3D24" />
            </Border.Effect>

            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto" />
                    <RowDefinition Height="*" />
                </Grid.RowDefinitions>

                <Border Grid.Row="0"
                        Height="164"
                        CornerRadius="26,26,20,20"
                        ClipToBounds="True">
                    <Border.Background>
                        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                            <GradientStop Color="#FF375B4C" Offset="0" />
                            <GradientStop Color="#FFB98457" Offset="1" />
                        </LinearGradientBrush>
                    </Border.Background>

                    <Grid Margin="24">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*" />
                            <ColumnDefinition Width="Auto" />
                        </Grid.ColumnDefinitions>

                        <StackPanel Grid.Column="0" VerticalAlignment="Center">
                            <DockPanel LastChildFill="False">
                                <TextBlock Text="PaperEye"
                                           Foreground="#FFFFF7EA"
                                           FontSize="30"
                                           FontWeight="Bold" />
                                <Border DockPanel.Dock="Right"
                                        Margin="14,3,0,0"
                                        Background="#33FFFFFF"
                                        BorderBrush="#55FFFFFF"
                                        BorderThickness="1"
                                        CornerRadius="14"
                                        Padding="10,4">
                                    <TextBlock x:Name="HeroBadgeText"
                                               Text="Local only"
                                               Foreground="#FFFFF7EA"
                                               FontSize="12"
                                               FontWeight="SemiBold" />
                                </Border>
                            </DockPanel>

                            <TextBlock x:Name="HeroSubtitleText"
                                       Margin="0,8,0,0"
                                       Text="Paper-like eye-care filter"
                                       Foreground="#F4FFEEDB"
                                       FontSize="14" />

                            <Border Margin="0,18,0,0"
                                    Background="#22FFFFFF"
                                    BorderBrush="#40FFFFFF"
                                    BorderThickness="1"
                                    CornerRadius="15"
                                    Padding="12,7"
                                    HorizontalAlignment="Left">
                                <TextBlock x:Name="StatusText"
                                           Text="Status: On"
                                           Foreground="#FFFFF7EA"
                                           FontSize="13"
                                           FontWeight="SemiBold" />
                            </Border>
                        </StackPanel>

                        <Grid Grid.Column="1"
                              Width="116"
                              Height="116"
                              Margin="20,0,0,0"
                              VerticalAlignment="Center"
                              Opacity="0.55">
                            <Ellipse Fill="#33FFFFFF" />
                            <Ellipse Width="74" Height="74" Fill="#33FFF7D7" HorizontalAlignment="Center" VerticalAlignment="Center" />
                            <Ellipse Width="34" Height="34" Fill="#55FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center" />
                        </Grid>
                    </Grid>
                </Border>

                <ScrollViewer Grid.Row="1"
                              VerticalScrollBarVisibility="Auto"
                              HorizontalScrollBarVisibility="Disabled">
                    <StackPanel Margin="22">
                        <Border Style="{StaticResource CardBorder}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto" />
                                    <RowDefinition Height="Auto" />
                                </Grid.RowDefinitions>

                                <Grid Grid.Row="0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*" />
                                        <ColumnDefinition Width="Auto" />
                                    </Grid.ColumnDefinitions>

                                    <StackPanel Grid.Column="0">
                                        <TextBlock x:Name="IntensityTitleText"
                                                   Text="Paper feel"
                                                   Foreground="#2E261D"
                                                   FontSize="15"
                                                   FontWeight="SemiBold" />
                                        <TextBlock x:Name="IntensityDescText"
                                                   Margin="0,4,18,0"
                                                   Text="Warm paper tint for long reading sessions."
                                                   Foreground="#8F775D"
                                                   TextWrapping="Wrap" />
                                    </StackPanel>

                                    <Border Grid.Column="1"
                                            Background="#FFF1E2CB"
                                            CornerRadius="13"
                                            Padding="12,6"
                                            VerticalAlignment="Top">
                                        <TextBlock x:Name="IntensityValueText"
                                                   Text="35%"
                                                   Foreground="#6A4827"
                                                   FontWeight="Bold" />
                                    </Border>
                                </Grid>

                                <Slider x:Name="IntensitySlider"
                                        Grid.Row="1"
                                        Margin="0,14,0,0"
                                        Minimum="0"
                                        Maximum="100"
                                        TickFrequency="1"
                                        IsSnapToTickEnabled="True"
                                        SmallChange="1"
                                        LargeChange="5"
                                        Value="35" />
                            </Grid>
                        </Border>

                        <Border Style="{StaticResource CardBorder}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto" />
                                    <RowDefinition Height="Auto" />
                                </Grid.RowDefinitions>

                                <Grid Grid.Row="0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*" />
                                        <ColumnDefinition Width="Auto" />
                                    </Grid.ColumnDefinitions>

                                    <StackPanel Grid.Column="0">
                                        <TextBlock x:Name="TextureTitleText"
                                                   Text="Texture intensity"
                                                   Foreground="#2E261D"
                                                   FontSize="15"
                                                   FontWeight="SemiBold" />
                                        <TextBlock x:Name="TextureDescText"
                                                   Margin="0,4,18,0"
                                                   Text="Dense paper noise with a few uneven speckles, fading in smoothly at low paper levels."
                                                   Foreground="#8F775D"
                                                   TextWrapping="Wrap" />
                                    </StackPanel>

                                    <Border Grid.Column="1"
                                            Background="#FFEDE5D7"
                                            CornerRadius="13"
                                            Padding="12,6"
                                            VerticalAlignment="Top">
                                        <TextBlock x:Name="TextureValueText"
                                                   Text="30%"
                                                   Foreground="#6A4827"
                                                   FontWeight="Bold" />
                                    </Border>
                                </Grid>

                                <Slider x:Name="TextureSlider"
                                        Grid.Row="1"
                                        Margin="0,14,0,0"
                                        Minimum="0"
                                        Maximum="100"
                                        TickFrequency="1"
                                        IsSnapToTickEnabled="True"
                                        SmallChange="1"
                                        LargeChange="5"
                                        Value="30" />
                            </Grid>
                        </Border>

                        <Border Style="{StaticResource CardBorder}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto" />
                                    <RowDefinition Height="Auto" />
                                </Grid.RowDefinitions>

                                <Grid Grid.Row="0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*" />
                                        <ColumnDefinition Width="Auto" />
                                    </Grid.ColumnDefinitions>

                                    <StackPanel Grid.Column="0">
                                        <TextBlock x:Name="WhiteCapTitleText"
                                                   Text="Highlight compression"
                                                   Foreground="#2E261D"
                                                   FontSize="15"
                                                   FontWeight="SemiBold" />
                                        <TextBlock x:Name="WhiteCapDescText"
                                                   Margin="0,4,18,0"
                                                   Text="Softly compresses bright whites; color retention is controlled by a separate slider."
                                                   Foreground="#8F775D"
                                                   TextWrapping="Wrap" />
                                    </StackPanel>

                                    <Border Grid.Column="1"
                                            Background="#FFE8DED0"
                                            CornerRadius="13"
                                            Padding="12,6"
                                            VerticalAlignment="Top">
                                        <TextBlock x:Name="WhiteCapValueText"
                                                   Text="10%"
                                                   Foreground="#6A4827"
                                                   FontWeight="Bold" />
                                    </Border>
                                </Grid>

                                <Slider x:Name="WhiteCapSlider"
                                        Grid.Row="1"
                                        Margin="0,14,0,0"
                                        Minimum="0"
                                        Maximum="60"
                                        TickFrequency="1"
                                        IsSnapToTickEnabled="True"
                                        SmallChange="1"
                                        LargeChange="5"
                                        Value="10" />
                            </Grid>
                        </Border>

                        <Border Style="{StaticResource CardBorder}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto" />
                                    <RowDefinition Height="Auto" />
                                </Grid.RowDefinitions>

                                <Grid Grid.Row="0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*" />
                                        <ColumnDefinition Width="Auto" />
                                    </Grid.ColumnDefinitions>

                                    <StackPanel Grid.Column="0">
                                        <TextBlock x:Name="ColorKeepTitleText"
                                                   Text="Color retention"
                                                   Foreground="#2E261D"
                                                   FontSize="15"
                                                   FontWeight="SemiBold" />
                                        <TextBlock x:Name="ColorKeepDescText"
                                                   Margin="0,4,18,0"
                                                   Text="Separately controls how much nearby color detail is preserved during highlight compression."
                                                   Foreground="#8F775D"
                                                   TextWrapping="Wrap" />
                                    </StackPanel>

                                    <Border Grid.Column="1"
                                            Background="#FFE8DED0"
                                            CornerRadius="13"
                                            Padding="12,6"
                                            VerticalAlignment="Top">
                                        <TextBlock x:Name="ColorKeepValueText"
                                                   Text="70%"
                                                   Foreground="#6A4827"
                                                   FontWeight="Bold" />
                                    </Border>
                                </Grid>

                                <Slider x:Name="ColorKeepSlider"
                                        Grid.Row="1"
                                        Margin="0,14,0,0"
                                        Minimum="0"
                                        Maximum="100"
                                        TickFrequency="1"
                                        IsSnapToTickEnabled="True"
                                        SmallChange="1"
                                        LargeChange="5"
                                        Value="70" />
                            </Grid>
                        </Border>

                        <Border Style="{StaticResource CardBorder}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto" />
                                    <RowDefinition Height="Auto" />
                                </Grid.RowDefinitions>

                                <Grid Grid.Row="0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*" />
                                        <ColumnDefinition Width="Auto" />
                                    </Grid.ColumnDefinitions>

                                    <StackPanel Grid.Column="0">
                                        <TextBlock x:Name="TextContrastTitleText"
                                                   Text="Text contrast"
                                                   Foreground="#2E261D"
                                                   FontSize="15"
                                                   FontWeight="SemiBold" />
                                        <TextBlock x:Name="TextContrastDescText"
                                                   Margin="0,4,18,0"
                                                   Text="Improves separation between dark text and light backgrounds for reading pages and documents."
                                                   Foreground="#8F775D"
                                                   TextWrapping="Wrap" />
                                    </StackPanel>

                                    <Border Grid.Column="1"
                                            Background="#FFE8DED0"
                                            CornerRadius="13"
                                            Padding="12,6"
                                            VerticalAlignment="Top">
                                        <TextBlock x:Name="TextContrastValueText"
                                                   Text="0%"
                                                   Foreground="#6A4827"
                                                   FontWeight="Bold" />
                                    </Border>
                                </Grid>

                                <Slider x:Name="TextContrastSlider"
                                        Grid.Row="1"
                                        Margin="0,14,0,0"
                                        Minimum="0"
                                        Maximum="100"
                                        TickFrequency="1"
                                        IsSnapToTickEnabled="True"
                                        SmallChange="1"
                                        LargeChange="5"
                                        Value="0" />
                            </Grid>
                        </Border>

                        <Border Style="{StaticResource CardBorder}">
                            <StackPanel>
                                <TextBlock x:Name="SettingsTitleText"
                                           Text="Preferences"
                                           Foreground="#2E261D"
                                           FontSize="15"
                                           FontWeight="SemiBold" />

                                <Grid Margin="0,14,0,0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*" />
                                    </Grid.ColumnDefinitions>

                                    <StackPanel>
                                        <CheckBox x:Name="StartupCheckBox"
                                                  Content="Start with Windows"
                                                  Foreground="#2E261D"
                                                  FontWeight="SemiBold" />
                                        <TextBlock x:Name="StartupHintText"
                                                   Margin="24,4,0,0"
                                                   Text="Launch PaperEye in the tray after you sign in."
                                                   Foreground="#8F775D"
                                                   TextWrapping="Wrap" />
                                    </StackPanel>
                                </Grid>

                                <Grid Margin="0,16,0,0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*" />
                                        <ColumnDefinition Width="160" />
                                    </Grid.ColumnDefinitions>

                                    <StackPanel Grid.Column="0" Margin="0,0,18,0">
                                        <TextBlock x:Name="LanguageTitleText"
                                                   Text="Language"
                                                   Foreground="#2E261D"
                                                   FontWeight="SemiBold" />
                                        <TextBlock x:Name="LanguageHintText"
                                                   Margin="0,4,0,0"
                                                   Text="Applies immediately and is saved to settings."
                                                   Foreground="#8F775D"
                                                   TextWrapping="Wrap" />
                                    </StackPanel>

                                    <ComboBox x:Name="LanguageCombo"
                                              Grid.Column="1"
                                              Height="32"
                                              VerticalAlignment="Top"
                                              SelectedIndex="0">
                                        <ComboBoxItem x:Name="LanguageZhItem" Tag="zh-CN" Content="Chinese" />
                                        <ComboBoxItem x:Name="LanguageEnItem" Tag="en-US" Content="English" />
                                    </ComboBox>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <UniformGrid Columns="3" Margin="0,0,0,14">
                            <Button x:Name="ToggleButton"
                                    Content="Pause effect"
                                    Margin="0,0,8,0"
                                    Background="#FF365E4F"
                                    Foreground="#FFFFF8EA" />
                            <Button x:Name="HideButton"
                                    Content="Hide to tray"
                                    Margin="0,0,8,0"
                                    Background="#FFE9DCC9"
                                    Foreground="#4D3926" />
                            <Button x:Name="ExitButton"
                                    Content="Exit app"
                                    Background="#FF7C4B3A"
                                    Foreground="#FFFFF8EA" />
                        </UniformGrid>

                        <TextBlock x:Name="HotkeysText"
                                   Foreground="#9A866B"
                                   TextWrapping="Wrap"
                                   Margin="2,0,2,4"
                                   Text="Hotkeys: Ctrl+Alt+P toggles the effect. Ctrl+Alt+Up/Down adjust paper feel by 1%. Right click the tray icon to reopen the panel." />
                    </StackPanel>
                </ScrollViewer>
            </Grid>
        </Border>
    </Grid>
</Window>
'@

$overlayReader = New-Object System.Xml.XmlNodeReader ([xml]$overlayXaml)
$script:OverlayWindow = [System.Windows.Markup.XamlReader]::Load($overlayReader)
$script:OverlayTintLayer = $script:OverlayWindow.FindName('OverlayTintLayer')
$script:OverlayNoiseLayer = $script:OverlayWindow.FindName('OverlayNoiseLayer')
$script:OverlayWhiteCapLayer = $script:OverlayWindow.FindName('OverlayWhiteCapLayer')

$mainReader = New-Object System.Xml.XmlNodeReader ([xml]$mainXaml)
$script:MainWindow = [System.Windows.Markup.XamlReader]::Load($mainReader)
$script:HeroSubtitleText = $script:MainWindow.FindName('HeroSubtitleText')
$script:HeroBadgeText = $script:MainWindow.FindName('HeroBadgeText')
$script:StatusText = $script:MainWindow.FindName('StatusText')
$script:IntensityTitleText = $script:MainWindow.FindName('IntensityTitleText')
$script:IntensityDescText = $script:MainWindow.FindName('IntensityDescText')
$script:IntensityValueText = $script:MainWindow.FindName('IntensityValueText')
$script:IntensitySlider = $script:MainWindow.FindName('IntensitySlider')
$script:TextureTitleText = $script:MainWindow.FindName('TextureTitleText')
$script:TextureDescText = $script:MainWindow.FindName('TextureDescText')
$script:TextureValueText = $script:MainWindow.FindName('TextureValueText')
$script:TextureSlider = $script:MainWindow.FindName('TextureSlider')
$script:WhiteCapTitleText = $script:MainWindow.FindName('WhiteCapTitleText')
$script:WhiteCapDescText = $script:MainWindow.FindName('WhiteCapDescText')
$script:WhiteCapValueText = $script:MainWindow.FindName('WhiteCapValueText')
$script:WhiteCapSlider = $script:MainWindow.FindName('WhiteCapSlider')
$script:ColorKeepTitleText = $script:MainWindow.FindName('ColorKeepTitleText')
$script:ColorKeepDescText = $script:MainWindow.FindName('ColorKeepDescText')
$script:ColorKeepValueText = $script:MainWindow.FindName('ColorKeepValueText')
$script:ColorKeepSlider = $script:MainWindow.FindName('ColorKeepSlider')
$script:TextContrastTitleText = $script:MainWindow.FindName('TextContrastTitleText')
$script:TextContrastDescText = $script:MainWindow.FindName('TextContrastDescText')
$script:TextContrastValueText = $script:MainWindow.FindName('TextContrastValueText')
$script:TextContrastSlider = $script:MainWindow.FindName('TextContrastSlider')
$script:SettingsTitleText = $script:MainWindow.FindName('SettingsTitleText')
$script:StartupCheckBox = $script:MainWindow.FindName('StartupCheckBox')
$script:StartupHintText = $script:MainWindow.FindName('StartupHintText')
$script:LanguageTitleText = $script:MainWindow.FindName('LanguageTitleText')
$script:LanguageHintText = $script:MainWindow.FindName('LanguageHintText')
$script:LanguageCombo = $script:MainWindow.FindName('LanguageCombo')
$script:LanguageZhItem = $script:MainWindow.FindName('LanguageZhItem')
$script:LanguageEnItem = $script:MainWindow.FindName('LanguageEnItem')
$script:HotkeysText = $script:MainWindow.FindName('HotkeysText')
$script:ToggleButton = $script:MainWindow.FindName('ToggleButton')
$script:HideButton = $script:MainWindow.FindName('HideButton')
$script:ExitButton = $script:MainWindow.FindName('ExitButton')

$script:App = [System.Windows.Application]::new()
$script:App.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown

$script:OverlayWindow.Add_SourceInitialized({
    Set-ClickThrough -Window $script:OverlayWindow
    Register-OverlaySystemHooks
    Update-OverlayBounds
})

$script:MainWindow.Add_SourceInitialized({
    Register-HotKeys

    $helper = [System.Windows.Interop.WindowInteropHelper]::new($script:MainWindow)
    $script:MainHwndSource = [System.Windows.Interop.HwndSource]::FromHwnd($helper.Handle)

    $script:HotkeyHook = [System.Windows.Interop.HwndSourceHook]{
        param(
            [IntPtr]$hwnd,
            [int]$msg,
            [IntPtr]$wParam,
            [IntPtr]$lParam,
            [ref]$handled
        )

        if ($msg -eq [Win32]::WM_HOTKEY) {
            if (Handle-HotKeyMessage -WParam $wParam) {
                $handled.Value = $true
            }
        }

        return [IntPtr]::Zero
    }

    if ($script:MainHwndSource) {
        $script:MainHwndSource.AddHook($script:HotkeyHook)
    }
})

$script:MainWindow.Add_Loaded({
    Update-OverlayBounds
    Update-VisualState
})

$script:MainWindow.Add_StateChanged({
    if ($script:MainWindow.WindowState -eq [System.Windows.WindowState]::Minimized) {
        $script:MainWindow.Hide()
        $script:MainWindow.WindowState = [System.Windows.WindowState]::Normal
    }
})

$script:MainWindow.Add_Closing({
    param($sender, $eventArgs)

    if (-not $script:ShuttingDown) {
        $eventArgs.Cancel = $true
        $sender.Hide()
    }
})

$script:ToggleButton.Add_Click({
    Toggle-Effect
})

$script:HideButton.Add_Click({
    $script:MainWindow.Hide()
})

$script:ExitButton.Add_Click({
    Request-Shutdown
})

$script:StartupCheckBox.Add_Checked({
    if ($script:UiUpdating) {
        return
    }

    if (Set-AutoStart -Enabled $true) {
        $script:State.StartOnBoot = $true
    }
    else {
        $script:State.StartOnBoot = Get-AutoStartEnabled
    }

    Update-VisualState
})

$script:StartupCheckBox.Add_Unchecked({
    if ($script:UiUpdating) {
        return
    }

    if (Set-AutoStart -Enabled $false) {
        $script:State.StartOnBoot = $false
    }
    else {
        $script:State.StartOnBoot = Get-AutoStartEnabled
    }

    Update-VisualState
})

$script:LanguageCombo.Add_SelectionChanged({
    if ($script:UiUpdating) {
        return
    }

    $selected = $script:LanguageCombo.SelectedItem
    if ($selected -and $selected.Tag) {
        $script:State.Language = Normalize-Language -Language ([string]$selected.Tag)
        Update-VisualState
    }
})

$script:IntensitySlider.Add_ValueChanged({
    if ($script:UiUpdating) {
        return
    }

    $newValue = [int][Math]::Round($script:IntensitySlider.Value)
    $script:State.Intensity = Clamp-Int -Value $newValue -Min 0 -Max 100

    if ($script:State.Intensity -gt 0) {
        $script:State.LastIntensity = $script:State.Intensity
        $script:State.Enabled = $true
    }

    Update-VisualState
})

$script:TextureSlider.Add_ValueChanged({
    if ($script:UiUpdating) {
        return
    }

    $newValue = [int][Math]::Round($script:TextureSlider.Value)
    $script:State.TextureIntensity = Clamp-Int -Value $newValue -Min 0 -Max 100
    Update-VisualState
})

$script:WhiteCapSlider.Add_ValueChanged({
    if ($script:UiUpdating) {
        return
    }

    $newValue = [int][Math]::Round($script:WhiteCapSlider.Value)
    $script:State.WhiteCap = Clamp-Int -Value $newValue -Min 0 -Max 60

    if ($script:State.WhiteCap -gt 0) {
        $script:State.Enabled = $true
    }

    Update-VisualState
})

$script:ColorKeepSlider.Add_ValueChanged({
    if ($script:UiUpdating) {
        return
    }

    $newValue = [int][Math]::Round($script:ColorKeepSlider.Value)
    $script:State.ColorKeep = Clamp-Int -Value $newValue -Min 0 -Max 100
    Update-VisualState
})

$script:TextContrastSlider.Add_ValueChanged({
    if ($script:UiUpdating) {
        return
    }

    $newValue = [int][Math]::Round($script:TextContrastSlider.Value)
    $script:State.TextContrast = Clamp-Int -Value $newValue -Min 0 -Max 100
    Update-VisualState
})

$script:OverlayWindow.Add_Closed({
    if (-not $script:ShuttingDown) {
        $script:OverlayWindow = $null
    }
})

$script:TrayIcon = New-Object System.Windows.Forms.NotifyIcon
$script:TrayIcon.Icon = [System.Drawing.SystemIcons]::Application
$script:TrayIcon.Visible = $true
Update-TrayText

$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip

$script:MenuOpen = New-Object System.Windows.Forms.ToolStripMenuItem
$script:MenuOpen.Text = 'Open panel'
$script:MenuOpen.Add_Click({
    Show-ControlPanel
})
[void]$trayMenu.Items.Add($script:MenuOpen)

$script:MenuToggle = New-Object System.Windows.Forms.ToolStripMenuItem
$script:MenuToggle.Text = 'Toggle effect'
$script:MenuToggle.Add_Click({
    Toggle-Effect
})
[void]$trayMenu.Items.Add($script:MenuToggle)

$script:MenuExit = New-Object System.Windows.Forms.ToolStripMenuItem
$script:MenuExit.Text = 'Exit app'
$script:MenuExit.Add_Click({
    Request-Shutdown
})
[void]$trayMenu.Items.Add($script:MenuExit)

$script:TrayIcon.ContextMenuStrip = $trayMenu
$script:TrayIcon.Add_DoubleClick({
    Show-ControlPanel
})

Update-OverlayBounds

if (-not $script:OverlayWindow.IsVisible) {
    $script:OverlayWindow.Show()
}

if (-not $script:MainWindow.IsVisible) {
    $script:MainWindow.Show()
}

Update-VisualState
[void]$script:App.Run($script:MainWindow)
