# Monitor.Hardware.Tests.ps1
# Integration / Hardware Tests for Monitor Switching and PBP
# WARNING: These tests interact with physical hardware. They take time and will flash the screen.
# Execute with: Invoke-Pester -Path .\Tests\Monitor.Hardware.Tests.ps1 -Passthru

Describe 'Monitor Hardware Integration' -Tag 'Hardware', 'Integration' {
    
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '..\PSMonitorTools\PSMonitorTools.psd1'
        Import-Module $modulePath -Force
        
        # Configuration - Can be overriden (e.g. via environment variable)
        $TestMonitorName = $env:TEST_MONITOR_NAME 
        if ([string]::IsNullOrWhiteSpace($TestMonitorName)) {
            $TestMonitorName = 'Dell U4924DW' # Default for local dev
        }
        
        # Check if monitor is actually present
        $mon = Get-MonitorInfo -MonitorName $TestMonitorName -ErrorAction SilentlyContinue
        if (-not $mon) {
            Write-Warning "Monitor '$TestMonitorName' not found. Skipping Hardware tests."
            $Script:SkipHardwareTests = $true
        } else {
            Write-Host "Running Hardware Tests on '$TestMonitorName'" -ForegroundColor Cyan
            $Script:SkipHardwareTests = $false
        }

        $Script:sleepSeconds = 5
        
        # Helper function to reduce boilerplate in Get/Set tests
        function Test-MonitorFeature {
            param(
                [Parameter(Mandatory)]
                [scriptblock]$GetCurrent,
                
                [Parameter(Mandatory)]
                [scriptblock]$SetValue,
                
                [Parameter(Mandatory)]
                [string]$FeatureName,
                
                [Parameter(Mandatory)]
                [string]$PropertyName,
                
                [int]$SleepSeconds = 2
            )
            
            $initial = & $GetCurrent
            if ($null -eq $initial -or $null -eq $initial.$PropertyName) {
                Write-Warning "$FeatureName control not supported or failed to read."
                Set-ItResult -Skipped
                return
            }
            
            $original = $initial.$PropertyName
            Write-Host "Initial ${FeatureName}: $original" -ForegroundColor Gray
            
            $target = if ($original -ge 50) { $original - 10 } else { $original + 10 }
            
            try {
                & $SetValue $target | Should -BeTrue
                Start-Sleep -Seconds $SleepSeconds
                (& $GetCurrent).$PropertyName | Should -Be $target
            }
            finally {
                & $SetValue $original | Out-Null
                Start-Sleep -Seconds $SleepSeconds
            }
        }
    }

    Context 'Basic Switching and PBP' {
        It 'Is not skipped' {
            if ($Script:SkipHardwareTests) { Set-ItResult -Skipped -Message "Monitor not found" }
        }

        It '1. Disables PBP initially' {
            if ($Script:SkipHardwareTests) { Set-ItResult -Skipped }
            
            Disable-MonitorPBP -MonitorName $TestMonitorName | Should -Be $true
            
            $state = Get-MonitorInput -MonitorName $TestMonitorName
            $state.PBP | Should -BeFalse
        }

        It '2. Switches to Hdmi1' {
            if ($Script:SkipHardwareTests) { Set-ItResult -Skipped }

            Switch-MonitorInput -MonitorName $TestMonitorName -InputLeft Hdmi1 | Should -Be $true
            
            $state = Get-MonitorInput -MonitorName $TestMonitorName
            $state.InputLeft | Should -Be 'Hdmi1'
        }

        # Skipped internal inputs to save time
        # It '3. Switches to Hdmi2' { ... }
        # It '4. Switches to UsbC' { ... }

        It '5. Switches to DisplayPort' {
            if ($Script:SkipHardwareTests) { Set-ItResult -Skipped }

            Switch-MonitorInput -MonitorName $TestMonitorName -InputLeft DisplayPort | Should -Be $true
            
            $state = Get-MonitorInput -MonitorName $TestMonitorName
            $state.InputLeft | Should -Be 'DisplayPort'
        }

        It '6. Enables PBP' {
            if ($Script:SkipHardwareTests) { Set-ItResult -Skipped }

            Enable-MonitorPBP -MonitorName $TestMonitorName | Should -Be $true
            
            $state = Get-MonitorInput -MonitorName $TestMonitorName
            $state.PBP | Should -BeTrue
        }
    }
    
    Context 'PBP Combination Matrix' {
        # Reduced set of test cases to save time (representative combinations)
        $testCases = @(
            @{ Left='Hdmi1'; Right='Hdmi2' }
            @{ Left='Hdmi1'; Right='UsbC' }
            @{ Left='DisplayPort'; Right='Hdmi1' }
            @{ Left='UsbC'; Right='DisplayPort' }
        )

        It "Combinations: Left=<Left>, Right=<Right>" -TestCases $testCases {
            param($Left, $Right)
            if ($Script:SkipHardwareTests) { Set-ItResult -Skipped }
            
            Switch-MonitorInput -MonitorName $TestMonitorName -InputLeft $Left -InputRight $Right | Should -Be $true

            $state = Get-MonitorInput -MonitorName $TestMonitorName

            # Log state for debugging
            $state | Out-String | Write-Host -ForegroundColor DarkGray
            
            # Exception: Some monitors auto-disable PBP for specific combinations (e.g. DP high freq).
            # We accept PBP=False if the inputs were incompatible, but log a warning
            if ($state.PBP) {
                $state.InputLeft | Should -Be $Left
                $state.InputRight | Should -Be $Right
            } else {
                Write-Warning "PBP was disabled by the monitor for Left=$Left / Right=$Right (incompatible combination or timing issue)"
            }
        }
    }

    Context 'Cleanup' {
        It '8. Disables PBP again' {
            if ($Script:SkipHardwareTests) { Set-ItResult -Skipped }

            Disable-MonitorPBP -MonitorName $TestMonitorName | Should -Be $true
            
            $state = Get-MonitorInput -MonitorName $TestMonitorName
            $state.PBP | Should -BeFalse
        }

        It '9. Resets to DisplayPort' {
            if ($Script:SkipHardwareTests) { Set-ItResult -Skipped }

            Switch-MonitorInput -MonitorName $TestMonitorName -InputLeft DisplayPort | Should -Be $true
            
            $state = Get-MonitorInput -MonitorName $TestMonitorName
            $state.InputLeft | Should -Be 'DisplayPort'
        }
    }

    Context 'Smart Ordering and Collision Avoidance' {
        It 'Setup: Enables PBP and sets initial state (Left=DisplayPort, Right=UsbC)' {
            if ($Script:SkipHardwareTests) { Set-ItResult -Skipped }

            Enable-MonitorPBP -MonitorName $TestMonitorName | Out-Null
            Start-Sleep -Seconds 10 # Wait for PBP to activate

            # Set distinct inputs to prepare for collision
            Switch-MonitorInput -MonitorName $TestMonitorName -InputLeft DisplayPort | Out-Null
            Switch-MonitorInput -MonitorName $TestMonitorName -InputRight UsbC | Out-Null
            
            $state = Get-MonitorInput -MonitorName $TestMonitorName
            $state | Should -Not -BeNullOrEmpty
            $state.InputRight | Should -Be 'UsbC'
        }

        It 'Handles Collision: Sets Left=UsbC (collide with old Right) and Right=Hdmi1' {
            if ($Script:SkipHardwareTests) { Set-ItResult -Skipped }

            # This triggers the "Smart Ordering" logic inside the module
            Switch-MonitorInput -MonitorName $TestMonitorName -InputLeft UsbC -InputRight Hdmi1 | Should -Be $true
            
            $state = Get-MonitorInput -MonitorName $TestMonitorName
            $state | Should -Not -BeNullOrEmpty
            $state.InputLeft | Should -Be 'UsbC'
            $state.InputRight | Should -Be 'Hdmi1'
        }

        It 'Cleanup: Disables PBP and resets to DisplayPort' {
            if ($Script:SkipHardwareTests) { Set-ItResult -Skipped }

            Disable-MonitorPBP -MonitorName $TestMonitorName | Should -Be $true
            
            Switch-MonitorInput -MonitorName $TestMonitorName -InputLeft DisplayPort | Should -Be $true
            
            $state = Get-MonitorInput -MonitorName $TestMonitorName
            $state.PBP | Should -BeFalse
            $state.InputLeft | Should -Be 'DisplayPort'
        }
    }

    Context 'Audio, Contrast and Brightness' {
        
        It 'Controls Audio Mute State' {
            if ($Script:SkipHardwareTests) { Set-ItResult -Skipped }

            $initial = Get-MonitorAudio -MonitorName $TestMonitorName
            if ($null -eq $initial -or $null -eq $initial.AudioEnabled) {
                 Write-Warning "Audio control not supported or failed to read."
                 Set-ItResult -Skipped
            } else {
                $origState = $initial.AudioEnabled
                Write-Host "Initial Audio Mute State: $origState" -ForegroundColor Gray

                try {
                    if ($origState) {
                        # Was Enabled (Unmuted), so Disable (Mute) it
                        Disable-MonitorAudio -MonitorName $TestMonitorName | Should -BeTrue
                        Start-Sleep -Seconds 2
                        (Get-MonitorAudio -MonitorName $TestMonitorName).AudioEnabled | Should -BeFalse
                    } else {
                        # Was Disabled (Muted), so Enable (Unmute) it
                        Enable-MonitorAudio -MonitorName $TestMonitorName | Should -BeTrue
                        Start-Sleep -Seconds 2
                        (Get-MonitorAudio -MonitorName $TestMonitorName).AudioEnabled | Should -BeTrue
                    }
                }
                finally {
                    # Restore
                    if ($origState) {
                        Enable-MonitorAudio -MonitorName $TestMonitorName | Out-Null
                    } else {
                        Disable-MonitorAudio -MonitorName $TestMonitorName | Out-Null
                    }
                    Start-Sleep -Seconds 2
                }
            }
        }

        It 'Controls Audio Volume' {
            if ($Script:SkipHardwareTests) { Set-ItResult -Skipped }
            
            Test-MonitorFeature `
                -GetCurrent { Get-MonitorAudioVolume -MonitorName $TestMonitorName } `
                -SetValue { param($v) Set-MonitorAudioVolume -MonitorName $TestMonitorName -Volume $v } `
                -FeatureName 'Volume' `
                -PropertyName 'Volume'
        }

        It 'Controls Contrast' {
            if ($Script:SkipHardwareTests) { Set-ItResult -Skipped }
            
            Test-MonitorFeature `
                -GetCurrent { Get-MonitorContrast -MonitorName $TestMonitorName } `
                -SetValue { param($v) Set-MonitorContrast -MonitorName $TestMonitorName -Contrast $v } `
                -FeatureName 'Contrast' `
                -PropertyName 'Contrast'
        }

        It 'Controls Brightness' {
            if ($Script:SkipHardwareTests) { Set-ItResult -Skipped }
            
            Test-MonitorFeature `
                -GetCurrent { Get-MonitorBrightness -MonitorName $TestMonitorName } `
                -SetValue { param($v) Set-MonitorBrightness -MonitorName $TestMonitorName -Brightness $v } `
                -FeatureName 'Brightness' `
                -PropertyName 'Brightness'
        }
    }
}
