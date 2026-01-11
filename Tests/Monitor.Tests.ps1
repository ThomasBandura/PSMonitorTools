Describe 'Monitor module' {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '..\PSMonitorTools\PSMonitorTools.psd1'
        Import-Module $modulePath -Force
        $module = Get-Module PSMonitorTools
    }

    Context 'Module export and structure' {
        It 'imports and exposes functions' {
            Get-Command Get-MonitorInfo | Should -Not -BeNullOrEmpty
            Get-Command Get-MonitorInput | Should -Not -BeNullOrEmpty
            Get-Command Switch-MonitorInput | Should -Not -BeNullOrEmpty
            Get-Command Enable-MonitorPBP | Should -Not -BeNullOrEmpty
            Get-Command Disable-MonitorPBP | Should -Not -BeNullOrEmpty
            Get-Command Get-MonitorAudioVolume | Should -Not -BeNullOrEmpty
            Get-Command Set-MonitorAudioVolume | Should -Not -BeNullOrEmpty
            Get-Command Get-MonitorAudio | Should -Not -BeNullOrEmpty
            Get-Command Enable-MonitorAudio | Should -Not -BeNullOrEmpty
            Get-Command Disable-MonitorAudio | Should -Not -BeNullOrEmpty
            Get-Command Get-MonitorBrightness | Should -Not -BeNullOrEmpty
            Get-Command Set-MonitorBrightness | Should -Not -BeNullOrEmpty
            Get-Command Get-MonitorContrast | Should -Not -BeNullOrEmpty
            Get-Command Set-MonitorContrast | Should -Not -BeNullOrEmpty
            Get-Command Get-MonitorPBP | Should -Not -BeNullOrEmpty
            Get-Command Find-MonitorVcpCodes | Should -Not -BeNullOrEmpty
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
        It 'Enable-MonitorPBP supports ShouldProcess (WhatIf)' {
            { Enable-MonitorPBP -MonitorName 'dell' -WhatIf } | Should -Not -Throw
        }

        It 'Disable-MonitorPBP supports ShouldProcess (WhatIf)' {
            { Disable-MonitorPBP -MonitorName 'dell' -WhatIf } | Should -Not -Throw
        }

        It 'Enable-MonitorPBP returns false cleanly if no monitor matches' {
            $result = Enable-MonitorPBP -MonitorName 'GhostMonitorXYZ' -Verbose
            $result | Should -BeFalse
        }

        It 'Disable-MonitorPBP returns false cleanly if no monitor matches' {
            $result = Disable-MonitorPBP -MonitorName 'GhostMonitorXYZ' -Verbose
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

    Context "Disable-MonitorPBP" {
        It "Should be exported" {
            Get-Command Disable-MonitorPBP -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should support WhatIf" {
            { Disable-MonitorPBP -MonitorName "NonExistent" -WhatIf } | Should -Not -Throw
        }

        It "Should handle non-existent monitor gracefully" {
            Disable-MonitorPBP -MonitorName "DefinitelyNotAMonitor" | Should -BeFalse
        }
    }

    Context "Get-MonitorAudioVolume" {
        It "Should be exported" {
             Get-Command Get-MonitorAudioVolume -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should handle non-existent monitor gracefully" {
            $result = Get-MonitorAudioVolume -MonitorName "DefinitelyNotAMonitor"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Set-MonitorAudioVolume" {
        It "Should be exported" {
            Get-Command Set-MonitorAudioVolume -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should support WhatIf" {
            { Set-MonitorAudioVolume -MonitorName "NonExistent" -Volume 50 -WhatIf } | Should -Not -Throw
        }

        It "Should validate Volume range (0-100)" {
            { Set-MonitorAudioVolume -MonitorName "Test" -Volume 101 } | Should -Throw
            { Set-MonitorAudioVolume -MonitorName "Test" -Volume -1 } | Should -Throw
        }

        It "Should handle non-existent monitor gracefully" {
            Set-MonitorAudioVolume -MonitorName "DefinitelyNotAMonitor" -Volume 50 | Should -BeFalse
        }
    }

    Context "Get-MonitorAudio" {
        It "Should be exported" {
             Get-Command Get-MonitorAudio -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should handle non-existent monitor gracefully" {
            $result = Get-MonitorAudio -MonitorName "DefinitelyNotAMonitor"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Enable-MonitorAudio" {
        It "Should be exported" {
            Get-Command Enable-MonitorAudio -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should support WhatIf" {
            { Enable-MonitorAudio -MonitorName "NonExistent" -WhatIf } | Should -Not -Throw
        }

        It "Should handle non-existent monitor gracefully" {
            Enable-MonitorAudio -MonitorName "DefinitelyNotAMonitor" | Should -BeFalse
        }
    }

    Context "Disable-MonitorAudio" {
        It "Should be exported" {
            Get-Command Disable-MonitorAudio -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should support WhatIf" {
            { Disable-MonitorAudio -MonitorName "NonExistent" -WhatIf } | Should -Not -Throw
        }

        It "Should handle non-existent monitor gracefully" {
            Disable-MonitorAudio -MonitorName "DefinitelyNotAMonitor" | Should -BeFalse
        }
    }

    Context "Get-MonitorBrightness" {
        It "Should be exported" {
             Get-Command Get-MonitorBrightness -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should handle non-existent monitor gracefully" {
            $result = Get-MonitorBrightness -MonitorName "DefinitelyNotAMonitor"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Set-MonitorBrightness" {
        It "Should be exported" {
            Get-Command Set-MonitorBrightness -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should support WhatIf" {
            { Set-MonitorBrightness -MonitorName "NonExistent" -Brightness 50 -WhatIf } | Should -Not -Throw
        }

        It "Should validate Brightness range (0-100)" {
            { Set-MonitorBrightness -MonitorName "Test" -Brightness 101 } | Should -Throw
            { Set-MonitorBrightness -MonitorName "Test" -Brightness -1 } | Should -Throw
        }
    }

    Context "Get-MonitorContrast" {
        It "Should be exported" {
             Get-Command Get-MonitorContrast -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should handle non-existent monitor gracefully" {
            $result = Get-MonitorContrast -MonitorName "DefinitelyNotAMonitor"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Set-MonitorContrast" {
        It "Should be exported" {
            Get-Command Set-MonitorContrast -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should support WhatIf" {
            { Set-MonitorContrast -MonitorName "NonExistent" -Contrast 50 -WhatIf } | Should -Not -Throw
        }

        It "Should validate Contrast range (0-100)" {
            { Set-MonitorContrast -MonitorName "Test" -Contrast 101 } | Should -Throw
            { Set-MonitorContrast -MonitorName "Test" -Contrast -1 } | Should -Throw
        }
    }



    Context 'Internals' {
        It 'Helper type is compiled and available' {
            ([System.Management.Automation.PSTypeName]'PSMonitorToolsHelper').Type | Should -Not -BeNullOrEmpty
        }
    }
}
