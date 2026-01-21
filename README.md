# PSMonitorTools

Monitor information and brightness control for Windows - available as both PowerShell module and C# executable.

[![PowerShell CI](https://github.com/ThomasBandura/PSMonitorTools/workflows/PowerShell%20CI/badge.svg)](https://github.com/ThomasBandura/PSMonitorTools/actions)
[![C# CI](https://github.com/ThomasBandura/PSMonitorTools/workflows/C%23%20CI/badge.svg)](https://github.com/ThomasBandura/PSMonitorTools/actions)
[![License](https://img.shields.io/github/license/ThomasBandura/PSMonitorTools)](LICENSE)

## 📦 Available Implementations

### 🔷 PowerShell Module
PowerShell module for scripting and automation.
- 📖 [PowerShell Documentation](./docs/PowerShell/)
- 💾 [Installation Guide](./docs/PowerShell/Installation.md)
- 📝 [Examples](./docs/Examples/PowerShell-Examples.md)

### 🔶 C# Executable
Standalone command-line tool and library.
- 📖 [C# CLI Documentation](./docs/CSharp/)
- 💾 [Installation Guide](./docs/CSharp/Installation.md)
- 📝 [Examples](./docs/Examples/CSharp-Examples.md)

## Project Goals

The primary goal of this project is to provide a reliable programmatic interface for controlling physical monitor settings on Windows. By exposing DDC/CI capabilities through friendly APIs, it facilitates automation scenarios such as:
- **Automation:** Switching monitor inputs based on work context (e.g., software KVM switching logic)
- **Comfort:** Adjusting brightness and contrast programmatically (e.g., based on time of day)
- **Efficiency:** Managing Picture-by-Picture (PBP) modes without navigating cumbersome OSD (On-Screen Display) menus
- **Inventory:** Retrieving hardware details (Serial Numbers, Firmware) for asset management

## Features

### PowerShell Module
- **Get-MonitorInfo**: Retrieves detailed information about connected monitors (Model, Serial Number, Firmware Version, Manufacturing Date)
- **Get-MonitorInput**: Retrieves current input sources and PBP status for a specific monitor
- **Switch-MonitorInput**: Switches the input source of a specific monitor (e.g., from HDMI1 to DisplayPort)
- **Enable-MonitorPBP / Disable-MonitorPBP**: Controls Picture-by-Picture (PBP) mode on supported monitors
- **Get-MonitorAudioVolume / Set-MonitorAudioVolume**: Controls monitor speaker volume
- **Enable-MonitorAudio / Disable-MonitorAudio**: Mutes or unmutes monitor audio
- **Get-MonitorBrightness / Set-MonitorBrightness**: Controls brightness (luminance) level (0-100)
- **Get-MonitorContrast / Set-MonitorContrast**: Controls contrast level (0-100)
- **Find-MonitorVcpCodes**: Interactive tool to discover hidden VCP codes
- **Tab Completion**: Supports argument completion for monitor names
- **Dual-API Strategy**: Uses both Low-Level Monitor Configuration API and WMI fallback

### C# Library & CLI
- **MonitorService**: Core library for monitor information and brightness control
- **CLI Commands**:
  - `get-info`: Get information about all connected monitors
  - `get-brightness`: Get brightness level of a monitor
  - `set-brightness`: Set brightness level of a monitor
- **Cross-platform API**: Reusable `MonitorTools.Core` library for integration into other C# projects

## Quick Start

### PowerShell
```powershell
# Install from PowerShell Gallery
Install-Module PSMonitorTools

# Or import locally
Import-Module ./PowerShell/PSMonitorTools/PSMonitorTools.psd1

# Get monitor info
Get-MonitorInfo

# Set brightness
Set-MonitorBrightness -Brightness 75
```

### C# CLI
```cmd
# Download from Releases or build
dotnet build CSharp/MonitorTools.sln

# Get monitor info
MonitorTools.exe get-info

# Set brightness
MonitorTools.exe set-brightness 75
```

## Installation

See detailed installation guides:
- **PowerShell**: [Installation Guide](./docs/PowerShell/Installation.md)
- **C# CLI**: [Installation Guide](./docs/CSharp/Installation.md)

## Usage Examples

### PowerShell

#### Get Monitor Information

```powershell
# Get all monitors
Get-MonitorInfo

# Get specific monitor
Get-MonitorInfo -MonitorName 'Dell'
```

**Output:**
```text
Index Name                          Model   SerialNumber Manufacturer Firmware WeekOfManufacture YearOfManufacture
----- ----                          -----   ------------ ------------ -------- ----------------- -----------------
    0 Dell U4924DW(DisplayPort 1.4) U4924DW xxxxxxx      DEL          105                     26              2023
```

#### Brightness Control

```powershell
# Get brightness
Get-MonitorBrightness

# Set brightness
Set-MonitorBrightness -Brightness 50
```

### C# CLI

#### Get Monitor Information

```cmd
MonitorTools.exe get-info
```

**Output:**
```text
Found 2 monitor(s):

Monitor 0:
  Device:      \\.\DISPLAY1
  Resolution:  3840x2160
  Primary:     Yes
  Brightness:  75%

Monitor 1:
  Device:      \\.\DISPLAY2
  Resolution:  1920x1080
  Primary:     No
```

#### Brightness Control

```cmd
# Get brightness
MonitorTools.exe get-brightness

# Set brightness
MonitorTools.exe set-brightness 50

# Set brightness for specific monitor
MonitorTools.exe set-brightness 75 --monitor 1
```

## Advanced PowerShell Features

### Get Input State

Check the current active input(s) and Picture-by-Picture (PBP) status.

```powershell
Get-MonitorInput -MonitorName 'Dell'
```

**Output:**
```text
Name                              Model   PBP InputLeft   InputRight
----                              -----   --- ---------   ----------
Dell U4924DW(DisplayPort PBP/PIP) U4924DW True Hdmi1      DisplayPort
```

### Switch Input Source

Switch the input of a specific monitor. You can control the Primary Input (Left) and the Secondary Input (Right) for PBP modes.

```powershell
# Switch 'Dell' monitor Primary Input to HDMI 1
Switch-MonitorInput -MonitorName 'Dell' -InputLeft Hdmi1

# Switch Primary to HDMI 1 and Secondary to DisplayPort (PBP setup)
Switch-MonitorInput -MonitorName 'U4924DW' -InputLeft Hdmi1 -InputRight DisplayPort

# Legacy support: -InputSource is an alias for -InputLeft
Switch-MonitorInput -MonitorName 'Dell' -InputSource Hdmi1
```

**Supported Inputs:**
- `Hdmi1`
- `Hdmi2`
- `DisplayPort`
- `UsbC`

### Control Picture-by-Picture (PBP)

Enable or disable PBP mode on supported monitors (uses VCP code `0xE9`).

```powershell
# Enable PBP on a Dell monitor
Enable-MonitorPBP -MonitorName 'Dell'

# Disable PBP
Disable-MonitorPBP -MonitorName 'Dell'
```

### Control Audio

Control the volume and mute state of the monitor speakers.

```powershell
# Get current volume
Get-MonitorAudioVolume -MonitorName 'Dell'

# Set volume to 50%
Set-MonitorAudioVolume -MonitorName 'Dell' -Volume 50

# Get current audio status (Enabled=Unmuted, Disabled=Muted)
Get-MonitorAudio -MonitorName 'Dell'

# Unmute Audio
Enable-MonitorAudio -MonitorName 'Dell'

# Mute Audio
Disable-MonitorAudio -MonitorName 'Dell'
```

### Control Brightness & Contrast

Adjust the screen brightness (luminance) and contrast.

```powershell
# Get current brightness
Get-MonitorBrightness -MonitorName 'Dell'

# Set brightness to 75%
Set-MonitorBrightness -MonitorName 'Dell' -Brightness 75

# Get current contrast
Get-MonitorContrast -MonitorName 'Dell'

# Set contrast to 60%
Set-MonitorContrast -MonitorName 'Dell' -Contrast 60
```

### Discover VCP Codes

Interactively find hidden VCP codes by scanning the monitor, asking you to change a setting via OSD, and scanning again to find differences.

```powershell
# Standard Scan (Common Consumer Codes)
Find-MonitorVcpCodes -MonitorName 'Dell U4924DW'

# Full Scan (0x00 - 0xFF) - Useful for finding proprietary codes (like KVM)
Find-MonitorVcpCodes -MonitorName 'Dell U4924DW' -FullScan
```

## Requirements

- Windows OS
- PowerShell 5.1 or PowerShell 7+ (pwsh)
- Monitors supporting DDC/CI (CI/DDC must be enabled in monitor settings)

> **Note:** This module was tested exclusively with a **Dell U4924DW**.

## Project Structure

- `PSMonitorTools/`: The core module.
- `Tests/`: Pester tests.
- `Get-MonitorInfo.ps1`: Wrapper script for quick execution.

