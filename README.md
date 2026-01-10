# PSMonitorTools

PowerShell module to retrieve physical monitor information (Model, Serial, Firmware) and control input sources (HDMI, DP, USB-C) via DDC/CI / VCP codes.

## Features

- **Get-MonitorInfo**: Retrieves detailed information about connected monitors (Model, Serial Number, Firmware Version, Manufacturing Date).
- **Switch-MonitorInput**: Switches the input source of a specific monitor (e.g., from HDMI1 to DisplayPort).
- **Enable-MonitorPBP / Disable-MonitorPBP**: Controls Picture-by-Picture (PBP) mode on supported monitors.
- **Set-MonitorAudioVolume**: Controls the volume of the monitor speakers.
- **Enable-MonitorAudio / Disable-MonitorAudio**: Mutes or Unmutes the monitor audio.
- **Find-MonitorVcpCodes**: Interactive tool to discover hidden VCP codes by comparing monitor state before and after a manual change.
- **Tab Completion**: Supports argument completion for monitor names.
- **Robustness**: Uses both Low-Level Monitor Configuration API and WMI fallback.

## Installation

1. Clone or download this repository.
2. Import the module directly:

```powershell
Import-Module ./PSMonitorTools/PSMonitorTools.psd1
```

## Usage

### Get Monitor Information

```powershell
Get-MonitorInfo
```

**Output:**
```text
Index Name                          Model   SerialNumber Manufacturer Firmware WeekOfManufacture YearOfManufacture
----- ----                          -----   ------------ ------------ -------- ----------------- -----------------
    0 Dell U4924DW(DisplayPort 1.4) U4924DW xxxxxxx      DEL          105                     26              2023
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
# Set volume to 50%
Set-MonitorAudioVolume -MonitorName 'Dell' -Volume 50

# Unmute Audio
Enable-MonitorAudio -MonitorName 'Dell'

# Mute Audio
Disable-MonitorAudio -MonitorName 'Dell'
```

### Discover VCP Codes

Interactively find hidden VCP codes by scanning the monitor, asking you to change a setting via OSD, and scanning again to find differences.

```powershell
Find-MonitorVcpCodes -MonitorName 'Dell U4924DW'
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

