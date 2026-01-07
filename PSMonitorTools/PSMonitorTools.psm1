# Load MonitorHelper class (robust script root)
$scriptPath = $PSMyInvocation.MyCommand.Path
if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
if (-not $scriptPath) { $scriptPath = $PSCommandPath }
$PSScriptRoot = if ($scriptPath) { Split-Path -Parent $scriptPath } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }

. "$PSScriptRoot\PSMonitorToolsHelper.ps1"

enum MonitorInput {
    Hdmi1 = 0x11
    Hdmi2 = 0x12
    DisplayPort = 0x0F
    UsbC = 0x1b
}

# Internal helper: enumerate physical monitors and invoke an action scriptblock for each
function ForEach-PhysicalMonitor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [scriptblock]$Action
    )

    $ConvertToString = { -join ($args[0] | Where-Object {$_} | ForEach-Object {[char]$_}) }
    $WmiMonitors = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue | Sort-Object InstanceName)

    $monitorIndex = 0
    $handles = try { [PSMonitorToolsHelper]::GetMonitorHandles() } catch { @() }
    foreach ($h in $handles) {
        if (-not $h) { continue }
        $physicalMonitors = [PSMonitorToolsHelper]::GetPhysicalMonitors($h)
        if (-not $physicalMonitors) { continue }
        try {
            foreach ($pm in $physicalMonitors) {
                if (-not $pm -or -not $pm.Handle) { continue }
                $ip = $pm.Handle -as [IntPtr]
                if ($ip -eq $null -or $ip -eq [IntPtr]::Zero) { continue }
                $pmSafe = [pscustomobject]@{ Handle = $ip; Description = $pm.Description }
                $wmiMonitor = if ($monitorIndex -lt $WmiMonitors.Count) { $WmiMonitors[$monitorIndex] } else { $null }
                & $Action $pmSafe $wmiMonitor ([int]$monitorIndex)
                $monitorIndex++
            }
        } finally { [PSMonitorToolsHelper]::DestroyPhysicalMonitors($physicalMonitors.Count, $physicalMonitors) | Out-Null }
    }
}


function Get-MonitorInfo {
    [CmdletBinding()]
    param()
    $results = [System.Collections.Generic.List[psobject]]::new()

    ForEach-PhysicalMonitor {
        param($physicalMonitor, $wmiMonitor, $idx)

        [uint32]$currentValue = 0; [uint32]$maxValue = 0
        $name = $physicalMonitor.Description
        $cap = try { [PSMonitorToolsHelper]::GetMonitorCapabilities($physicalMonitor.Handle) } catch { $null }
        if ($cap -and $cap -match 'model\(([^)]+)\)') { $model = $matches[1] } else { $model = if ($wmiMonitor) { (& { -join ($args[0] | Where-Object {$_} | ForEach-Object {[char]$_}) } $wmiMonitor.UserFriendlyName) } else { $null } }
        $serial = if ($wmiMonitor) { (& { -join ($args[0] | Where-Object {$_} | ForEach-Object {[char]$_}) } $wmiMonitor.SerialNumberID) } else { $null }
        $manufacturer = if ($wmiMonitor) { (& { -join ($args[0] | Where-Object {$_} | ForEach-Object {[char]$_}) } $wmiMonitor.ManufacturerName) } else { $null }
        if ($physicalMonitor.Handle -and [PSMonitorToolsHelper]::GetVcpFeature($physicalMonitor.Handle, 0xC9, [ref]$currentValue, [ref]$maxValue)) { $firmware = "{0:x}" -f ($currentValue -band 0x7FF) } else { $firmware = $null }
        $week = if ($wmiMonitor) { $wmiMonitor.WeekOfManufacture } else { $null }
        $year = if ($wmiMonitor) { $wmiMonitor.YearOfManufacture } else { $null }

        $obj = [pscustomobject]@{
            Index = $idx
            Name = $name
            Model = $model
            SerialNumber = $serial
            Manufacturer = $manufacturer
            Firmware = $firmware
            WeekOfManufacture = $week
            YearOfManufacture = $year
        }
        $results.Add($obj) | Out-Null
    }

    $results
}

Export-ModuleMember -Function Get-MonitorInfo

function Switch-MonitorInput {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Hdmi1','Hdmi2','DisplayPort','UsbC')]
        [MonitorInput]$InputSource
    )

    # Capture PSCmdlet context to ensure ShouldProcess prompts correctly even inside helper scopes
    $cmdletContext = $PSCmdlet

    $results = ForEach-PhysicalMonitor {
        param($pm, $wmiMonitor, $idx)
        
        $model = try { if ([PSMonitorToolsHelper]::GetMonitorCapabilities($pm.Handle) -match 'model\(([^)]+)\)') { $matches[1] } else { $null } } catch { $null }
        $wmiName = if ($wmiMonitor) { -join ($wmiMonitor.UserFriendlyName | Where-Object {$_} | ForEach-Object {[char]$_}) } else { $null }

        Write-Verbose "Checking monitor: Description='$($pm.Description)', Model='$model', WmiName='$wmiName' against '$MonitorName'"

        if (($pm.Description -and $pm.Description -like "*$MonitorName*") -or 
            ($model -and $model -like "*$MonitorName*") -or 
            ($wmiName -and $wmiName -like "*$MonitorName*")) {
            
            $val = [uint32]$InputSource
            $action = "Set input to $InputSource"
            if ($cmdletContext.ShouldProcess($pm.Description, $action)) {
                if ([PSMonitorToolsHelper]::SetVCPFeature($pm.Handle, 0x60, $val)) {
                    Write-Verbose ("Set input on $($pm.Description) to $InputSource (0x{0:x})" -f $val)
                    return $true
                } else {
                    Throw "Failed to set input on $($pm.Description)"
                }
            } else {
                Write-Verbose "Skipping input change for $($pm.Description) (WhatIf/Confirm)"
                return $false
            }
        }
        return $false
    }

    if ($results -contains $true) { return $true }
    return $false
}

Export-ModuleMember -Function Switch-MonitorInput

Register-ArgumentCompleter -CommandName Switch-MonitorInput -ParameterName MonitorName -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $candidates = [System.Collections.Generic.List[string]]::new()

    # 1. Try to get info via exported Get-MonitorInfo
    try {
        if (Get-Command Get-MonitorInfo -ErrorAction SilentlyContinue) {
            $monitors = Get-MonitorInfo -ErrorAction SilentlyContinue
            if ($monitors) {
                $monitors.Name | Where-Object { $_ } | ForEach-Object { $candidates.Add($_) }
                $monitors.Model | Where-Object { $_ } | ForEach-Object { $candidates.Add($_) }
            }
        }
    } catch { }

    # 2. Add WMI fallback (usually works even if API fails)
    try {
        $wmi = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue
        foreach ($m in $wmi) {
            if ($m.UserFriendlyName) {
                $name = -join ($m.UserFriendlyName | Where-Object {$_} | ForEach-Object {[char]$_})
                if (-not [string]::IsNullOrWhiteSpace($name)) { $candidates.Add($name) }
            }
        }
    } catch { }

    # 3. Filter and return
    $results = $candidates | Sort-Object -Unique
    foreach ($val in $results) {
        if ($val -like "*$wordToComplete*") {
            $quoted = "'$val'"
            [System.Management.Automation.CompletionResult]::new($quoted, $val, 'ParameterValue', $val)
        }
    }
}
