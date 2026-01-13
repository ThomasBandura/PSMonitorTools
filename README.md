# PSMonitorTools

PowerShell module to retrieve physical monitor information (Model, Serial, Firmware) and control input sources (HDMI, DP, USB-C) via DDC/CI / VCP codes.

## Features

- **Get-MonitorInfo**: Retrieves detailed information about connected monitors (Model, Serial Number, Firmware Version, Manufacturing Date).
- **Get-MonitorInput**: Retrieves current input sources and PBP status for a specific monitor.
- **Switch-MonitorInput**: Switches the input source of a specific monitor (e.g., from HDMI1 to DisplayPort).
- **Enable-MonitorPBP / Disable-MonitorPBP**: Controls Picture-by-Picture (PBP) mode on supported monitors.
- **Get-MonitorAudioVolume**: Retrieves current audio volume.
- **Set-MonitorAudioVolume**: Controls the volume of the monitor speakers.
- **Get-MonitorAudio**: Retrieves current audio mute state (Enabled/Disabled).
- **Enable-MonitorAudio / Disable-MonitorAudio**: Mutes or Unmutes the monitor audio.
- **Get-MonitorBrightness**: Retrieves current brightness (luminance) level (0-100).
- **Set-MonitorBrightness**: Sets the brightness level.
- **Get-MonitorContrast**: Retrieves current contrast level (0-100).
- **Set-MonitorContrast**: Sets the contrast level.
- **Find-MonitorVcpCodes**: Interactive tool to discover hidden VCP codes by comparing monitor state before and after a manual change.
- **Tab Completion**: Supports argument completion for monitor names.
- **Robustness (v0.6+)**: Includes "Smart Ordering" to prevent input collisions in PBP/Picture-by-Picture modes and active waiting for monitor readiness to ensure reliable command execution.
- **Dual-API Strategy**: Uses both Low-Level Monitor Configuration API and WMI fallback.

## Installation

1. Clone or download this repository.
2. Import the module directly:

```powershell
Import-Module ./PSMonitorTools/PSMonitorTools.psd1
```

## Usage

### Get Monitor Information

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

