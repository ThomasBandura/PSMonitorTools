using MonitorTools.Core;
using Xunit;

namespace MonitorTools.Core.Tests;

public class MonitorInfoTests
{
    [Fact]
    public void MonitorInfo_ToString_ReturnsFormattedString()
    {
        // Arrange
        var monitor = new MonitorInfo
        {
            DeviceName = "\\\\.\\DISPLAY1",
            Manufacturer = "Dell",
            Model = "U2415",
            Width = 1920,
            Height = 1200,
            IsPrimary = true
        };

        // Act
        var result = monitor.ToString();

        // Assert
        Assert.Contains("\\\\.\\DISPLAY1", result);
        Assert.Contains("Dell", result);
        Assert.Contains("U2415", result);
        Assert.Contains("1920x1200", result);
        Assert.Contains("[Primary]", result);
    }

    [Fact]
    public void MonitorInfo_ToString_NonPrimary_DoesNotShowPrimaryFlag()
    {
        // Arrange
        var monitor = new MonitorInfo
        {
            DeviceName = "\\\\.\\DISPLAY2",
            Manufacturer = "Samsung",
            Model = "S27",
            Width = 2560,
            Height = 1440,
            IsPrimary = false
        };

        // Act
        var result = monitor.ToString();

        // Assert
        Assert.DoesNotContain("[Primary]", result);
    }

    [Fact]
    public void MonitorInfo_Properties_CanBeSet()
    {
        // Arrange & Act
        var monitor = new MonitorInfo
        {
            Index = 1,
            DeviceName = "Test",
            Manufacturer = "TestManufacturer",
            Model = "TestModel",
            SerialNumber = "12345",
            Width = 1920,
            Height = 1080,
            IsPrimary = false,
            Brightness = 75
        };

        // Assert
        Assert.Equal(1, monitor.Index);
        Assert.Equal("Test", monitor.DeviceName);
        Assert.Equal("TestManufacturer", monitor.Manufacturer);
        Assert.Equal("TestModel", monitor.Model);
        Assert.Equal("12345", monitor.SerialNumber);
        Assert.Equal(1920, monitor.Width);
        Assert.Equal(1080, monitor.Height);
        Assert.False(monitor.IsPrimary);
        Assert.Equal(75, monitor.Brightness);
    }
}
