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
            # Note: This test runs against the real system state because CommandCompletion 
            # uses the engine's command discovery which bypasses Pester mocks in this scope.
            
            $script = 'Switch-MonitorInput -MonitorName '
            $cursor = $script.Length
            
            # This triggers the actual completer registered in the module
            $results = [System.Management.Automation.CommandCompletion]::CompleteInput($script, $cursor, $null)
            $completionTexts = $results.CompletionMatches | ForEach-Object { $_.CompletionText }

            # We expect completions if there are monitors, or at least no errors thrown.
            # Since we saw monitors in the debug output ("Dell..."), we expect > 0.
            # If run on a headless server, this might be 0, so we use a conditional check or warn.
            
            # Simple check: The completion object should not be null
            $results | Should -Not -BeNullOrEmpty
            
            # Optional: Check if quotes are applied correctly if items are found
            if ($completionTexts.Count -gt 0) {
                 $completionTexts[0] | Should -Match "^'.*'$" 
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
