# MonitorTools CLI Usage

## Commands

### get-info
Get information about all connected monitors.

```cmd
MonitorTools.exe get-info
```

Options:
- `--verbose, -v`: Show detailed information

Example:
```cmd
MonitorTools.exe get-info --verbose
```

### get-brightness
Get the brightness level of a monitor.

```cmd
MonitorTools.exe get-brightness [--monitor <index>]
```

Options:
- `--monitor, -m <index>`: Monitor index (0-based, default: 0)

Examples:
```cmd
# Get brightness of primary monitor
MonitorTools.exe get-brightness

# Get brightness of second monitor
MonitorTools.exe get-brightness --monitor 1
```

### set-brightness
Set the brightness level of a monitor.

```cmd
MonitorTools.exe set-brightness <brightness> [--monitor <index>]
```

Arguments:
- `brightness`: Brightness level (0-100)

Options:
- `--monitor, -m <index>`: Monitor index (0-based, default: 0)

Examples:
```cmd
# Set primary monitor to 50% brightness
MonitorTools.exe set-brightness 50

# Set second monitor to 75% brightness
MonitorTools.exe set-brightness 75 --monitor 1
```

### get-contrast
Get the contrast level of a monitor.

```cmd
MonitorTools.exe get-contrast [--monitor <index>]
```

### set-contrast
Set the contrast level of a monitor.

```cmd
MonitorTools.exe set-contrast <contrast> [--monitor <index>]
```

Examples:
```cmd
# Set contrast to 80%
MonitorTools.exe set-contrast 80

# Set contrast of second monitor
MonitorTools.exe set-contrast 90 -m 1
```

### get-volume
Get the audio volume level of a monitor.

```cmd
MonitorTools.exe get-volume [--monitor <index>]
```

### set-volume
Set the audio volume level of a monitor.

```cmd
MonitorTools.exe set-volume <volume> [--monitor <index>]
```

Examples:
```cmd
# Set volume to 50%
MonitorTools.exe set-volume 50

# Increase volume to 80%
MonitorTools.exe set-volume 80
```

### audio
Control monitor audio (mute/unmute).

```cmd
MonitorTools.exe audio <subcommand> [--monitor <index>]
```

Subcommands:
- `mute`: Mute monitor audio
- `unmute`: Unmute monitor audio
- `status`: Get current mute status

Examples:
```cmd
# Mute primary monitor
MonitorTools.exe audio mute

# Unmute second monitor
MonitorTools.exe audio unmute --monitor 1

# Check mute status
MonitorTools.exe audio status
```

### input
Get or set monitor input source.

```cmd
MonitorTools.exe input <subcommand> [options]
```

Subcommands:
- `get`: Get current input source
- `set <source>`: Set input source

Input sources:
- `Hdmi1`
- `Hdmi2`
- `DisplayPort`
- `UsbC`

Examples:
```cmd
# Get current input
MonitorTools.exe input get

# Switch to HDMI 1
MonitorTools.exe input set Hdmi1

# Switch second monitor to DisplayPort
MonitorTools.exe input set DisplayPort --monitor 1
```

### vcp
Get or set VCP (VESA Control Panel) feature codes directly.

```cmd
MonitorTools.exe vcp <subcommand> <code> [options]
```

Subcommands:
- `get <code>`: Get VCP feature value
- `set <code> <value>`: Set VCP feature value

VCP codes can be specified in hex (with or without 0x prefix):
- `0x10` or `10` for brightness
- `0x12` or `12` for contrast
- `0x60` or `60` for input source
- `0x62` or `62` for audio volume

Examples:
```cmd
# Get brightness using VCP code
MonitorTools.exe vcp get 0x10

# Set contrast using VCP code
MonitorTools.exe vcp set 0x12 75

# Get custom VCP feature
MonitorTools.exe vcp get 0xE9 --monitor 1
```

## Common Scenarios

### Quick brightness adjustment
```cmd
# Morning routine - lower brightness
MonitorTools.exe set-brightness 30

# Evening routine - increase brightness
MonitorTools.exe set-brightness 80
```

### Multi-monitor setup
```cmd
# List all monitors
MonitorTools.exe get-info

# Set all monitors to same brightness
MonitorTools.exe set-brightness 60 -m 0
MonitorTools.exe set-brightness 60 -m 1
```

### Input switching
```cmd
# Switch between work and gaming PC
MonitorTools.exe input set Hdmi1
MonitorTools.exe input set DisplayPort
```

### Audio control
```cmd
# Mute during meeting
MonitorTools.exe audio mute

# Adjust volume
MonitorTools.exe set-volume 40
```

### Batch scripting
Create a batch file `work-mode.bat`:
```batch
@echo off
echo Setting up work mode...
MonitorTools.exe input set DisplayPort -m 0
MonitorTools.exe set-brightness 70 -m 0
MonitorTools.exe set-contrast 80 -m 0
MonitorTools.exe set-volume 30 -m 0
echo Work mode activated!
```

Create a batch file `gaming-mode.bat`:
```batch
@echo off
echo Setting up gaming mode...
MonitorTools.exe input set Hdmi1 -m 0
MonitorTools.exe set-brightness 100 -m 0
MonitorTools.exe set-contrast 90 -m 0
MonitorTools.exe set-volume 60 -m 0
echo Gaming mode activated!
```

### PowerShell scripting
```powershell
# Automated brightness based on time
$hour = (Get-Date).Hour
$brightness = switch ($hour) {
    { $_ -ge 6 -and $_ -lt 9 } { 50 }    # Morning
    { $_ -ge 9 -and $_ -lt 17 } { 80 }   # Day
    { $_ -ge 17 -and $_ -lt 21 } { 60 }  # Evening
    default { 30 }                        # Night
}

& MonitorTools.exe set-brightness $brightness
Write-Host "Brightness set to $brightness% for current time"
```
