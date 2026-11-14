# Load native helper types (PSMonitorTools.Native)
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

# Capabilities strings per physical monitor for the current session (#21).
# Reading them via DDC/CI takes about 2 seconds per monitor, but the content does not change.
$script:CapabilitiesCache = @{}

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

function Read-MonitorCapabilitiesNative {
    <#
    .SYNOPSIS
        Reads the DDC/CI capabilities string of a physical monitor once. Returns $null on failure.
    .DESCRIPTION
        Thin wrapper around the slow native call so the caching can be tested with mocks.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [IntPtr]$MonitorHandle
    )

    try { return [PSMonitorTools.Native.MonitorHelper]::GetMonitorCapabilities($MonitorHandle) } catch { return $null }
}

function Get-MonitorCapabilities {
    <#
    .SYNOPSIS
        Returns the capabilities string of a physical monitor, cached per session
    .DESCRIPTION
        The cache key is built from the device path, the position behind the display and the
        description, so it stays valid while the physical monitor handles change between calls.
        Failed reads are not cached and are retried on the next call.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [IntPtr]$MonitorHandle,

        [Parameter(Mandatory=$true)]
        [string]$CacheKey
    )

    if ($script:CapabilitiesCache.ContainsKey($CacheKey)) {
        return $script:CapabilitiesCache[$CacheKey]
    }

    $cap = Read-MonitorCapabilitiesNative -MonitorHandle $MonitorHandle
    if (-not [string]::IsNullOrEmpty($cap)) {
        $script:CapabilitiesCache[$CacheKey] = $cap
    }
    return $cap
}

function Get-MonitorNameCandidate {
    <#
    .SYNOPSIS
        Returns monitor names for the argument completer without slow DDC/CI reads
    .DESCRIPTION
        Uses the physical monitor descriptions, the WMI friendly names and the model names
        that are already cached. Capabilities and firmware are not read.
    #>
    $candidates = [System.Collections.Generic.List[string]]::new()

    $handles = try { [PSMonitorTools.Native.MonitorHelper]::GetMonitorHandles() } catch { @() }
    foreach ($h in $handles) {
        if (-not $h) { continue }
        $physicalMonitors = try { [PSMonitorTools.Native.MonitorHelper]::GetPhysicalMonitors($h) } catch { $null }
        if (-not $physicalMonitors) { continue }
        try {
            foreach ($pm in $physicalMonitors) {
                if (-not [string]::IsNullOrWhiteSpace($pm.Description)) { $candidates.Add($pm.Description) }
            }
        } finally { [PSMonitorTools.Native.MonitorHelper]::DestroyPhysicalMonitors($physicalMonitors.Count, $physicalMonitors) | Out-Null }
    }

    $wmi = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue
    foreach ($m in $wmi) {
        $name = Convert-WmiString $m.UserFriendlyName
        if (-not [string]::IsNullOrWhiteSpace($name)) { $candidates.Add($name) }
    }

    foreach ($cap in $script:CapabilitiesCache.Values) {
        if ($cap -match 'model\(([^)]+)\)') { $candidates.Add($matches[1]) }
    }

    $candidates | Sort-Object -Unique
}

#region Behavior Rules
# Pure functions without DDC/CI access. They are checked against spec/monitor-behavior.json,
# the same cases MonitorTools.Core (C#) is tested with.

function Test-PbpModeActive {
    <#
    .SYNOPSIS
        Returns $true if a VCP 0xE9 value means PBP/PIP is active
    .DESCRIPTION
        Every value other than 0x00 counts as active (spec: pbpActive). $null (not readable) is inactive.
    #>
    param(
        [Parameter(Mandatory=$false)]
        $Value
    )

    return ($null -ne $Value -and $Value -ne $script:PbpModeValues.Off)
}

function Get-LeftInputValue {
    <#
    .SYNOPSIS
        Returns the VCP 0x60 value for the left input
    .DESCRIPTION
        While PBP is active, the value is masked with 0xF00 so that PBP stays on (spec: leftInputValue).
    #>
    param(
        [Parameter(Mandatory=$true)]
        [MonitorInput]$InputSource,

        [Parameter(Mandatory=$true)]
        [bool]$PbpActive
    )

    $value = [uint32]$InputSource
    if ($PbpActive) {
        $value = $script:PbpModeValues.LeftInputMask + $value
    }
    return [uint32]$value
}

function Get-VcpValueLimit {
    <#
    .SYNOPSIS
        Returns the highest allowed value for a continuous VCP feature (brightness, contrast, volume)
    .DESCRIPTION
        The maximum reported by the monitor. A maximum of 0 means the monitor did not report one;
        then 0-100 is assumed (spec: continuousValue).
    #>
    param(
        [Parameter(Mandatory=$false)]
        $Maximum
    )

    if ($Maximum -gt 0) { return [uint32]$Maximum }
    return [uint32]100
}

function Get-InputSwitchPlan {
    <#
    .SYNOPSIS
        Plans the order of an input switch and rejects combinations the monitor would ignore
    .DESCRIPTION
        While PBP is active, the monitor silently ignores a switch to the input the other side is
        showing. Rules (spec: inputSwitch):
        - Left and right must not end up on the same input ('Conflict').
        - Swapping both sides is not possible in one step ('Swap').
        - If the new left input is still shown on the right, the right side is switched first.
        Returns an object with Steps (Side, Input), Error ($null, 'Conflict' or 'Swap') and Message.
    .PARAMETER CurrentLeft
        Current left input code (low byte of VCP 0x60), 0 if unknown
    .PARAMETER CurrentRight
        Current right input code (low byte of VCP 0xE8), 0 if unknown
    #>
    param(
        [Parameter(Mandatory=$true)]
        [bool]$PbpActive,

        [Parameter(Mandatory=$false)]
        [int]$CurrentLeft = 0,

        [Parameter(Mandatory=$false)]
        [int]$CurrentRight = 0,

        # Target inputs; $null means "do not change this side"
        [Parameter(Mandatory=$false)]
        $Left = $null,

        [Parameter(Mandatory=$false)]
        $Right = $null
    )

    $steps = [System.Collections.Generic.List[psobject]]::new()
    if ($null -ne $Left) { $steps.Add([pscustomobject]@{ Side = 'Left'; Input = [MonitorInput]$Left }) }
    if ($null -ne $Right) { $steps.Add([pscustomobject]@{ Side = 'Right'; Input = [MonitorInput]$Right }) }

    $plan = [pscustomobject]@{ Steps = $steps; Error = $null; Message = $null }
    if (-not $PbpActive) {
        return $plan
    }

    $targetLeft = if ($null -ne $Left) { [int][MonitorInput]$Left } else { $CurrentLeft }
    $targetRight = if ($null -ne $Right) { [int][MonitorInput]$Right } else { $CurrentRight }

    if ($targetLeft -ne 0 -and $targetLeft -eq $targetRight) {
        $plan.Error = 'Conflict'
        $plan.Message = if ($null -ne $Left -and $null -ne $Right) {
            "Invalid PBP configuration: left and right input cannot both be $([MonitorInput]$targetLeft)."
        } elseif ($null -ne $Left) {
            "Invalid PBP configuration: $([MonitorInput]$targetLeft) is already used by the right side."
        } else {
            "Invalid PBP configuration: $([MonitorInput]$targetLeft) is already used by the left side."
        }
        $plan.Steps = @()
        return $plan
    }

    $bothSides = ($null -ne $Left -and $null -ne $Right)
    if ($bothSides -and $targetLeft -eq $CurrentRight -and $targetRight -eq $CurrentLeft) {
        $plan.Error = 'Swap'
        $plan.Message = "Swapping left ($([MonitorInput]$CurrentLeft)) and right ($([MonitorInput]$CurrentRight)) is not possible in one step: " +
            "the monitor ignores a switch to the input the other side is showing. Switch one side to a free input first."
        $plan.Steps = @()
        return $plan
    }

    # The new left input is still shown on the right: switch the right side first to free it
    if ($bothSides -and $targetLeft -eq $CurrentRight) {
        $steps.Reverse()
    }

    return $plan
}

#endregion

function Invoke-PhysicalMonitorAction {
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
    $handles = try { [PSMonitorTools.Native.MonitorHelper]::GetMonitorHandles() } catch { @() }
    foreach ($h in $handles) {
        if (-not $h) { continue }

        $devId = $null
        try { $devId = [PSMonitorTools.Native.MonitorHelper]::GetMonitorDevicePath($h) } catch {}

        $physicalMonitors = [PSMonitorTools.Native.MonitorHelper]::GetPhysicalMonitors($h)
        if (-not $physicalMonitors) { continue }
        try {
            $physicalIndex = -1
            foreach ($pm in $physicalMonitors) {
                $physicalIndex++
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
                        $wmiMonitor = $WmiMonitorsList.Where({ $_.InstanceName -eq $baseInstanceName }, 'First')[0]
                        if (-not $wmiMonitor) {
                             $wmiMonitor = $WmiMonitorsList.Where({ $_.InstanceName -eq "${baseInstanceName}_0" }, 'First')[0]
                        }
                    }
                }

                if ($wmiMonitor) {
                    $WmiMonitorsList.Remove($wmiMonitor) | Out-Null
                }

                # Centralized Calculation and Filtering
                $cacheKey = "$devId|$physicalIndex|$($pmSafe.Description)"
                $cap = Get-MonitorCapabilities -MonitorHandle $pmSafe.Handle -CacheKey $cacheKey
                $model = if ($cap -and $cap -match 'model\(([^)]+)\)') { $matches[1] } else { $null }
                $wmiFriendlyName = if ($wmiMonitor) { Convert-WmiString $wmiMonitor.UserFriendlyName } else { $null }

                if (-not [string]::IsNullOrWhiteSpace($MonitorName)) {
                     $namePattern = "*$([WildcardPattern]::Escape($MonitorName))*"
                     Write-Verbose "Checking monitor: Description='$($pmSafe.Description)', Model='$model', WmiName='$wmiFriendlyName' against '$MonitorName'"
                     if (-not (($pmSafe.Description -and $pmSafe.Description -like $namePattern) -or 
                        ($model -and $model -like $namePattern) -or 
                        ($wmiFriendlyName -and $wmiFriendlyName -like $namePattern))) {
                        continue
                    }
                }

                & $Action $pmSafe $wmiMonitor ([int]$monitorIndex) $cap $model $wmiFriendlyName
                $monitorIndex++
            }
        } finally { [PSMonitorTools.Native.MonitorHelper]::DestroyPhysicalMonitors($physicalMonitors.Count, $physicalMonitors) | Out-Null }
    }
}

function Read-VcpFeatureNative {
    <#
    .SYNOPSIS
        Reads a VCP feature once via DDC/CI. Returns an object with Current and Maximum, or $null.
    .DESCRIPTION
        Thin wrapper around the native call so the retry and verification logic can be tested with mocks.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [IntPtr]$MonitorHandle,

        [Parameter(Mandatory=$true)]
        [byte]$VcpCode
    )

    [uint32]$currentValue = 0
    [uint32]$maxValue = 0
    if ([PSMonitorTools.Native.MonitorHelper]::GetVcpFeature($MonitorHandle, $VcpCode, [ref]$currentValue, [ref]$maxValue)) {
        return [pscustomobject]@{ Current = $currentValue; Maximum = $maxValue }
    }
    return $null
}

function Write-VcpFeatureNative {
    <#
    .SYNOPSIS
        Writes a VCP feature once via DDC/CI. Returns $true on success.
    .DESCRIPTION
        Thin wrapper around the native call so the retry logic can be tested with mocks.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [IntPtr]$MonitorHandle,

        [Parameter(Mandatory=$true)]
        [byte]$VcpCode,

        [Parameter(Mandatory=$true)]
        [uint32]$Value
    )

    return [PSMonitorTools.Native.MonitorHelper]::SetVCPFeature($MonitorHandle, $VcpCode, $Value)
}

function Invoke-VcpGet {
    <#
    .SYNOPSIS
        Helper function to get VCP feature value with standardized error handling
    .DESCRIPTION
        DDC/CI reads fail occasionally, e.g. while the monitor re-syncs after an input or PBP
        change. Failed reads are therefore retried (default: 3 attempts, 500 ms apart).
        Callers that already poll in a loop pass -MaxAttempts 1.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [IntPtr]$MonitorHandle,

        [Parameter(Mandatory=$true)]
        [byte]$VcpCode,

        [Parameter(Mandatory=$false)]
        [string]$FeatureName,

        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 10)]
        [int]$MaxAttempts = 3,

        [Parameter(Mandatory=$false)]
        [int]$RetryDelayMilliseconds = 500,

        # Return the maximum value reported by the monitor instead of the current value
        [Parameter(Mandatory=$false)]
        [switch]$Maximum
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $reply = Read-VcpFeatureNative -MonitorHandle $MonitorHandle -VcpCode $VcpCode
        if ($null -ne $reply) {
            if ($Maximum) { return $reply.Maximum }
            return $reply.Current
        }

        Write-Verbose ("Failed to read VCP code 0x{0:X2} ($FeatureName), attempt $attempt/$MaxAttempts" -f $VcpCode)
        if ($attempt -lt $MaxAttempts) {
            Start-Sleep -Milliseconds $RetryDelayMilliseconds
        }
    }

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
        if (Write-VcpFeatureNative -MonitorHandle $MonitorHandle -VcpCode $VcpCode -Value $Value) {
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
            $current = Invoke-VcpGet -MonitorHandle $MonitorHandle -VcpCode $VcpCode -FeatureName $FeatureName -MaxAttempts 1
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

function Resolve-MonitorSetResult {
    <#
    .SYNOPSIS
        Combines the per-monitor results of a set operation into a single boolean
    .DESCRIPTION
        Writes an error if no monitor matched the name. Returns $true only if every matching
        monitor reported success.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [object[]]$Results,

        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$MonitorName
    )

    $boolResults = @($Results | Where-Object { $_ -is [bool] })
    if ($boolResults.Count -eq 0) {
        Write-Error "No monitor found matching '$MonitorName'."
        return $false
    }

    return -not ($boolResults -contains $false)
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

    Invoke-PhysicalMonitorAction -MonitorName $MonitorName -Action {
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
        [switch]$SkipVerification,

        # Check the value against the maximum reported by the monitor (continuous values)
        [Parameter(Mandatory=$false)]
        [switch]$CheckMaximum
    )

    $results = Invoke-PhysicalMonitorAction -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx)

        $action = "Set $FeatureName to 0x{0:X}" -f $Value
        if (-not $CmdletContext.ShouldProcess($pm.Description, $action)) {
            return $false
        }

        if ($CheckMaximum) {
            $max = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $VcpCode -FeatureName $FeatureName -Maximum
            # A maximum of 0 or no answer means the monitor did not report one; then 0-100 is assumed
            $limit = Get-VcpValueLimit -Maximum $max
            if ($Value -gt $limit) {
                Write-Error "$FeatureName must be between 0 and $limit on '$($pm.Description)' (maximum reported by the monitor)."
                return $false
            }
        }

        return Invoke-VcpSet -MonitorHandle $pm.Handle -VcpCode $VcpCode -Value $Value `
            -MonitorDescription $pm.Description -FeatureName $FeatureName -SkipVerification:$SkipVerification
    }

    return Resolve-MonitorSetResult -Results $results -MonitorName $MonitorName
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

    Invoke-PhysicalMonitorAction -MonitorName $MonitorName -Action {
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

    $results = Invoke-PhysicalMonitorAction -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx)
            
        $value = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $script:VcpCodes.PbpMode -FeatureName 'PBP Mode'
        # 0x00 usually means PBP Off
        return (Test-PbpModeActive -Value $value)
    }
    
    return ($results -contains $true)
}

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

    $results = Invoke-PhysicalMonitorAction -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx, $cap, $model)
            
        # Check PBP Status
        $pbpValue = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $script:VcpCodes.PbpMode -FeatureName 'PBP Mode'
        $pbpActive = Test-PbpModeActive -Value $pbpValue
        
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

    # Note: $PSBoundParameters always uses the parameter name, so -InputSource (alias) appears as InputLeft
    if (-not $PSBoundParameters.ContainsKey('InputLeft') -and -not $PSBoundParameters.ContainsKey('InputRight')) {
        Throw "You must specify at least one input source (-InputLeft/-InputSource or -InputRight)."
    }

    # Capture PSCmdlet context to ensure ShouldProcess prompts correctly even inside helper scopes
    $cmdletContext = $PSCmdlet
    
    # Capture presence of parameters because $PSBoundParameters inside the scriptblock will differ
    $doSetLeft = $PSBoundParameters.ContainsKey('InputLeft')
    $doSetRight = $PSBoundParameters.ContainsKey('InputRight')

    $results = Invoke-PhysicalMonitorAction -MonitorName $MonitorName -Action {
        param($pm, $wmiMonitor, $idx)
            
        $success = $true

        # Check PBP Status
        $pbpValue = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $script:VcpCodes.PbpMode -FeatureName 'PBP Mode'
        $pbpActive = Test-PbpModeActive -Value $pbpValue

        # Current inputs are only needed for the PBP collision rules
        $currentLeftVal = 0
        $currentRightVal = 0
        if ($pbpActive) {
            $leftVal = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $script:VcpCodes.InputSource -FeatureName 'Input Source'
            $rightVal = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $script:VcpCodes.PbpRightInput -FeatureName 'PBP Right Input'
            $currentLeftVal = if ($null -ne $leftVal) { $leftVal -band 0xFF } else { 0 }
            $currentRightVal = if ($null -ne $rightVal) { $rightVal -band 0xFF } else { 0 }
        }

        $targetLeft = if ($doSetLeft) { $InputLeft } else { $null }
        $targetRight = if ($doSetRight) { $InputRight } else { $null }
        $plan = Get-InputSwitchPlan -PbpActive $pbpActive -CurrentLeft $currentLeftVal -CurrentRight $currentRightVal `
            -Left $targetLeft -Right $targetRight
        if ($plan.Error) {
            Write-Error $plan.Message
            return $false
        }

        # Waits until the monitor reports the expected value for one step.
        # Returns 'Verified', 'Mismatch' (monitor answered with a different value) or
        # 'NoResponse' (monitor did not answer DDC/CI at all).
        # Each step must be confirmed before the next one is sent: the monitor accepts but ignores
        # commands while it is still re-syncing after the previous switch.
        $FnWaitForStep = {
            param($Step, [int]$TimeoutSeconds = 10)

            $expected = $Step.Input -band 0xFF
            $anyResponse = $false
            $lastActual = $null
            $maxPolls = $TimeoutSeconds * 2   # one poll every 500 ms
            for ($poll = 1; $poll -le $maxPolls; $poll++) {
                Start-Sleep -Milliseconds 500
                $raw = Invoke-VcpGet -MonitorHandle $pm.Handle -VcpCode $Step.Code -FeatureName $Step.Desc -MaxAttempts 1
                if ($null -eq $raw) {
                    Write-Verbose "$($Step.Desc): no DDC/CI response (poll $poll/$maxPolls)"
                    continue
                }
                $anyResponse = $true
                $lastActual = $raw -band 0xFF
                if ($lastActual -eq $expected) {
                    Write-Verbose ("$($Step.Desc) verified as 0x{0:X2} (poll $poll/$maxPolls)" -f $lastActual)
                    return [pscustomobject]@{ Status = 'Verified'; Message = $null }
                }
            }

            if (-not $anyResponse) {
                return [pscustomobject]@{ Status = 'NoResponse'; Message = $null }
            }
            return [pscustomobject]@{
                Status  = 'Mismatch'
                Message = "$($Step.Desc): expected 0x{0:X2}, got 0x{1:X2}" -f $expected, $lastActual
            }
        }

        # Turn the planned steps into VCP writes
        $steps = foreach ($planned in $plan.Steps) {
            if ($planned.Side -eq 'Left') {
                [pscustomobject]@{ Type = 'Left'; Desc = 'Primary/Left Input'; Code = $script:VcpCodes.InputSource
                    Input = [uint32]$planned.Input; Value = Get-LeftInputValue -InputSource $planned.Input -PbpActive $pbpActive }
            } else {
                [pscustomobject]@{ Type = 'Right'; Desc = 'Secondary/Right Input'; Code = $script:VcpCodes.PbpRightInput
                    Input = [uint32]$planned.Input; Value = [uint32]$planned.Input }
            }
        }

        $noResponse = $false
        foreach ($step in $steps) {
            # Left input is masked with 0xF00 while PBP is active (see Get-LeftInputValue)
            $val = $step.Value

            if (-not $cmdletContext.ShouldProcess($pm.Description, ("Set $($step.Desc) to 0x{0:X}" -f $val))) {
                return $false
            }

            $set = Invoke-VcpSet -MonitorHandle $pm.Handle -VcpCode $step.Code -Value $val `
                -MonitorDescription $pm.Description -FeatureName $step.Desc -SkipVerification
            if (-not $set) {
                return $false
            }

            # The right input is only meaningful (and readable) while PBP is active
            if ($step.Type -eq 'Right' -and -not $pbpActive) {
                continue
            }

            # Verify this step before sending the next one
            $check = & $FnWaitForStep $step
            switch ($check.Status) {
                'Mismatch' {
                    Write-Error "Failed to verify input state on $($pm.Description): $($check.Message)"
                    return $false
                }
                'NoResponse' {
                    # After switching to an input this PC is not connected to, the monitor usually stops
                    # answering DDC/CI requests. That is expected and reported as a warning, not an error.
                    $noResponse = $true
                }
            }
        }

        if ($noResponse) {
            Write-Warning ("Input switched on '$($pm.Description)', but the monitor did not answer DDC/CI to confirm it. " +
                "This is expected if this PC is not connected to the new input.")
        }

        return $success
    }

    return Resolve-MonitorSetResult -Results $results -MonitorName $MonitorName
}

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

function Set-MonitorAudioVolume {
    <#
    .SYNOPSIS
        Sets the audio volume level of the monitor
    .PARAMETER MonitorName
        Name or model of the monitor to configure
    .PARAMETER Volume
        Volume level (0 to the maximum reported by the monitor, usually 100)
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName,
        
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 65535)]
        [int]$Volume
    )

    return Set-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.AudioVolume `
        -Value ([uint32]$Volume) -FeatureName "Audio Volume" -CmdletContext $PSCmdlet -CheckMaximum
}

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

    # VCP 0x8D, device-specific encoding (verified on Dell U4924DW): 0x00 = Mute, 0x01 = Unmute.
    # MCCS defines 0x01 = Mute, 0x02 = Unmute; the Dell ignores 0x02. See docs (Audio).
    return Set-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.AudioMute `
        -Value 0x01 -FeatureName "Audio (Unmute)" -CmdletContext $PSCmdlet -SkipVerification
}

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

    # VCP 0x8D, device-specific encoding (verified on Dell U4924DW): 0x00 = Mute, 0x01 = Unmute.
    # MCCS defines 0x01 = Mute, 0x02 = Unmute; the Dell ignores 0x02. See docs (Audio).
    return Set-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.AudioMute `
        -Value 0x00 -FeatureName "Audio (Mute)" -CmdletContext $PSCmdlet -SkipVerification
}

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

function Set-MonitorBrightness {
    <#
    .SYNOPSIS
        Sets the brightness level of the monitor
    .PARAMETER MonitorName
        Name or model of the monitor to configure
    .PARAMETER Brightness
        Brightness level (0 to the maximum reported by the monitor, usually 100)
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName,
        
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 65535)]
        [int]$Brightness
    )

    return Set-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.Brightness `
        -Value ([uint32]$Brightness) -FeatureName "Brightness" -CmdletContext $PSCmdlet -CheckMaximum
}

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

function Set-MonitorContrast {
    <#
    .SYNOPSIS
        Sets the contrast level of the monitor
    .PARAMETER MonitorName
        Name or model of the monitor to configure
    .PARAMETER Contrast
        Contrast level (0 to the maximum reported by the monitor, usually 100)
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MonitorName,
        
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 65535)]
        [int]$Contrast
    )

    return Set-MonitorVcpValue -MonitorName $MonitorName -VcpCode $script:VcpCodes.Contrast `
        -Value ([uint32]$Contrast) -FeatureName "Contrast" -CmdletContext $PSCmdlet -CheckMaximum
}

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

    $results = Invoke-PhysicalMonitorAction -MonitorName $MonitorName -Action {
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
            if ([PSMonitorTools.Native.MonitorHelper]::GetVcpFeature($pm.Handle, $code, [ref]$curr, [ref]$max)) {
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
            if ([PSMonitorTools.Native.MonitorHelper]::GetVcpFeature($pm.Handle, $code, [ref]$curr, [ref]$max)) {
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

#endregion

#region Exports

Export-ModuleMember -Function @(
    'Get-MonitorInfo'
    'Get-MonitorInput'
    'Switch-MonitorInput'
    'Get-MonitorPBP'
    'Enable-MonitorPBP'
    'Disable-MonitorPBP'
    'Get-MonitorAudioVolume'
    'Set-MonitorAudioVolume'
    'Get-MonitorAudio'
    'Enable-MonitorAudio'
    'Disable-MonitorAudio'
    'Get-MonitorBrightness'
    'Set-MonitorBrightness'
    'Get-MonitorContrast'
    'Set-MonitorContrast'
    'Find-MonitorVcpCodes'
)

#endregion

#region Argument Completers

Register-ArgumentCompleter -CommandName Get-MonitorInfo, Get-MonitorInput, Get-MonitorPBP, Switch-MonitorInput, Enable-MonitorPBP, Disable-MonitorPBP, Get-MonitorAudioVolume, Set-MonitorAudioVolume, Get-MonitorAudio, Enable-MonitorAudio, Disable-MonitorAudio, Get-MonitorBrightness, Set-MonitorBrightness, Get-MonitorContrast, Set-MonitorContrast, Find-MonitorVcpCodes -ParameterName MonitorName -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    # Only cheap sources (descriptions, WMI, cached models): no DDC/CI capabilities or firmware reads (#21)
    $results = try { Get-MonitorNameCandidate } catch { @() }

    # Filter and return
    $word = $wordToComplete.Trim([char[]]"'`"")
    $wordPattern = "*$([WildcardPattern]::Escape($word))*"
    foreach ($val in $results) {
        if ($val -like $wordPattern) {
            $quoted = "'" + ($val -replace "'", "''") + "'"
            [System.Management.Automation.CompletionResult]::new($quoted, $val, 'ParameterValue', $val)
        }
    }
}

#endregion
