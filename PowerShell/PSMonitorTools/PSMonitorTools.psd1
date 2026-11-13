@{
    RootModule = 'PSMonitorTools.psm1'
    ModuleVersion = '0.9.0'
    GUID = '07d96b06-cac4-48db-8cc1-8d50e11a8227'
    Author = 'Thomas Bandura'
    CompanyName = ''
    Copyright = '(c) 2026 Thomas Bandura. MIT License.'
    PowerShellVersion = '5.1'
    Description = 'PowerShell module to retrieve physical monitor information, control input sources (HDMI, DP, USB-C), PBP modes, and Audio Volume/Mute via DDC/CI.'
    FunctionsToExport = @('Get-MonitorInfo','Get-MonitorInput','Switch-MonitorInput', 'Enable-MonitorPBP', 'Disable-MonitorPBP', 'Get-MonitorAudioVolume', 'Set-MonitorAudioVolume', 'Get-MonitorAudio', 'Enable-MonitorAudio', 'Disable-MonitorAudio', 'Get-MonitorBrightness', 'Set-MonitorBrightness', 'Get-MonitorContrast', 'Set-MonitorContrast', 'Get-MonitorPBP', 'Find-MonitorVcpCodes')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Monitor', 'DDC-CI', 'VCP', 'PBP', 'Brightness', 'Input', 'Windows')
            ProjectUri = 'https://github.com/ThomasBandura/PSMonitorTools'
            LicenseUri = 'https://github.com/ThomasBandura/PSMonitorTools/blob/master/LICENSE'
            ReleaseNotes = 'https://github.com/ThomasBandura/PSMonitorTools/blob/master/CHANGELOG.md'
        }
    }
}
