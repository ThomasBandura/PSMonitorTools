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

        It '<SetFunc> validates <Param> range (<Min>-<Max>)' -TestCases $setFunctions {
            param($SetFunc, $Param, $Min, $Max)
            { & $SetFunc -MonitorName "Test" -$Param ($Max + 1) } | Should -Throw
            { & $SetFunc -MonitorName "Test" -$Param ($Min - 1) } | Should -Throw
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
