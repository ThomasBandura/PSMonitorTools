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

        It 'returns false cleanly if no monitor matches' {
            # Integration test: 'GhostMonitorXYZ' should not exist
            $result = Switch-MonitorInput -MonitorName 'GhostMonitorXYZ' -InputLeft Hdmi1 -Verbose
            $result | Should -BeFalse
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

        It '<Function> returns false cleanly if no monitor matches' -TestCases $pbpFunctions {
            param($Function)
            $result = & $Function -MonitorName 'GhostMonitorXYZ' -Verbose
            $result | Should -BeFalse
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

        It '<SetFunc> handles non-existent monitor gracefully' -TestCases $setFunctions {
            param($SetFunc, $Param)
            $params = @{ MonitorName = "DefinitelyNotAMonitor"; $Param = 50 }
            & $SetFunc @params | Should -BeFalse
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

        It '<Function> handles non-existent monitor gracefully' -TestCases $audioToggleFunctions {
            param($Function)
            & $Function -MonitorName "DefinitelyNotAMonitor" | Should -BeFalse
        }
    }



    Context 'Internals' {
        It 'Helper type is compiled and available' {
            ([System.Management.Automation.PSTypeName]'PSMonitorToolsHelper').Type | Should -Not -BeNullOrEmpty
        }
    }
}
