<#
MIT License

Copyright (c) 2026 Pin-Lui

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

# Elite Multibox Launcher
#
# Launches one or more external programs (game client, companion apps, etc.)
# once per selected "Commander"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

# Config lives beside the script (not %APPDATA%)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir "config.json"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

function Show-Error([string]$Message) {
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        "Elite Multibox Launcher",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Show-Info([string]$Message) {
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        "Elite Multibox Launcher",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Set-DarkTheme($Control) {
    $Control.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $Control.ForeColor = [System.Drawing.Color]::Gainsboro

    foreach ($child in $Control.Controls) {
        if ($child -is [System.Windows.Forms.Button]) {
            $child.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 55)
            $child.ForeColor = [System.Drawing.Color]::White
            $child.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
            $child.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(85, 85, 85)
        }
        elseif ($child -is [System.Windows.Forms.TextBox]) {
            $child.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
            $child.ForeColor = [System.Drawing.Color]::White
            $child.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        }
        elseif ($child -is [System.Windows.Forms.CheckedListBox]) {
            $child.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
            $child.ForeColor = [System.Drawing.Color]::White
            $child.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        }
        elseif ($child -is [System.Windows.Forms.Label]) {

            if ($child.ForeColor -eq [System.Drawing.Color]::Empty -or
                $child.ForeColor -eq [System.Drawing.SystemColors]::ControlText) {
                $child.ForeColor = [System.Drawing.Color]::Gainsboro
            }
            $child.BackColor = [System.Drawing.Color]::Transparent
        }

        if ($child.HasChildren) {
            Set-DarkTheme $child
        }
    }
}

function Get-Config {
    # Auto-create an empty config on first run
    if (-not (Test-Path $ConfigPath)) {
        $default = @{
            commanders            = @()
            programs              = @()
            selectedCommanderKeys = @()
            selectedProgramKeys   = @()
        }
        $default | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8
    }

    try {
        return Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Show-Error "Could not read config.json.`r`n`r`n$($_.Exception.Message)"
        throw
    }
}

function Save-Config($Config) {
    try {
        $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8
    }
    catch {
        Show-Error ("Could not save config.json to:`r`n$ConfigPath`r`n`r`n$($_.Exception.Message)`r`n`r`n" +
            "This folder may be read-only (e.g. Program Files) or synced/locked by another process. " +
            "Move EliteMultiboxLauncher.ps1 (and EliteMultiboxLauncher.vbs) to a folder you have write access to, " +
            "such as your Documents folder, and try again. Your changes were not saved.")
    }
}

function Expand-ProgramArgs([string]$Arguments, $Commander) {
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        return ""
    }

    $result = $Arguments
    $result = $result.Replace("{Commander}", [string]$Commander.name)
    $result = $result.Replace("{WindowsUser}", [string]$Commander.windowsUser)
    $result = $result.Replace("{MinEdProfile}", [string]$Commander.minEdProfile)
    return $result
}

function Start-AsUser($Commander, $Program) {
    $path = [string]$Program.path
    if (-not (Test-Path $path)) {
        throw "Program not found: $path"
    }

    $expandedArgs = Expand-ProgramArgs ([string]$Program.arguments) $Commander

    $useRunAs = $true
    if ($null -ne $Commander.PSObject.Properties['useRunAs'] -and $null -ne $Commander.useRunAs) {
        $useRunAs = [bool]$Commander.useRunAs
    }

    if (-not $useRunAs) {
        if ([string]::IsNullOrWhiteSpace($expandedArgs)) {
            Start-Process -FilePath $path | Out-Null
        }
        else {
            Start-Process -FilePath $path -ArgumentList $expandedArgs | Out-Null
        }
        return
    }

    $command = '"' + $path + '"'
    if (-not [string]::IsNullOrWhiteSpace($expandedArgs)) {
        $command += " " + $expandedArgs
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "$env:SystemRoot\System32\runas.exe"
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $false
    $psi.Arguments = '/user:"' + [string]$Commander.windowsUser + '" /savecred "' + ($command -replace '"','\"') + '"'

    $proc = [System.Diagnostics.Process]::Start($psi)
    if ($null -eq $proc) {
        throw "RUNAS could not be started."
    }
}

# One dialog serves both Add and Edit 
function New-CommanderDialog($Existing = $null) {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = if ($Existing) { "Edit Commander" } else { "Add Commander" }
    $f.Size = New-Object System.Drawing.Size(430, 290)
    $f.StartPosition = "CenterParent"
    $f.FormBorderStyle = "FixedDialog"
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false

    $labels = @("Display name", "Windows user", "min-ed-profile")
    $values = @(
        $(if ($Existing) { [string]$Existing.name } else { "" }),
        $(if ($Existing) { [string]$Existing.windowsUser } else { "" }),
        $(if ($Existing) { [string]$Existing.minEdProfile } else { "" })
    )

    $boxes = @()
    for ($i=0; $i -lt 3; $i++) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $labels[$i]
        $lbl.Location = New-Object System.Drawing.Point(20, (25 + $i*45))
        $lbl.Size = New-Object System.Drawing.Size(110, 24)
        $f.Controls.Add($lbl)

        $tb = New-Object System.Windows.Forms.TextBox
        $tb.Location = New-Object System.Drawing.Point(135, (22 + $i*45))
        $tb.Size = New-Object System.Drawing.Size(255, 25)
        $tb.Text = $values[$i]
        $f.Controls.Add($tb)
        $boxes += $tb
    }

    $chkUseRunAs = New-Object System.Windows.Forms.CheckBox
    $chkUseRunAs.Text = "Use RunAs (different Windows user)"
    $chkUseRunAs.Location = New-Object System.Drawing.Point(135, 157)
    $chkUseRunAs.Size = New-Object System.Drawing.Size(255, 24)
    $chkUseRunAs.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $chkUseRunAs.ForeColor = [System.Drawing.Color]::Gainsboro
    $chkUseRunAs.Checked = $true
    if ($Existing -and $null -ne $Existing.PSObject.Properties['useRunAs'] -and $null -ne $Existing.useRunAs) {
        $chkUseRunAs.Checked = [bool]$Existing.useRunAs
    }
    $f.Controls.Add($chkUseRunAs)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = "Save"
    $ok.Location = New-Object System.Drawing.Point(215, 205)
    $ok.Size = New-Object System.Drawing.Size(80, 30)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $f.AcceptButton = $ok
    $f.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = "Cancel"
    $cancel.Location = New-Object System.Drawing.Point(310, 205)
    $cancel.Size = New-Object System.Drawing.Size(80, 30)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $f.CancelButton = $cancel
    $f.Controls.Add($cancel)

    Set-DarkTheme $f
    if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if ([string]::IsNullOrWhiteSpace($boxes[0].Text)) {
            Show-Error "Display name is required."
            return $null
        }

        if ($chkUseRunAs.Checked -and [string]::IsNullOrWhiteSpace($boxes[1].Text)) {
            Show-Error "Windows user is required when Use RunAs is enabled."
            return $null
        }

        if ($boxes[1].Text -match '"') {
            Show-Error "Windows user cannot contain a double-quote (`") character."
            return $null
        }

        return [pscustomobject]@{
            name          = $boxes[0].Text.Trim()
            windowsUser   = $boxes[1].Text.Trim()
            minEdProfile  = $boxes[2].Text.Trim()
            useRunAs      = [bool]$chkUseRunAs.Checked
        }
    }

    return $null
}

function New-ProgramDialog($Existing = $null) {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = if ($Existing) { "Edit Program" } else { "Add Program" }
    $f.Size = New-Object System.Drawing.Size(640, 280)
    $f.StartPosition = "CenterParent"
    $f.FormBorderStyle = "FixedDialog"
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false

    $lblName = New-Object System.Windows.Forms.Label
    $lblName.Text = "Name"
    $lblName.Location = New-Object System.Drawing.Point(20, 25)
    $lblName.Size = New-Object System.Drawing.Size(80, 24)
    $f.Controls.Add($lblName)

    $txtName = New-Object System.Windows.Forms.TextBox
    $txtName.Location = New-Object System.Drawing.Point(105, 22)
    $txtName.Size = New-Object System.Drawing.Size(490, 25)
    if ($Existing) { $txtName.Text = [string]$Existing.name }
    $f.Controls.Add($txtName)

    $lblPath = New-Object System.Windows.Forms.Label
    $lblPath.Text = "Path"
    $lblPath.Location = New-Object System.Drawing.Point(20, 70)
    $lblPath.Size = New-Object System.Drawing.Size(80, 24)
    $f.Controls.Add($lblPath)

    $txtPath = New-Object System.Windows.Forms.TextBox
    $txtPath.Location = New-Object System.Drawing.Point(105, 67)
    $txtPath.Size = New-Object System.Drawing.Size(395, 25)
    if ($Existing) { $txtPath.Text = [string]$Existing.path }
    $f.Controls.Add($txtPath)

    $browse = New-Object System.Windows.Forms.Button
    $browse.Text = "Browse..."
    $browse.Location = New-Object System.Drawing.Point(510, 65)
    $browse.Size = New-Object System.Drawing.Size(85, 28)
    $f.Controls.Add($browse)

    $browse.Add_Click({
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        # "All files" is included alongside the executable filter
        $ofd.Filter = "Programs (*.exe;*.cmd;*.bat)|*.exe;*.cmd;*.bat|All files (*.*)|*.*"
        if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtPath.Text = $ofd.FileName
        }
    })

    $lblArgs = New-Object System.Windows.Forms.Label
    $lblArgs.Text = "Arguments"
    $lblArgs.Location = New-Object System.Drawing.Point(20, 115)
    $lblArgs.Size = New-Object System.Drawing.Size(80, 24)
    $f.Controls.Add($lblArgs)

    $txtArgs = New-Object System.Windows.Forms.TextBox
    $txtArgs.Location = New-Object System.Drawing.Point(105, 112)
    $txtArgs.Size = New-Object System.Drawing.Size(490, 25)
    if ($Existing) { $txtArgs.Text = [string]$Existing.arguments }
    $f.Controls.Add($txtArgs)

    $hint = New-Object System.Windows.Forms.Label
    $hint.Text = "Variables: {Commander}   {WindowsUser}   {MinEdProfile}"
    $hint.Location = New-Object System.Drawing.Point(105, 142)
    $hint.Size = New-Object System.Drawing.Size(420, 22)
    $hint.ForeColor = [System.Drawing.Color]::DimGray
    $f.Controls.Add($hint)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = "Save"
    $ok.Location = New-Object System.Drawing.Point(420, 190)
    $ok.Size = New-Object System.Drawing.Size(80, 30)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $f.AcceptButton = $ok
    $f.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = "Cancel"
    $cancel.Location = New-Object System.Drawing.Point(515, 190)
    $cancel.Size = New-Object System.Drawing.Size(80, 30)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $f.CancelButton = $cancel
    $f.Controls.Add($cancel)

    Set-DarkTheme $f
    if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if ([string]::IsNullOrWhiteSpace($txtName.Text) -or
            [string]::IsNullOrWhiteSpace($txtPath.Text)) {
            Show-Error "Program name and path are required."
            return $null
        }

        return [pscustomobject]@{
            name      = $txtName.Text.Trim()
            path      = $txtPath.Text.Trim()
            arguments = $txtArgs.Text
        }
    }

    return $null
}

# CheckedListBox's built-in CheckOnClick toggles the check state on a click
# anywhere in the row, not just on the checkbox glyph — but Edit/Remove need
# a plain row click to just select an item, without also flipping its check.
# CheckOnClick is left off (set where these lists are created) and this
# reimplements it manually so only clicking the ~18px checkbox area toggles
# the check, while any click still updates SelectedIndex for Edit/Remove.
function Add-CheckboxOnlyClickBehavior($List) {
    $List.Add_MouseDown({
        param($control, $e)

        $index = $control.IndexFromPoint($e.Location)
        if ($index -lt 0) {
            $control.Tag = $null
            return
        }

        # Captured on MouseDown, compared again on MouseUp, so a
        # click-drag-release off the checkbox (or onto a different row)
        # doesn't register as a toggle — only a clean click on the same
        # checkbox does.
        $control.Tag = [PSCustomObject]@{
            Index       = $index
            CheckboxHit = ($e.X -ge 0 -and $e.X -le 18)
            WasChecked  = $control.GetItemChecked($index)
        }
    })

    $List.Add_MouseUp({
        param($control, $e)

        $clickState = $control.Tag
        $control.Tag = $null

        $index = $control.IndexFromPoint($e.Location)
        if ($index -lt 0) {
            return
        }

        # Always select on click (even off the checkbox)
        $control.SelectedIndex = $index

        if ($null -eq $clickState -or
            -not $clickState.CheckboxHit -or
            $clickState.Index -ne $index) {
            return
        }

        $targetIndex = [int]$clickState.Index
        $targetChecked = -not [bool]$clickState.WasChecked
        $targetList = $control

        # Deferred via BeginInvoke rather than called inline: this MouseUp
        # handler runs alongside the CheckedListBox's own built-in mouse
        # handling for the same click, and setting the check synchronously
        # here was inconsistent depending on which ran first. Queuing it lets
        # the control finish its own handling before this applies the toggle.
        $action = {
            if ($targetIndex -ge 0 -and $targetIndex -lt $targetList.Items.Count) {
                # Marks this specific SetItemChecked call as authorized, so
                # the ItemCheck handler below lets it through instead of
                # canceling it as an unrecognized (native, non-checkbox)
                # check attempt. Must be $global:, not $script: — this
                # block is .GetNewClosure()'d just below (needed so
                # $targetIndex/$targetChecked/$targetList keep the values
                # captured at click time rather than whatever they are by
                # the time BeginInvoke actually runs this), and that binds
                # the block to its own dynamic module with its own separate
                # script scope. $script:AllowCheckToggle here would silently
                # set a variable the ItemCheck handler never sees.
                $global:AllowCheckToggle = $true
                try {
                    $targetList.SetItemChecked($targetIndex, $targetChecked)
                }
                finally {
                    $global:AllowCheckToggle = $false
                }
            }
        }.GetNewClosure()

        [void]$control.BeginInvoke([System.Windows.Forms.MethodInvoker]$action)
    })
}

# Selection is persisted by identity, not by list position, because the
# list order isn't stable — adding, removing, or editing a commander/program
# shifts every index after it. Saving "index 2 was checked" would silently
# re-check the wrong entry after any edit; a value that identifies the
# specific commander survives reordering.
function Get-CommanderSelectionKey($Commander) {
    $windowsUser = [string]$Commander.windowsUser
    if (-not [string]::IsNullOrWhiteSpace($windowsUser)) {
        return "user|$($windowsUser.Trim())"
    }

    return "name|$([string]$Commander.name)"
}

function Get-ProgramSelectionKey($Program) {
    $path = [string]$Program.path
    if (-not [string]::IsNullOrWhiteSpace($path)) {
        return "path|$($path.Trim())"
    }
    return "name|$([string]$Program.name)"
}

function Save-SelectionState {
    $commanderKeys = @()
    foreach ($i in $cmdList.CheckedIndices) {
        $index = [int]$i
        if ($index -ge 0 -and $index -lt @($config.commanders).Count) {
            $key = Get-CommanderSelectionKey $config.commanders[$index]
            if (-not [string]::IsNullOrWhiteSpace($key)) {
                $commanderKeys += $key
            }
        }
    }

    $programKeys = @()
    foreach ($i in $progList.CheckedIndices) {
        $index = [int]$i
        if ($index -ge 0 -and $index -lt @($config.programs).Count) {
            $key = Get-ProgramSelectionKey $config.programs[$index]
            if (-not [string]::IsNullOrWhiteSpace($key)) {
                $programKeys += $key
            }
        }
    }

    $config.selectedCommanderKeys = @($commanderKeys | Select-Object -Unique)
    $config.selectedProgramKeys = @($programKeys | Select-Object -Unique)
    Save-Config $config
}

function Update-Lists {
    $script:RestoringChecks = $true
    try {
        $savedCommanderKeys = @($config.selectedCommanderKeys)
        $savedProgramKeys = @($config.selectedProgramKeys)

        $cmdList.Items.Clear()
        foreach ($c in @($config.commanders)) {
            $index = $cmdList.Items.Add($c.name)
            $key = Get-CommanderSelectionKey $c
            if ($savedCommanderKeys -contains $key) {
                $cmdList.SetItemChecked($index, $true)
            }
        }

        $progList.Items.Clear()
        foreach ($p in @($config.programs)) {
            $index = $progList.Items.Add($p.name)
            $key = Get-ProgramSelectionKey $p
            if ($savedProgramKeys -contains $key) {
                $progList.SetItemChecked($index, $true)
            }
        }
    }
    finally {
        $script:RestoringChecks = $false
    }
}

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

try {

$config = Get-Config

if ($null -eq $config) {
    $config = [pscustomobject]@{}
}

foreach ($propertyName in @('commanders', 'programs', 'selectedCommanderKeys', 'selectedProgramKeys')) {
    if ($null -eq $config.PSObject.Properties[$propertyName]) {
        $config | Add-Member -MemberType NoteProperty -Name $propertyName -Value @()
    }
    elseif ($null -eq $config.$propertyName) {
        $config.$propertyName = @()
    }
}

if ($null -eq $config.PSObject.Properties['closeAfterLaunch']) {
    $config | Add-Member -MemberType NoteProperty -Name 'closeAfterLaunch' -Value $false
}
elseif ($null -eq $config.closeAfterLaunch) {
    $config.closeAfterLaunch = $false
}

$script:RestoringChecks = $false
# Gates every check-state change that isn't a list restore: only set to
# $true for the duration of a call this script itself intends (checkbox-
# glyph click, Select All/None) — see the ItemCheck handlers below, which
# cancel anything else so native single/double-click toggling never applies.
# Deliberately $global:, not $script: — the checkbox-glyph click sets this
# from inside a .GetNewClosure()'d scriptblock (see Add-CheckboxOnlyClick
# Behavior below), and GetNewClosure() binds a scriptblock to its own new
# dynamic module with an isolated script scope, so a $script: variable set
# there is invisible outside it. Global scope is the only scope that
# closure and this script actually share.
$global:AllowCheckToggle = $false

# -----------------------------------------------------------------------------
# Main form and controls
# -----------------------------------------------------------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "Elite Multibox Launcher"
$form.Size = New-Object System.Drawing.Size(900, 620)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(720, 500)
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.ForeColor = [System.Drawing.Color]::Gainsboro

$title = New-Object System.Windows.Forms.Label
$title.Text = "Elite Multibox Launcher"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(20, 15)
$title.Size = New-Object System.Drawing.Size(500, 40)
$title.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($title)

$lblCmd = New-Object System.Windows.Forms.Label
$lblCmd.Text = "COMMANDERS"
$lblCmd.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblCmd.Location = New-Object System.Drawing.Point(20, 70)
$lblCmd.Size = New-Object System.Drawing.Size(200, 25)
$lblCmd.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($lblCmd)

$lblProg = New-Object System.Windows.Forms.Label
$lblProg.Text = "PROGRAMS"
$lblProg.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblProg.Location = New-Object System.Drawing.Point(455, 70)
$lblProg.Size = New-Object System.Drawing.Size(200, 25)
$lblProg.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($lblProg)

$cmdList = New-Object System.Windows.Forms.CheckedListBox
# Off so Add-CheckboxOnlyClickBehavior's manual handling is the only thing
# driving check state — leaving the built-in behavior on too would fight
# with it (double-toggle on a single click).
$cmdList.CheckOnClick = $false
$cmdList.Location = New-Object System.Drawing.Point(20, 100)
$cmdList.Size = New-Object System.Drawing.Size(405, 350)
$cmdList.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($cmdList)

$progList = New-Object System.Windows.Forms.CheckedListBox
$progList.CheckOnClick = $false
$progList.Location = New-Object System.Drawing.Point(455, 100)
$progList.Size = New-Object System.Drawing.Size(405, 350)
$progList.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($progList)

Add-CheckboxOnlyClickBehavior $cmdList
Add-CheckboxOnlyClickBehavior $progList

$btnCmdAll = New-Object System.Windows.Forms.Button
$btnCmdAll.Text = "Select All"
$btnCmdAll.Location = New-Object System.Drawing.Point(20, 465)
$btnCmdAll.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnCmdAll.Size = New-Object System.Drawing.Size(85, 30)
$form.Controls.Add($btnCmdAll)

$btnCmdNone = New-Object System.Windows.Forms.Button
$btnCmdNone.Text = "Clear"
$btnCmdNone.Location = New-Object System.Drawing.Point(110, 465)
$btnCmdNone.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnCmdNone.Size = New-Object System.Drawing.Size(70, 30)
$form.Controls.Add($btnCmdNone)

$btnCmdAdd = New-Object System.Windows.Forms.Button
$btnCmdAdd.Text = "Add"
$btnCmdAdd.Location = New-Object System.Drawing.Point(185, 465)
$btnCmdAdd.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnCmdAdd.Size = New-Object System.Drawing.Size(70, 30)
$form.Controls.Add($btnCmdAdd)

$btnCmdEdit = New-Object System.Windows.Forms.Button
$btnCmdEdit.Text = "Edit"
$btnCmdEdit.Location = New-Object System.Drawing.Point(260, 465)
$btnCmdEdit.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnCmdEdit.Size = New-Object System.Drawing.Size(70, 30)
$form.Controls.Add($btnCmdEdit)

$btnCmdRemove = New-Object System.Windows.Forms.Button
$btnCmdRemove.Text = "Remove"
$btnCmdRemove.Location = New-Object System.Drawing.Point(335, 465)
$btnCmdRemove.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnCmdRemove.Size = New-Object System.Drawing.Size(90, 30)
$form.Controls.Add($btnCmdRemove)

$btnProgAll = New-Object System.Windows.Forms.Button
$btnProgAll.Text = "Select All"
$btnProgAll.Location = New-Object System.Drawing.Point(455, 465)
$btnProgAll.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnProgAll.Size = New-Object System.Drawing.Size(85, 30)
$form.Controls.Add($btnProgAll)

$btnProgNone = New-Object System.Windows.Forms.Button
$btnProgNone.Text = "Clear"
$btnProgNone.Location = New-Object System.Drawing.Point(545, 465)
$btnProgNone.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnProgNone.Size = New-Object System.Drawing.Size(70, 30)
$form.Controls.Add($btnProgNone)

$btnProgAdd = New-Object System.Windows.Forms.Button
$btnProgAdd.Text = "Add"
$btnProgAdd.Location = New-Object System.Drawing.Point(620, 465)
$btnProgAdd.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnProgAdd.Size = New-Object System.Drawing.Size(70, 30)
$form.Controls.Add($btnProgAdd)

$btnProgEdit = New-Object System.Windows.Forms.Button
$btnProgEdit.Text = "Edit"
$btnProgEdit.Location = New-Object System.Drawing.Point(695, 465)
$btnProgEdit.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnProgEdit.Size = New-Object System.Drawing.Size(70, 30)
$form.Controls.Add($btnProgEdit)

$btnProgRemove = New-Object System.Windows.Forms.Button
$btnProgRemove.Text = "Remove"
$btnProgRemove.Location = New-Object System.Drawing.Point(770, 465)
$btnProgRemove.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnProgRemove.Size = New-Object System.Drawing.Size(90, 30)
$form.Controls.Add($btnProgRemove)

$start = New-Object System.Windows.Forms.Button
$start.Text = "START SELECTED"
$start.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$start.Location = New-Object System.Drawing.Point(300, 525)
$start.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom
$start.Size = New-Object System.Drawing.Size(280, 45)
$form.Controls.Add($start)

$closeAfterLaunch = New-Object System.Windows.Forms.CheckBox
$closeAfterLaunch.Text = "Close launcher after starting"
$closeAfterLaunch.AutoSize = $true
$closeAfterLaunch.Location = New-Object System.Drawing.Point(350, 500)
$closeAfterLaunch.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom
$closeAfterLaunch.Checked = [bool]$config.closeAfterLaunch
$form.Controls.Add($closeAfterLaunch)

# -----------------------------------------------------------------------------
# Initial state and list persistence
# -----------------------------------------------------------------------------

Update-Lists

$cmdList.Add_ItemCheck({
    param($control, $e)
    if ($script:RestoringChecks) { return }
    if (-not $global:AllowCheckToggle) {
        # Not one of our own authorized calls — this is CheckedListBox's
        # native click/double-click/keyboard toggle trying to fire on its
        # own. Resetting NewValue to CurrentValue cancels it, which is what
        # makes the checkbox glyph the only thing that can check an item.
        $e.NewValue = $e.CurrentValue
        return
    }
    $form.BeginInvoke([System.Action]{ Save-SelectionState }) | Out-Null
})

$progList.Add_ItemCheck({
    param($control, $e)
    if ($script:RestoringChecks) { return }
    if (-not $global:AllowCheckToggle) {
        $e.NewValue = $e.CurrentValue
        return
    }
    $form.BeginInvoke([System.Action]{ Save-SelectionState }) | Out-Null
})

# -----------------------------------------------------------------------------
# Event handlers
# -----------------------------------------------------------------------------

$closeAfterLaunch.Add_CheckedChanged({
    $config.closeAfterLaunch = [bool]$closeAfterLaunch.Checked
    Save-Config $config
})

$btnCmdAll.Add_Click({
    # Same authorization flag as the checkbox-glyph click, so this bulk
    # check-setting isn't itself canceled by the new ItemCheck guard.
    $global:AllowCheckToggle = $true
    try {
        for ($i=0; $i -lt $cmdList.Items.Count; $i++) { $cmdList.SetItemChecked($i, $true) }
    }
    finally {
        $global:AllowCheckToggle = $false
    }
    $form.BeginInvoke([System.Action]{ Save-SelectionState }) | Out-Null
})

$btnCmdNone.Add_Click({
    $global:AllowCheckToggle = $true
    try {
        for ($i=0; $i -lt $cmdList.Items.Count; $i++) { $cmdList.SetItemChecked($i, $false) }
    }
    finally {
        $global:AllowCheckToggle = $false
    }
    $form.BeginInvoke([System.Action]{ Save-SelectionState }) | Out-Null
})

# Double-clicking a commander row opens a plain command prompt as that
# commander's Windows user — a quick way to check credentials/permissions
# for that account without adding cmd.exe as a saved program entry.
# IndexFromPoint (rather than SelectedIndex) is used so this only fires for
# the row actually under the cursor, independent of whatever the existing
# MouseDown/MouseUp checkbox handling left selected.
$cmdList.Add_MouseDoubleClick({
    param($control, $e)

    $index = $control.IndexFromPoint($e.Location)
    if ($index -lt 0 -or $index -ge @($config.commanders).Count) {
        return
    }

    $commander = $config.commanders[$index]
    # Reuses Start-AsUser with cmd.exe as a synthetic "program" instead of a
    # separate launch path, so this gets the same runas/quoting/error
    # handling as every other launch instead of a second copy of that logic.
    $cmdProgram = [pscustomobject]@{
        path      = $env:ComSpec
        arguments = ""
    }

    try {
        Start-AsUser $commander $cmdProgram
    }
    catch {
        Show-Error "Could not open a command prompt for $($commander.name): $($_.Exception.Message)"
    }
})

$btnProgAll.Add_Click({
    $global:AllowCheckToggle = $true
    try {
        for ($i=0; $i -lt $progList.Items.Count; $i++) { $progList.SetItemChecked($i, $true) }
    }
    finally {
        $global:AllowCheckToggle = $false
    }
    $form.BeginInvoke([System.Action]{ Save-SelectionState }) | Out-Null
})

$btnProgNone.Add_Click({
    $global:AllowCheckToggle = $true
    try {
        for ($i=0; $i -lt $progList.Items.Count; $i++) { $progList.SetItemChecked($i, $false) }
    }
    finally {
        $global:AllowCheckToggle = $false
    }
    $form.BeginInvoke([System.Action]{ Save-SelectionState }) | Out-Null
})

$btnCmdAdd.Add_Click({
    $new = New-CommanderDialog
    if ($new) {
        $config.commanders = @($config.commanders) + $new
        Save-Config $config
        Update-Lists
    }
})

$btnCmdEdit.Add_Click({
    $i = $cmdList.SelectedIndex
    if ($i -lt 0) { Show-Info "Select a commander first."; return }
    $edited = New-CommanderDialog $config.commanders[$i]
    if ($edited) {
        $arr = @($config.commanders)
        $arr[$i] = $edited
        $config.commanders = $arr
        Save-Config $config
        Update-Lists
    }
})

$btnCmdRemove.Add_Click({
    $i = $cmdList.SelectedIndex
    if ($i -lt 0) { Show-Info "Select a commander first."; return }

    $answer = [System.Windows.Forms.MessageBox]::Show(
        "Remove commander '$($config.commanders[$i].name)'?",
        "Confirm",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
        $arr = @($config.commanders)
        $config.commanders = @($arr | Where-Object { $_ -ne $arr[$i] })
        Save-Config $config
        Update-Lists
    }
})

$btnProgAdd.Add_Click({
    $new = New-ProgramDialog
    if ($new) {
        $config.programs = @($config.programs) + $new
        Save-Config $config
        Update-Lists
    }
})

$btnProgEdit.Add_Click({
    $i = $progList.SelectedIndex
    if ($i -lt 0) { Show-Info "Select a program first."; return }
    $edited = New-ProgramDialog $config.programs[$i]
    if ($edited) {
        $arr = @($config.programs)
        $arr[$i] = $edited
        $config.programs = $arr
        Save-Config $config
        Update-Lists
    }
})

$btnProgRemove.Add_Click({
    $i = $progList.SelectedIndex
    if ($i -lt 0) { Show-Info "Select a program first."; return }

    $answer = [System.Windows.Forms.MessageBox]::Show(
        "Remove program '$($config.programs[$i].name)'?",
        "Confirm",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
        $arr = @($config.programs)
        $config.programs = @($arr | Where-Object { $_ -ne $arr[$i] })
        Save-Config $config
        Update-Lists
    }
})

$start.Add_Click({
    $selectedCommanders = @()
    foreach ($i in $cmdList.CheckedIndices) {
        $selectedCommanders += $config.commanders[[int]$i]
    }

    $selectedPrograms = @()
    foreach ($i in $progList.CheckedIndices) {
        $selectedPrograms += $config.programs[[int]$i]
    }

    if ($selectedCommanders.Count -eq 0) {
        Show-Info "Select at least one Commander."
        return
    }

    if ($selectedPrograms.Count -eq 0) {
        Show-Info "Select at least one program."
        return
    }

    $errors = @()

    # Every checked program is launched for every checked commander (a full
    # cross product), matching the two independent checklists in the UI —
    # e.g. 3 commanders x 2 programs queues 6 launches, one per pairing.
    foreach ($commander in $selectedCommanders) {
        foreach ($program in $selectedPrograms) {
            try {
                Start-AsUser $commander $program
                Start-Sleep -Milliseconds 250
            }
            catch {
                $errors += "$($commander.name) / $($program.name): $($_.Exception.Message)"
            }
        }
    }

    if ($errors.Count -gt 0) {
        Show-Error ("Some programs could not be started:`r`n`r`n" + ($errors -join "`r`n"))
    }
    elseif ($closeAfterLaunch.Checked) {
        $form.Close()
    }
})

$form.Add_FormClosing({
    Save-SelectionState
})

# -----------------------------------------------------------------------------
# Start UI
# -----------------------------------------------------------------------------

Set-DarkTheme $form
[void]$form.ShowDialog()

}
catch {
    Show-Error "Unexpected error:`r`n`r`n$($_.Exception.Message)`r`n`r`n$($_.ScriptStackTrace)"
}
