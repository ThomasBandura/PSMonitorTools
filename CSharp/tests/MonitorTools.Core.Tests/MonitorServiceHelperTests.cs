using MonitorTools.Core;

namespace MonitorTools.Core.Tests;

[System.Runtime.Versioning.SupportedOSPlatform("windows")]
public class PhysicalIndexTests
{
    [Theory]
    [InlineData(0, 0, 0)]
    [InlineData(1, 1, 0)]
    [InlineData(2, 1, 1)]   // clone mode: second physical monitor behind display 1
    [InlineData(3, 2, 0)]
    public void ResolvePhysicalIndex_MapsIndexToDisplayAndPhysicalMonitor(int index, int expectedDisplay, int expectedPhysical)
    {
        // Display 0: 1 monitor, display 1: 2 cloned monitors, display 2: 1 monitor
        var result = MonitorService.ResolvePhysicalIndex(new[] { 1, 2, 1 }, index);

        Assert.Equal((expectedDisplay, expectedPhysical), result);
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(4)]
    public void ResolvePhysicalIndex_ReturnsNullOutOfRange(int index)
    {
        Assert.Null(MonitorService.ResolvePhysicalIndex(new[] { 1, 2, 1 }, index));
    }

    [Fact]
    public void ResolvePhysicalIndex_ReturnsNullWithoutDisplays()
    {
        Assert.Null(MonitorService.ResolvePhysicalIndex(Array.Empty<int>(), 0));
    }
}

[System.Runtime.Versioning.SupportedOSPlatform("windows")]
public class ContinuousValueTests
{
    [Theory]
    [InlineData(0, 100u)]
    [InlineData(100, 100u)]
    [InlineData(250, 255u)]
    [InlineData(50, 0u)]    // no maximum reported: 0-100 assumed
    public void ValidateContinuousValue_AcceptsValuesWithinMaximum(int value, uint maximum)
    {
        MonitorService.ValidateContinuousValue(value, maximum, "Brightness");
    }

    [Theory]
    [InlineData(-1, 100u)]
    [InlineData(101, 100u)]
    [InlineData(80, 50u)]
    [InlineData(101, 0u)]
    public void ValidateContinuousValue_RejectsValuesOutsideMaximum(int value, uint maximum)
    {
        var ex = Assert.Throws<ArgumentOutOfRangeException>(
            () => MonitorService.ValidateContinuousValue(value, maximum, "Brightness"));
        Assert.Contains("Brightness must be between 0 and", ex.Message);
    }
}

[System.Runtime.Versioning.SupportedOSPlatform("windows")]
public class WmiInstanceNameTests
{
    [Fact]
    public void ConvertDevicePath_ReturnsWmiInstanceName()
    {
        var path = @"\\?\DISPLAY#DELA1A6#5&1a2b3c4d&0&UID4352#{e6f07b5f-ee97-4a90-b076-33f57bf4eaa7}";

        var result = MonitorService.ConvertDevicePathToWmiInstanceName(path);

        Assert.Equal(@"DISPLAY\DELA1A6\5&1a2b3c4d&0&UID4352", result);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData(@"MONITOR\DELA1A6\{4d36e96e-e325-11ce-bfc1-08002be10318}\0001")]
    [InlineData(@"\\?\DISPLAY")]
    public void ConvertDevicePath_ReturnsNullForUnexpectedFormat(string? path)
    {
        Assert.Null(MonitorService.ConvertDevicePathToWmiInstanceName(path));
    }
}

public class CriticalVcpCodeTests
{
    [Theory]
    [InlineData(0x04)]
    [InlineData(0x05)]
    [InlineData(0x06)]
    [InlineData(0x08)]
    [InlineData(0x0A)]
    [InlineData(0xB0)]
    [InlineData(0xD6)]
    public void IsCritical_ReturnsTrueForResetAndPowerCodes(byte code)
    {
        Assert.True(VcpCode.IsCritical(code));
    }

    [Theory]
    [InlineData(VcpCode.Brightness)]
    [InlineData(VcpCode.Contrast)]
    [InlineData(VcpCode.InputSource)]
    [InlineData(VcpCode.AudioVolume)]
    [InlineData(VcpCode.PbpMode)]
    public void IsCritical_ReturnsFalseForRegularCodes(byte code)
    {
        Assert.False(VcpCode.IsCritical(code));
    }
}
