Describe 'Monitor module' {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '..\PSMonitorTools\PSMonitorTools.psd1'
        Import-Module $modulePath -Force
        $module = Get-Module PSMonitorTools
    }

    Context 'Module export and structure' {
        BeforeAll {
            $expectedFunctions = @(
                'Get-MonitorInfo', 'Get-MonitorInput', 'Switch-MonitorInput',
                'Enable-MonitorPBP', 'Disable-MonitorPBP', 'Get-MonitorPBP',
                'Get-MonitorAudioVolume', 'Set-MonitorAudioVolume',
                'Get-MonitorAudio', 'Enable-MonitorAudio', 'Disable-MonitorAudio',
                'Get-MonitorBrightness', 'Set-MonitorBrightness',
                'Get-MonitorContrast', 'Set-MonitorContrast',
                'Find-MonitorVcpCodes'
            )
        }

        It 'exports all expected functions' {
            foreach ($fn in $expectedFunctions) {
                Get-Command $fn -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }

        It 'InputLeft parameter uses MonitorInput enum' {
            $param = (Get-Command Switch-MonitorInput).Parameters['InputLeft']
            $param.ParameterType.Name | Should -Be 'MonitorInput'
        }
    }

    Context 'Argument Completer' {
        It 'provides completions via CommandCompletion (Integration)' {
            $script = 'Switch-MonitorInput -MonitorName '
            $cursor = $script.Length
            
            # Use try/catch to debug failures
            try {
                $results = [System.Management.Automation.CommandCompletion]::CompleteInput($script, $cursor, $null)
            } catch {
                Write-Warning "CompleteInput failed: $_"
                throw
            }

            # Check if we got a valid completion object
            $results | Should -Not -BeNull
            
            # In CI environments (headless), we might get 0 matches. This is valid.
            # Only if we HAVE monitors (detected via Get-MonitorInfo) must we have completions.
            $monitors = Get-MonitorInfo
            if ($monitors) {
                $results.CompletionMatches.Count | Should -BeGreaterThan 0
                $results.CompletionMatches[0].CompletionText | Should -Match "^'.*'$"
            } else {
                Write-Warning "Skipping completion match verification (no monitors detected)."
            }
        }
    }

    Context 'Get-MonitorInput Logic' {
        It 'returns false cleanly if no monitor matches' {
            # Integration test: 'GhostMonitorXYZ' should not exist
            $result = Get-MonitorInput -MonitorName 'GhostMonitorXYZ' -Verbose
            $result | Should -BeNullOrEmpty
        }

        It 'returns an object with unexpected PBP/Input properties if a monitor is found' {
             $monitors = Get-MonitorInfo
             if ($monitors) {
                 # Just use the first one
                 $name = $monitors[0].Name
                 $result = Get-MonitorInput -MonitorName $name
                 $result | Should -Not -BeNull
                 # Verify structure
                 $result.PSObject.Properties.Name | Should -Contain 'InputLeft'
                 $result.PSObject.Properties.Name | Should -Contain 'InputRight'
                 $result.PSObject.Properties.Name | Should -Contain 'PBP'
             }
        }
    }

    Context 'Switch-MonitorInput Logic' {
        It 'supports ShouldProcess (WhatIf) with legacy InputSource' {
            { Switch-MonitorInput -MonitorName 'dell' -InputSource Hdmi1 -WhatIf -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'supports ShouldProcess (WhatIf) with InputLeft' {
            { Switch-MonitorInput -MonitorName 'dell' -InputLeft Hdmi1 -WhatIf -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'supports ShouldProcess (WhatIf) with InputRight' {
            { Switch-MonitorInput -MonitorName 'dell' -InputRight DisplayPort -WhatIf -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'supports ShouldProcess (WhatIf) with both Inputs' {
            { Switch-MonitorInput -MonitorName 'dell' -InputLeft Hdmi1 -InputRight DisplayPort -WhatIf -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'throws if no input is specified' {
            { Switch-MonitorInput -MonitorName 'dell' } | Should -Throw
        }

        It 'returns false and writes an error if no monitor matches' {
            # Integration test: 'GhostMonitorXYZ' should not exist
            $result = Switch-MonitorInput -MonitorName 'GhostMonitorXYZ' -InputLeft Hdmi1 -ErrorAction SilentlyContinue -ErrorVariable err
            $result | Should -BeFalse
            $err | Should -Not -BeNullOrEmpty
            "$($err[0])" | Should -Match 'No monitor found'
        }

        It 'fails validation for invalid InputSource' {
            { Switch-MonitorInput -MonitorName 'Any' -InputLeft 'InvalidSource' } | Should -Throw
        }
    }

    Context 'PBP Functions Logic' {
        BeforeAll {
            $pbpFunctions = @(
                @{ Function = 'Enable-MonitorPBP'; HasParameters = $false }
                @{ Function = 'Disable-MonitorPBP'; HasParameters = $false }
            )
        }

        It '<Function> supports ShouldProcess (WhatIf)' -TestCases $pbpFunctions {
            param($Function)
            { & $Function -MonitorName 'dell' -WhatIf } | Should -Not -Throw
        }

        It '<Function> returns false and writes an error if no monitor matches' -TestCases $pbpFunctions {
            param($Function)
            $result = & $Function -MonitorName 'GhostMonitorXYZ' -ErrorAction SilentlyContinue -ErrorVariable err
            $result | Should -BeFalse
            $err | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Get-MonitorInfo Output' {
        It 'returns objects with expected properties' {
            $monitors = Get-MonitorInfo
            
            # Skip if no monitors attached (CI/Headless), but if we have results, verify structure
            if ($monitors) {
                $m = $monitors | Select-Object -First 1
                $names = $m.PSObject.Properties.Name
                $names | Should -Contain 'Name'
                $names | Should -Contain 'Model'
                $names | Should -Contain 'SerialNumber'
                $names | Should -Contain 'Manufacturer'
                $names | Should -Contain 'Firmware'
                $names | Should -Contain 'Index'
            } else {
                Write-Warning "No monitors detected on this system. Output structure verification skipped."
            }
        }

        It 'does not crash on repeated calls' {
            { Get-MonitorInfo } | Should -Not -Throw
            { Get-MonitorInfo } | Should -Not -Throw
        }

        It 'supports filtering by Name' {
            $monitors = Get-MonitorInfo
            if ($monitors) {
                # Pick a name from the list
                $target = $monitors[0].Name
                $filtered = Get-MonitorInfo -MonitorName $target
                $filtered | Should -Not -BeNullOrEmpty
                $filtered[0].Name | Should -Be $target
            }
        }

        It 'returns empty if filter matches nothing' {
            $filtered = Get-MonitorInfo -MonitorName "GhostMonitorXYZ"
            $filtered | Should -BeNullOrEmpty
        }
    }

    Context 'Audio/Brightness/Contrast Functions' {
        BeforeAll {
            $setFunctions = @(
                @{ GetFunc = 'Get-MonitorAudioVolume'; SetFunc = 'Set-MonitorAudioVolume'; Param = 'Volume'; Min = 0; Max = 100 }
                @{ GetFunc = 'Get-MonitorBrightness'; SetFunc = 'Set-MonitorBrightness'; Param = 'Brightness'; Min = 0; Max = 100 }
                @{ GetFunc = 'Get-MonitorContrast'; SetFunc = 'Set-MonitorContrast'; Param = 'Contrast'; Min = 0; Max = 100 }
            )
            
            $audioToggleFunctions = @(
                @{ Function = 'Enable-MonitorAudio' }
                @{ Function = 'Disable-MonitorAudio' }
            )
        }

        It '<GetFunc> is exported' -TestCases $setFunctions {
            param($GetFunc)
            Get-Command $GetFunc -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It '<SetFunc> is exported' -TestCases $setFunctions {
            param($SetFunc)
            Get-Command $SetFunc -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It '<GetFunc> handles non-existent monitor gracefully' -TestCases $setFunctions {
            param($GetFunc)
            $result = & $GetFunc -MonitorName "DefinitelyNotAMonitor"
            $result | Should -BeNullOrEmpty
        }

        It '<SetFunc> supports WhatIf' -TestCases $setFunctions {
            param($SetFunc, $Param)
            $params = @{ MonitorName = "NonExistent"; $Param = 50; WhatIf = $true }
            { & $SetFunc @params } | Should -Not -Throw
        }

        It '<SetFunc> rejects <Param> values outside 0-65535 at parameter level' -TestCases $setFunctions {
            param($SetFunc, $Param)
            # The actual upper limit is the maximum reported by the monitor (see mocked tests)
            { & $SetFunc -MonitorName "Test" -$Param 65536 } | Should -Throw
            { & $SetFunc -MonitorName "Test" -$Param -1 } | Should -Throw
        }

        It '<SetFunc> returns false and writes an error for a non-existent monitor' -TestCases $setFunctions {
            param($SetFunc, $Param)
            $params = @{ MonitorName = "DefinitelyNotAMonitor"; $Param = 50 }
            & $SetFunc @params -ErrorAction SilentlyContinue -ErrorVariable err | Should -BeFalse
            $err | Should -Not -BeNullOrEmpty
        }

        It 'Get-MonitorAudio is exported' {
            Get-Command Get-MonitorAudio -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Get-MonitorAudio handles non-existent monitor gracefully' {
            $result = Get-MonitorAudio -MonitorName "DefinitelyNotAMonitor"
            $result | Should -BeNullOrEmpty
        }

        It '<Function> is exported' -TestCases $audioToggleFunctions {
            param($Function)
            Get-Command $Function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It '<Function> supports WhatIf' -TestCases $audioToggleFunctions {
            param($Function)
            { & $Function -MonitorName "NonExistent" -WhatIf } | Should -Not -Throw
        }

        It '<Function> returns false and writes an error for a non-existent monitor' -TestCases $audioToggleFunctions {
            param($Function)
            & $Function -MonitorName "DefinitelyNotAMonitor" -ErrorAction SilentlyContinue -ErrorVariable err | Should -BeFalse
            $err | Should -Not -BeNullOrEmpty
        }
    }



    Context 'Internals' {
        It 'Helper type is compiled and available' {
            ([System.Management.Automation.PSTypeName]'PSMonitorTools.Native.MonitorHelper').Type | Should -Not -BeNullOrEmpty
        }

        It 'Helper types do not pollute the global namespace' {
            ([System.Management.Automation.PSTypeName]'PSMonitorToolsHelper').Type | Should -BeNullOrEmpty
            ([System.Management.Automation.PSTypeName]'PhysicalMonitor').Type | Should -BeNullOrEmpty
        }

        It 'internal helper Invoke-PhysicalMonitorAction is not exported' {
            Get-Command Invoke-PhysicalMonitorAction -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
    }
}

Describe 'Monitor module logic (mocked hardware)' {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '..\PSMonitorTools\PSMonitorTools.psd1'
        Import-Module $modulePath -Force
    }

    Context 'Switch-MonitorInput verification' {
        BeforeEach {
            InModuleScope PSMonitorTools {
                Mock Start-Sleep {}
                Mock Invoke-PhysicalMonitorAction {
                    & $Action ([pscustomobject]@{ Handle = [IntPtr]::Zero; Description = 'Fake Monitor' }) $null 0
                }
                Mock Invoke-VcpSet { $true }
                # PBP off
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE9 } { 0 }
            }
        }

        It 'returns true with a warning when the monitor stops answering after the switch' {
            InModuleScope PSMonitorTools {
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0x60 } { $null }

                $result = Switch-MonitorInput -MonitorName 'Fake' -InputLeft Hdmi1 -Confirm:$false `
                    -WarningVariable warn -WarningAction SilentlyContinue -ErrorVariable err -ErrorAction SilentlyContinue

                $result | Should -BeTrue
                "$warn" | Should -Match 'did not answer DDC/CI'
                $err | Should -BeNullOrEmpty
            }
        }

        It 'verifies only once (Invoke-VcpSet is called with -SkipVerification)' {
            InModuleScope PSMonitorTools {
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0x60 } { 0xF11 }

                Switch-MonitorInput -MonitorName 'Fake' -InputLeft Hdmi1 -Confirm:$false | Should -BeTrue

                Should -Invoke Invoke-VcpSet -Times 1 -Exactly -ParameterFilter { $SkipVerification }
            }
        }

        It 'sends the right input only after the left input was confirmed (PBP)' {
            InModuleScope PSMonitorTools {
                $script:calls = [System.Collections.Generic.List[string]]::new()
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE9 } { 0x24 }   # PBP on
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0x60 } { $script:calls.Add('get 60'); 0xF11 }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE8 } { $script:calls.Add('get E8'); 0x1B }
                Mock Invoke-VcpSet { $script:calls.Add(('set {0:X2}' -f $VcpCode)); $true }

                Switch-MonitorInput -MonitorName 'Fake' -InputLeft Hdmi1 -InputRight UsbC -Confirm:$false | Should -BeTrue

                # Collision detection reads 60/E8 first; afterwards: set left, confirm left, set right, confirm right
                $afterReads = $script:calls[2..($script:calls.Count - 1)]
                $afterReads | Should -Be @('set 60', 'get 60', 'set E8', 'get E8')
            }
        }

        It 'returns false with an error when the monitor reports a different input' {
            InModuleScope PSMonitorTools {
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0x60 } { 0x0F }

                $result = Switch-MonitorInput -MonitorName 'Fake' -InputLeft Hdmi1 -Confirm:$false `
                    -ErrorVariable err -ErrorAction SilentlyContinue

                $result | Should -BeFalse
                "$err" | Should -Match 'expected 0x11, got 0x0F'
            }
        }
    }

    Context 'Set results across multiple monitors' {
        It 'returns false if one of several monitors fails' {
            InModuleScope PSMonitorTools {
                Mock Invoke-PhysicalMonitorAction {
                    & $Action ([pscustomobject]@{ Handle = [IntPtr]::Zero; Description = 'Monitor A' }) $null 0
                    & $Action ([pscustomobject]@{ Handle = [IntPtr]::Zero; Description = 'Monitor B' }) $null 1
                }
                Mock Invoke-VcpSet -ParameterFilter { $MonitorDescription -eq 'Monitor A' } { $true }
                Mock Invoke-VcpSet -ParameterFilter { $MonitorDescription -eq 'Monitor B' } { $false }

                Set-MonitorBrightness -MonitorName 'Monitor' -Brightness 50 -Confirm:$false | Should -BeFalse
            }
        }

        It 'returns true if all monitors succeed' {
            InModuleScope PSMonitorTools {
                Mock Invoke-PhysicalMonitorAction {
                    & $Action ([pscustomobject]@{ Handle = [IntPtr]::Zero; Description = 'Monitor A' }) $null 0
                    & $Action ([pscustomobject]@{ Handle = [IntPtr]::Zero; Description = 'Monitor B' }) $null 1
                }
                Mock Invoke-VcpSet { $true }

                Set-MonitorBrightness -MonitorName 'Monitor' -Brightness 50 -Confirm:$false | Should -BeTrue
            }
        }
    }
}

Describe 'Monitor module logic (mocked hardware, part 2)' {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '..\PSMonitorTools\PSMonitorTools.psd1'
        Import-Module $modulePath -Force
    }

    BeforeEach {
        InModuleScope PSMonitorTools {
            Mock Start-Sleep {}
            Mock Invoke-PhysicalMonitorAction {
                & $Action ([pscustomobject]@{ Handle = [IntPtr]::Zero; Description = 'Fake Monitor' }) $null 0 $null 'FakeModel'
            }
        }
    }

    Context 'Invoke-VcpGet retries' {
        It 'retries failed reads and returns the value of the first successful read' {
            InModuleScope PSMonitorTools {
                $script:reads = 0
                Mock Read-VcpFeatureNative {
                    $script:reads++
                    if ($script:reads -lt 3) { return $null }
                    [pscustomobject]@{ Current = 0x0F; Maximum = 100 }
                }

                Invoke-VcpGet -MonitorHandle ([IntPtr]::Zero) -VcpCode 0x60 | Should -Be 0x0F
                Should -Invoke Read-VcpFeatureNative -Times 3 -Exactly
            }
        }

        It 'returns $null after MaxAttempts failed reads' {
            InModuleScope PSMonitorTools {
                Mock Read-VcpFeatureNative { $null }

                Invoke-VcpGet -MonitorHandle ([IntPtr]::Zero) -VcpCode 0x60 | Should -BeNullOrEmpty
                Should -Invoke Read-VcpFeatureNative -Times 3 -Exactly
            }
        }

        It 'reads only once with -MaxAttempts 1' {
            InModuleScope PSMonitorTools {
                Mock Read-VcpFeatureNative { $null }

                Invoke-VcpGet -MonitorHandle ([IntPtr]::Zero) -VcpCode 0x60 -MaxAttempts 1 | Should -BeNullOrEmpty
                Should -Invoke Read-VcpFeatureNative -Times 1 -Exactly
            }
        }

        It 'returns the maximum with -Maximum' {
            InModuleScope PSMonitorTools {
                Mock Read-VcpFeatureNative { [pscustomobject]@{ Current = 75; Maximum = 255 } }

                Invoke-VcpGet -MonitorHandle ([IntPtr]::Zero) -VcpCode 0x10 -Maximum | Should -Be 255
            }
        }
    }

    Context 'Invoke-VcpSet retries' {
        It 'retries a failed write and succeeds' {
            InModuleScope PSMonitorTools {
                $script:writes = 0
                Mock Write-VcpFeatureNative { $script:writes++; $script:writes -ge 3 }

                Invoke-VcpSet -MonitorHandle ([IntPtr]::Zero) -VcpCode 0x10 -Value 50 -MonitorDescription 'Fake' -SkipVerification |
                    Should -BeTrue
                Should -Invoke Write-VcpFeatureNative -Times 3 -Exactly
            }
        }

        It 'returns false with an error after MaxRetries failed writes' {
            InModuleScope PSMonitorTools {
                Mock Write-VcpFeatureNative { $false }

                $result = Invoke-VcpSet -MonitorHandle ([IntPtr]::Zero) -VcpCode 0x10 -Value 50 -MonitorDescription 'Fake' `
                    -MaxRetries 2 -SkipVerification -ErrorAction SilentlyContinue -ErrorVariable err

                $result | Should -BeFalse
                "$err" | Should -Match 'after 2 attempts'
                Should -Invoke Write-VcpFeatureNative -Times 2 -Exactly
            }
        }

        It 'verifies the new value after writing' {
            InModuleScope PSMonitorTools {
                Mock Write-VcpFeatureNative { $true }
                Mock Invoke-VcpGet { 50 }

                Invoke-VcpSet -MonitorHandle ([IntPtr]::Zero) -VcpCode 0x10 -Value 50 -MonitorDescription 'Fake' |
                    Should -BeTrue
                Should -Invoke Invoke-VcpGet -Times 1 -Exactly -ParameterFilter { $VcpCode -eq 0x10 -and $MaxAttempts -eq 1 }
            }
        }
    }

    Context 'Switch-MonitorInput PBP handling' {
        It 'masks the left input with 0xF00 when PBP is active' {
            InModuleScope PSMonitorTools {
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE9 } { 0x24 }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0x60 } { 0xF11 }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE8 } { 0x12 }
                Mock Invoke-VcpSet { $true }

                Switch-MonitorInput -MonitorName 'Fake' -InputLeft Hdmi1 -Confirm:$false | Should -BeTrue
                Should -Invoke Invoke-VcpSet -Times 1 -Exactly -ParameterFilter { $VcpCode -eq 0x60 -and $Value -eq 0xF11 }
            }
        }

        It 'does not mask the left input when PBP is off' {
            InModuleScope PSMonitorTools {
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE9 } { 0 }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0x60 } { 0x11 }
                Mock Invoke-VcpSet { $true }

                Switch-MonitorInput -MonitorName 'Fake' -InputLeft Hdmi1 -Confirm:$false | Should -BeTrue
                Should -Invoke Invoke-VcpSet -Times 1 -Exactly -ParameterFilter { $VcpCode -eq 0x60 -and $Value -eq 0x11 }
            }
        }

        It 'rejects the same input on both sides when PBP is active' {
            InModuleScope PSMonitorTools {
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE9 } { 0x24 }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0x60 } { 0xF0F }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE8 } { 0x12 }
                Mock Invoke-VcpSet { $true }

                $result = Switch-MonitorInput -MonitorName 'Fake' -InputLeft Hdmi1 -InputRight Hdmi1 -Confirm:$false `
                    -ErrorAction SilentlyContinue -ErrorVariable err

                $result | Should -BeFalse
                "$err" | Should -Match 'cannot be the same'
                Should -Invoke Invoke-VcpSet -Times 0 -Exactly
            }
        }

        It 'rejects a right input that equals the current left input when PBP is active' {
            InModuleScope PSMonitorTools {
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE9 } { 0x24 }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0x60 } { 0xF0F }   # left = DisplayPort
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE8 } { 0x12 }
                Mock Invoke-VcpSet { $true }

                Switch-MonitorInput -MonitorName 'Fake' -InputRight DisplayPort -Confirm:$false -ErrorAction SilentlyContinue |
                    Should -BeFalse
                Should -Invoke Invoke-VcpSet -Times 0 -Exactly
            }
        }

        It 'switches the right input first when the new left input is the current right input (smart ordering)' {
            InModuleScope PSMonitorTools {
                $script:sets = [System.Collections.Generic.List[string]]::new()
                $script:left = 0xF0F    # DisplayPort
                $script:right = 0x1B    # UsbC
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE9 } { 0x24 }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0x60 } { $script:left }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE8 } { $script:right }
                Mock Invoke-VcpSet {
                    $script:sets.Add(('{0:X2}' -f $VcpCode))
                    if ($VcpCode -eq 0x60) { $script:left = $Value } else { $script:right = $Value }
                    $true
                }

                Switch-MonitorInput -MonitorName 'Fake' -InputLeft UsbC -InputRight Hdmi1 -Confirm:$false | Should -BeTrue
                $script:sets | Should -Be @('E8', '60')
            }
        }

        It 'sets the right input without waiting for confirmation when PBP is off' {
            InModuleScope PSMonitorTools {
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE9 } { 0 }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE8 } { 0x12 }
                Mock Invoke-VcpSet { $true }

                Switch-MonitorInput -MonitorName 'Fake' -InputRight UsbC -Confirm:$false | Should -BeTrue
                Should -Invoke Invoke-VcpSet -Times 1 -Exactly -ParameterFilter { $VcpCode -eq 0xE8 }
                Should -Invoke Invoke-VcpGet -Times 0 -Exactly -ParameterFilter { $VcpCode -eq 0xE8 }
            }
        }

        It 'does nothing with -WhatIf' {
            InModuleScope PSMonitorTools {
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE9 } { 0 }
                Mock Invoke-VcpSet { $true }

                Switch-MonitorInput -MonitorName 'Fake' -InputLeft Hdmi1 -WhatIf | Should -BeFalse
                Should -Invoke Invoke-VcpSet -Times 0 -Exactly
            }
        }
    }

    Context 'Get-MonitorInput evaluation' {
        It 'reports both inputs when PBP is active' {
            InModuleScope PSMonitorTools {
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE9 } { 0x24 }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0x60 } { 0xF11 }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE8 } { 0x1B }

                $state = Get-MonitorInput -MonitorName 'Fake'

                $state.PBP | Should -BeTrue
                "$($state.InputLeft)" | Should -Be 'Hdmi1'
                "$($state.InputRight)" | Should -Be 'UsbC'
                $state.Model | Should -Be 'FakeModel'
            }
        }

        It 'does not read the right input when PBP is off' {
            InModuleScope PSMonitorTools {
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE9 } { 0 }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0x60 } { 0xF0F }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE8 } { 0x1B }

                $state = Get-MonitorInput -MonitorName 'Fake'

                $state.PBP | Should -BeFalse
                "$($state.InputLeft)" | Should -Be 'DisplayPort'
                $state.InputRight | Should -BeNullOrEmpty
                Should -Invoke Invoke-VcpGet -Times 0 -Exactly -ParameterFilter { $VcpCode -eq 0xE8 }
            }
        }

        It 'reports unknown input codes' {
            InModuleScope PSMonitorTools {
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE9 } { 0 }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0x60 } { 0x05 }

                (Get-MonitorInput -MonitorName 'Fake').InputLeft | Should -Be 'Unknown (0x05)'
            }
        }
    }

    Context 'Monitor maximum (#30)' {
        It 'rejects a value above the maximum reported by the monitor' {
            InModuleScope PSMonitorTools {
                Mock Invoke-VcpGet -ParameterFilter { $Maximum } { 100 }
                Mock Invoke-VcpSet { $true }

                $result = Set-MonitorBrightness -MonitorName 'Fake' -Brightness 101 -Confirm:$false `
                    -ErrorAction SilentlyContinue -ErrorVariable err

                $result | Should -BeFalse
                "$err" | Should -Match 'between 0 and 100'
                Should -Invoke Invoke-VcpSet -Times 0 -Exactly
            }
        }

        It 'accepts values up to a higher maximum' {
            InModuleScope PSMonitorTools {
                Mock Invoke-VcpGet -ParameterFilter { $Maximum } { 255 }
                Mock Invoke-VcpSet { $true }

                Set-MonitorContrast -MonitorName 'Fake' -Contrast 200 -Confirm:$false | Should -BeTrue
                Should -Invoke Invoke-VcpSet -Times 1 -Exactly -ParameterFilter { $Value -eq 200 }
            }
        }

        It 'assumes 0-100 when the monitor reports no maximum' {
            InModuleScope PSMonitorTools {
                Mock Invoke-VcpGet -ParameterFilter { $Maximum } { $null }
                Mock Invoke-VcpSet { $true }

                Set-MonitorAudioVolume -MonitorName 'Fake' -Volume 100 -Confirm:$false | Should -BeTrue
                Set-MonitorAudioVolume -MonitorName 'Fake' -Volume 101 -Confirm:$false -ErrorAction SilentlyContinue | Should -BeFalse
            }
        }
    }

    Context 'Resolve-MonitorSetResult' {
        It 'returns true only if all results are true' {
            InModuleScope PSMonitorTools {
                Resolve-MonitorSetResult -Results @($true, $true) -MonitorName 'x' | Should -BeTrue
                Resolve-MonitorSetResult -Results @($true, $false) -MonitorName 'x' | Should -BeFalse
            }
        }

        It 'ignores non-boolean output and writes an error when nothing matched' {
            InModuleScope PSMonitorTools {
                Resolve-MonitorSetResult -Results @('noise', $true) -MonitorName 'x' | Should -BeTrue
                $result = Resolve-MonitorSetResult -Results @() -MonitorName 'Ghost' -ErrorAction SilentlyContinue -ErrorVariable err
                $result | Should -BeFalse
                "$err" | Should -Match "No monitor found matching 'Ghost'"
            }
        }
    }
}

Describe 'Capabilities cache and completer (#21)' {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '..\PSMonitorTools\PSMonitorTools.psd1'
        Import-Module $modulePath -Force
    }

    BeforeEach {
        InModuleScope PSMonitorTools { $script:CapabilitiesCache.Clear() }
    }

    It 'reads the capabilities only once per monitor' {
        InModuleScope PSMonitorTools {
            Mock Read-MonitorCapabilitiesNative { '(prot(monitor)model(U4924DW))' }

            $first = Get-MonitorCapabilities -MonitorHandle ([IntPtr]1) -CacheKey 'dev|0|Dell'
            $second = Get-MonitorCapabilities -MonitorHandle ([IntPtr]2) -CacheKey 'dev|0|Dell'

            $first | Should -Be '(prot(monitor)model(U4924DW))'
            $second | Should -Be $first
            Should -Invoke Read-MonitorCapabilitiesNative -Times 1 -Exactly
        }
    }

    It 'keeps separate entries per monitor' {
        InModuleScope PSMonitorTools {
            Mock Read-MonitorCapabilitiesNative { "model(M$MonitorHandle)" }

            Get-MonitorCapabilities -MonitorHandle ([IntPtr]1) -CacheKey 'a' | Should -Be 'model(M1)'
            Get-MonitorCapabilities -MonitorHandle ([IntPtr]2) -CacheKey 'b' | Should -Be 'model(M2)'
            Should -Invoke Read-MonitorCapabilitiesNative -Times 2 -Exactly
        }
    }

    It 'does not cache failed reads' {
        InModuleScope PSMonitorTools {
            Mock Read-MonitorCapabilitiesNative { $null }

            Get-MonitorCapabilities -MonitorHandle ([IntPtr]1) -CacheKey 'x' | Should -BeNullOrEmpty
            Get-MonitorCapabilities -MonitorHandle ([IntPtr]1) -CacheKey 'x' | Should -BeNullOrEmpty
            Should -Invoke Read-MonitorCapabilitiesNative -Times 2 -Exactly
            $script:CapabilitiesCache.ContainsKey('x') | Should -BeFalse
        }
    }

    It 'completer candidates do not read capabilities or VCP values' {
        InModuleScope PSMonitorTools {
            Mock Read-MonitorCapabilitiesNative { throw 'must not be called' }
            Mock Read-VcpFeatureNative { throw 'must not be called' }
            $script:CapabilitiesCache['k'] = '(model(CachedModel))'

            $names = @(Get-MonitorNameCandidate)

            $names | Should -Contain 'CachedModel'
            Should -Invoke Read-MonitorCapabilitiesNative -Times 0 -Exactly
            Should -Invoke Read-VcpFeatureNative -Times 0 -Exactly
        }
    }
}
