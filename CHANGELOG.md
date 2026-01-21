# Changelog

All notable changes to PSMonitorTools will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

## [0.6.0] - Previous Release

### Added
- Smart Ordering to prevent input collisions in PBP modes
- Active waiting for monitor readiness
- Improved robustness for command execution

### Features
- Get-MonitorInfo - Retrieve monitor details
- Get/Set-MonitorBrightness - Control brightness
- Get/Set-MonitorContrast - Control contrast
- Get-MonitorInput - Check current input sources
- Switch-MonitorInput - Switch monitor inputs
- Enable/Disable-MonitorPBP - Control Picture-by-Picture mode
- Get/Set-MonitorAudioVolume - Control speaker volume
- Enable/Disable-MonitorAudio - Mute/unmute audio
- Find-MonitorVcpCodes - Discover VCP codes
- Tab completion support for monitor names
- Dual-API strategy (Low-Level API + WMI fallback)
