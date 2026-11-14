# Changelog

All notable changes to PSMonitorTools will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- C#/CLI: input switches are confirmed by the monitor step by step instead of fixed 2-second pauses; a switch the monitor ignores now fails with exit code 1 instead of reporting success. A missing DDC/CI answer after switching away is reported as a warning.
- C#/CLI: while PBP is active, a left input already shown on the right (and vice versa) is rejected, and swapping left and right is rejected with a clear message; the monitor silently ignored both before. PowerShell rejects the swap up front as well.
- C#: `EnablePbp`/`DisablePbp` wait until the monitor confirms the PBP change (up to 15 s), and VCP reads are retried up to 3 times like in the PowerShell module, so commands right after a PBP change no longer fail.
- CLI: `vcp set` accepts hex values (`vcp set 0x60 0xF0F`), as already shown in the documentation.
- C#: `SetInput` (`input set`, `input switch`, `pbp set-left`) masks the left input with 0xF00 while PBP is active, like the PowerShell module. On the Dell U4924DW, PBP also stayed on without the mask (#6).
- C#: every VCP 0xE9 value other than 0x00 counts as PBP active, like the PowerShell module; monitors without PBP support count as inactive when switching inputs (#7).

### Changed
- PowerShell: the capabilities string (model name) is read once per monitor and session instead of on every cmdlet call; on the Dell U4924DW a call drops from about 1.8 s to under 0.1 s after the first one (#21).
- PowerShell: tab completion for `-MonitorName` uses monitor descriptions, WMI names and cached model names only, without DDC/CI reads (#21).
- CLI: migrated from System.CommandLine 2.0.0-beta4 to 3.0.0; shared `--monitor` option and central error handling, commands return exit codes instead of calling `Environment.Exit` (#27).
- C#: monitor indexes refer to physical monitors (like the PowerShell module), so cloned displays are reachable individually (#8).
- Brightness, contrast and volume are checked against the maximum reported by the monitor instead of a fixed 0-100; C# sets the brightness via VCP 0x10 like the PowerShell module (#30).

### Documentation
- Audio mute (VCP 0x8D) is documented as device-specific: Dell U4924DW uses 0x00 = muted, 0x01 = unmuted and ignores the MCCS values (0x01 = muted, 0x02 = unmuted) (#15).

### Tests
- More Pester tests with mocked hardware (retries, PBP mask, collision handling, smart ordering, input evaluation, monitor maximum); coverage 62% -> 78% (#25).

## [1.0.0] - 2026-11-13

### Breaking Changes
- PowerShell: Set/Switch cmdlets write an error when no monitor matches `-MonitorName` and return `$true` only if all matching monitors succeeded (#10).
- PowerShell: native helper types moved to the namespace `PSMonitorTools.Native` (`[PSMonitorToolsHelper]` is now `[PSMonitorTools.Native.MonitorHelper]`) (#31).
- CLI: `vcp set` requires `--force` for codes that reset settings or change the power state (0x04, 0x05, 0x06, 0x08, 0x0A, 0xB0, 0xD6) (#19).

### Added
- CLI: `input switch --left/--right` switches inputs with PBP collision handling (#23).
- C#: `SetInputSmart` and the PBP methods are part of `IMonitorService` (#23).

### Fixed
- C#: manufacturer, model and serial number are assigned per monitor instead of using the first WMI entry for all (#3).
- PowerShell: `Switch-MonitorInput` verifies each step once (no second verification loop) and reports a missing DDC/CI response after switching away as a warning (#9).
- PowerShell: transient DDC/CI read failures are retried (up to 3 attempts), e.g. right after an input or PBP change.
- C#: monitor handles are looked up per call, so a long-lived `MonitorService` keeps working after PBP changes re-enumerate the display.

### Changed
- C#: WMI, brightness and firmware data are loaded lazily, only for `get-info` (#22).
- PowerShell: module cleanup, `ForEach-PhysicalMonitor` renamed to `Invoke-PhysicalMonitorAction`, exports in one place (#33).
- Versions aligned to `1.0.0`; the C# version is defined once in `CSharp/Directory.Build.props`.

## [0.9.1] - 2026-11-13

### Fixed
- CI/Release: use .NET SDK from `global.json` instead of .NET 8 (#2).
- C#: `SetVcpFeature`/`SetBrightness` now fail instead of silently reporting success (#4).
- CLI: all `pbp` subcommands accept `--monitor`/`-m` (#5) and write errors to stderr (#12).
- PowerShell: wildcard characters in `-MonitorName` and quotes in tab completion are escaped (#11).
- C#: physical monitor handles are always released; errors include the Win32 error code (#28, #29).

### Security
- `dxva2.dll`/`user32.dll` are only loaded from System32 (#16).
- Workflows: least-privilege token permissions, updated actions, third-party actions pinned by SHA (#17).
- Release workflow validates the tag version and no longer interpolates it into scripts (#18).
- Pester pinned to 5.7.1 in CI (#20).

### Changed
- C# hardware tests only run with `MONITORTOOLS_HARDWARE_TESTS=1` (#24).
- Code coverage includes `PSMonitorTools.psm1` (#26).
- Build script reads the version from the module manifest; docs updated to .NET 10 (#14).
- Module manifest declares `PowerShellVersion`, `Copyright` and gallery metadata (#32).

### Removed
- Unused internal `Wait-MonitorInput` function (#13) and unused P/Invoke declarations (#28).

## [0.9.0] - 2026-06-09

### Changed
- Upgraded C# projects to .NET 10.0 and pinned SDK to `10.0.300`.
- Bumped package/module versions to `0.9.0`.
- Updated documentation and build scripts for the new SDK and version.

## [0.8.3] - 2026-01-23

### Fixed
- Fixed deprecated `set-output` command in GitHub Actions workflows
- Replaced deprecated `actions/create-release@v1` and `actions/upload-release-asset@v1` with `softprops/action-gh-release@v1`
- Fixed release asset naming conflict by renaming executables to `MonitorTools-win-x64.exe` and `MonitorTools-win-x86.exe`
- Improved release workflow reliability and modernized GitHub Actions implementation

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
