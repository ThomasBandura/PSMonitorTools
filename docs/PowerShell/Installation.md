# PowerShell Module Installation

## Installation from PowerShell Gallery

```powershell
Install-Module -Name PSMonitorTools
```

## Manual Installation

1. Download the latest release from [Releases](https://github.com/ThomasBandura/PSMonitorTools/releases)
2. Extract the ZIP file
3. Copy the `PSMonitorTools` folder to one of your PowerShell module paths:
   - Current User: `$HOME\Documents\PowerShell\Modules`
   - All Users: `C:\Program Files\PowerShell\Modules`

## Verify Installation

```powershell
Get-Module -ListAvailable PSMonitorTools
Import-Module PSMonitorTools
Get-Command -Module PSMonitorTools
```

## Requirements

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or PowerShell 7+
- Administrator rights may be required for some operations
