# Elite Dangerous Multibox Launcher

A lightweight Windows application that lets you launch multiple Elite Dangerous CMDRs and their companion programs from a single, convenient interface.

## **Note: This script does not create Windows user accounts. Please ensure all required accounts already exist. For companion programs such as browsers to work properly, log in at least once to each Windows user account and set a default browser. Requiert for EDMC authentication!**

## Files

Keep these files together in a Folder:

```text
EliteMultiboxLauncher.vbs <---- Launch the ps1 without a command prompt.
EliteMultiboxLauncher.ps1 <---- The program can be run directly.
config.json               <---- The savefile
```

## First Start

After downloading/extracting the launcher, Windows may block downloaded script files.

Before starting it for the first time:

1. Right-click `EliteMultiboxLauncher.vbs` → **Properties** → check **Unblock** → **Apply**.
2. Right-click `EliteMultiboxLauncher.ps1` → **Properties** → check **Unblock** → **Apply**.
3. Optional: Make a shortcut from the `.vbs` file on your Desktop

Then start the launcher with:

```text
EliteMultiboxLauncher.vbs
```

The `.vbs` starts the GUI without leaving a PowerShell console open in the background.

## Features

* Add, edit, and remove commanders and programs.
* Select which commanders and programs to launch.
* Persistent checkbox selections
* Optional RunAs per commander
* Run alternate commanders under separate Windows users.
* Run your default commander under your current Windows user.
* MinEdLauncher profile support
* Configuration stored in `config.json`

## How It Works

Select one or more commanders, select the programs you want, then click **START SELECTED.**

The launcher starts every selected program for every selected commander.

The **checkbox** controls whether an item launches. Clicking the **name** only highlights the row for **Edit** or **Remove.**

## Commander Variables

Program arguments can use commander-specific variables:

```text
{Commander}
{WindowsUser}
{MinEdProfile}
```

They are replaced automatically for each commander when you launch a program.

Example:

```text
/frontier {MinEdProfile} /edo /autorun /autoquit
```

## RunAs

Each commander has a **Use RunAs** option.

- **Enabled:** programs run under the configured Windows user using `runas /savecred`.
- **Disabled:** programs run normally under your current Windows user.

The first launch under a new Windows user may ask for that user's Windows password. The launcher does not store passwords itself.

## Requirements

- Windows
- Windows PowerShell
- min-ED https://github.com/rfvgyhn/min-ed-launcher

## Demo
![Elite Multibox Launcher Demo](demo.gif)
