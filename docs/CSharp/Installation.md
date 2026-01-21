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

#### Development Build
Build for testing and development:
```bash
cd CSharp
dotnet build
```

#### Release Build
Build optimized release version:
```bash
cd CSharp
dotnet build -c Release
```

#### Run Tests
```bash
# Run all tests
dotnet test

# Run only unit tests
dotnet test --filter "FullyQualifiedName~Core.Tests"

# Run only integration tests
dotnet test --filter "FullyQualifiedName~IntegrationTests"

# Run with detailed output
dotnet test --verbosity normal
```

#### Publish Single-File Executable

**Framework-Dependent** (~1.2 MB, requires .NET 8 Runtime):
```bash
cd CSharp
dotnet publish src/MonitorTools.CLI/MonitorTools.CLI.csproj -c Release -r win-x64 -o publish
```
The executable will be in `publish/MonitorTools.exe`

**Self-Contained** (~34 MB, no runtime needed):
```bash
cd CSharp
dotnet publish src/MonitorTools.CLI/MonitorTools.CLI.csproj -c Release -r win-x64 --self-contained -o publish -p:EnableCompressionInSingleFile=true
```
The executable will be in `publish/MonitorTools.exe` and can run on any Windows x64 machine without .NET installed.

**Other Platforms**:
```bash
# Windows x86 (32-bit)
dotnet publish src/MonitorTools.CLI/MonitorTools.CLI.csproj -c Release -r win-x86 --self-contained -o publish

# Windows ARM64
dotnet publish src/MonitorTools.CLI/MonitorTools.CLI.csproj -c Release -r win-arm64 --self-contained -o publish
```

## Verify Installation

```cmd
MonitorTools.exe --version
MonitorTools.exe --help
```

## Requirements

- Windows 11
- .NET 8.0 Runtime (not required for self-contained builds)
