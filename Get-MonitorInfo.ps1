# Doku: https://learn.microsoft.com/de-de/windows/win32/monitor/using-the-low-level-monitor-configuration-functions

# Shim: import module and call exported function for backward compatibility
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptDir 'PSMonitorTools'
Import-Module -Name $modulePath -Force -ErrorAction Stop
Get-MonitorInfo @Args