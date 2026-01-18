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

function Convert-WmiString {
    param($WmiOutput)
    if (-not $WmiOutput) { return $null }
    -join ($WmiOutput | Where-Object {$_} | ForEach-Object {[char]$_})
}

function ForEach-PhysicalMonitor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [scriptblock]$Action,

        [Parameter(Mandatory=$false)]
        [string]$MonitorName
    )

    $WmiMonitorsList = [System.Collections.Generic.List[psobject]]::new()
    Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue | Sort-Object InstanceName | ForEach-Object { $WmiMonitorsList.Add($_) }

    $monitorIndex = 0
    $handles = try { [PSMonitorToolsHelper]::GetMonitorHandles() } catch { @() }
    foreach ($h in $handles) {
        if (-not $h) { continue }

        $devId = $null
        try { $devId = [PSMonitorToolsHelper]::GetMonitorDevicePath($h) } catch {}

        $physicalMonitors = [PSMonitorToolsHelper]::GetPhysicalMonitors($h)
        if (-not $physicalMonitors) { continue }
        try {
            foreach ($pm in $physicalMonitors) {
                $ip = $pm.Handle
                if ($null -eq $ip) { continue }
                $pmSafe = [pscustomobject]@{ Handle = $ip; Description = $pm.Description }
                
                $wmiMonitor = $null
                
                # Check for Device Interface Path (EDD_GET_DEVICE_INTERFACE_NAME)
                # Format: \\?\DISPLAY#HwId#InstanceId#{InterfaceClassGuid}
                if ($devId -and $devId.StartsWith("\\?\")) {
                    $parts = $devId.Split('#')
                    if ($parts.Count -ge 3) {
                        $baseInstanceName = "DISPLAY\$($parts[1])\$($parts[2])"
                        $wmiMonitor = $WmiMonitorsList | Where-Object { $_.InstanceName -eq $baseInstanceName } | Select-Object -First 1
                        if (-not $wmiMonitor) {
                             $wmiMonitor = $WmiMonitorsList | Where-Object { $_.InstanceName -eq "${baseInstanceName}_0" } | Select-Object -First 1
                        }
                    }
                }

                if ($wmiMonitor) {
                    $WmiMonitorsList.Remove($wmiMonitor) | Out-Null
                }

                # Centralized Calculation and Filtering
                $cap = try { [PSMonitorToolsHelper]::GetMonitorCapabilities($pmSafe.Handle) } catch { $null }
                $model = if ($cap -and $cap -match 'model\(([^)]+)\)') { $matches[1] } else { $null }
                $wmiFriendlyName = if ($wmiMonitor) { Convert-WmiString $wmiMonitor.UserFriendlyName } else { $null }

                if (-not [string]::IsNullOrWhiteSpace($MonitorName)) {
                     Write-Verbose "Checking monitor: Description='$($pmSafe.Description)', Model='$model', WmiName='$wmiFriendlyName' against '$MonitorName'"
                     if (-not (($pmSafe.Description -and $pmSafe.Description -like "*$MonitorName*") -or 
                        ($model -and $model -like "*$MonitorName*") -or 
                        ($wmiFriendlyName -and $wmiFriendlyName -like "*$MonitorName*"))) {
                        continue
                    }
                }

                & $Action $pmSafe $wmiMonitor ([int]$monitorIndex) $cap $model $wmiFriendlyName
                $monitorIndex++
            }
        } finally { [PSMonitorToolsHelper]::DestroyPhysicalMonitors($physicalMonitors.Count, $physicalMonitors) | Out-Null }
    }
}


function Get-MonitorInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$MonitorName
    )
    $results = [System.Collections.Generic.List[psobject]]::new()

    ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($physicalMonitor, $wmiMonitor, $idx, $cap, $calculatedModel, $wmiName)

        [uint32]$currentValue = 0; [uint32]$maxValue = 0
        $name = $physicalMonitor.Description
        
        $model = if ($calculatedModel) { $calculatedModel } else { $wmiName }

        $serial = if ($wmiMonitor) { Convert-WmiString $wmiMonitor.SerialNumberID } else { $null }
        $manufacturer = if ($wmiMonitor) { Convert-WmiString $wmiMonitor.ManufacturerName } else { $null }
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

function Get-MonitorPBP {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx)
            
        $curr = 0; $max = 0
        if ([PSMonitorToolsHelper]::GetVcpFeature($pm.Handle, 0xE9, [ref]$curr, [ref]$max)) {
            # 0x00 usually means PBP Off
            return ($curr -ne 0x00)
        }
        return $false
    }
    
    if ($results -contains $true) { return $true }
    return $false
}

Export-ModuleMember -Function Get-MonitorPBP

function Get-MonitorInput {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx, $cap, $model)
            
        # Check PBP Status
        $pbpActive = $false
        $currPbp = 0; $maxPbp = 0
        if ([PSMonitorToolsHelper]::GetVcpFeature($pm.Handle, 0xE9, [ref]$currPbp, [ref]$maxPbp)) {
            $pbpActive = ($currPbp -ne 0x00)
        }

        $currentLeftVal = 0; $maxL = 0
        $currentRightVal = 0; $maxR = 0
        
        # 0x60 is standard Input Select (Left/Primary)
        $hasLeft = [PSMonitorToolsHelper]::GetVcpFeature($pm.Handle, 0x60, [ref]$currentLeftVal, [ref]$maxL)
        
        # PBP Right Input (VCP 0xE8)
        $hasRight = $false
        if ($pbpActive) {
            $hasRight = [PSMonitorToolsHelper]::GetVcpFeature($pm.Handle, 0xE8, [ref]$currentRightVal, [ref]$maxR)
        }

        $leftCode = if ($hasLeft) { $currentLeftVal -band 0xFF } else { $null }
        $rightCode = if ($hasRight) { $currentRightVal -band 0xFF } else { $null }

        $leftInputSpec = if ($null -ne $leftCode) {
            if ([Enum]::IsDefined([MonitorInput], [int]$leftCode)) { [MonitorInput][int]$leftCode } else { "Unknown (0x{0:X2})" -f $leftCode }
        } else { $null }

        $rightInputSpec = if ($null -ne $rightCode) {
            if ([Enum]::IsDefined([MonitorInput], [int]$rightCode)) { [MonitorInput][int]$rightCode } else { "Unknown (0x{0:X2})" -f $rightCode }
        } else { $null }

        [pscustomobject]@{
            Name = $pm.Description
            Model = $model
            PBP = $pbpActive
            InputLeft = $leftInputSpec
            InputRight = $rightInputSpec
        }
    }

    $results
}

Export-ModuleMember -Function Get-MonitorInput

function Switch-MonitorInput {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName,
        
        [Parameter(Mandatory = $false)]
        [Alias('InputSource')]
        [MonitorInput]$InputLeft,
        
        [Parameter(Mandatory = $false)]
        [MonitorInput]$InputRight
    )

    if (-not $PSBoundParameters.ContainsKey('InputLeft') -and -not $PSBoundParameters.ContainsKey('InputSource') -and -not $PSBoundParameters.ContainsKey('InputRight')) {
        Throw "You must specify at least one input source (-InputLeft/-InputSource or -InputRight)."
    }

    # Capture PSCmdlet context to ensure ShouldProcess prompts correctly even inside helper scopes
    $cmdletContext = $PSCmdlet
    
    # Capture presence of parameters because $PSBoundParameters inside the scriptblock will differ
    $doSetLeft = $PSBoundParameters.ContainsKey('InputLeft') -or $PSBoundParameters.ContainsKey('InputSource')
    $doSetRight = $PSBoundParameters.ContainsKey('InputRight')

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx)
            
        $success = $true

        # Check PBP Status
        $pbpActive = $false
        $currPbp = 0; $maxPbp = 0
        if ([PSMonitorToolsHelper]::GetVcpFeature($pm.Handle, 0xE9, [ref]$currPbp, [ref]$maxPbp)) {
            $pbpActive = ($currPbp -ne 0x00)
        }

        if ($pbpActive) {
            $currL = 0; $maxL = 0; $currR = 0; $maxR = 0
            $currentLeftVal = if ([PSMonitorToolsHelper]::GetVcpFeature($pm.Handle, 0x60, [ref]$currL, [ref]$maxL)) { $currL -band 0xFF } else { 0 }
            $currentRightVal = if ([PSMonitorToolsHelper]::GetVcpFeature($pm.Handle, 0xE8, [ref]$currR, [ref]$maxR)) { $currR -band 0xFF } else { 0 }

            $targetLeftKey = if ($doSetLeft) { [uint32]$InputLeft } else { $currentLeftVal }
            $targetRightKey = if ($doSetRight) { [uint32]$InputRight } else { $currentRightVal }

            if ($targetLeftKey -ne 0 -and $targetRightKey -ne 0 -and $targetLeftKey -eq $targetRightKey) {
                Write-Error ("Invalid PBP Configuration: Input Left (0x{0:x}) cannot be the same as Input Right (0x{1:x})." -f $targetLeftKey, $targetRightKey)
                return $false
            }
        }
        
        # Helper for Set and Verify
        $FnSetVerify = {
            param($Code, $Val, $Desc)
            $action = "Set $Desc input to 0x{0:X}" -f $Val
            
            if ($cmdletContext.ShouldProcess($pm.Description, $action)) {
                # Retry logic for SET command (Monitor might be busy/switching modes)
                $setSuccess = $false
                $attempt = 1
                $maxAttempts = 5

                while (-not $setSuccess -and $attempt -le $maxAttempts) {
                    if ([PSMonitorToolsHelper]::SetVCPFeature($pm.Handle, $Code, $Val)) {
                        $setSuccess = $true
                    } else {
                        Write-Verbose "Attempt $attempt/$maxAttempts to set $Desc input failed (Monitor busy?). Retrying in 1s..."
                        Start-Sleep -Seconds 1
                        $attempt++
                    }
                }

                if ($setSuccess) {
                        Write-Verbose ("Set $Desc input on $($pm.Description) to 0x{0:X}" -f $Val)
                        
                        # Verification Loop
                        $sw = [System.Diagnostics.Stopwatch]::StartNew()
                        $verified = $false
                        while ($sw.Elapsed.TotalSeconds -lt 10) {
                            Start-Sleep -Milliseconds 500
                            $c = 0; $m = 0
                            if ([PSMonitorToolsHelper]::GetVcpFeature($pm.Handle, $Code, [ref]$c, [ref]$m)) {
                                if (($c -band 0xFF) -eq ($Val -band 0xFF)) {
                                    $verified = $true
                                    Write-Verbose ("Verified $Desc input switched to 0x{0:X}" -f ($c -band 0xFF))
                                    break
                                }
                            }
                        }
                        $sw.Stop()
                        
                        if (-not $verified) {
                            Write-Warning ("Monitor '$($pm.Description)' did not confirm switch of $Desc input to '0x{0:X}' within 10 seconds." -f $Val)
                        }
                        return $true
                    } else {
                        Write-Error "Failed to set $Desc input on $($pm.Description) after $maxAttempts attempts."
                        return $false
                    }
                } else {
                    return $true
                }
            }

            # Define steps
            $steps = [System.Collections.Generic.List[psobject]]::new()
            if ($doSetLeft) { 
                $steps.Add([pscustomobject]@{ Type="Left"; Code=0x60; Input=[uint32]$InputLeft; MaskPbp=$true }) 
            }
            if ($doSetRight) { 
                $steps.Add([pscustomobject]@{ Type="Right"; Code=0xE8; Input=[uint32]$InputRight; MaskPbp=$false }) 
            }

            # Smart Ordering: Collision Detection
            # If Target Left matches Current Right, we must switch Right FIRST to free up the input.
            if ($pbpActive -and $doSetLeft -and $doSetRight) {
                # CurrentRightVal comes from the PBP check block above
                if (([uint32]$InputLeft -band 0xFF) -eq $currentRightVal) {
                    Write-Verbose "Smart Ordering: Target Left matches Current Right. Switching Right input FIRST to avoid collision."
                    $steps.Reverse()
                }
            }

            foreach ($step in $steps) {
                $val = $step.Input
                
                # If PBP is active, mask Left input with 0xF00 to prevent disabling PBP (Generic/Dell behavior)
                if ($pbpActive -and $step.MaskPbp) {
                    $val = 0xF00 + $val
                    Write-Verbose ("PBP is active. Using masked value 0x{0:X} for Left Input." -f $val)
                }

                $desc = if ($step.Type -eq "Left") { "Primary/Left" } else { "Secondary/Right" }

                if (-not (& $FnSetVerify $step.Code $val $desc)) {
                    $success = $false
                }
            }
            
            # 3. Wait for Ready State (Post-Switch Stability)
            # Ensure function doesn't return until monitor accepts DDC commands again.
            if ($success) {
                Write-Verbose "Waiting for monitor to stabilize..."
                $ready = $false
                $waitRetry = 0
                while (-not $ready -and $waitRetry -lt 20) { # Max 10 seconds wait (20 * 500ms)
                    Start-Sleep -Milliseconds 500
                    # Test Read on Input Select (0x60). If this succeeds, monitor is DDC-ready.
                    $c = 0; $m = 0
                    if ([PSMonitorToolsHelper]::GetVcpFeature($pm.Handle, 0x60, [ref]$c, [ref]$m)) {
                        $ready = $true
                        Write-Verbose "Monitor is ready for new commands."
                    } else {
                        Write-Verbose "Monitor busy (DDC read failed). Waiting..."
                        $waitRetry++
                    }
                }
            }

            return $success
    }

    if ($results -contains $true) { return $true }
    return $false
}

Export-ModuleMember -Function Switch-MonitorInput


function Enable-MonitorPBP {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    $cmdletContext = $PSCmdlet

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx)
            
        # VCP 0xE9 is commonly used for PBP/PIP. 0x24 is a common PBP mode.
        $val = 0x24 
        $action = "Enable PBP (0xE9 -> 0x24)"
        if ($cmdletContext.ShouldProcess($pm.Description, $action)) {
            if ([PSMonitorToolsHelper]::SetVCPFeature($pm.Handle, 0xE9, $val)) {
                Write-Verbose ("Enabled PBP on $($pm.Description)")
                return $true
            } else {
                Throw "Failed to enable PBP on $($pm.Description)"
            }
        } else {
            return $false
        }
    }

    if ($results -contains $true) { return $true }
    return $false
}

Export-ModuleMember -Function Enable-MonitorPBP

function Disable-MonitorPBP {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    $cmdletContext = $PSCmdlet

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx)
            
        $val = 0x00
        $action = "Disable PBP (0xE9 -> 0x00)"
        if ($cmdletContext.ShouldProcess($pm.Description, $action)) {
            if ([PSMonitorToolsHelper]::SetVCPFeature($pm.Handle, 0xE9, $val)) {
                Write-Verbose ("Disabled PBP on $($pm.Description)")
                return $true
            } else {
                Throw "Failed to disable PBP on $($pm.Description)"
            }
        } else {
            return $false
        }
    }

    if ($results -contains $true) { return $true }
    return $false
}

Export-ModuleMember -Function Disable-MonitorPBP

function Get-MonitorAudioVolume {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx, $cap, $model)
            
        $curr = 0; $max = 0
        $volume = if ([PSMonitorToolsHelper]::GetVcpFeature($pm.Handle, 0x62, [ref]$curr, [ref]$max)) { $curr } else { $null }
        
        [pscustomobject]@{
            Name = $pm.Description
            Model = $model
            Volume = $volume
        }
    }

    $results
}

Export-ModuleMember -Function Get-MonitorAudioVolume

function Set-MonitorAudioVolume {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName,
        
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 100)]
        [int]$Volume
    )

    $cmdletContext = $PSCmdlet

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx)
            
        $val = [uint32]$Volume
        $action = "Set Volume to $Volume"
        if ($cmdletContext.ShouldProcess($pm.Description, $action)) {
            if ([PSMonitorToolsHelper]::SetVCPFeature($pm.Handle, 0x62, $val)) {
                Write-Verbose ("Set volume on $($pm.Description) to $Volume")
                return $true
            } else {
                Throw "Failed to set volume on $($pm.Description)"
            }
        } else {
            return $false
        }
    }

    if ($results -contains $true) { return $true }
    return $false
}

Export-ModuleMember -Function Set-MonitorAudioVolume

function Get-MonitorAudio {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx, $cap, $model)
            
        $curr = 0; $max = 0
        $audioStatus = if ([PSMonitorToolsHelper]::GetVcpFeature($pm.Handle, 0x8D, [ref]$curr, [ref]$max)) { 
            # 0x01 = On, 0x00 = Off/Mute.
            if ($curr -eq 1) { $true } else { $false }
        } else { $null }
        
        [pscustomobject]@{
            Name = $pm.Description
            Model = $model
            AudioEnabled = $audioStatus
        }
    }

    $results
}

Export-ModuleMember -Function Get-MonitorAudio

function Enable-MonitorAudio {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    $cmdletContext = $PSCmdlet

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx)
            
        # VCP 0x8D: 0x00 = Mute, 0x01 = Unmute
        $val = 0x01 
        $action = "Enable Audio (Unmute)"
        if ($cmdletContext.ShouldProcess($pm.Description, $action)) {
            if ([PSMonitorToolsHelper]::SetVCPFeature($pm.Handle, 0x8D, $val)) {
                Write-Verbose ("Enabled audio on $($pm.Description)")
                return $true
            } else {
                Throw "Failed to enable audio on $($pm.Description)"
            }
        } else {
            return $false
        }
    }

    if ($results -contains $true) { return $true }
    return $false
}

Export-ModuleMember -Function Enable-MonitorAudio

function Disable-MonitorAudio {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    $cmdletContext = $PSCmdlet

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx)
            
        # VCP 0x8D: 0x00 = Mute, 0x01 = Unmute
        $val = 0x00
        $action = "Disable Audio (Mute)"
        if ($cmdletContext.ShouldProcess($pm.Description, $action)) {
            if ([PSMonitorToolsHelper]::SetVCPFeature($pm.Handle, 0x8D, $val)) {
                Write-Verbose ("Disabled audio on $($pm.Description)")
                return $true
            } else {
                Throw "Failed to disable audio on $($pm.Description)"
            }
        } else {
            return $false
        }
    }

    if ($results -contains $true) { return $true }
    return $false
}

Export-ModuleMember -Function Disable-MonitorAudio

function Get-MonitorBrightness {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx, $cap, $model)
            
        $curr = 0; $max = 0
        # VCP 0x10 = Luminance/Brightness
        $val = if ([PSMonitorToolsHelper]::GetVcpFeature($pm.Handle, 0x10, [ref]$curr, [ref]$max)) { $curr } else { $null }
        
        [pscustomobject]@{
            Name = $pm.Description
            Model = $model
            Brightness = $val
        }
    }

    $results
}

Export-ModuleMember -Function Get-MonitorBrightness

function Set-MonitorBrightness {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName,
        
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 100)]
        [int]$Brightness
    )

    $cmdletContext = $PSCmdlet

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx)
            
        $val = [uint32]$Brightness
        $action = "Set Brightness to $Brightness"
        if ($cmdletContext.ShouldProcess($pm.Description, $action)) {
            # VCP 0x10 = Luminance/Brightness
            if ([PSMonitorToolsHelper]::SetVCPFeature($pm.Handle, 0x10, $val)) {
                Write-Verbose ("Set brightness on $($pm.Description) to $Brightness")
                return $true
            } else {
                Throw "Failed to set brightness on $($pm.Description)"
            }
        } else {
            return $false
        }
    }

    if ($results -contains $true) { return $true }
    return $false
}

Export-ModuleMember -Function Set-MonitorBrightness

function Get-MonitorContrast {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx, $cap, $model)
            
        $curr = 0; $max = 0
        # VCP 0x12 = Contrast
        $val = if ([PSMonitorToolsHelper]::GetVcpFeature($pm.Handle, 0x12, [ref]$curr, [ref]$max)) { $curr } else { $null }
        
        [pscustomobject]@{
            Name = $pm.Description
            Model = $model
            Contrast = $val
        }
    }

    $results
}

Export-ModuleMember -Function Get-MonitorContrast

function Set-MonitorContrast {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName,
        
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 100)]
        [int]$Contrast
    )

    $cmdletContext = $PSCmdlet

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx)
            
        $val = [uint32]$Contrast
        $action = "Set Contrast to $Contrast"
        if ($cmdletContext.ShouldProcess($pm.Description, $action)) {
            # VCP 0x12 = Contrast
            if ([PSMonitorToolsHelper]::SetVCPFeature($pm.Handle, 0x12, $val)) {
                Write-Verbose ("Set contrast on $($pm.Description) to $Contrast")
                return $true
            } else {
                Throw "Failed to set contrast on $($pm.Description)"
            }
        } else {
            return $false
        }
    }

    if ($results -contains $true) { return $true }
    return $false
}

Export-ModuleMember -Function Set-MonitorContrast





function Find-MonitorVcpCodes {
    <#
    .SYNOPSIS
        Helps discover hidden or undocumented VCP codes by comparing monitor state before and after a manual OSD change.
    
    .DESCRIPTION
        This interactive tool scans a range of VCP codes (default 0xE0-0xFF plus 0x60), pauses to allow the user
        to manually change a setting on the monitor (via physical buttons), and then rescans to report any differences.
        This is useful for reverse-engineering proprietary controls like PBP inputs, specific modes, etc.
    
    .PARAMETER MonitorName
        Filter to select which monitor to scan.
    
    .PARAMETER ScanRange
        The list of VCP codes (byte array) to scan. Defaults to 0x60 plus 0xE0..0xFF.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$MonitorName,

        [Parameter(Mandatory=$false)]
        [byte[]]$ScanRange,

        [Parameter(Mandatory=$false)]
        [switch]$FullScan
    )

    if ($FullScan) {
        $ScanRange = 0x00..0xFF
    } elseif (-not $ScanRange) {
        $ScanRange = @(0x60) + (0xE0..0xFF)
    }

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx, $cap, $model)
            
        Write-Host "`nTarget Found: $($pm.Description)" -ForegroundColor Cyan
        
        # --- 1. Baseline ---
        Write-Host "[Step 1] Reading baseline VCP values ($($ScanRange.Count) codes to scan)..." -ForegroundColor Yellow
        $baseline = @{}
        $i = 0
        foreach ($code in $ScanRange) {
            $i++
            if ($i % 5 -eq 0) { Write-Progress -Activity "Reading Baseline" -Status "Scanning VCP 0x$("{0:X2}" -f $code)" -PercentComplete (($i / $ScanRange.Count) * 100) }
            
            $curr = 0; $max = 0
            if ([PSMonitorToolsHelper]::GetVcpFeature($pm.Handle, $code, [ref]$curr, [ref]$max)) {
                $baseline[$code] = $curr
            }
        }
        Write-Progress -Activity "Reading Baseline" -Completed
        Write-Host "Baseline captured ($($baseline.Count) codes readable)." -ForegroundColor Green

        # --- 2. Pause ---
        Write-Host "`n[Step 2] ACTION REQUIRED:" -ForegroundColor Cyan
        Write-Host "  1. Use your monitor's OSD buttons to CHANGE the setting you want to find."
        Write-Host "  2. Ensure the monitor is in a stable state."
        Write-Host "  3. Press ENTER here when done." -NoNewline
        Read-Host

        # --- 3. Comparison ---
        Write-Host "[Step 3] Reading new VCP values..." -ForegroundColor Yellow
        $changesFound = $false

        $i = 0
        $keysToCheck = $baseline.Keys
        foreach ($code in $keysToCheck) {
            $i++
            if ($i % 5 -eq 0) { Write-Progress -Activity "Comparing Values" -Status "Checking VCP 0x$("{0:X2}" -f $code)" -PercentComplete (($i / $keysToCheck.Count) * 100) }

            # Rescan specific code
            $curr = 0; $max = 0
            if ([PSMonitorToolsHelper]::GetVcpFeature($pm.Handle, $code, [ref]$curr, [ref]$max)) {
                $oldVal = $baseline[$code]
                if ($curr -ne $oldVal) {
                    $hexCode = "0x{0:X2}" -f $code
                    $hexOld = "0x{0:X2}" -f $oldVal
                    $hexNew = "0x{0:X2}" -f $curr
                    
                    Write-Host "CHANGE DETECTED: VCP $hexCode : $hexOld -> $hexNew" -ForegroundColor Magenta
                    $changesFound = $true
                }
            }
        }
        Write-Progress -Activity "Comparing Values" -Completed
        
        if (-not $changesFound) {
            Write-Host "No VCP changes detected in the scanned range." -ForegroundColor Gray
        }
        
        return $true
    }
    
    if ($results -notcontains $true) {
        Write-Warning "No monitor found matching '$MonitorName'"
    }
}

Export-ModuleMember -Function Find-MonitorVcpCodes

Register-ArgumentCompleter -CommandName Get-MonitorInfo, Get-MonitorInput, Get-MonitorPBP, Switch-MonitorInput, Enable-MonitorPBP, Disable-MonitorPBP, Get-MonitorAudioVolume, Set-MonitorAudioVolume, Get-MonitorAudio, Enable-MonitorAudio, Disable-MonitorAudio, Get-MonitorBrightness, Set-MonitorBrightness, Get-MonitorContrast, Set-MonitorContrast, Find-MonitorVcpCodes -ParameterName MonitorName -ScriptBlock {
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
