@{
    RootModule = 'PSMonitorTools.psm1'
    ModuleVersion = '0.3'
    GUID = '07d96b06-cac4-48db-8cc1-8d50e11a8227'
    Author = 'Thomas Bandura'
    CompanyName = ''
    Copyright = ''
    Description = 'PowerShell module to retrieve physical monitor information, control input sources (HDMI, DP, USB-C), PBP modes, and Audio Volume/Mute via DDC/CI.'
    FunctionsToExport = @('Get-MonitorInfo','Switch-MonitorInput', 'Enable-MonitorPBP', 'Disable-MonitorPBP', 'Set-MonitorAudioVolume', 'Enable-MonitorAudio', 'Disable-MonitorAudio')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
