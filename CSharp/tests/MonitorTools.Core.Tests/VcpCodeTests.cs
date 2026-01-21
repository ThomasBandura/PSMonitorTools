using MonitorTools.Core;
using Xunit;

namespace MonitorTools.Core.Tests;

public class VcpCodeTests
{
    [Fact]
    public void VcpCode_Brightness_HasCorrectValue()
    {
        // Arrange & Assert
        Assert.Equal(0x10, VcpCode.Brightness);
    }

    [Fact]
    public void VcpCode_Contrast_HasCorrectValue()
    {
        // Arrange & Assert
        Assert.Equal(0x12, VcpCode.Contrast);
    }

    [Fact]
    public void VcpCode_InputSource_HasCorrectValue()
    {
        // Arrange & Assert
        Assert.Equal(0x60, VcpCode.InputSource);
    }

    [Fact]
    public void VcpCode_AudioVolume_HasCorrectValue()
    {
        // Arrange & Assert
        Assert.Equal(0x62, VcpCode.AudioVolume);
    }

    [Fact]
    public void VcpCode_AudioMute_HasCorrectValue()
    {
        // Arrange & Assert
        Assert.Equal(0x8D, VcpCode.AudioMute);
    }
}

public class MonitorInputTests
{
    [Theory]
    [InlineData(MonitorInput.Hdmi1, 0x11)]
    [InlineData(MonitorInput.Hdmi2, 0x12)]
    [InlineData(MonitorInput.DisplayPort, 0x0F)]
    [InlineData(MonitorInput.UsbC, 0x1B)]
    public void MonitorInput_HasCorrectValues(MonitorInput input, int expectedValue)
    {
        // Assert
        Assert.Equal(expectedValue, (int)input);
    }

    [Fact]
    public void MonitorInput_CanConvertFromByte()
    {
        // Arrange
        byte displayPortValue = 0x0F;

        // Act
        var input = (MonitorInput)displayPortValue;

        // Assert
        Assert.Equal(MonitorInput.DisplayPort, input);
    }
}

public class AudioMuteStateTests
{
    [Fact]
    public void AudioMuteState_Unmuted_HasCorrectValue()
    {
        Assert.Equal(1, (int)AudioMuteState.Unmuted);
    }

    [Fact]
    public void AudioMuteState_Muted_HasCorrectValue()
    {
        Assert.Equal(0, (int)AudioMuteState.Muted);
    }
}

public class PbpModeValueTests
{
    [Fact]
    public void PbpModeValue_Off_IsZero()
    {
        Assert.Equal(0x00u, PbpModeValue.Off);
    }

    [Fact]
    public void PbpModeValue_On_HasCorrectValue()
    {
        Assert.Equal(0x24u, PbpModeValue.On);
    }
}
