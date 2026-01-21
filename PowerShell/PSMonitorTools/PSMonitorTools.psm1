# Load MonitorHelper class (robust script root)
$scriptPath = $PSMyInvocation.MyCommand.Path
if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
if (-not $scriptPath) { $scriptPath = $PSCommandPath }
$PSScriptRoot = if ($scriptPath) { Split-Path -Parent $scriptPath } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }

. "$PSScriptRoot\PSMonitorToolsHelper.ps1"

#region Enums and Constants

enum MonitorInput {
    Hdmi1 = 0x11
    Hdmi2 = 0x12
    DisplayPort = 0x0F
    UsbC = 0x1b
}

# VCP Feature Codes (DDC/CI Standard)
$script:VcpCodes = @{
    InputSource = 0x60          # Primary/Left Input Select
    AudioVolume = 0x62          # Speaker Volume
    Brightness = 0x10           # Luminance
    Contrast = 0x12             # Contrast
    AudioMute = 0x8D            # Audio Mute/Unmute
    Firmware = 0xC9             # Firmware Version
    PbpMode = 0xE9              # PBP/PIP Mode
    PbpRightInput = 0xE8        # PBP Right Input Source
}

$script:PbpModeValues = @{
    Off = 0x00
    On = 0x24
    LeftInputMask = 0xF00
}

#endregion

#region Private Helper Functions

function Convert-WmiString {
    <#
    .SYNOPSIS
        Converts WMI byte array to string
    #>
    param($WmiOutput)
    if (-not $WmiOutput) { return $null }
    -join ($WmiOutput | Where-Object {$_} | ForEach-Object {[char]$_})
}

function ForEach-PhysicalMonitor {
    <#
    .SYNOPSIS
        Enumerates physical monitors and invokes an action scriptblock for each
    .DESCRIPTION
        Internal helper function to iterate through all physical monitors with optional filtering by name
    #>
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

function Invoke-VcpGet {
    <#
    .SYNOPSIS
        Helper function to get VCP feature value with standardized error handling
    #>
    param(
        [Parameter(Mandatory=$true)]
        [IntPtr]$MonitorHandle,
        
        [Parameter(Mandatory=$true)]
        [byte]$VcpCode,
        
        [Parameter(Mandatory=$false)]
        [string]$FeatureName
    )
    
    [uint32]$currentValue = 0
    [uint32]$maxValue = 0
    
    if ([PSMonitorToolsHelper]::GetVcpFeature($MonitorHandle, $VcpCode, [ref]$currentValue, [ref]$maxValue)) {
        return $currentValue
    }
    
    Write-Verbose ("Failed to read VCP code 0x{0:X2} ($FeatureName)" -f $VcpCode)
    return $null
}

function Invoke-VcpSet {
    <#
    .SYNOPSIS
        Helper function to set VCP feature value with retry logic and verification
    #>
    param(
        [Parameter(Mandatory=$true)]
        [IntPtr]$MonitorHandle,
        
        [Parameter(Mandatory=$true)]
        [byte]$VcpCode,
        
        [Parameter(Mandatory=$true)]
        [uint32]$Value,
        
        [Parameter(Mandatory=$true)]
        [string]$MonitorDescription,
        
        [Parameter(Mandatory=$false)]
        [string]$FeatureName = "VCP Feature",
        
        [Parameter(Mandatory=$false)]
        [int]$MaxRetries = 5,
        
        [Parameter(Mandatory=$false)]
        [switch]$SkipVerification
    )
    
    # Retry logic for SET command (Monitor might be busy/switching modes)
    $setSuccess = $false
    $attempt = 1

    while (-not $setSuccess -and $attempt -le $MaxRetries) {
        if ([PSMonitorToolsHelper]::SetVCPFeature($MonitorHandle, $VcpCode, $Value)) {
            $setSuccess = $true
        } else {
            Write-Verbose "Attempt $attempt/$MaxRetries to set $FeatureName failed (Monitor busy?). Retrying in 1s..."
            Start-Sleep -Seconds 1
            $attempt++
        }
    }

    if (-not $setSuccess) {
        Write-Error "Failed to set $FeatureName on $MonitorDescription after $MaxRetries attempts."
        return $false
    }
    
    Write-Verbose ("Set $FeatureName on $MonitorDescription to 0x{0:X}" -f $Value)
    
    # Verification Loop (if not skipped)
    if (-not $SkipVerification) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $verified = $false
        while ($sw.Elapsed.TotalSeconds -lt 10) {
            Start-Sleep -Milliseconds 500
            $current = Invoke-VcpGet -MonitorHandle $MonitorHandle -VcpCode $VcpCode -FeatureName $FeatureName
            if ($null -ne $current -and (($current -band 0xFF) -eq ($Value -band 0xFF))) {
                $verified = $true
                Write-Verbose ("Verified $FeatureName switched to 0x{0:X}" -f ($current -band 0xFF))
                break
            }
        }
        $sw.Stop()
        
        if (-not $verified) {
            Write-Warning ("Monitor '$MonitorDescription' did not confirm change of $FeatureName to 0x{0:X} within 10 seconds." -f $Value)
        }
    }
    
    return $true
}

function Get-MonitorVcpValue {
    <#
    .SYNOPSIS
        Generic helper to get a VCP value from all matching monitors
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$MonitorName,
        
        [Parameter(Mandatory=$true)]
        [byte]$VcpCode,
        
        [Parameter(Mandatory=$true)]
        [string]$PropertyName,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$ValueTransform
    )
    
    $results = [System.Collections.Generic.List[psobject]]::new()

    ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx, $cap, $model)
        
        $value = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $VcpCode -FeatureName $PropertyName
        
        if ($null -ne $ValueTransform) {
            $value = & $ValueTransform $value
        }
        
        $obj = [pscustomobject]@{
            Name = $pm.Description
            Model = $model
            $PropertyName = $value
        }
        $results.Add($obj) | Out-Null
    }

    return $results
}

function Set-MonitorVcpValue {
    <#
    .SYNOPSIS
        Generic helper to set a VCP value on matching monitors
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$MonitorName,
        
        [Parameter(Mandatory=$true)]
        [byte]$VcpCode,
        
        [Parameter(Mandatory=$true)]
        [uint32]$Value,
        
        [Parameter(Mandatory=$true)]
        [string]$FeatureName,
        
        [Parameter(Mandatory=$true)]
        $CmdletContext,
        
        [Parameter(Mandatory=$false)]
        [switch]$SkipVerification
    )
    
    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx)
        
        $action = "Set $FeatureName to 0x{0:X}" -f $Value
        if ($CmdletContext.ShouldProcess($pm.Description, $action)) {
            return Invoke-VcpSet -MonitorHandle $pm.Handle -VcpCode $VcpCode -Value $Value `
                -MonitorDescription $pm.Description -FeatureName $FeatureName -SkipVerification:$SkipVerification
        }
        return $false
    }

    return ($results -contains $true)
}

#endregion

#region Public Functions

function Get-MonitorInfo {
    <#
    .SYNOPSIS
        Retrieves detailed information about physical monitors
    .PARAMETER MonitorName
        Optional filter to match specific monitor by name, model, or manufacturer
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$MonitorName
    )
    $results = [System.Collections.Generic.List[psobject]]::new()

    ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($physicalMonitor, $wmiMonitor, $idx, $cap, $calculatedModel, $wmiName)

        $name = $physicalMonitor.Description
        $model = if ($calculatedModel) { $calculatedModel } else { $wmiName }
        $serial = if ($wmiMonitor) { Convert-WmiString $wmiMonitor.SerialNumberID } else { $null }
        $manufacturer = if ($wmiMonitor) { Convert-WmiString $wmiMonitor.ManufacturerName } else { $null }
        
        # Read firmware version
        $firmware = $null
        $fwValue = Invoke-VcpGet -MonitorHandle $physicalMonitor.Handle -VcpCode $script:VcpCodes.Firmware -FeatureName 'Firmware'
        if ($null -ne $fwValue) {
            $firmware = "{0:x}" -f ($fwValue -band 0x7FF)
        }
        
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
    <#
    .SYNOPSIS
        Gets the PBP (Picture-by-Picture) mode status
    .PARAMETER MonitorName
        Name or model of the monitor to query
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx)
            
        $value = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $script:VcpCodes.PbpMode -FeatureName 'PBP Mode'
        # 0x00 usually means PBP Off
        return ($null -ne $value -and $value -ne $script:PbpModeValues.Off)
    }
    
    return ($results -contains $true)
}

Export-ModuleMember -Function Get-MonitorPBP

function Get-MonitorInput {
    <#
    .SYNOPSIS
        Gets the current input source(s) of the monitor
    .PARAMETER MonitorName
        Name or model of the monitor to query
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    $results = ForEach-PhysicalMonitor -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx, $cap, $model)
            
        # Check PBP Status
        $pbpValue = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $script:VcpCodes.PbpMode -FeatureName 'PBP Mode'
        $pbpActive = ($null -ne $pbpValue -and $pbpValue -ne $script:PbpModeValues.Off)
        
        # Get Left/Primary Input
        $leftValue = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $script:VcpCodes.InputSource -FeatureName 'Input Source'
        $leftCode = if ($null -ne $leftValue) { $leftValue -band 0xFF } else { $null }
        
        # Get Right/Secondary Input (only if PBP is active)
        $rightCode = $null
        if ($pbpActive) {
            $rightValue = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $script:VcpCodes.PbpRightInput -FeatureName 'PBP Right Input'
            $rightCode = if ($null -ne $rightValue) { $rightValue -band 0xFF } else { $null }
        }

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

function Wait-MonitorInput {
    <#
    .SYNOPSIS
        Waits for a monitor to reach a specific input state with retry logic
    .DESCRIPTION
        This function repeatedly checks the monitor input state until a specified condition is met
        or the maximum number of retries is reached. Useful for waiting after input switches
        when DDC/CI communication may be temporarily unavailable.
    .PARAMETER MonitorName
        Name or model of the monitor to query
    .PARAMETER Condition
        A scriptblock that receives the monitor state and returns $true when the desired state is reached
    .PARAMETER MaxRetries
        Maximum number of retry attempts (default: 5)
    .PARAMETER RetryDelaySeconds
        Delay in seconds between retry attempts (default: 2)
    .PARAMETER TimeoutSeconds
        Alternative to MaxRetries: total timeout in seconds
    .EXAMPLE
        Wait-MonitorInput -MonitorName 'Dell' -Condition { param($s) $s.InputLeft -eq 'Hdmi1' }
    .EXAMPLE
        Wait-MonitorInput -MonitorName 'Dell' -Condition { param($s) $s.PBP -and $s.InputRight -eq 'UsbC' } -MaxRetries 10
    #>
    [CmdletBinding(DefaultParameterSetName='Retries')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$Condition,
        
        [Parameter(ParameterSetName='Retries')]
        [int]$MaxRetries = 5,
        
        [Parameter(ParameterSetName='Retries')]
        [Parameter(ParameterSetName='Timeout')]
        [int]$RetryDelaySeconds = 2,
        
        [Parameter(ParameterSetName='Timeout')]
        [int]$TimeoutSeconds
    )
    
    if ($PSCmdlet.ParameterSetName -eq 'Timeout') {
        $MaxRetries = [Math]::Ceiling($TimeoutSeconds / $RetryDelaySeconds)
    }
    
    $attempt = 0
    $lastState = $null
    
    while ($attempt -lt $MaxRetries) {
        if ($attempt -gt 0) {
            Start-Sleep -Seconds $RetryDelaySeconds
        }
        
        try {
            $state = Get-MonitorInput -MonitorName $MonitorName -ErrorAction Stop
            $lastState = $state
            
            # Check if condition is met
            if (& $Condition $state) {
                Write-Verbose "Monitor state condition met after $($attempt + 1) attempt(s)"
                return $state
            }
        } catch {
            Write-Warning "Failed to read monitor state (attempt $($attempt + 1)/$MaxRetries): $_"
        }
        
        $attempt++
    }
    
    # Condition not met within retry limit
    if ($lastState) {
        Write-Warning "Monitor state condition not met after $MaxRetries attempts. Last state: PBP=$($lastState.PBP), Left=$($lastState.InputLeft), Right=$($lastState.InputRight)"
    } else {
        Write-Warning "Failed to read monitor state after $MaxRetries attempts."
    }
    
    return $lastState
}

# Wait-MonitorInput is an internal helper function, not exported

function Switch-MonitorInput {
    <#
    .SYNOPSIS
        Switches the monitor input source(s)
    .PARAMETER MonitorName
        Name or model of the monitor to configure
    .PARAMETER InputLeft
        The input source for the left/primary display
    .PARAMETER InputRight
        The input source for the right/secondary display (PBP mode only)
    #>
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
        $pbpValue = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $script:VcpCodes.PbpMode -FeatureName 'PBP Mode'
        $pbpActive = ($null -ne $pbpValue -and $pbpValue -ne $script:PbpModeValues.Off)

        # Get current values for collision detection
        $currentLeftVal = 0
        $currentRightVal = 0
        if ($pbpActive) {
            $leftVal = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $script:VcpCodes.InputSource -FeatureName 'Input Source'
            $rightVal = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $script:VcpCodes.PbpRightInput -FeatureName 'PBP Right Input'
            $currentLeftVal = if ($null -ne $leftVal) { $leftVal -band 0xFF } else { 0 }
            $currentRightVal = if ($null -ne $rightVal) { $rightVal -band 0xFF } else { 0 }

            # Determine target values
            $targetLeftKey = if ($doSetLeft) { [uint32]$InputLeft } else { $currentLeftVal }
            $targetRightKey = if ($doSetRight) { [uint32]$InputRight } else { $currentRightVal }

            # Validate: Left and Right cannot be the same in PBP mode
            if ($targetLeftKey -ne 0 -and $targetRightKey -ne 0 -and $targetLeftKey -eq $targetRightKey) {
                Write-Error ("Invalid PBP Configuration: Input Left (0x{0:x}) cannot be the same as Input Right (0x{1:x})." -f $targetLeftKey, $targetRightKey)
                return $false
            }
        }
        
        # Helper for Set and Verify (uses Invoke-VcpSet)
        $FnSetVerify = {
            param($Code, $Val, $Desc)
            return Invoke-VcpSet -MonitorHandle $pm.Handle -VcpCode $Code -Value $Val `
                -MonitorDescription $pm.Description -FeatureName $Desc
        }

        # Define steps
        $steps = [System.Collections.Generic.List[psobject]]::new()
        if ($doSetLeft) { 
            $steps.Add([pscustomobject]@{ Type="Left"; Code=$script:VcpCodes.InputSource; Input=[uint32]$InputLeft; MaskPbp=$true }) 
        }
        if ($doSetRight) { 
            $steps.Add([pscustomobject]@{ Type="Right"; Code=$script:VcpCodes.PbpRightInput; Input=[uint32]$InputRight; MaskPbp=$false }) 
        }

        # Smart Ordering: Collision Detection
        # If Target Left matches Current Right, we must switch Right FIRST to free up the input.
        if ($pbpActive -and $doSetLeft -and $doSetRight) {
            if (([uint32]$InputLeft -band 0xFF) -eq $currentRightVal) {
                Write-Verbose "Smart Ordering: Target Left matches Current Right. Switching Right input FIRST to avoid collision."
                $steps.Reverse()
            }
        }

        foreach ($step in $steps) {
            $val = $step.Input
            
            # If PBP is active, mask Left input with 0xF00 to prevent disabling PBP (Generic/Dell behavior)
            if ($pbpActive -and $step.MaskPbp) {
                $val = $script:PbpModeValues.LeftInputMask + $val
                Write-Verbose ("PBP is active. Using masked value 0x{0:X} for Left Input." -f $val)
            }

            $desc = if ($step.Type -eq "Left") { "Primary/Left Input" } else { "Secondary/Right Input" }

            if ($cmdletContext.ShouldProcess($pm.Description, ("Set $desc to 0x{0:X}" -f $val))) {
                if (-not (& $FnSetVerify $step.Code $val $desc)) {
                    $success = $false
                }
            } else {
                return $false
            }
        }
        
        # Verification: Wait and verify the actual state matches what we requested
        if ($success) {
            Write-Verbose "Verifying monitor state..."
            $verified = $false
            $verifyRetry = 0
            $maxVerifyRetries = 8
            
            while (-not $verified -and $verifyRetry -lt $maxVerifyRetries) {
                Start-Sleep -Seconds 1
                
                try {
                    # Re-read current state
                    $actualLeftRaw = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $script:VcpCodes.InputSource -FeatureName 'Input Source'
                    
                    if ($null -eq $actualLeftRaw) {
                        Write-Verbose "Monitor busy (DDC read failed). Retry $($verifyRetry + 1)/$maxVerifyRetries"
                        $verifyRetry++
                        continue
                    }
                    
                    $actualLeft = $actualLeftRaw -band 0xFF
                    
                    # Check if Left input matches (if we set it)
                    $leftMatches = $true
                    if ($doSetLeft) {
                        $expectedLeft = [uint32]$InputLeft -band 0xFF
                        $leftMatches = ($actualLeft -eq $expectedLeft)
                        if (-not $leftMatches) {
                            Write-Verbose "Left input mismatch: Expected 0x$($expectedLeft.ToString('X')), Got 0x$($actualLeft.ToString('X')). Retry $($verifyRetry + 1)/$maxVerifyRetries"
                        }
                    }
                    
                    # Check if Right input matches (if we set it and PBP is active)
                    $rightMatches = $true
                    if ($doSetRight -and $pbpActive) {
                        $actualRightRaw = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $script:VcpCodes.PbpRightInput -FeatureName 'PBP Right Input'
                        if ($null -ne $actualRightRaw) {
                            $actualRight = $actualRightRaw -band 0xFF
                            $expectedRight = [uint32]$InputRight -band 0xFF
                            $rightMatches = ($actualRight -eq $expectedRight)
                            if (-not $rightMatches) {
                                Write-Verbose "Right input mismatch: Expected 0x$($expectedRight.ToString('X')), Got 0x$($actualRight.ToString('X')). Retry $($verifyRetry + 1)/$maxVerifyRetries"
                            }
                        }
                    }
                    
                    if ($leftMatches -and $rightMatches) {
                        $verified = $true
                        Write-Verbose "Input state verified after $($verifyRetry + 1) attempt(s)"
                    } else {
                        $verifyRetry++
                    }
                } catch {
                    Write-Verbose "Verification read failed: $_. Retry $($verifyRetry + 1)/$maxVerifyRetries"
                    $verifyRetry++
                }
            }
            
            if (-not $verified) {
                Write-Error "Failed to verify input state on $($pm.Description) after $maxVerifyRetries attempts."
                $success = $false
            }
        }

        return $success
    }

    return ($results -contains $true)
}

Export-ModuleMember -Function Switch-MonitorInput


function Enable-MonitorPBP {
    <#
    .SYNOPSIS
        Enables PBP (Picture-by-Picture) mode on the monitor
    .PARAMETER MonitorName
        Name or model of the monitor to configure
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    return Set-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.PbpMode `
        -Value $script:PbpModeValues.On -FeatureName "PBP Mode" -CmdletContext $PSCmdlet
}

Export-ModuleMember -Function Enable-MonitorPBP

function Disable-MonitorPBP {
    <#
    .SYNOPSIS
        Disables PBP (Picture-by-Picture) mode on the monitor
    .PARAMETER MonitorName
        Name or model of the monitor to configure
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    return Set-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.PbpMode `
        -Value $script:PbpModeValues.Off -FeatureName "PBP Mode" -CmdletContext $PSCmdlet
}

Export-ModuleMember -Function Disable-MonitorPBP

function Get-MonitorAudioVolume {
    <#
    .SYNOPSIS
        Gets the audio volume level of the monitor
    .PARAMETER MonitorName
        Name or model of the monitor to query
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    return Get-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.AudioVolume -PropertyName 'Volume'
}

Export-ModuleMember -Function Get-MonitorAudioVolume

function Set-MonitorAudioVolume {
    <#
    .SYNOPSIS
        Sets the audio volume level of the monitor
    .PARAMETER MonitorName
        Name or model of the monitor to configure
    .PARAMETER Volume
        Volume level (0-100)
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName,
        
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 100)]
        [int]$Volume
    )

    return Set-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.AudioVolume `
        -Value ([uint32]$Volume) -FeatureName "Audio Volume" -CmdletContext $PSCmdlet
}

Export-ModuleMember -Function Set-MonitorAudioVolume

function Get-MonitorAudio {
    <#
    .SYNOPSIS
        Gets the audio mute/unmute status of the monitor
    .PARAMETER MonitorName
        Name or model of the monitor to query
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    return Get-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.AudioMute `
        -PropertyName 'AudioEnabled' -ValueTransform { param($v) if ($null -eq $v) { $null } else { $v -eq 1 } }
}

Export-ModuleMember -Function Get-MonitorAudio

function Enable-MonitorAudio {
    <#
    .SYNOPSIS
        Unmutes the monitor audio
    .PARAMETER MonitorName
        Name or model of the monitor to configure
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    # VCP 0x8D: 0x00 = Mute, 0x01 = Unmute
    return Set-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.AudioMute `
        -Value 0x01 -FeatureName "Audio (Unmute)" -CmdletContext $PSCmdlet -SkipVerification
}

Export-ModuleMember -Function Enable-MonitorAudio

function Disable-MonitorAudio {
    <#
    .SYNOPSIS
        Mutes the monitor audio
    .PARAMETER MonitorName
        Name or model of the monitor to configure
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    # VCP 0x8D: 0x00 = Mute, 0x01 = Unmute
    return Set-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.AudioMute `
        -Value 0x00 -FeatureName "Audio (Mute)" -CmdletContext $PSCmdlet -SkipVerification
}

Export-ModuleMember -Function Disable-MonitorAudio

function Get-MonitorBrightness {
    <#
    .SYNOPSIS
        Gets the brightness level of the monitor
    .PARAMETER MonitorName
        Name or model of the monitor to query
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    return Get-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.Brightness -PropertyName 'Brightness'
}

Export-ModuleMember -Function Get-MonitorBrightness

function Set-MonitorBrightness {
    <#
    .SYNOPSIS
        Sets the brightness level of the monitor
    .PARAMETER MonitorName
        Name or model of the monitor to configure
    .PARAMETER Brightness
        Brightness level (0-100)
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName,
        
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 100)]
        [int]$Brightness
    )

    return Set-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.Brightness `
        -Value ([uint32]$Brightness) -FeatureName "Brightness" -CmdletContext $PSCmdlet
}

Export-ModuleMember -Function Set-MonitorBrightness

function Get-MonitorContrast {
    <#
    .SYNOPSIS
        Gets the contrast level of the monitor
    .PARAMETER MonitorName
        Name or model of the monitor to query
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName
    )

    return Get-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.Contrast -PropertyName 'Contrast'
}

Export-ModuleMember -Function Get-MonitorContrast

function Set-MonitorContrast {
    <#
    .SYNOPSIS
        Sets the contrast level of the monitor
    .PARAMETER MonitorName
        Name or model of the monitor to configure
    .PARAMETER Contrast
        Contrast level (0-100)
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName,
        
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 100)]
        [int]$Contrast
    )

    return Set-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.Contrast `
        -Value ([uint32]$Contrast) -FeatureName "Contrast" -CmdletContext $PSCmdlet
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

#endregion

#region Argument Completers

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

#endregion
