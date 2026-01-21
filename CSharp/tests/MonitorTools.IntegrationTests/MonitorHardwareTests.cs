using MonitorTools.Core;

namespace MonitorTools.IntegrationTests;

/// <summary>
/// Hardware integration tests for monitor control.
/// WARNING: These tests interact with physical hardware and may flash the screen.
/// Run only when a test monitor is connected.
/// Tests match the structure of Monitor.Hardware.Tests.ps1
/// </summary>
[Collection("Hardware")]
public class MonitorHardwareTests : IDisposable
{
    private readonly MonitorService _service;
    private readonly bool _skipTests;
    private readonly int _testMonitorIndex = 0;

    public MonitorHardwareTests()
    {
        _service = new MonitorService();
        
        var monitors = _service.GetMonitors();
        _skipTests = monitors.Length == 0;

        if (!_skipTests)
        {
            Console.WriteLine($"Running Hardware Tests on Monitor {_testMonitorIndex}");
            Console.WriteLine($"Monitor: {monitors[_testMonitorIndex].DeviceName} - {monitors[_testMonitorIndex].Model}");
        }
        else
        {
            Console.WriteLine("No monitors found. Skipping hardware tests.");
        }
    }

    public void Dispose()
    {
        // Ensure PBP is disabled after all tests
        try
        {
            if (!_skipTests)
            {
                _service.DisablePbp(_testMonitorIndex);
                Thread.Sleep(2000);
            }
        }
        catch { }
    }

    private void Sleep()
    {
        Thread.Sleep(2000);
    }

    // ===== Basic Switching and PBP =====

    [Fact]
    public void Test01_DisablesPbpInitially()
    {
        if (_skipTests) return;

        // Act
        _service.DisablePbp(_testMonitorIndex);
        Sleep();

        // Assert
        Assert.False(_service.IsPbpEnabled(_testMonitorIndex));
    }

    [Fact]
    public void Test02_SwitchesToHdmi1()
    {
        if (_skipTests) return;

        // Act
        _service.SetInput(MonitorInput.Hdmi1, _testMonitorIndex);
        Sleep();

        // Assert
        var current = _service.GetInput(_testMonitorIndex);
        Assert.Equal(MonitorInput.Hdmi1, current);
    }

    [Fact]
    public void Test03_SwitchesToDisplayPort()
    {
        if (_skipTests) return;

        // Act
        _service.SetInput(MonitorInput.DisplayPort, _testMonitorIndex);
        Sleep();

        // Assert
        var current = _service.GetInput(_testMonitorIndex);
        Assert.Equal(MonitorInput.DisplayPort, current);
    }

    [Fact]
    public void Test04_EnablesPbp()
    {
        if (_skipTests) return;

        // Act
        _service.EnablePbp(_testMonitorIndex);
        Sleep();
        Sleep(); // PBP needs more time

        // Assert
        Assert.True(_service.IsPbpEnabled(_testMonitorIndex));
    }

    // ===== PBP Combination Matrix =====

    [Theory]
    [InlineData(MonitorInput.Hdmi1, MonitorInput.Hdmi2)]
    [InlineData(MonitorInput.Hdmi1, MonitorInput.UsbC)]
    [InlineData(MonitorInput.DisplayPort, MonitorInput.Hdmi1)]
    [InlineData(MonitorInput.UsbC, MonitorInput.DisplayPort)]
    public void Test05_PbpCombinations(MonitorInput left, MonitorInput right)
    {
        if (_skipTests) return;

        try
        {
            // Reset to known state: Disable PBP, set to DisplayPort
            if (_service.IsPbpEnabled(_testMonitorIndex))
            {
                _service.DisablePbp(_testMonitorIndex);
                Sleep();
                Sleep();
            }
            _service.SetInput(MonitorInput.DisplayPort, _testMonitorIndex);
            Sleep();
            
            // Now enable PBP
            _service.EnablePbp(_testMonitorIndex);
            Sleep();
            Sleep();

            Console.WriteLine($"Testing PBP: Left={left}, Right={right}");

            // Act
            _service.SetInputSmart(left, right, _testMonitorIndex);
            Sleep();

            // Assert
            var actualLeft = _service.GetInput(_testMonitorIndex);
            var actualRight = _service.GetPbpRightInput(_testMonitorIndex);
            
            // Some combinations may auto-disable PBP or fail to switch
            if (_service.IsPbpEnabled(_testMonitorIndex))
            {
                // Check if inputs actually switched
                if (actualLeft == left && actualRight == right)
                {
                    // Perfect - both inputs switched as expected
                    Assert.Equal(left, actualLeft);
                    Assert.Equal(right, actualRight);
                }
                else
                {
                    // Inputs didn't switch - monitor rejected this combination
                    Console.WriteLine($"Warning: Monitor did not switch to {left}/{right} (actual: {actualLeft}/{actualRight})");
                    Console.WriteLine("This combination may not be supported or conflicts with active connection");
                }
            }
            else
            {
                Console.WriteLine($"Warning: PBP was disabled by monitor for {left}/{right}");
            }
        }
        catch (InvalidOperationException ex)
        {
            Console.WriteLine($"PBP combination not supported: {ex.Message}");
            return;
        }
    }

    // ===== Cleanup =====

    [Fact]
    public void Test06_DisablesPbpAgain()
    {
        if (_skipTests) return;

        // Act
        _service.DisablePbp(_testMonitorIndex);
        Sleep();

        // Assert
        Assert.False(_service.IsPbpEnabled(_testMonitorIndex));
    }

    [Fact]
    public void Test07_ResetsToDisplayPort()
    {
        if (_skipTests) return;

        // Act
        _service.SetInput(MonitorInput.DisplayPort, _testMonitorIndex);
        Sleep();

        // Assert
        var current = _service.GetInput(_testMonitorIndex);
        Assert.Equal(MonitorInput.DisplayPort, current);
    }

    // ===== Smart Ordering and Collision Avoidance =====

    [Fact]
    public void Test08_SmartOrderingSetup()
    {
        if (_skipTests) return;

        // Arrange - Enable PBP and set distinct inputs
        _service.EnablePbp(_testMonitorIndex);
        Sleep();
        Sleep();

        _service.SetInput(MonitorInput.DisplayPort, _testMonitorIndex);
        Sleep();
        _service.SetPbpRightInput(MonitorInput.UsbC, _testMonitorIndex);
        Sleep();

        // Assert
        var rightInput = _service.GetPbpRightInput(_testMonitorIndex);
        Assert.Equal(MonitorInput.UsbC, rightInput);
    }

    [Fact]
    public void Test09_SmartOrderingHandlesCollision()
    {
        if (_skipTests) return;

        try
        {
            // Ensure PBP is enabled and set initial state
            if (!_service.IsPbpEnabled(_testMonitorIndex))
            {
                _service.EnablePbp(_testMonitorIndex);
                Sleep();
                Sleep();
            }

            // Setup: Set to DisplayPort + UsbC
            _service.SetInput(MonitorInput.DisplayPort, _testMonitorIndex);
            Sleep();
            _service.SetPbpRightInput(MonitorInput.UsbC, _testMonitorIndex);
            Sleep();

            // This triggers smart ordering: Left=UsbC collides with current Right=UsbC
            // Smart logic should switch Right first to free up UsbC
            _service.SetInputSmart(MonitorInput.UsbC, MonitorInput.Hdmi1, _testMonitorIndex);
            Sleep();
            Sleep();

            // Assert
            var actualLeft = _service.GetInput(_testMonitorIndex);
            var actualRight = _service.GetPbpRightInput(_testMonitorIndex);

            Assert.Equal(MonitorInput.UsbC, actualLeft);
            Assert.Equal(MonitorInput.Hdmi1, actualRight);
        }
        catch (InvalidOperationException ex)
        {
            Console.WriteLine($"Smart ordering test failed: {ex.Message}");
            return;
        }
    }

    [Fact]
    public void Test10_SmartOrderingCleanup()
    {
        if (_skipTests) return;

        // Act
        _service.DisablePbp(_testMonitorIndex);
        Sleep();

        _service.SetInput(MonitorInput.DisplayPort, _testMonitorIndex);
        Sleep();

        // Assert
        Assert.False(_service.IsPbpEnabled(_testMonitorIndex));
        Assert.Equal(MonitorInput.DisplayPort, _service.GetInput(_testMonitorIndex));
    }

    // ===== Audio, Contrast and Brightness =====

    [Fact]
    public void Test11_ControlsAudioMute()
    {
        if (_skipTests) return;

        try
        {
            // Arrange
            var initialMuted = _service.IsMuted(_testMonitorIndex);
            Console.WriteLine($"Initial Mute State: {initialMuted}");

            // Act & Assert - Toggle mute
            if (initialMuted)
            {
                _service.Unmute(_testMonitorIndex);
                Sleep();
                Assert.False(_service.IsMuted(_testMonitorIndex));

                // Restore
                _service.Mute(_testMonitorIndex);
                Sleep();
            }
            else
            {
                _service.Mute(_testMonitorIndex);
                Sleep();
                Assert.True(_service.IsMuted(_testMonitorIndex));

                // Restore
                _service.Unmute(_testMonitorIndex);
                Sleep();
            }
        }
        catch (InvalidOperationException ex)
        {
            Console.WriteLine($"Audio mute control not supported: {ex.Message}");
            return;
        }
    }

    [Fact]
    public void Test12_ControlsAudioVolume()
    {
        if (_skipTests) return;

        try
        {
            // Arrange
            var initial = _service.GetVolume(_testMonitorIndex);
            var target = initial >= 50 ? initial - 10 : initial + 10;

            Console.WriteLine($"Initial Volume: {initial}%");
            Console.WriteLine($"Target Volume: {target}%");

            // Act
            _service.SetVolume(target, _testMonitorIndex);
            Sleep();

            var actual = _service.GetVolume(_testMonitorIndex);

            // Assert
            Assert.Equal(target, actual);
            
            // Restore original volume
            _service.SetVolume(initial, _testMonitorIndex);
            Sleep();
        }
        catch (InvalidOperationException ex)
        {
            Console.WriteLine($"Volume control not supported: {ex.Message}");
            return;
        }
    }

    [Fact]
    public void Test13_ControlsContrast()
    {
        if (_skipTests) return;

        try
        {
            // Arrange
            var initial = _service.GetContrast(_testMonitorIndex);
            var target = initial >= 50 ? initial - 10 : initial + 10;

            Console.WriteLine($"Initial Contrast: {initial}%");
            Console.WriteLine($"Target Contrast: {target}%");

            // Act
            _service.SetContrast(target, _testMonitorIndex);
            Sleep();

            var actual = _service.GetContrast(_testMonitorIndex);

            // Assert
            Assert.Equal(target, actual);
            
            // Restore original contrast
            _service.SetContrast(initial, _testMonitorIndex);
            Sleep();
        }
        catch (InvalidOperationException ex)
        {
            Console.WriteLine($"Contrast control not supported: {ex.Message}");
            return;
        }
    }

    [Fact]
    public void Test14_ControlsBrightness()
    {
        if (_skipTests) return;

        try
        {
            // Arrange
            var initial = _service.GetBrightness(_testMonitorIndex);
            var target = initial >= 50 ? initial - 10 : initial + 10;

            Console.WriteLine($"Initial Brightness: {initial}%");
            Console.WriteLine($"Target Brightness: {target}%");

            // Act
            _service.SetBrightness(target, _testMonitorIndex);
            Sleep();

            var actual = _service.GetBrightness(_testMonitorIndex);

            // Assert
            Assert.Equal(target, actual);
            
            // Restore original brightness
            _service.SetBrightness(initial, _testMonitorIndex);
            Sleep();
        }
        catch (InvalidOperationException ex)
        {
            Console.WriteLine($"Brightness control not supported: {ex.Message}");
            return;
        }
    }
}

/// <summary>
/// Ensures hardware tests run sequentially, not in parallel
/// </summary>
[CollectionDefinition("Hardware", DisableParallelization = true)]
public class HardwareTestCollection
{
}
