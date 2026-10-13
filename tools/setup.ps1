# Weisy first-run setup, called by start.bat before the server starts (env WEISY_DIR = program folder).
# One small dialog, asked ONCE: where to keep the data (default: the Weisy-Data folder in %APPDATA%) and whether to put a
# shortcut on the desktop. The shortcut answer is kept in desktop-shortcut.txt: "no" is final, a folder path means "yes,
# for that folder" - after an update into a new folder the shortcut is quietly pointed there. A changed data folder
# is kept in location.txt (read by server.py). -Preview <png> only saves a picture of the dialog.
param([string]$Preview = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Name Dpi -Namespace Weisy -MemberDefinition '[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[void][Weisy.Dpi]::SetProcessDPIAware()
[System.Windows.Forms.Application]::EnableVisualStyles()

$folder = ([string]$env:WEISY_DIR).TrimEnd('\')
if (-not $folder) { $folder = (Split-Path -Parent $PSScriptRoot) }
$base = Join-Path $env:APPDATA 'Weisy-Data'          # fixed place for the small files; also the default data folder
$mark = Join-Path $base 'desktop-shortcut.txt'
$pointer = Join-Path $base 'location.txt'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function C([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
function Read-Text($path) { if (Test-Path -LiteralPath $path) { ([IO.File]::ReadAllText($path)).Trim() } else { '' } }
function Write-Text($path, $text) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null; [IO.File]::WriteAllText($path, $text, $utf8) }

$script:location = Read-Text $pointer
if (-not $script:location) { $script:location = $base }

function Show-Dialog {
    $font = 'Microsoft YaHei UI'
    $f = New-Object System.Windows.Forms.Form
    $f.Text = [string]::Join('', [char[]](0x6F66, 0x8349, 0x9F20, 0x9F20, 0x4E4B, 0x5BB6))   # the app name
    $f.ClientSize = New-Object System.Drawing.Size(480, 330)
    $f.StartPosition = 'CenterScreen'; $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.BackColor = C '#F3F4F1'; $f.TopMost = $true; $f.Font = New-Object System.Drawing.Font($font, 9.5)
    $ico = Join-Path $folder 'src\assets\icon.ico'
    $png = Join-Path $folder 'src\assets\icon-64.png'
    if (Test-Path $ico) { $f.Icon = New-Object System.Drawing.Icon($ico) }
    if (Test-Path $png) {
        $pb = New-Object System.Windows.Forms.PictureBox
        $pb.Image = [System.Drawing.Image]::FromFile($png); $pb.SizeMode = 'Zoom'
        $pb.Location = New-Object System.Drawing.Point(28, 28); $pb.Size = New-Object System.Drawing.Size(52, 52)
        $f.Controls.Add($pb)
    }
    $t = New-Object System.Windows.Forms.Label
    $t.Text = '第一次使用，先做两个选择'
    $t.Font = New-Object System.Drawing.Font($font, 14, [System.Drawing.FontStyle]::Bold); $t.ForeColor = C '#171B19'
    $t.Location = New-Object System.Drawing.Point(96, 28); $t.Size = New-Object System.Drawing.Size(360, 30)
    $b = New-Object System.Windows.Forms.Label
    $b.Text = "选好数据保存的位置，再决定要不要桌面图标。`n不要图标也行，随时双击 start.bat 打开。"
    $b.ForeColor = C '#434B47'
    $b.Location = New-Object System.Drawing.Point(96, 62); $b.Size = New-Object System.Drawing.Size(360, 44)
    $lh = New-Object System.Windows.Forms.Label
    $lh.Text = '数据保存位置'; $lh.Font = New-Object System.Drawing.Font($font, 9.5, [System.Drawing.FontStyle]::Bold); $lh.ForeColor = C '#434B47'
    $lh.Location = New-Object System.Drawing.Point(28, 118); $lh.Size = New-Object System.Drawing.Size(200, 22)
    $loc = New-Object System.Windows.Forms.Label
    $loc.BackColor = [System.Drawing.Color]::White; $loc.BorderStyle = 'FixedSingle'; $loc.Text = $script:location
    $loc.AutoEllipsis = $true; $loc.TextAlign = 'MiddleLeft'; $loc.ForeColor = C '#171B19'; $loc.Font = New-Object System.Drawing.Font($font, 8.5)
    $loc.Location = New-Object System.Drawing.Point(28, 142); $loc.Size = New-Object System.Drawing.Size(340, 32)
    $chg = New-Object System.Windows.Forms.Button
    $chg.Text = '更改…'; $chg.FlatStyle = 'Flat'; $chg.FlatAppearance.BorderColor = C '#C5CAC4'
    $chg.BackColor = [System.Drawing.Color]::White; $chg.ForeColor = C '#171B19'; $chg.Cursor = 'Hand'
    $chg.Location = New-Object System.Drawing.Point(376, 142); $chg.Size = New-Object System.Drawing.Size(76, 32)
    $chg.Add_Click({
        $d = New-Object System.Windows.Forms.FolderBrowserDialog
        $d.Description = '选一个文件夹来保存数据（会在里面新建一个 Weisy-Data 文件夹）'
        $d.ShowNewFolderButton = $true
        if ($d.ShowDialog($f) -eq 'OK') {
            $picked = $d.SelectedPath
            $script:location = if (Test-Path -LiteralPath (Join-Path $picked 'weisy.json')) { $picked } else { Join-Path $picked 'Weisy-Data' }
            $loc.Text = $script:location
        }
    })
    $w = New-Object System.Windows.Forms.Label
    $w.Text = "  ⚠  数据位置和桌面图标只会询问这一次，以后不会再次询问，请慎重考虑。"
    $w.BackColor = C '#F6ECD8'; $w.ForeColor = C '#9E6410'
    $w.Font = New-Object System.Drawing.Font($font, 9.5, [System.Drawing.FontStyle]::Bold); $w.TextAlign = 'MiddleLeft'
    $w.Location = New-Object System.Drawing.Point(28, 190); $w.Size = New-Object System.Drawing.Size(424, 56)
    $yes = New-Object System.Windows.Forms.Button
    $yes.Text = '创建桌面图标并开始'; $yes.FlatStyle = 'Flat'; $yes.FlatAppearance.BorderSize = 0
    $yes.BackColor = C '#2A43C0'; $yes.ForeColor = [System.Drawing.Color]::White; $yes.Cursor = 'Hand'
    $yes.Location = New-Object System.Drawing.Point(104, 268); $yes.Size = New-Object System.Drawing.Size(176, 42)
    $yes.DialogResult = 'Yes'
    $no = New-Object System.Windows.Forms.Button
    $no.Text = '不要图标，开始'; $no.FlatStyle = 'Flat'; $no.FlatAppearance.BorderColor = C '#C5CAC4'
    $no.BackColor = [System.Drawing.Color]::White; $no.ForeColor = C '#171B19'; $no.Cursor = 'Hand'
    $no.Location = New-Object System.Drawing.Point(290, 268); $no.Size = New-Object System.Drawing.Size(162, 42)
    $no.DialogResult = 'No'
    $f.CancelButton = $no   # Esc or the window's close button count as "no icon"
    $f.Controls.AddRange(@($t, $b, $lh, $loc, $chg, $w, $yes, $no))
    if ($Preview) {
        $f.Show(); $f.Refresh()
        $bmp = New-Object System.Drawing.Bitmap($f.Width, $f.Height)
        $f.DrawToBitmap($bmp, (New-Object System.Drawing.Rectangle(0, 0, $f.Width, $f.Height)))
        $bmp.Save($Preview); $f.Close(); return 'preview'
    }
    $f.Activate()
    return [string]$f.ShowDialog()
}

if ($Preview) { [void](Show-Dialog); exit 0 }
$ans = Read-Text $mark
if ($ans -eq 'no' -or $ans -eq $folder) { exit 0 }
if (-not $ans) {
    $answer = Show-Dialog
    # keep the chosen data folder (the default needs no pointer)
    if ($script:location -ne $base) {
        try {
            New-Item -ItemType Directory -Force -Path $script:location | Out-Null
            Write-Text $pointer $script:location
        } catch {
            [void][System.Windows.Forms.MessageBox]::Show("这个位置用不了，数据会保存在默认位置：`n$base", 'Weisy')
            if (Test-Path -LiteralPath $pointer) { Remove-Item -LiteralPath $pointer -Force }
        }
    } elseif (Test-Path -LiteralPath $pointer) { Remove-Item -LiteralPath $pointer -Force }
    if ($answer -ne 'Yes') { Write-Text $mark 'no'; exit 0 }
}
try {
    $name = [string]::Join('', [char[]](0x6F66, 0x8349, 0x9F20, 0x9F20, 0x4E4B, 0x5BB6))
    $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) ($name + '.lnk')))
    $lnk.TargetPath = Join-Path $folder 'start.bat'
    $lnk.WorkingDirectory = $folder
    $lnk.IconLocation = (Join-Path $folder 'src\assets\icon.ico')
    $lnk.WindowStyle = 7   # minimised: the launcher window is only a flash
    $lnk.Save()
    Write-Text $mark $folder
} catch { exit 1 }
