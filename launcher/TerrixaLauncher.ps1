Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

function Get-LauncherRoot {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}

function Read-Config($path) {
    if (!(Test-Path -LiteralPath $path)) {
        throw "Missing config file: $path"
    }
    return (Get-Content -Raw -LiteralPath $path | ConvertFrom-Json)
}

function Resolve-GamePath($launcherRoot, $relativePath) {
    $root = Resolve-Path (Join-Path $launcherRoot '..')
    return Join-Path $root $relativePath
}

function Start-Game($exePath, $statusLabel) {
    if (!(Test-Path -LiteralPath $exePath)) {
        [System.Windows.Forms.MessageBox]::Show("Game executable not found:`n$exePath", "Terrixa Launcher", 'OK', 'Error') | Out-Null
        return
    }

    $statusLabel.Text = 'Launching Terrixa...'
    $process = Start-Process -FilePath $exePath -WorkingDirectory (Split-Path -Parent $exePath) -PassThru
    $statusLabel.Text = 'Terrixa launched.'

    # Rename window after launch
    Start-Job -ScriptBlock {
        param($procId)
        Add-Type @"
            using System;
            using System.Runtime.InteropServices;
            using System.Text;
            public class WinApi {
                [DllImport("user32.dll")]
                public static extern bool SetWindowText(IntPtr hWnd, string lpString);
                [DllImport("user32.dll")]
                public static extern bool IsWindowVisible(IntPtr hWnd);
            }
"@
        # Try multiple times to find the window
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep -Milliseconds 500
            $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
            if ($proc -and $proc.MainWindowHandle -ne [IntPtr]::Zero) {
                [WinApi]::SetWindowText($proc.MainWindowHandle, "Terrixa 5.15.2")
                break
            }
        }
    } -ArgumentList $process.Id | Out-Null
}

function Check-Updates($manifestUrl, $statusLabel, $logBox) {
    if ([string]::IsNullOrWhiteSpace($manifestUrl) -or $manifestUrl -like 'https://example.com*') {
        $statusLabel.Text = 'Update URL not configured.'
        $logBox.AppendText("- Set launcher/config.json -> updateManifestUrl to your real URL.`r`n")
        return
    }

    try {
        $statusLabel.Text = 'Checking for updates...'
        $manifest = Invoke-RestMethod -Uri $manifestUrl -Method Get -TimeoutSec 15
        $version = if ($manifest.version) { $manifest.version } else { 'unknown' }
        $statusLabel.Text = "Latest version: $version"
        $logBox.AppendText("- Update check OK. Latest: $version`r`n")
    } catch {
        $statusLabel.Text = 'Update check failed.'
        $logBox.AppendText("- Update check failed: $($_.Exception.Message)`r`n")
    }
}

$launcherRoot = Get-LauncherRoot
$configPath = Join-Path $launcherRoot 'config.json'
$config = Read-Config $configPath
$exePath = Resolve-GamePath $launcherRoot $config.gameExecutable

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Terrixa Launcher'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(520, 360)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = 'TERRIXA'
$title.Font = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(20, 18)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'Play, update, and launch from one place.'
$subtitle.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(24, 62)
$form.Controls.Add($subtitle)

$playBtn = New-Object System.Windows.Forms.Button
$playBtn.Text = 'Play Terrixa'
$playBtn.Size = New-Object System.Drawing.Size(150, 42)
$playBtn.Location = New-Object System.Drawing.Point(24, 100)
$form.Controls.Add($playBtn)

$updateBtn = New-Object System.Windows.Forms.Button
$updateBtn.Text = 'Check Updates'
$updateBtn.Size = New-Object System.Drawing.Size(150, 42)
$updateBtn.Location = New-Object System.Drawing.Point(184, 100)
$form.Controls.Add($updateBtn)

$openFolderBtn = New-Object System.Windows.Forms.Button
$openFolderBtn.Text = 'Open Game Folder'
$openFolderBtn.Size = New-Object System.Drawing.Size(150, 42)
$openFolderBtn.Location = New-Object System.Drawing.Point(344, 100)
$form.Controls.Add($openFolderBtn)

$status = New-Object System.Windows.Forms.Label
$status.Text = 'Ready.'
$status.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$status.AutoSize = $true
$status.Location = New-Object System.Drawing.Point(24, 158)
$form.Controls.Add($status)

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true
$log.ScrollBars = 'Vertical'
$log.ReadOnly = $true
$log.Size = New-Object System.Drawing.Size(470, 130)
$log.Location = New-Object System.Drawing.Point(24, 185)
$log.Font = New-Object System.Drawing.Font('Consolas', 9)
$log.Text = "Terrixa launcher initialized.`r`n- Executable: $exePath`r`n"
$form.Controls.Add($log)

$playBtn.Add_Click({ Start-Game -exePath $exePath -statusLabel $status })
$updateBtn.Add_Click({ Check-Updates -manifestUrl $config.updateManifestUrl -statusLabel $status -logBox $log })
$openFolderBtn.Add_Click({ Start-Process explorer.exe (Resolve-Path (Join-Path $launcherRoot '..')) })

[void]$form.ShowDialog()
