# PowerShell Examples

## Basic Usage

### Get all monitor information
```powershell
Get-MonitorInfo
```

### Get specific monitor by index
```powershell
$monitors = Get-MonitorInfo
$primaryMonitor = $monitors | Where-Object { $_.IsPrimary }
```

## Brightness Control

### Get brightness of primary monitor
```powershell
Get-MonitorBrightness
```

### Get brightness of specific monitor
```powershell
Get-MonitorBrightness -MonitorIndex 1
```

### Set brightness
```powershell
# Set primary monitor to 50%
Set-MonitorBrightness -Brightness 50

# Set second monitor to 75%
Set-MonitorBrightness -Brightness 75 -MonitorIndex 1
```

## Advanced Scenarios

### Create brightness presets
```powershell
function Set-BrightnessPreset {
    param(
        [ValidateSet('Day', 'Night', 'Movie')]
        [string]$Preset
    )
    
    switch ($Preset) {
        'Day'   { Set-MonitorBrightness -Brightness 100 }
        'Night' { Set-MonitorBrightness -Brightness 20 }
        'Movie' { Set-MonitorBrightness -Brightness 40 }
    }
}

# Usage
Set-BrightnessPreset -Preset Night
```

### Scheduled brightness adjustment
```powershell
# Create scheduled task for morning
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
    -Argument '-Command "Set-MonitorBrightness -Brightness 80"'
$trigger = New-ScheduledTaskTrigger -Daily -At 7am
Register-ScheduledTask -TaskName "MonitorBrightness-Morning" `
    -Action $action -Trigger $trigger
```

### Export monitor configuration
```powershell
$config = Get-MonitorInfo | Select-Object DeviceName, Width, Height, Brightness
$config | Export-Csv -Path "monitor-config.csv" -NoTypeInformation
```

### Sync brightness across all monitors
```powershell
function Sync-MonitorBrightness {
    param([int]$Brightness)
    
    $monitors = Get-MonitorInfo
    foreach ($monitor in $monitors) {
        Set-MonitorBrightness -Brightness $Brightness -MonitorIndex $monitor.Index
    }
}

# Usage
Sync-MonitorBrightness -Brightness 60
```

### Monitor health check
```powershell
function Test-MonitorHealth {
    $monitors = Get-MonitorInfo
    
    foreach ($monitor in $monitors) {
        [PSCustomObject]@{
            Monitor = $monitor.DeviceName
            Resolution = "$($monitor.Width)x$($monitor.Height)"
            BrightnessSupported = $null -ne $monitor.Brightness
            Status = if ($monitor.Brightness) { "OK" } else { "Warning" }
        }
    }
}

Test-MonitorHealth | Format-Table
```
