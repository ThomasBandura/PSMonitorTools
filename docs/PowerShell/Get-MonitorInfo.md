# Get-MonitorInfo

## Synopsis
Gets information about all connected monitors.

## Syntax

```powershell
Get-MonitorInfo [<CommonParameters>]
```

## Description
The `Get-MonitorInfo` cmdlet retrieves detailed information about all monitors connected to the system, including manufacturer, model, resolution, and brightness settings.

## Examples

### Example 1: Get all monitors
```powershell
Get-MonitorInfo
```
Returns information about all connected monitors.

### Example 2: Get only primary monitor
```powershell
Get-MonitorInfo | Where-Object { $_.IsPrimary -eq $true }
```
Filters to show only the primary monitor.

### Example 3: Export to JSON
```powershell
Get-MonitorInfo | ConvertTo-Json | Out-File monitors.json
```
Exports monitor information to a JSON file.

## Outputs

### PSCustomObject
Returns objects with the following properties:
- **Index**: Monitor index (0-based)
- **DeviceName**: Windows device name
- **Manufacturer**: Monitor manufacturer
- **Model**: Monitor model name
- **SerialNumber**: Serial number (if available)
- **Width**: Screen width in pixels
- **Height**: Screen height in pixels
- **IsPrimary**: Whether this is the primary monitor
- **Brightness**: Current brightness level (0-100, if supported)

## Notes
- Requires Windows 10/11 or Windows Server 2016+
- Some monitors may not support brightness control
- Administrator rights may be required for certain operations
