# C# CLI Installation

## Download

Download the latest executable from [Releases](https://github.com/ThomasBandura/PSMonitorTools/releases):
- `MonitorTools-win-x64.exe` for 64-bit Windows
- `MonitorTools-win-x86.exe` for 32-bit Windows

## Installation

### Option 1: Portable
Simply download and run the executable from any location.

### Option 2: Add to PATH
1. Create a folder (e.g., `C:\Tools\MonitorTools`)
2. Copy the executable to that folder
3. Add the folder to your PATH environment variable:
   ```cmd
   setx PATH "%PATH%;C:\Tools\MonitorTools"
   ```

### Option 3: Build from Source
```bash
cd CSharp
dotnet build -c Release
```

For a self-contained executable:
```bash
cd CSharp
dotnet publish src/MonitorTools.CLI -c Release -r win-x64 --self-contained
```

## Verify Installation

```cmd
MonitorTools.exe --version
MonitorTools.exe --help
```

## Requirements

- Windows 10/11 or Windows Server 2016+
- .NET 8.0 Runtime (not required for self-contained builds)
- Administrator rights may be required for some operations
