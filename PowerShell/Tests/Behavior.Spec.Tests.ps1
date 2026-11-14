<#
    Shared behavior cases (spec/monitor-behavior.json).
    MonitorTools.Core is tested with the same file (BehaviorSpecTests.cs), so both implementations
    follow the same rules. Runs on Windows PowerShell 5.1 and PowerShell 7.
#>

BeforeDiscovery {
    $specPath = Join-Path $PSScriptRoot '..\..\spec\monitor-behavior.json'
    $spec = Get-Content -Path $specPath -Raw -Encoding UTF8 | ConvertFrom-Json

    function ConvertTo-TestCase($Items) {
        foreach ($item in $Items) {
            $case = @{}
            foreach ($property in $item.PSObject.Properties) {
                # 'input' and 'error' are automatic variables in PowerShell
                $name = switch ($property.Name) { 'input' { 'inputName' } 'error' { 'expectedError' } default { $property.Name } }
                $case[$name] = $property.Value
            }
            $case
        }
    }

    $pbpCases = @(ConvertTo-TestCase $spec.pbpActive)
    $leftInputCases = @(ConvertTo-TestCase $spec.leftInputValue)
    $continuousCases = @(ConvertTo-TestCase $spec.continuousValue)
    $switchCases = @(ConvertTo-TestCase $spec.inputSwitch)
}

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\PSMonitorTools\PSMonitorTools.psd1'
    Import-Module $modulePath -Force

    # Hex strings ("0xF0F") to numbers; [Convert] accepts the 0x prefix
    function ConvertFrom-Hex([string]$Text) { [Convert]::ToUInt32($Text, 16) }
}

Describe 'Shared behavior spec' {

    Context 'pbpActive' {
        It 'VCP 0xE9 = <value> means active = <active>' -TestCases $pbpCases {
            param($value, $active)
            $number = ConvertFrom-Hex $value
            InModuleScope PSMonitorTools -Parameters @{ Number = $number; Active = $active } {
                param($Number, $Active)
                Test-PbpModeActive -Value $Number | Should -Be $Active
            }
        }
    }

    Context 'leftInputValue' {
        It '<inputName> with PBP active = <pbpActive> is written as <value>' -TestCases $leftInputCases {
            param($inputName, $pbpActive, $value)
            $expected = ConvertFrom-Hex $value
            InModuleScope PSMonitorTools -Parameters @{ Name = $inputName; Pbp = $pbpActive; Expected = $expected } {
                param($Name, $Pbp, $Expected)
                Get-LeftInputValue -InputSource $Name -PbpActive $Pbp | Should -Be $Expected
            }
        }
    }

    Context 'continuousValue' {
        It 'value <value> with maximum <maximum>: limit <limit>, valid = <valid>' -TestCases $continuousCases {
            param($value, $maximum, $valid, $limit)
            InModuleScope PSMonitorTools -Parameters @{ Value = $value; Maximum = $maximum; Valid = $valid; Limit = $limit } {
                param($Value, $Maximum, $Valid, $Limit)
                $actualLimit = Get-VcpValueLimit -Maximum $Maximum
                $actualLimit | Should -Be $Limit
                ($Value -le $actualLimit) | Should -Be $Valid
            }
        }
    }

    Context 'inputSwitch (plan)' {
        It '<name>' -TestCases $switchCases {
            param($pbpActive, $currentLeft, $currentRight, $left, $right, $steps, $expectedError)
            InModuleScope PSMonitorTools -Parameters @{
                Pbp = $pbpActive; CurrentLeft = $currentLeft; CurrentRight = $currentRight
                Left = $left; Right = $right; Steps = @($steps); ExpectedError = $expectedError
            } {
                param($Pbp, $CurrentLeft, $CurrentRight, $Left, $Right, $Steps, $ExpectedError)
                $leftCode = if ($CurrentLeft) { [int][MonitorInput]$CurrentLeft } else { 0 }
                $rightCode = if ($CurrentRight) { [int][MonitorInput]$CurrentRight } else { 0 }

                $plan = Get-InputSwitchPlan -PbpActive $Pbp -CurrentLeft $leftCode -CurrentRight $rightCode -Left $Left -Right $Right

                $plan.Error | Should -Be $ExpectedError
                $actualSteps = @($plan.Steps | ForEach-Object { "$($_.Side):$($_.Input)" })
                $actualSteps | Should -Be @($Steps | Where-Object { $_ })
            }
        }
    }

    Context 'inputSwitch (Switch-MonitorInput with mocked monitor)' {
        It '<name>' -TestCases $switchCases {
            param($pbpActive, $currentLeft, $currentRight, $left, $right, $steps, $expectedError)
            InModuleScope PSMonitorTools -Parameters @{
                Pbp = $pbpActive; CurrentLeft = $currentLeft; CurrentRight = $currentRight
                Left = $left; Right = $right; Steps = @($steps); ExpectedError = $expectedError
            } {
                param($Pbp, $CurrentLeft, $CurrentRight, $Left, $Right, $Steps, $ExpectedError)

                # Simulated monitor: the inputs change when they are written
                $script:monitorPbp = if ($Pbp) { 0x24 } else { 0x00 }
                $script:monitorLeft = if ($CurrentLeft) { [int][MonitorInput]$CurrentLeft } else { $null }
                $script:monitorRight = if ($CurrentRight) { [int][MonitorInput]$CurrentRight } else { $null }
                $script:writes = [System.Collections.Generic.List[string]]::new()

                Mock Start-Sleep {}
                Mock Invoke-PhysicalMonitorAction {
                    & $Action ([pscustomobject]@{ Handle = [IntPtr]::Zero; Description = 'Fake Monitor' }) $null 0 $null 'FakeModel'
                }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE9 } { $script:monitorPbp }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0x60 } { $script:monitorLeft }
                Mock Invoke-VcpGet -ParameterFilter { $VcpCode -eq 0xE8 } { $script:monitorRight }
                Mock Invoke-VcpSet {
                    if ($VcpCode -eq 0x60) { $script:monitorLeft = $Value; $script:writes.Add("Left:$([MonitorInput]($Value -band 0xFF))") }
                    if ($VcpCode -eq 0xE8) { $script:monitorRight = $Value; $script:writes.Add("Right:$([MonitorInput]$Value)") }
                    $true
                }

                $parameters = @{ MonitorName = 'Fake'; Confirm = $false; ErrorAction = 'SilentlyContinue'; ErrorVariable = 'err' }
                if ($Left) { $parameters.InputLeft = $Left }
                if ($Right) { $parameters.InputRight = $Right }
                $result = Switch-MonitorInput @parameters 3>$null

                if ($ExpectedError) {
                    $result | Should -BeFalse
                    $err | Should -Not -BeNullOrEmpty
                    $script:writes.Count | Should -Be 0
                } else {
                    $result | Should -BeTrue
                    @($script:writes) | Should -Be @($Steps | Where-Object { $_ })
                }
            }
        }
    }
}
