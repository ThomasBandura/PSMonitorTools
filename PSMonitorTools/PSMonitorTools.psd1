@{
    RootModule = 'PSMonitorTools.psm1'
    ModuleVersion = '0.1'
    GUID = '07d96b06-cac4-48db-8cc1-8d50e11a8227'
    Author = 'Thomas Bandura'
    CompanyName = ''
    Copyright = ''
    Description = 'PowerShell module to retrieve physical monitor information (Model, Serial, Firmware) and control input sources (HDMI, DP, USB-C) via DDC/CI.'
    FunctionsToExport = @('Get-MonitorInfo','Switch-MonitorInput')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
