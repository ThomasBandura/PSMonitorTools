using MonitorTools.Core;

namespace MonitorTools.Core.Tests;

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
