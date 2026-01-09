Describe 'Monitor module' {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '..\PSMonitorTools\PSMonitorTools.psd1'
        Import-Module $modulePath -Force
        $module = Get-Module PSMonitorTools
    }

    Context 'Module export and structure' {
        It 'imports and exposes functions' {
            Get-Command Get-MonitorInfo | Should -Not -BeNullOrEmpty
            Get-Command Switch-MonitorInput | Should -Not -BeNullOrEmpty
            Get-Command Enable-MonitorPBP | Should -Not -BeNullOrEmpty
            Get-Command Disable-MonitorPBP | Should -Not -BeNullOrEmpty
        }

        It 'InputSource parameter has ValidateSet values' {
            $attr = (Get-Command Switch-MonitorInput).Parameters['InputSource'].Attributes
            $vals = @()
            foreach ($a in $attr) { if ($a -is [System.Management.Automation.ValidateSetAttribute]) { $vals += $a.ValidValues } }
            $vals | Should -Contain 'Hdmi1'
            $vals | Should -Contain 'Hdmi2'
            $vals | Should -Contain 'DisplayPort'
            $vals | Should -Contain 'UsbC'
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

    Context 'Switch-MonitorInput Logic' {
        It 'supports ShouldProcess (WhatIf)' {
             # Smoke test for syntax/parameters without executing logic
            { Switch-MonitorInput -MonitorName 'dell' -InputSource Hdmi1 -WhatIf } | Should -Not -Throw
        }

        It 'returns false cleanly if no monitor matches' {
            # Integration test: 'GhostMonitorXYZ' should not exist
            $result = Switch-MonitorInput -MonitorName 'GhostMonitorXYZ' -InputSource Hdmi1 -Verbose
            $result | Should -BeFalse
        }

        It 'fails validation for invalid InputSource' {
            { Switch-MonitorInput -MonitorName 'Any' -InputSource 'InvalidSource' } | Should -Throw
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
    }

    Context 'Internals' {
        It 'Helper type is compiled and available' {
            ([System.Management.Automation.PSTypeName]'PSMonitorToolsHelper').Type | Should -Not -BeNullOrEmpty
        }
    }
}
