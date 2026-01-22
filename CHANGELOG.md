# Changelog

All notable changes to PSMonitorTools will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.8.1] - 2026-01-22

### Changed
- Changed license from Creative Commons to MIT License
- Updated project to allow commercial use
- Fix: Add permissions for release creation

## [0.8.0] - 2026-01-21

### Added
- C# implementation with CLI and Core library
- `MonitorTools.Core` - Reusable C# library for monitor operations
- `MonitorTools.CLI` - Command-line executable for Windows
- Comprehensive documentation for both PowerShell and C# implementations
- GitHub Actions CI/CD workflows for automated building and testing
- Unit tests for C# Core library

### Changed
- Restructured repository to support both PowerShell and C# implementations
- Moved PowerShell module to `PowerShell/` subdirectory
- Updated README with information about both implementations
- Enhanced .gitignore for C#/.NET projects
- Unified version numbering (0.8.0) across PowerShell and C# implementations

## [0.7.0] - 2026-01-19

### Changed
- Refactored monitor control functions for consistency
- Improved code organization and maintainability

## [0.6.3] - 2026-01-18

### Changed
- Refactored `Switch-MonitorInput` for improved clarity in target key assignment
- Enhanced monitor function filtering logic
- Added comprehensive tests for audio, contrast, and brightness controls

### Fixed
- Improved monitor-to-WMI mapping using device path matching
- Refined monitor handle validation logic
- Enhanced monitor helper stability

## [0.6.0] - 2026-01-16

### Added
- Smart ordering to prevent input collisions in PBP modes
- Active waiting for monitor readiness
- Project goals section to documentation

### Changed
- Simplified monitor handle null check logic
- Removed fallback WMI monitor matching logic
- Improved overall robustness for command execution
- Limited CI test runs to Monitor.Tests.ps1 for efficiency

## [0.5.0] - 2026-01-14

### Added
- Monitor input switching reliability improvements
- Enhanced collision handling for PBP mode input switching

### Changed
- Improved input switching reliability with retry logic
- Better error handling for monitor state transitions

## [0.4.0] - 2026-01-11

### Added
- `Get-MonitorInput` - Check current input sources
- `Switch-MonitorInput` - Switch monitor inputs with PBP support
- `Get-MonitorBrightness` / `Set-MonitorBrightness` - Control brightness
- `Get-MonitorContrast` / `Set-MonitorContrast` - Control contrast
- `Get-MonitorAudioVolume` / `Set-MonitorAudioVolume` - Control speaker volume
- `Get-MonitorPBP` - Get PBP mode status
- `Find-MonitorVcpCodes` - Interactive VCP code discovery tool
- Enhanced `Switch-MonitorInput` logic with smart PBP handling

### Changed
- Improved README with comprehensive examples
- Enhanced test coverage

## [0.3.0] - 2026-01-10

### Added
- `Enable-MonitorAudio` / `Disable-MonitorAudio` - Mute/unmute monitor audio
- `Get-MonitorAudio` - Get audio mute state
- Audio control functions using VCP codes
- Audio volume control examples

### Changed
- Enhanced README with audio control documentation
- Added audio control tests

## [0.2.0] - 2026-01-09

### Added
- `Enable-MonitorPBP` / `Disable-MonitorPBP` - Control Picture-by-Picture mode
- PBP mode support for dual input configurations
- PBP control examples and documentation

### Changed
- Updated README with PBP functionality
- Added PBP-related tests

## [0.1.0] - 2026-01-08

### Added
- Initial release of PSMonitorTools
- `Get-MonitorInfo` - Retrieve detailed monitor information
- Pester test framework setup
- GitHub Actions CI workflow
- Basic documentation and README
- Tab completion support for monitor names
- Dual-API strategy (Low-Level Monitor Configuration API + WMI fallback)
- Support for retrieving:
  - Monitor manufacturer, model, serial number
  - Screen resolution (width/height)
  - Primary monitor detection
  - Firmware version
  - Manufacturing date (week/year)
  - Current brightness level
