[CmdletBinding()]
param(
    [string]$TargetRoot,
    [string]$ProjectName,
    [string]$ProjectDate = (Get-Date -Format 'yyyyMMdd'),
    [switch]$NoOpen
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplatePath = Join-Path $ScriptDirectory 'template.json'

if (-not (Test-Path -LiteralPath $TemplatePath -PathType Leaf)) {
    throw "找不到目录模板：$TemplatePath"
}

$Template = Get-Content -LiteralPath $TemplatePath -Raw -Encoding UTF8 | ConvertFrom-Json

function Test-ProjectDate {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ($Value -notmatch '^\d{8}$') {
        return $false
    }

    $parsedDate = [datetime]::MinValue
    return [datetime]::TryParseExact(
        $Value,
        'yyyyMMdd',
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None,
        [ref]$parsedDate
    )
}

function Test-ProjectName {
    param([Parameter(Mandatory = $true)][string]$Value)

    $trimmed = $Value.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return '项目名称不能为空。'
    }

    if ($trimmed.EndsWith('.') -or $trimmed.EndsWith(' ')) {
        return '项目名称不能以句点或空格结尾。'
    }

    foreach ($character in [IO.Path]::GetInvalidFileNameChars()) {
        if ($trimmed.Contains([string]$character)) {
            return "项目名称包含 Windows 不允许的字符：$character"
        }
    }

    if ($trimmed -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$') {
        return '项目名称是 Windows 保留名称，请更换。'
    }

    return $null
}

function Get-RelativeFolderPaths {
    param(
        [Parameter(Mandatory = $true)]$Nodes,
        [string]$Prefix = ''
    )

    foreach ($node in $Nodes) {
        $relativePath = if ([string]::IsNullOrWhiteSpace($Prefix)) {
            [string]$node.name
        }
        else {
            Join-Path $Prefix ([string]$node.name)
        }

        Write-Output $relativePath

        if ($null -ne $node.PSObject.Properties['children'] -and $node.children.Count -gt 0) {
            Get-RelativeFolderPaths -Nodes $node.children -Prefix $relativePath
        }
    }
}

function Get-PreviewLines {
    param(
        [Parameter(Mandatory = $true)]$Nodes,
        [string]$Prefix = ''
    )

    for ($index = 0; $index -lt $Nodes.Count; $index++) {
        $node = $Nodes[$index]
        $isLast = $index -eq ($Nodes.Count - 1)
        $connector = if ($isLast) { '└─ ' } else { '├─ ' }
        Write-Output ("{0}{1}{2}" -f $Prefix, $connector, [string]$node.name)

        if ($null -ne $node.PSObject.Properties['children'] -and $node.children.Count -gt 0) {
            $childPrefix = $Prefix + $(if ($isLast) { '   ' } else { '│  ' })
            Get-PreviewLines -Nodes $node.children -Prefix $childPrefix
        }
    }
}

function New-VideoProjectDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Date,
        [switch]$SkipOpen
    )

    if (-not (Test-ProjectDate -Value $Date)) {
        throw '日期必须是有效的 8 位日期，例如 20260714。'
    }

    $nameError = Test-ProjectName -Value $Name
    if ($null -ne $nameError) {
        throw $nameError
    }

    $trimmedName = $Name.Trim()

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        New-Item -ItemType Directory -Path $Root -Force | Out-Null
    }

    $resolvedRoot = (Resolve-Path -LiteralPath $Root).ProviderPath
    $projectFolderName = ([string]$Template.root_pattern).
        Replace('{date}', $Date).
        Replace('{project_name}', $trimmedName)
    $projectPath = Join-Path $resolvedRoot $projectFolderName

    $created = New-Object 'System.Collections.Generic.List[string]'
    $existing = New-Object 'System.Collections.Generic.List[string]'

    if (Test-Path -LiteralPath $projectPath -PathType Container) {
        $existing.Add($projectPath)
    }
    else {
        New-Item -ItemType Directory -Path $projectPath | Out-Null
        $created.Add($projectPath)
    }

    foreach ($relativePath in (Get-RelativeFolderPaths -Nodes $Template.folders)) {
        $fullPath = Join-Path $projectPath $relativePath
        if (Test-Path -LiteralPath $fullPath -PathType Container) {
            $existing.Add($fullPath)
        }
        else {
            New-Item -ItemType Directory -Path $fullPath | Out-Null
            $created.Add($fullPath)
        }
    }

    if (-not $SkipOpen) {
        Start-Process -FilePath 'explorer.exe' -ArgumentList @($projectPath)
    }

    return [pscustomobject]@{
        ProjectPath = $projectPath
        CreatedCount = $created.Count
        ExistingCount = $existing.Count
        Created = @($created)
        Existing = @($existing)
    }
}

function Show-GeneratorWindow {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class VideoProjectDpiNative
{
    [DllImport("user32.dll")]
    public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr dpiContext);
}
"@

    # Per-Monitor V2 keeps the WPF window sharp when it moves between monitors
    # with different scale factors. Thread-level context is required because the
    # UI runs inside powershell.exe, whose process manifest is only system-aware.
    $previousDpiContext = [VideoProjectDpiNative]::SetThreadDpiAwarenessContext([IntPtr](-4))

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Windows.Forms

    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="视频管理助手"
        Width="1040" Height="720" MinWidth="960" MinHeight="660"
        WindowStartupLocation="CenterScreen" WindowStyle="None" WindowState="Normal"
        ResizeMode="CanResizeWithGrip" Background="#D2D2D2"
        FontFamily="Source Han Sans SC" Foreground="#242424"
        UseLayoutRounding="True" SnapsToDevicePixels="True"
        TextOptions.TextFormattingMode="Display"
        TextOptions.TextRenderingMode="ClearType"
        TextOptions.TextHintingMode="Fixed"
        RenderOptions.ClearTypeHint="Enabled">
    <Window.Resources>
        <SolidColorBrush x:Key="Gold" Color="#EC6A49"/>
        <SolidColorBrush x:Key="WarmWhite" Color="#F7F7F7"/>
        <SolidColorBrush x:Key="Muted" Color="#B9B9B9"/>
        <SolidColorBrush x:Key="Panel" Color="#454545"/>
        <SolidColorBrush x:Key="Line" Color="#606060"/>

        <Style x:Key="FieldLabel" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#B9B9B9"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Margin" Value="0,0,0,8"/>
        </Style>

        <Style x:Key="InputField" TargetType="TextBox">
            <Setter Property="Height" Value="46"/>
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="14,11"/>
            <Setter Property="CaretBrush" Value="#EC6A49"/>
            <Setter Property="SelectionBrush" Value="#A7523D"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
        </Style>

        <Style x:Key="InputShell" TargetType="Border">
            <Setter Property="Height" Value="46"/>
            <Setter Property="Background" Value="#4A4A4A"/>
            <Setter Property="BorderBrush" Value="#606060"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="10"/>
            <Style.Triggers>
                <Trigger Property="IsKeyboardFocusWithin" Value="True">
                    <Setter Property="BorderBrush" Value="#EC6A49"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="GhostButton" TargetType="Button">
            <Setter Property="Height" Value="46"/>
            <Setter Property="Padding" Value="15,0"/>
            <Setter Property="Foreground" Value="#F4F4F4"/>
            <Setter Property="Background" Value="#4A4A4A"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="ButtonBorder" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="0,9,9,0">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                                <Setter TargetName="ButtonBorder" Property="Background" Value="#555555"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="ButtonBorder" Property="Background" Value="#555555"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Height" Value="54"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#EC6A49"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="PrimaryBorder" Background="{TemplateBinding Background}" CornerRadius="10">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="PrimaryBorder" Property="Background" Value="#F27A59"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="PrimaryBorder" Property="Background" Value="#D85B3D"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ChromeButton" TargetType="Button">
            <Setter Property="Width" Value="46"/>
            <Setter Property="Height" Value="46"/>
            <Setter Property="Foreground" Value="#666666"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="ChromeBorder" Background="{TemplateBinding Background}" CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ChromeBorder" Property="Background" Value="#C4C4C4"/>
                                <Setter Property="Foreground" Value="#242424"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="EditorialCheckBox" TargetType="CheckBox">
            <Setter Property="Foreground" Value="#D8D8D8"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <StackPanel Orientation="Horizontal">
                            <Border x:Name="CheckBorder" Width="16" Height="16" CornerRadius="4"
                                    Background="#4A4A4A" BorderBrush="#727272" BorderThickness="1">
                                <Path x:Name="CheckMark" Data="M 3 8 L 6.5 11.5 L 13 4.5"
                                      Stroke="#FFFFFF" StrokeThickness="2" Visibility="Collapsed"/>
                            </Border>
                            <ContentPresenter Margin="9,0,0,0" VerticalAlignment="Center"/>
                        </StackPanel>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="CheckBorder" Property="Background" Value="#EC6A49"/>
                                <Setter TargetName="CheckBorder" Property="BorderBrush" Value="#EC6A49"/>
                                <Setter TargetName="CheckMark" Property="Visibility" Value="Visible"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="CheckBorder" Property="BorderBrush" Value="#EC6A49"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="58"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <Border x:Name="TitleBar" Grid.Row="0" Background="#D2D2D2" BorderBrush="#BEBEBE" BorderThickness="0,0,0,1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="28,0,0,0">
                    <TextBlock Text="视频管理助手" Foreground="#242424" FontWeight="SemiBold" FontSize="14"/>
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal">
                    <Button x:Name="MinimizeButton" Content="—" Style="{StaticResource ChromeButton}"/>
                    <Button x:Name="CloseButton" Content="×" Style="{StaticResource ChromeButton}"/>
                </StackPanel>
            </Grid>
        </Border>

        <Grid Grid.Row="1" Margin="44,52,44,40">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="374"/>
                <ColumnDefinition Width="34"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Grid Grid.Column="0">
                <Border Background="#3D3D3D" CornerRadius="20" IsHitTestVisible="False">
                    <Border.Effect>
                        <DropShadowEffect Color="#000000" BlurRadius="20" ShadowDepth="4" Opacity="0.18"/>
                    </Border.Effect>
                </Border>
                <Border Background="#3D3D3D" CornerRadius="20" Padding="28,28,28,26"
                        SnapsToDevicePixels="True" RenderOptions.ClearTypeHint="Enabled">
                <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <StackPanel>
                    <Border Width="36" Height="2" Background="#EC6A49" HorizontalAlignment="Left" Margin="0,0,0,18"/>
                    <TextBlock Text="给项目一个&#x0a;清晰的开始" FontSize="28" FontWeight="Light"
                               LineHeight="37" Foreground="#FFFFFF"/>
                    <TextBlock Text="建立统一目录，让素材、工程与交付从第一天就保持秩序。"
                               FontSize="12" Foreground="#B9B9B9" TextWrapping="Wrap"
                               LineHeight="20" Margin="0,13,4,0"/>
                </StackPanel>

                <StackPanel Grid.Row="1" VerticalAlignment="Center" Margin="0,24,0,16">
                    <TextBlock Text="项目名称" Style="{StaticResource FieldLabel}"/>
                    <Border Style="{StaticResource InputShell}" Margin="0,0,0,17">
                        <TextBox x:Name="NameBox" Style="{StaticResource InputField}"/>
                    </Border>

                    <Grid Margin="0,0,0,17">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="130"/>
                            <ColumnDefinition Width="12"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0">
                            <TextBlock Text="日期" Style="{StaticResource FieldLabel}"/>
                            <Border Style="{StaticResource InputShell}">
                                <TextBox x:Name="DateBox" Style="{StaticResource InputField}"/>
                            </Border>
                        </StackPanel>
                        <StackPanel Grid.Column="2">
                            <TextBlock Text="保存位置" Style="{StaticResource FieldLabel}"/>
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="1"/>
                                    <ColumnDefinition Width="70"/>
                                </Grid.ColumnDefinitions>
                                <Border Grid.ColumnSpan="3" Style="{StaticResource InputShell}">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="1"/>
                                            <ColumnDefinition Width="70"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBox x:Name="RootBox" Style="{StaticResource InputField}" FontSize="12"/>
                                        <Border Grid.Column="1" Background="#606060" Margin="0,8"/>
                                        <Button x:Name="BrowseButton" Grid.Column="2" Content="选择"
                                                Style="{StaticResource GhostButton}"/>
                                    </Grid>
                                </Border>
                            </Grid>
                        </StackPanel>
                    </Grid>

                    <CheckBox x:Name="OpenCheck" Content="生成后打开项目目录" IsChecked="True"
                              Style="{StaticResource EditorialCheckBox}"/>
                </StackPanel>

                <StackPanel Grid.Row="2">
                    <Button x:Name="GenerateButton" Content="生成目录" Style="{StaticResource PrimaryButton}"/>
                    <TextBlock x:Name="StatusLabel" Text="不会修改已有内容"
                               Foreground="#AAAAAA" FontSize="11" TextWrapping="Wrap"
                               LineHeight="17" Margin="2,12,2,0"/>
                </StackPanel>
                </Grid>
                </Border>
            </Grid>

            <Grid Grid.Column="2">
                <Border Background="#F7F7F7" CornerRadius="20" IsHitTestVisible="False">
                    <Border.Effect>
                        <DropShadowEffect Color="#000000" BlurRadius="18" ShadowDepth="3" Opacity="0.08"/>
                    </Border.Effect>
                </Border>
                <Border Background="#F7F7F7" BorderBrush="#FFFFFF" BorderThickness="1"
                        CornerRadius="20" Padding="38,34,38,34"
                        SnapsToDevicePixels="True" RenderOptions.ClearTypeHint="Enabled">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="1"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Border Background="#EC6A49" CornerRadius="12" Padding="11,5" HorizontalAlignment="Left">
                            <TextBlock Text="生成预览" Foreground="#FFFFFF" FontSize="10" FontWeight="SemiBold"/>
                        </Border>
                    </Grid>

                    <TextBlock x:Name="PreviewRoot" Grid.Row="1" Text="YYYYMMDD_项目名称"
                               Foreground="#242424" FontSize="24" FontWeight="SemiBold"
                               TextWrapping="Wrap" Margin="0,21,0,20"/>

                    <Border Grid.Row="2" Background="#DEDEDE"/>

                    <ScrollViewer Grid.Row="3" VerticalScrollBarVisibility="Auto" Margin="0,18,0,0">
                        <TextBlock x:Name="PreviewBox" Foreground="#3A3A3A" FontSize="12"
                                   FontFamily="Source Han Sans SC" LineHeight="18"/>
                    </ScrollViewer>
                </Grid>
                </Border>
            </Grid>
        </Grid>
    </Grid>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $titleBar = $window.FindName('TitleBar')
    $minimizeButton = $window.FindName('MinimizeButton')
    $closeButton = $window.FindName('CloseButton')
    $nameBox = $window.FindName('NameBox')
    $dateBox = $window.FindName('DateBox')
    $rootBox = $window.FindName('RootBox')
    $browseButton = $window.FindName('BrowseButton')
    $openCheck = $window.FindName('OpenCheck')
    $generateButton = $window.FindName('GenerateButton')
    $statusLabel = $window.FindName('StatusLabel')
    $previewRoot = $window.FindName('PreviewRoot')
    $previewBox = $window.FindName('PreviewBox')

    $dateBox.Text = (Get-Date -Format 'yyyyMMdd')

    $updatePreview = {
        $dateValue = if ([string]::IsNullOrWhiteSpace($dateBox.Text)) { 'YYYYMMDD' } else { $dateBox.Text.Trim() }
        $nameValue = if ([string]::IsNullOrWhiteSpace($nameBox.Text)) { '项目名称' } else { $nameBox.Text.Trim() }
        $previewRoot.Text = ([string]$Template.root_pattern).
            Replace('{date}', $dateValue).
            Replace('{project_name}', $nameValue)
        $previewBox.Text = (Get-PreviewLines -Nodes $Template.folders) -join "`r`n"
    }

    $titleBar.Add_MouseLeftButtonDown({
        if ($_.ClickCount -eq 2) {
            $window.WindowState = if ($window.WindowState -eq 'Maximized') { 'Normal' } else { 'Maximized' }
        }
        else {
            $window.DragMove()
        }
    })

    $minimizeButton.Add_Click({ $window.WindowState = 'Minimized' })
    $closeButton.Add_Click({ $window.Close() })

    $browseButton.Add_Click({
        $dialog = New-Object Windows.Forms.FolderBrowserDialog
        $dialog.Description = '请选择项目目录的保存位置'
        $dialog.ShowNewFolderButton = $true
        if ($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
            $rootBox.Text = $dialog.SelectedPath
            $statusLabel.Text = '已选择保存位置'
            $statusLabel.Foreground = '#B9B9B9'
        }
    })

    $dateBox.Add_TextChanged($updatePreview)
    $nameBox.Add_TextChanged($updatePreview)

    $generateButton.Add_Click({
        try {
            if ([string]::IsNullOrWhiteSpace($rootBox.Text)) {
                throw '请先选择保存位置。'
            }

            $generateButton.IsEnabled = $false
            $generateButton.Content = '正在生成…'
            $statusLabel.Text = '正在生成目录'
            $statusLabel.Foreground = '#EC6A49'

            $result = New-VideoProjectDirectory `
                -Root $rootBox.Text.Trim() `
                -Name $nameBox.Text `
                -Date $dateBox.Text.Trim() `
                -SkipOpen:(-not [bool]$openCheck.IsChecked)

            $generateButton.Content = '已完成'
            $statusLabel.Text = "新建 $($result.CreatedCount) 个 · 已有 $($result.ExistingCount) 个`n$($result.ProjectPath)"
            $statusLabel.Foreground = '#A5C49A'
        }
        catch {
            $generateButton.Content = '重新生成'
            $statusLabel.Text = $_.Exception.Message
            $statusLabel.Foreground = '#FF9A84'
        }
        finally {
            $generateButton.IsEnabled = $true
        }
    })

    & $updatePreview
    $window.Add_ContentRendered({ $nameBox.Focus() })
    try {
        [void]$window.ShowDialog()
    }
    finally {
        if ($previousDpiContext -ne [IntPtr]::Zero) {
            [void][VideoProjectDpiNative]::SetThreadDpiAwarenessContext($previousDpiContext)
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($TargetRoot) -or -not [string]::IsNullOrWhiteSpace($ProjectName)) {
    if ([string]::IsNullOrWhiteSpace($TargetRoot) -or [string]::IsNullOrWhiteSpace($ProjectName)) {
        throw '命令行模式必须同时提供 -TargetRoot 和 -ProjectName。'
    }

    $result = New-VideoProjectDirectory `
        -Root $TargetRoot `
        -Name $ProjectName `
        -Date $ProjectDate `
        -SkipOpen:$NoOpen

    $result | ConvertTo-Json -Depth 5
}
else {
    Show-GeneratorWindow
}
