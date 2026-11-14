# Contributing to PSMonitorTools

Thank you for your interest in contributing to PSMonitorTools! This document provides guidelines and instructions for contributing.

## Code of Conduct

Be respectful and constructive in all interactions. We're here to build useful tools together.

## How to Contribute

### Reporting Bugs

When reporting bugs, please include:
- Your Windows version
- PowerShell or C# version
- Monitor make and model
- Steps to reproduce the issue
- Expected vs. actual behavior
- Any error messages

### Suggesting Features

Feature requests are welcome! Please:
- Check if the feature already exists
- Explain the use case
- Provide examples if possible

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - PowerShell: Follow existing code style
   - C#: Follow C# conventions, use nullable reference types
   - Add tests where applicable
   - Update documentation

4. **Test your changes**
   - PowerShell: Run Pester tests
     ```powershell
     Invoke-Pester PowerShell/Tests/
     ```
   - C#: Run unit tests
     ```bash
     dotnet test CSharp/MonitorTools.sln
     ```

5. **Commit your changes**
   ```bash
   git commit -m "Add feature: description"
   ```

6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Open a Pull Request**

## Development Setup

### PowerShell Development

Requirements:
- PowerShell 5.1 or PowerShell 7+
- Pester 5.0+ for testing

```powershell
# Install Pester
Install-Module -Name Pester -Force -SkipPublisherCheck

# Import module for testing
Import-Module ./PowerShell/PSMonitorTools/PSMonitorTools.psd1

# Run tests
Invoke-Pester ./PowerShell/Tests/
```

### C# Development

Requirements:
- .NET 10.0 SDK (see `global.json`)
- Visual Studio 2022 or VS Code with C# extension

```bash
# Restore dependencies
dotnet restore CSharp/MonitorTools.sln

# Build
dotnet build CSharp/MonitorTools.sln

# Run tests (hardware tests are skipped by default)
dotnet test CSharp/MonitorTools.sln

# Run hardware tests too (switches real monitor inputs/PBP!)
dotnet test CSharp/MonitorTools.sln -s CSharp/tests/hardware.runsettings

# Run CLI
dotnet run --project CSharp/src/MonitorTools.CLI
```

To run the hardware tests from the VS Code Test Explorer (C# Dev Kit), add this to your
**user** settings (not the shared `.vscode/settings.json`, otherwise they run for everyone)
and reload the window:

```json
"dotnet.unitTests.runSettingsPath": "<repo>/CSharp/tests/hardware.runsettings"
```

## Code Style

### PowerShell
- The module must keep working on **Windows PowerShell 5.1** (CI runs the tests on 5.1 and 7). Avoid PowerShell 7-only syntax (`?.`, `??`, ternary `? :`, `&&`/`||`) and keep the code readable: no precompiled binaries, native calls stay as C# source in `PSMonitorToolsHelper.ps1`.
- Use approved verbs (Get, Set, Enable, Disable, etc.)
- Follow [PowerShell Best Practices](https://poshcode.gitbooks.io/powershell-practice-and-style/)
- Include comment-based help for all functions
- Use parameter validation attributes

### C#
- Follow standard C# naming conventions
- Use nullable reference types
- Add XML documentation comments
- Keep methods focused and testable
- Use dependency injection where appropriate

## Testing

### Shared behavior rules
The PowerShell module and `MonitorTools.Core` implement the same rules (PBP detection, left input mask, value limits, input switch order and rejections). They are described once as test cases in [`spec/monitor-behavior.json`](spec/monitor-behavior.json) and both test suites run them. When you change such a rule, update the spec and both implementations; see [`spec/README.md`](spec/README.md).

### PowerShell
- Add Pester tests for new cmdlets
- Test both success and error scenarios
- Mock external dependencies where possible

### C#
- Write unit tests using xUnit
- Aim for high code coverage
- Test edge cases and error conditions

## Documentation

- Update README.md if adding major features
- Add examples to docs/Examples/
- Update API documentation
- Include usage examples in your PR description

## Questions?

Feel free to open an issue for questions or discussions!

Thank you for contributing! 🎉
