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

# -----------------------------------------------------------------------------
# Global constants / editable settings
# -----------------------------------------------------------------------------
# Sizes and positions are in pixels.
# Message templates use {0}, {1}, etc.

# Email tooltip hover delay in milliseconds (2500 = 2.5 seconds).
$EmailHoverDelayMs = 2500

# Visible text and message templates
$script:LauncherText = @{
    # Add-entry button text for both lists.
    AddButton = "Add"
    # Title of the commander add dialog.
    AddCommanderTitle = "Add Commander"
    # Title of the program add dialog.
    AddProgramTitle = "Add Program"
    # Main window title, heading, and information/error dialog title.
    AppTitle = "Elite Multibox Launcher"
    # Program file browser button text.
    BrowseButton = "Browse..."
    # Cancel button text in both editor dialogs.
    CancelButton = "Cancel"
    # Clear-selection button text for both lists.
    ClearButton = "Clear"
    # Close-after-launch checkbox text.
    CloseAfterLaunchLabel = "Close launcher after starting"
    # Command prompt error; {0} = commander, {1} = exception message.
    CommandPromptError = "Could not open a command prompt for {0}: {1}"
    # Commander display-name field label.
    CommanderNameLabel = "Display name"
    # Validation error for an empty commander name.
    CommanderNameRequired = "Display name is required."
    # Main window commander-list heading.
    CommandersHeading = "COMMANDERS"
    # Configuration read error; {0} = exception message.
    ConfigReadError = "Could not read config.json.`r`n`r`n{0}"
    # Configuration save error; {0} = path, {1} = exception message.
    ConfigSaveError = "Could not save config.json to:`r`n{0}`r`n`r`n{1}`r`n`r`n"
    # Save error help, first segment; preserve the trailing space.
    ConfigSaveHelpFolder = "This folder may be read-only (e.g. Program Files) or synced/locked by another process. "
    # Save error help, second segment; preserve the trailing space.
    ConfigSaveHelpMove = "Move EliteMultiboxLauncher.ps1 (and EliteMultiboxLauncher.vbs) to a folder you have write access to, "
    # Save error help, final segment.
    ConfigSaveHelpRetry = "such as your Documents folder, and try again. Your changes were not saved."
    # Removal confirmation dialog title.
    ConfirmationTitle = "Confirm"
    # Edit-entry button text for both lists.
    EditButton = "Edit"
    # Title of the commander edit dialog.
    EditCommanderTitle = "Edit Commander"
    # Title of the program edit dialog.
    EditProgramTitle = "Edit Program"
    # Optional email field label.
    EmailLabel = "Email (optional)"
    # Email tooltip; {0} = commander email.
    EmailTooltip = "Email: {0}"
    # One launch failure; {0} = commander, {1} = program, {2} = exception message.
    LaunchErrorDetail = "{0} / {1}: {2}"
    # Heading before the list of failed launches; includes two line breaks.
    LaunchErrorsHeading = "Some programs could not be started:`r`n`r`n"
    # MinEdLauncher profile field label.
    MinEdProfileLabel = "min-ed-profile"
    # Program arguments field label.
    ProgramArgumentsLabel = "Arguments"
    # Validation error for an empty program name or path.
    ProgramFieldsRequired = "Program name and path are required."
    # File picker filters; retain the description|pattern pair syntax.
    ProgramFileFilter = "Programs (*.exe;*.cmd;*.bat)|*.exe;*.cmd;*.bat|All files (*.*)|*.*"
    # Program name field label.
    ProgramNameLabel = "Name"
    # Missing executable message; {0} = expanded program path.
    ProgramNotFound = "Program not found: {0}"
    # Program executable path field label.
    ProgramPathLabel = "Path"
    # Wildcard help shown beneath program arguments.
    ProgramVariablesHint = "Variables: {Commander}   {WindowsUser}   {MinEdProfile}"
    # Main window program-list heading.
    ProgramsHeading = "PROGRAMS"
    # Remove-entry button text for both lists.
    RemoveButton = "Remove"
    # Commander removal confirmation; {0} = commander name.
    RemoveCommanderPrompt = "Remove commander '{0}'?"
    # Program removal confirmation; {0} = program name.
    RemoveProgramPrompt = "Remove program '{0}'?"
    # Error when Windows fails to start RunAs.
    RunAsStartError = "RUNAS could not be started."
    # Save button text in both editor dialogs.
    SaveButton = "Save"
    # Select-all button text for both lists.
    SelectAllButton = "Select All"
    # Prompt when editing/removing without a selected commander.
    SelectCommanderFirst = "Select a commander first."
    # Prompt when launching without a checked commander.
    SelectCommanderToLaunch = "Select at least one Commander."
    # Prompt when editing/removing without a selected program.
    SelectProgramFirst = "Select a program first."
    # Prompt when launching without a checked program.
    SelectProgramToLaunch = "Select at least one program."
    # Main launch button text.
    StartButton = "START SELECTED"
    # Unexpected error; {0} = exception message, {1} = script stack trace.
    UnexpectedError = "Unexpected error:`r`n`r`n{0}`r`n`r`n{1}"
    # Commander RunAs checkbox text.
    UseRunAsLabel = "Use RunAs (different Windows user)"
    # Windows account field label.
    WindowsUserLabel = "Windows user"
    # Validation error for a double quote in the Windows user.
    WindowsUserQuoteError = "Windows user cannot contain a double-quote (`") character."
    # Validation error for an empty Windows user when RunAs is enabled.
    WindowsUserRequired = "Windows user is required when Use RunAs is enabled."
}

# Behavior, defaults, timing and fonts
$script:LauncherSettings = @{
    # Program name sorted to the top; comparison remains case-insensitive.
    PriorityProgramName = "Elite Dangerous"
    # Configuration filename relative to the script folder.
    ConfigFileName = "config.json"
    # Font family for the title, section headings, and launch button.
    FontFamily = "Segoe UI"
    # Wait after each successful program launch, in milliseconds.
    LaunchDelayMs = 250
    # How long the email tooltip remains visible, in milliseconds.
    EmailTooltipDurationMs = 5000
    # Email tooltip horizontal offset from the pointer, in pixels.
    EmailTooltipOffsetX = 12
    # Email tooltip vertical offset from the pointer, in pixels.
    EmailTooltipOffsetY = 20
    # Rightmost clickable checkbox coordinate within a list row, in pixels.
    CheckboxHitWidth = 18
    # Maximum JSON serialization depth used when saving configuration.
    ConfigJsonDepth = 10
    # RunAs default for new commanders and older entries without the setting.
    DefaultUseRunAs = $true
    # Close-after-launch default when the saved setting is absent or null.
    DefaultCloseAfterLaunch = $false
    # Main title font size, in points.
    TitleFontSize = 18
    # Both list heading font sizes, in points.
    HeadingFontSize = 10
    # Main launch button font size, in points.
    StartButtonFontSize = 12
}

# Shared theme colors
$script:LauncherColors = @{
    # Window, dialog, and RunAs checkbox background.
    Background = [System.Drawing.Color]::FromArgb(30, 30, 30)
    # Button background.
    ButtonBackground = [System.Drawing.Color]::FromArgb(55, 55, 55)
    # Flat-button border color.
    ButtonBorder = [System.Drawing.Color]::FromArgb(85, 85, 85)
    # Text-entry field background.
    TextBoxBackground = [System.Drawing.Color]::FromArgb(45, 45, 45)
    # Checked-list background.
    ListBackground = [System.Drawing.Color]::FromArgb(40, 40, 40)
    # Default window, dialog, and label text color.
    Foreground = [System.Drawing.Color]::Gainsboro
    # Button, text-field, and list text color.
    ControlForeground = [System.Drawing.Color]::White
    # Initial program wildcard-hint text color; existing theme traversal is unchanged.
    HintForeground = [System.Drawing.Color]::DimGray
    # Label background color.
    LabelBackground = [System.Drawing.Color]::Transparent
}

# Window and control geometry
$script:LauncherLayout = @{
    # Commander Dialog size (width, height), in pixels.
    CommanderDialogSize = New-Object System.Drawing.Size(430, 335)
    # Commander Field Label size (width, height), in pixels.
    CommanderFieldLabelSize = New-Object System.Drawing.Size(110, 24)
    # Commander Field Input size (width, height), in pixels.
    CommanderFieldInputSize = New-Object System.Drawing.Size(255, 25)
    # Commander Use Run As position (X, Y), in pixels.
    CommanderUseRunAsLocation = New-Object System.Drawing.Point(135, 202)
    # Commander Use Run As size (width, height), in pixels.
    CommanderUseRunAsSize = New-Object System.Drawing.Size(255, 24)
    # Commander Save Button position (X, Y), in pixels.
    CommanderSaveButtonLocation = New-Object System.Drawing.Point(215, 250)
    # Commander Save Button size (width, height), in pixels.
    CommanderSaveButtonSize = New-Object System.Drawing.Size(80, 30)
    # Commander Cancel Button position (X, Y), in pixels.
    CommanderCancelButtonLocation = New-Object System.Drawing.Point(310, 250)
    # Commander Cancel Button size (width, height), in pixels.
    CommanderCancelButtonSize = New-Object System.Drawing.Size(80, 30)
    # Program Dialog size (width, height), in pixels.
    ProgramDialogSize = New-Object System.Drawing.Size(640, 280)
    # Program Name Label position (X, Y), in pixels.
    ProgramNameLabelLocation = New-Object System.Drawing.Point(20, 25)
    # Program Name Label size (width, height), in pixels.
    ProgramNameLabelSize = New-Object System.Drawing.Size(80, 24)
    # Program Name Input position (X, Y), in pixels.
    ProgramNameInputLocation = New-Object System.Drawing.Point(105, 22)
    # Program Name Input size (width, height), in pixels.
    ProgramNameInputSize = New-Object System.Drawing.Size(490, 25)
    # Program Path Label position (X, Y), in pixels.
    ProgramPathLabelLocation = New-Object System.Drawing.Point(20, 70)
    # Program Path Label size (width, height), in pixels.
    ProgramPathLabelSize = New-Object System.Drawing.Size(80, 24)
    # Program Path Input position (X, Y), in pixels.
    ProgramPathInputLocation = New-Object System.Drawing.Point(105, 67)
    # Program Path Input size (width, height), in pixels.
    ProgramPathInputSize = New-Object System.Drawing.Size(395, 25)
    # Program Browse Button position (X, Y), in pixels.
    ProgramBrowseButtonLocation = New-Object System.Drawing.Point(510, 65)
    # Program Browse Button size (width, height), in pixels.
    ProgramBrowseButtonSize = New-Object System.Drawing.Size(85, 28)
    # Program Arguments Label position (X, Y), in pixels.
    ProgramArgumentsLabelLocation = New-Object System.Drawing.Point(20, 115)
    # Program Arguments Label size (width, height), in pixels.
    ProgramArgumentsLabelSize = New-Object System.Drawing.Size(80, 24)
    # Program Arguments Input position (X, Y), in pixels.
    ProgramArgumentsInputLocation = New-Object System.Drawing.Point(105, 112)
    # Program Arguments Input size (width, height), in pixels.
    ProgramArgumentsInputSize = New-Object System.Drawing.Size(490, 25)
    # Program Variables Hint position (X, Y), in pixels.
    ProgramVariablesHintLocation = New-Object System.Drawing.Point(105, 142)
    # Program Variables Hint size (width, height), in pixels.
    ProgramVariablesHintSize = New-Object System.Drawing.Size(420, 22)
    # Program Save Button position (X, Y), in pixels.
    ProgramSaveButtonLocation = New-Object System.Drawing.Point(420, 190)
    # Program Save Button size (width, height), in pixels.
    ProgramSaveButtonSize = New-Object System.Drawing.Size(80, 30)
    # Program Cancel Button position (X, Y), in pixels.
    ProgramCancelButtonLocation = New-Object System.Drawing.Point(515, 190)
    # Program Cancel Button size (width, height), in pixels.
    ProgramCancelButtonSize = New-Object System.Drawing.Size(80, 30)
    # Main Window size (width, height), in pixels.
    MainWindowSize = New-Object System.Drawing.Size(900, 620)
    # Main Window minimum size (width, height), in pixels.
    MainWindowMinimumSize = New-Object System.Drawing.Size(720, 500)
    # Title position (X, Y), in pixels.
    TitleLocation = New-Object System.Drawing.Point(20, 15)
    # Title size (width, height), in pixels.
    TitleSize = New-Object System.Drawing.Size(500, 40)
    # Commanders Heading position (X, Y), in pixels.
    CommandersHeadingLocation = New-Object System.Drawing.Point(20, 70)
    # Commanders Heading size (width, height), in pixels.
    CommandersHeadingSize = New-Object System.Drawing.Size(200, 25)
    # Programs Heading position (X, Y), in pixels.
    ProgramsHeadingLocation = New-Object System.Drawing.Point(455, 70)
    # Programs Heading size (width, height), in pixels.
    ProgramsHeadingSize = New-Object System.Drawing.Size(200, 25)
    # Commanders List position (X, Y), in pixels.
    CommandersListLocation = New-Object System.Drawing.Point(20, 100)
    # Commanders List size (width, height), in pixels.
    CommandersListSize = New-Object System.Drawing.Size(405, 350)
    # Programs List position (X, Y), in pixels.
    ProgramsListLocation = New-Object System.Drawing.Point(455, 100)
    # Programs List size (width, height), in pixels.
    ProgramsListSize = New-Object System.Drawing.Size(405, 350)
    # Commanders Select All position (X, Y), in pixels.
    CommandersSelectAllLocation = New-Object System.Drawing.Point(20, 465)
    # Commanders Select All size (width, height), in pixels.
    CommandersSelectAllSize = New-Object System.Drawing.Size(85, 30)
    # Commanders Clear position (X, Y), in pixels.
    CommandersClearLocation = New-Object System.Drawing.Point(110, 465)
    # Commanders Clear size (width, height), in pixels.
    CommandersClearSize = New-Object System.Drawing.Size(70, 30)
    # Commanders Add position (X, Y), in pixels.
    CommandersAddLocation = New-Object System.Drawing.Point(185, 465)
    # Commanders Add size (width, height), in pixels.
    CommandersAddSize = New-Object System.Drawing.Size(70, 30)
    # Commanders Edit position (X, Y), in pixels.
    CommandersEditLocation = New-Object System.Drawing.Point(260, 465)
    # Commanders Edit size (width, height), in pixels.
    CommandersEditSize = New-Object System.Drawing.Size(70, 30)
    # Commanders Remove position (X, Y), in pixels.
    CommandersRemoveLocation = New-Object System.Drawing.Point(335, 465)
    # Commanders Remove size (width, height), in pixels.
    CommandersRemoveSize = New-Object System.Drawing.Size(90, 30)
    # Programs Select All position (X, Y), in pixels.
    ProgramsSelectAllLocation = New-Object System.Drawing.Point(455, 465)
    # Programs Select All size (width, height), in pixels.
    ProgramsSelectAllSize = New-Object System.Drawing.Size(85, 30)
    # Programs Clear position (X, Y), in pixels.
    ProgramsClearLocation = New-Object System.Drawing.Point(545, 465)
    # Programs Clear size (width, height), in pixels.
    ProgramsClearSize = New-Object System.Drawing.Size(70, 30)
    # Programs Add position (X, Y), in pixels.
    ProgramsAddLocation = New-Object System.Drawing.Point(620, 465)
    # Programs Add size (width, height), in pixels.
    ProgramsAddSize = New-Object System.Drawing.Size(70, 30)
    # Programs Edit position (X, Y), in pixels.
    ProgramsEditLocation = New-Object System.Drawing.Point(695, 465)
    # Programs Edit size (width, height), in pixels.
    ProgramsEditSize = New-Object System.Drawing.Size(70, 30)
    # Programs Remove position (X, Y), in pixels.
    ProgramsRemoveLocation = New-Object System.Drawing.Point(770, 465)
    # Programs Remove size (width, height), in pixels.
    ProgramsRemoveSize = New-Object System.Drawing.Size(90, 30)
    # Start Button position (X, Y), in pixels.
    StartButtonLocation = New-Object System.Drawing.Point(300, 525)
    # Start Button size (width, height), in pixels.
    StartButtonSize = New-Object System.Drawing.Size(280, 45)
    # Close After Launch position (X, Y), in pixels.
    CloseAfterLaunchLocation = New-Object System.Drawing.Point(350, 500)
    # Commander form label X coordinate, in pixels.
    CommanderFieldLabelX = 20
    # Commander form input X coordinate, in pixels.
    CommanderFieldInputX = 135
    # First commander field label Y coordinate, in pixels.
    CommanderFieldLabelStartY = 25
    # Vertical distance between commander field rows, in pixels.
    CommanderFieldRowSpacing = 45
    # First commander field input Y coordinate, in pixels.
    CommanderFieldInputStartY = 22
}

# Technical strings and compatibility values
$script:LauncherTechnical = @{
    # One space between the executable and its expanded arguments.
    ArgumentSeparator = " "
    # Existing JSON boolean property; must match the configuration schema.
    CloseAfterLaunchProperty = 'closeAfterLaunch'
    # Exact wildcard token replaced by the commander name.
    CommanderWildcard = "{Commander}"
    # Existing JSON array property name; must match the configuration schema.
    CommandersProperty = 'commanders'
    # Configuration text encoding; preserves Windows PowerShell UTF8 behavior.
    ConfigEncoding = "UTF8"
    # Editor window border mode; preserves fixed dialog sizing.
    DialogBorderStyle = "FixedDialog"
    # Editor window positioning mode.
    DialogStartPosition = "CenterParent"
    # Literal double quote used in validation and RunAs command construction.
    DoubleQuote = '"'
    # Empty text used for optional fields, no arguments, and cleared tooltips.
    EmptyString = ""
    # PowerShell error policy; Stop preserves the existing exception handling.
    ErrorAction = "Stop"
    # Replacement text used to escape command quotes for RunAs.
    EscapedDoubleQuote = '\"'
    # Main window initial positioning mode.
    MainStartPosition = "CenterScreen"
    # Exact wildcard token replaced by the MinEdLauncher profile.
    MinEdProfileWildcard = "{MinEdProfile}"
    # Saved name selection key; {0} = name. Keep compatible with config.json.
    NameSelectionKey = "name|{0}"
    # Windows CRLF separator between launch errors.
    NewLine = "`r`n"
    # Saved program selection key; {0} = trimmed path. Keep compatible with config.json.
    PathSelectionKey = "path|{0}"
    # Existing JSON array property name; must match the configuration schema.
    ProgramsProperty = 'programs'
    # RunAs executable template; {0} = Windows system root. Preserve the system-relative path.
    RunAsPath = "{0}\System32\runas.exe"
    # RunAs argument separator; preserves credential saving and command quoting.
    RunAsSaveCredentialSeparator = '" /savecred "'
    # RunAs argument prefix, including the opening Windows-user quote.
    RunAsUserPrefix = '/user:"'
    # Existing JSON selection property; must match the configuration schema.
    SelectedCommanderKeysProperty = 'selectedCommanderKeys'
    # Existing JSON selection property; must match the configuration schema.
    SelectedProgramKeysProperty = 'selectedProgramKeys'
    # Existing JSON property name; must match the commander object schema.
    UseRunAsProperty = 'useRunAs'
    # Saved user selection key; {0} = trimmed Windows user. Keep compatible with config.json.
    UserSelectionKey = "user|{0}"
    # Exact wildcard token replaced by the Windows user.
    WindowsUserWildcard = "{WindowsUser}"
}

$ErrorActionPreference = $script:LauncherTechnical.ErrorAction

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir $script:LauncherSettings.ConfigFileName


# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

function Show-Error([string]$Message) {
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $script:LauncherText.AppTitle,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Show-Info([string]$Message) {
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $script:LauncherText.AppTitle,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Set-DarkTheme($Control) {
    $Control.BackColor = $script:LauncherColors.Background
    $Control.ForeColor = $script:LauncherColors.Foreground

    foreach ($child in $Control.Controls) {
        if ($child -is [System.Windows.Forms.Button]) {
            $child.BackColor = $script:LauncherColors.ButtonBackground
            $child.ForeColor = $script:LauncherColors.ControlForeground
            $child.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
            $child.FlatAppearance.BorderColor = $script:LauncherColors.ButtonBorder
        }
        elseif ($child -is [System.Windows.Forms.TextBox]) {
            $child.BackColor = $script:LauncherColors.TextBoxBackground
            $child.ForeColor = $script:LauncherColors.ControlForeground
            $child.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        }
        elseif ($child -is [System.Windows.Forms.CheckedListBox]) {
            $child.BackColor = $script:LauncherColors.ListBackground
            $child.ForeColor = $script:LauncherColors.ControlForeground
            $child.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        }
        elseif ($child -is [System.Windows.Forms.Label]) {

            if ($child.ForeColor -eq [System.Drawing.Color]::Empty -or
                $child.ForeColor -eq [System.Drawing.SystemColors]::ControlText) {
                $child.ForeColor = $script:LauncherColors.Foreground
            }
            $child.BackColor = $script:LauncherColors.LabelBackground
        }

        if ($child.HasChildren) {
            Set-DarkTheme $child
        }
    }
}

function Get-Config {
    if (-not (Test-Path $ConfigPath)) {
        $default = @{
            commanders            = @()
            programs              = @()
            selectedCommanderKeys = @()
            selectedProgramKeys   = @()
        }
        $default | ConvertTo-Json -Depth $script:LauncherSettings.ConfigJsonDepth | Set-Content -Path $ConfigPath -Encoding $script:LauncherTechnical.ConfigEncoding
    }

    try {
        return Get-Content $ConfigPath -Raw -Encoding $script:LauncherTechnical.ConfigEncoding | ConvertFrom-Json
    }
    catch {
        Show-Error ($script:LauncherText.ConfigReadError -f $_.Exception.Message)
        throw
    }
}

function Save-Config($Config) {
    try {
        $Config | ConvertTo-Json -Depth $script:LauncherSettings.ConfigJsonDepth | Set-Content -Path $ConfigPath -Encoding $script:LauncherTechnical.ConfigEncoding
    }
    catch {
        Show-Error (($script:LauncherText.ConfigSaveError -f $ConfigPath, $_.Exception.Message) +
            $script:LauncherText.ConfigSaveHelpFolder +
            $script:LauncherText.ConfigSaveHelpMove +
            $script:LauncherText.ConfigSaveHelpRetry)
    }
}

function Expand-ProgramArgs([string]$Arguments, $Commander) {
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        return $script:LauncherTechnical.EmptyString
    }

    $windowsUser = [string]$Commander.windowsUser
    if ([string]::IsNullOrWhiteSpace($windowsUser)) {
        $windowsUser = [string]$env:USERNAME
    }

    $result = $Arguments
    $result = $result.Replace($script:LauncherTechnical.CommanderWildcard, [string]$Commander.name)
    $result = $result.Replace($script:LauncherTechnical.WindowsUserWildcard, $windowsUser)
    $result = $result.Replace($script:LauncherTechnical.MinEdProfileWildcard, [string]$Commander.minEdProfile)
    return $result
}

function Start-AsUser($Commander, $Program) {
    $path = Expand-ProgramArgs ([string]$Program.path) $Commander
    if (-not (Test-Path $path)) {
        throw ($script:LauncherText.ProgramNotFound -f $path)
    }

    $expandedArgs = Expand-ProgramArgs ([string]$Program.arguments) $Commander

    $useRunAs = $script:LauncherSettings.DefaultUseRunAs
    if ($null -ne $Commander.PSObject.Properties[$script:LauncherTechnical.UseRunAsProperty] -and $null -ne $Commander.useRunAs) {
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

    $command = $script:LauncherTechnical.DoubleQuote + $path + $script:LauncherTechnical.DoubleQuote
    if (-not [string]::IsNullOrWhiteSpace($expandedArgs)) {
        $command += $script:LauncherTechnical.ArgumentSeparator + $expandedArgs
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = ($script:LauncherTechnical.RunAsPath -f $env:SystemRoot)
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $false
    $psi.Arguments = $script:LauncherTechnical.RunAsUserPrefix + [string]$Commander.windowsUser + $script:LauncherTechnical.RunAsSaveCredentialSeparator + ($command -replace $script:LauncherTechnical.DoubleQuote,$script:LauncherTechnical.EscapedDoubleQuote) + $script:LauncherTechnical.DoubleQuote

    $proc = [System.Diagnostics.Process]::Start($psi)
    if ($null -eq $proc) {
        throw $script:LauncherText.RunAsStartError
    }
}

function New-CommanderDialog($Existing = $null) {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = if ($Existing) { $script:LauncherText.EditCommanderTitle } else { $script:LauncherText.AddCommanderTitle }
    $f.Size = $script:LauncherLayout.CommanderDialogSize
    $f.StartPosition = $script:LauncherTechnical.DialogStartPosition
    $f.FormBorderStyle = $script:LauncherTechnical.DialogBorderStyle
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false

    $labels = @($script:LauncherText.CommanderNameLabel, $script:LauncherText.WindowsUserLabel, $script:LauncherText.MinEdProfileLabel, $script:LauncherText.EmailLabel)
    $values = @(
        $(if ($Existing) { [string]$Existing.name } else { $script:LauncherTechnical.EmptyString }),
        $(if ($Existing) { [string]$Existing.windowsUser } else { $script:LauncherTechnical.EmptyString }),
        $(if ($Existing) { [string]$Existing.minEdProfile } else { $script:LauncherTechnical.EmptyString }),
        $(if ($Existing) { [string]$Existing.email } else { $script:LauncherTechnical.EmptyString })
    )

    $boxes = @()
    for ($i=0; $i -lt 4; $i++) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $labels[$i]
        $lbl.Location = New-Object System.Drawing.Point($script:LauncherLayout.CommanderFieldLabelX, ($script:LauncherLayout.CommanderFieldLabelStartY + $i*$script:LauncherLayout.CommanderFieldRowSpacing))
        $lbl.Size = $script:LauncherLayout.CommanderFieldLabelSize
        $f.Controls.Add($lbl)

        $tb = New-Object System.Windows.Forms.TextBox
        $tb.Location = New-Object System.Drawing.Point($script:LauncherLayout.CommanderFieldInputX, ($script:LauncherLayout.CommanderFieldInputStartY + $i*$script:LauncherLayout.CommanderFieldRowSpacing))
        $tb.Size = $script:LauncherLayout.CommanderFieldInputSize
        $tb.Text = $values[$i]
        $f.Controls.Add($tb)
        $boxes += $tb
    }

    $chkUseRunAs = New-Object System.Windows.Forms.CheckBox
    $chkUseRunAs.Text = $script:LauncherText.UseRunAsLabel
    $chkUseRunAs.Location = $script:LauncherLayout.CommanderUseRunAsLocation
    $chkUseRunAs.Size = $script:LauncherLayout.CommanderUseRunAsSize
    $chkUseRunAs.BackColor = $script:LauncherColors.Background
    $chkUseRunAs.ForeColor = $script:LauncherColors.Foreground
    $chkUseRunAs.Checked = $script:LauncherSettings.DefaultUseRunAs
    if ($Existing -and $null -ne $Existing.PSObject.Properties[$script:LauncherTechnical.UseRunAsProperty] -and $null -ne $Existing.useRunAs) {
        $chkUseRunAs.Checked = [bool]$Existing.useRunAs
    }
    $f.Controls.Add($chkUseRunAs)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = $script:LauncherText.SaveButton
    $ok.Location = $script:LauncherLayout.CommanderSaveButtonLocation
    $ok.Size = $script:LauncherLayout.CommanderSaveButtonSize
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $f.AcceptButton = $ok
    $f.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = $script:LauncherText.CancelButton
    $cancel.Location = $script:LauncherLayout.CommanderCancelButtonLocation
    $cancel.Size = $script:LauncherLayout.CommanderCancelButtonSize
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $f.CancelButton = $cancel
    $f.Controls.Add($cancel)

    Set-DarkTheme $f
    if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if ([string]::IsNullOrWhiteSpace($boxes[0].Text)) {
            Show-Error $script:LauncherText.CommanderNameRequired
            return $null
        }

        if ($chkUseRunAs.Checked -and [string]::IsNullOrWhiteSpace($boxes[1].Text)) {
            Show-Error $script:LauncherText.WindowsUserRequired
            return $null
        }

        if ($boxes[1].Text -match $script:LauncherTechnical.DoubleQuote) {
            Show-Error $script:LauncherText.WindowsUserQuoteError
            return $null
        }

        return [pscustomobject]@{
            name          = $boxes[0].Text.Trim()
            windowsUser   = $boxes[1].Text.Trim()
            minEdProfile  = $boxes[2].Text.Trim()
            email         = $boxes[3].Text.Trim()
            useRunAs      = [bool]$chkUseRunAs.Checked
        }
    }

    return $null
}

function New-ProgramDialog($Existing = $null) {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = if ($Existing) { $script:LauncherText.EditProgramTitle } else { $script:LauncherText.AddProgramTitle }
    $f.Size = $script:LauncherLayout.ProgramDialogSize
    $f.StartPosition = $script:LauncherTechnical.DialogStartPosition
    $f.FormBorderStyle = $script:LauncherTechnical.DialogBorderStyle
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false

    $lblName = New-Object System.Windows.Forms.Label
    $lblName.Text = $script:LauncherText.ProgramNameLabel
    $lblName.Location = $script:LauncherLayout.ProgramNameLabelLocation
    $lblName.Size = $script:LauncherLayout.ProgramNameLabelSize
    $f.Controls.Add($lblName)

    $txtName = New-Object System.Windows.Forms.TextBox
    $txtName.Location = $script:LauncherLayout.ProgramNameInputLocation
    $txtName.Size = $script:LauncherLayout.ProgramNameInputSize
    if ($Existing) { $txtName.Text = [string]$Existing.name }
    $f.Controls.Add($txtName)

    $lblPath = New-Object System.Windows.Forms.Label
    $lblPath.Text = $script:LauncherText.ProgramPathLabel
    $lblPath.Location = $script:LauncherLayout.ProgramPathLabelLocation
    $lblPath.Size = $script:LauncherLayout.ProgramPathLabelSize
    $f.Controls.Add($lblPath)

    $txtPath = New-Object System.Windows.Forms.TextBox
    $txtPath.Location = $script:LauncherLayout.ProgramPathInputLocation
    $txtPath.Size = $script:LauncherLayout.ProgramPathInputSize
    if ($Existing) { $txtPath.Text = [string]$Existing.path }
    $f.Controls.Add($txtPath)

    $browse = New-Object System.Windows.Forms.Button
    $browse.Text = $script:LauncherText.BrowseButton
    $browse.Location = $script:LauncherLayout.ProgramBrowseButtonLocation
    $browse.Size = $script:LauncherLayout.ProgramBrowseButtonSize
    $f.Controls.Add($browse)

    $browse.Add_Click({
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Filter = $script:LauncherText.ProgramFileFilter
        if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtPath.Text = $ofd.FileName
        }
    })

    $lblArgs = New-Object System.Windows.Forms.Label
    $lblArgs.Text = $script:LauncherText.ProgramArgumentsLabel
    $lblArgs.Location = $script:LauncherLayout.ProgramArgumentsLabelLocation
    $lblArgs.Size = $script:LauncherLayout.ProgramArgumentsLabelSize
    $f.Controls.Add($lblArgs)

    $txtArgs = New-Object System.Windows.Forms.TextBox
    $txtArgs.Location = $script:LauncherLayout.ProgramArgumentsInputLocation
    $txtArgs.Size = $script:LauncherLayout.ProgramArgumentsInputSize
    if ($Existing) { $txtArgs.Text = [string]$Existing.arguments }
    $f.Controls.Add($txtArgs)

    $hint = New-Object System.Windows.Forms.Label
    $hint.Text = $script:LauncherText.ProgramVariablesHint
    $hint.Location = $script:LauncherLayout.ProgramVariablesHintLocation
    $hint.Size = $script:LauncherLayout.ProgramVariablesHintSize
    $hint.ForeColor = $script:LauncherColors.HintForeground
    $f.Controls.Add($hint)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = $script:LauncherText.SaveButton
    $ok.Location = $script:LauncherLayout.ProgramSaveButtonLocation
    $ok.Size = $script:LauncherLayout.ProgramSaveButtonSize
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $f.AcceptButton = $ok
    $f.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = $script:LauncherText.CancelButton
    $cancel.Location = $script:LauncherLayout.ProgramCancelButtonLocation
    $cancel.Size = $script:LauncherLayout.ProgramCancelButtonSize
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $f.CancelButton = $cancel
    $f.Controls.Add($cancel)

    Set-DarkTheme $f
    if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if ([string]::IsNullOrWhiteSpace($txtName.Text) -or
            [string]::IsNullOrWhiteSpace($txtPath.Text)) {
            Show-Error $script:LauncherText.ProgramFieldsRequired
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

function Add-CheckboxOnlyClickBehavior($List) {
    $List.Add_MouseDown({
        param($control, $e)

        $index = $control.IndexFromPoint($e.Location)
        if ($index -lt 0) {
            $control.Tag = $null
            return
        }

        $control.Tag = [PSCustomObject]@{
            Index       = $index
            CheckboxHit = ($e.X -ge 0 -and $e.X -le $script:LauncherSettings.CheckboxHitWidth)
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

        $control.SelectedIndex = $index

        if ($null -eq $clickState -or
            -not $clickState.CheckboxHit -or
            $clickState.Index -ne $index) {
            return
        }

        $targetIndex = [int]$clickState.Index
        $targetChecked = -not [bool]$clickState.WasChecked
        $targetList = $control

        $action = {
            if ($targetIndex -ge 0 -and $targetIndex -lt $targetList.Items.Count) {

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

function Get-CommanderSelectionKey($Commander) {
    $windowsUser = [string]$Commander.windowsUser
    if (-not [string]::IsNullOrWhiteSpace($windowsUser)) {
        return ($script:LauncherTechnical.UserSelectionKey -f $windowsUser.Trim())
    }

    return ($script:LauncherTechnical.NameSelectionKey -f ([string]$Commander.name))
}

function Get-ProgramSelectionKey($Program) {
    $path = [string]$Program.path
    if (-not [string]::IsNullOrWhiteSpace($path)) {
        return ($script:LauncherTechnical.PathSelectionKey -f $path.Trim())
    }
    return ($script:LauncherTechnical.NameSelectionKey -f ([string]$Program.name))
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

function Reset-CommanderTooltip {
    $commanderHoverTimer.Stop()
    $commanderToolTip.Hide($cmdList)
    $script:CommanderHoverIndex = -1
    $script:CommanderHoverText = $script:LauncherTechnical.EmptyString
}

function Update-Lists {
    $script:RestoringChecks = $true
    try {
        $savedCommanderKeys = @($config.selectedCommanderKeys)
        $savedProgramKeys = @($config.selectedProgramKeys)

        $commandersNoRunAs = @()
        $commandersRunAs = @()
        foreach ($c in @($config.commanders)) {
            if ($null -ne $c.PSObject.Properties[$script:LauncherTechnical.UseRunAsProperty] -and -not [bool]$c.useRunAs) {
                $commandersNoRunAs += $c
            }
            else {
                $commandersRunAs += $c
            }
        }
        $config.commanders = @($commandersNoRunAs) + @($commandersRunAs)

        $eliteDangerousPrograms = @()
        $otherPrograms = @()
        foreach ($p in @($config.programs)) {
            if ([string]$p.name -eq $script:LauncherSettings.PriorityProgramName) {
                $eliteDangerousPrograms += $p
            }
            else {
                $otherPrograms += $p
            }
        }
        $config.programs = @($eliteDangerousPrograms) + @($otherPrograms)

        Reset-CommanderTooltip
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

foreach ($propertyName in @($script:LauncherTechnical.CommandersProperty, $script:LauncherTechnical.ProgramsProperty, $script:LauncherTechnical.SelectedCommanderKeysProperty, $script:LauncherTechnical.SelectedProgramKeysProperty)) {
    if ($null -eq $config.PSObject.Properties[$propertyName]) {
        $config | Add-Member -MemberType NoteProperty -Name $propertyName -Value @()
    }
    elseif ($null -eq $config.$propertyName) {
        $config.$propertyName = @()
    }
}

if ($null -eq $config.PSObject.Properties[$script:LauncherTechnical.CloseAfterLaunchProperty]) {
    $config | Add-Member -MemberType NoteProperty -Name $script:LauncherTechnical.CloseAfterLaunchProperty -Value $script:LauncherSettings.DefaultCloseAfterLaunch
}
elseif ($null -eq $config.closeAfterLaunch) {
    $config.closeAfterLaunch = $script:LauncherSettings.DefaultCloseAfterLaunch
}

$script:RestoringChecks = $false
$global:AllowCheckToggle = $false

# -----------------------------------------------------------------------------
# Main form and controls
# -----------------------------------------------------------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = $script:LauncherText.AppTitle
$form.Size = $script:LauncherLayout.MainWindowSize
$form.StartPosition = $script:LauncherTechnical.MainStartPosition
$form.MinimumSize = $script:LauncherLayout.MainWindowMinimumSize
$form.BackColor = $script:LauncherColors.Background
$form.ForeColor = $script:LauncherColors.Foreground

$title = New-Object System.Windows.Forms.Label
$title.Text = $script:LauncherText.AppTitle
$title.Font = New-Object System.Drawing.Font($script:LauncherSettings.FontFamily, $script:LauncherSettings.TitleFontSize, [System.Drawing.FontStyle]::Bold)
$title.Location = $script:LauncherLayout.TitleLocation
$title.Size = $script:LauncherLayout.TitleSize
$title.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($title)

$lblCmd = New-Object System.Windows.Forms.Label
$lblCmd.Text = $script:LauncherText.CommandersHeading
$lblCmd.Font = New-Object System.Drawing.Font($script:LauncherSettings.FontFamily, $script:LauncherSettings.HeadingFontSize, [System.Drawing.FontStyle]::Bold)
$lblCmd.Location = $script:LauncherLayout.CommandersHeadingLocation
$lblCmd.Size = $script:LauncherLayout.CommandersHeadingSize
$lblCmd.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($lblCmd)

$lblProg = New-Object System.Windows.Forms.Label
$lblProg.Text = $script:LauncherText.ProgramsHeading
$lblProg.Font = New-Object System.Drawing.Font($script:LauncherSettings.FontFamily, $script:LauncherSettings.HeadingFontSize, [System.Drawing.FontStyle]::Bold)
$lblProg.Location = $script:LauncherLayout.ProgramsHeadingLocation
$lblProg.Size = $script:LauncherLayout.ProgramsHeadingSize
$lblProg.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($lblProg)

$cmdList = New-Object System.Windows.Forms.CheckedListBox
$cmdList.CheckOnClick = $false
$cmdList.Location = $script:LauncherLayout.CommandersListLocation
$cmdList.Size = $script:LauncherLayout.CommandersListSize
$cmdList.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($cmdList)

$commanderToolTip = New-Object System.Windows.Forms.ToolTip
$commanderHoverTimer = New-Object System.Windows.Forms.Timer
$commanderHoverTimer.Interval = [Math]::Max(1, [int]$EmailHoverDelayMs)
$script:CommanderHoverIndex = -1
$script:CommanderHoverText = $script:LauncherTechnical.EmptyString

$commanderHoverTimer.Add_Tick({
    $commanderHoverTimer.Stop()
    $point = $cmdList.PointToClient([System.Windows.Forms.Cursor]::Position)
    $index = $cmdList.IndexFromPoint($point)
    if ($cmdList.ClientRectangle.Contains($point) -and
        $index -ge 0 -and $index -eq $script:CommanderHoverIndex -and
        -not [string]::IsNullOrWhiteSpace($script:CommanderHoverText)) {
        $commanderToolTip.Show($script:CommanderHoverText, $cmdList, $point.X + $script:LauncherSettings.EmailTooltipOffsetX, $point.Y + $script:LauncherSettings.EmailTooltipOffsetY, $script:LauncherSettings.EmailTooltipDurationMs)
    }
    else {
        Reset-CommanderTooltip
    }
})

$cmdList.Add_MouseMove({
    param($eventSource, $e)
    $index = $cmdList.IndexFromPoint($e.Location)
    $tooltipText = $script:LauncherTechnical.EmptyString
    if ($index -ge 0 -and $index -lt @($config.commanders).Count) {
        $email = [string]$config.commanders[$index].email
        if (-not [string]::IsNullOrWhiteSpace($email)) {
            $tooltipText = ($script:LauncherText.EmailTooltip -f $email)
        }
    }
    if ($index -ne $script:CommanderHoverIndex -or $tooltipText -ne $script:CommanderHoverText) {
        Reset-CommanderTooltip
        $script:CommanderHoverIndex = $index
        $script:CommanderHoverText = $tooltipText
        if (-not [string]::IsNullOrWhiteSpace($tooltipText)) {
            $commanderHoverTimer.Start()
        }
    }
})
$cmdList.Add_MouseLeave({
    Reset-CommanderTooltip
})
$form.Add_FormClosed({
    $commanderHoverTimer.Stop()
    $commanderHoverTimer.Dispose()
    $commanderToolTip.Dispose()
})

$progList = New-Object System.Windows.Forms.CheckedListBox
$progList.CheckOnClick = $false
$progList.Location = $script:LauncherLayout.ProgramsListLocation
$progList.Size = $script:LauncherLayout.ProgramsListSize
$progList.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($progList)

Add-CheckboxOnlyClickBehavior $cmdList
Add-CheckboxOnlyClickBehavior $progList

$btnCmdAll = New-Object System.Windows.Forms.Button
$btnCmdAll.Text = $script:LauncherText.SelectAllButton
$btnCmdAll.Location = $script:LauncherLayout.CommandersSelectAllLocation
$btnCmdAll.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnCmdAll.Size = $script:LauncherLayout.CommandersSelectAllSize
$form.Controls.Add($btnCmdAll)

$btnCmdNone = New-Object System.Windows.Forms.Button
$btnCmdNone.Text = $script:LauncherText.ClearButton
$btnCmdNone.Location = $script:LauncherLayout.CommandersClearLocation
$btnCmdNone.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnCmdNone.Size = $script:LauncherLayout.CommandersClearSize
$form.Controls.Add($btnCmdNone)

$btnCmdAdd = New-Object System.Windows.Forms.Button
$btnCmdAdd.Text = $script:LauncherText.AddButton
$btnCmdAdd.Location = $script:LauncherLayout.CommandersAddLocation
$btnCmdAdd.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnCmdAdd.Size = $script:LauncherLayout.CommandersAddSize
$form.Controls.Add($btnCmdAdd)

$btnCmdEdit = New-Object System.Windows.Forms.Button
$btnCmdEdit.Text = $script:LauncherText.EditButton
$btnCmdEdit.Location = $script:LauncherLayout.CommandersEditLocation
$btnCmdEdit.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnCmdEdit.Size = $script:LauncherLayout.CommandersEditSize
$form.Controls.Add($btnCmdEdit)

$btnCmdRemove = New-Object System.Windows.Forms.Button
$btnCmdRemove.Text = $script:LauncherText.RemoveButton
$btnCmdRemove.Location = $script:LauncherLayout.CommandersRemoveLocation
$btnCmdRemove.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnCmdRemove.Size = $script:LauncherLayout.CommandersRemoveSize
$form.Controls.Add($btnCmdRemove)

$btnProgAll = New-Object System.Windows.Forms.Button
$btnProgAll.Text = $script:LauncherText.SelectAllButton
$btnProgAll.Location = $script:LauncherLayout.ProgramsSelectAllLocation
$btnProgAll.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnProgAll.Size = $script:LauncherLayout.ProgramsSelectAllSize
$form.Controls.Add($btnProgAll)

$btnProgNone = New-Object System.Windows.Forms.Button
$btnProgNone.Text = $script:LauncherText.ClearButton
$btnProgNone.Location = $script:LauncherLayout.ProgramsClearLocation
$btnProgNone.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnProgNone.Size = $script:LauncherLayout.ProgramsClearSize
$form.Controls.Add($btnProgNone)

$btnProgAdd = New-Object System.Windows.Forms.Button
$btnProgAdd.Text = $script:LauncherText.AddButton
$btnProgAdd.Location = $script:LauncherLayout.ProgramsAddLocation
$btnProgAdd.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnProgAdd.Size = $script:LauncherLayout.ProgramsAddSize
$form.Controls.Add($btnProgAdd)

$btnProgEdit = New-Object System.Windows.Forms.Button
$btnProgEdit.Text = $script:LauncherText.EditButton
$btnProgEdit.Location = $script:LauncherLayout.ProgramsEditLocation
$btnProgEdit.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnProgEdit.Size = $script:LauncherLayout.ProgramsEditSize
$form.Controls.Add($btnProgEdit)

$btnProgRemove = New-Object System.Windows.Forms.Button
$btnProgRemove.Text = $script:LauncherText.RemoveButton
$btnProgRemove.Location = $script:LauncherLayout.ProgramsRemoveLocation
$btnProgRemove.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnProgRemove.Size = $script:LauncherLayout.ProgramsRemoveSize
$form.Controls.Add($btnProgRemove)

$start = New-Object System.Windows.Forms.Button
$start.Text = $script:LauncherText.StartButton
$start.Font = New-Object System.Drawing.Font($script:LauncherSettings.FontFamily, $script:LauncherSettings.StartButtonFontSize, [System.Drawing.FontStyle]::Bold)
$start.Location = $script:LauncherLayout.StartButtonLocation
$start.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom
$start.Size = $script:LauncherLayout.StartButtonSize
$form.Controls.Add($start)

$closeAfterLaunch = New-Object System.Windows.Forms.CheckBox
$closeAfterLaunch.Text = $script:LauncherText.CloseAfterLaunchLabel
$closeAfterLaunch.AutoSize = $true
$closeAfterLaunch.Location = $script:LauncherLayout.CloseAfterLaunchLocation
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

$cmdList.Add_MouseDoubleClick({
    param($control, $e)

    $index = $control.IndexFromPoint($e.Location)
    if ($index -lt 0 -or $index -ge @($config.commanders).Count) {
        return
    }

    $commander = $config.commanders[$index]
    $cmdProgram = [pscustomobject]@{
        path      = $env:ComSpec
        arguments = $script:LauncherTechnical.EmptyString
    }

    try {
        Start-AsUser $commander $cmdProgram
    }
    catch {
        Show-Error ($script:LauncherText.CommandPromptError -f $commander.name, $_.Exception.Message)
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
    if ($i -lt 0) { Show-Info $script:LauncherText.SelectCommanderFirst; return }
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
    if ($i -lt 0) { Show-Info $script:LauncherText.SelectCommanderFirst; return }

    $answer = [System.Windows.Forms.MessageBox]::Show(
        ($script:LauncherText.RemoveCommanderPrompt -f $config.commanders[$i].name),
        $script:LauncherText.ConfirmationTitle,
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
    if ($i -lt 0) { Show-Info $script:LauncherText.SelectProgramFirst; return }
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
    if ($i -lt 0) { Show-Info $script:LauncherText.SelectProgramFirst; return }

    $answer = [System.Windows.Forms.MessageBox]::Show(
        ($script:LauncherText.RemoveProgramPrompt -f $config.programs[$i].name),
        $script:LauncherText.ConfirmationTitle,
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
        Show-Info $script:LauncherText.SelectCommanderToLaunch
        return
    }

    if ($selectedPrograms.Count -eq 0) {
        Show-Info $script:LauncherText.SelectProgramToLaunch
        return
    }

    $errors = @()

    foreach ($commander in $selectedCommanders) {
        foreach ($program in $selectedPrograms) {
            try {
                Start-AsUser $commander $program
                Start-Sleep -Milliseconds $script:LauncherSettings.LaunchDelayMs
            }
            catch {
                $errors += ($script:LauncherText.LaunchErrorDetail -f $commander.name, $program.name, $_.Exception.Message)
            }
        }
    }

    if ($errors.Count -gt 0) {
        Show-Error ($script:LauncherText.LaunchErrorsHeading + ($errors -join $script:LauncherTechnical.NewLine))
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
    Show-Error ($script:LauncherText.UnexpectedError -f $_.Exception.Message, $_.ScriptStackTrace)
}
