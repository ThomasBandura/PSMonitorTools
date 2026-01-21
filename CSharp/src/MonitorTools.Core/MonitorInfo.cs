namespace MonitorTools.Core;

/// <summary>
/// Represents information about a monitor
/// </summary>
public class MonitorInfo
{
    /// <summary>
    /// Monitor index (0-based)
    /// </summary>
    public int Index { get; set; }

    /// <summary>
    /// Monitor device name
    /// </summary>
    public string DeviceName { get; set; } = string.Empty;

    /// <summary>
    /// Monitor description (from physical monitor API)
    /// </summary>
    public string Description { get; set; } = string.Empty;

    /// <summary>
    /// Monitor manufacturer
    /// </summary>
    public string Manufacturer { get; set; } = string.Empty;

    /// <summary>
    /// Monitor model name
    /// </summary>
    public string Model { get; set; } = string.Empty;

    /// <summary>
    /// Monitor serial number
    /// </summary>
    public string SerialNumber { get; set; } = string.Empty;

    /// <summary>
    /// Firmware version
    /// </summary>
    public string? Firmware { get; set; }

    /// <summary>
    /// Week of manufacture
    /// </summary>
    public int? WeekOfManufacture { get; set; }

    /// <summary>
    /// Year of manufacture
    /// </summary>
    public int? YearOfManufacture { get; set; }

    /// <summary>
    /// Screen resolution width
    /// </summary>
    public int Width { get; set; }

    /// <summary>
    /// Screen resolution height
    /// </summary>
    public int Height { get; set; }

    /// <summary>
    /// Whether this is the primary monitor
    /// </summary>
    public bool IsPrimary { get; set; }

    /// <summary>
    /// Current brightness level (0-100)
    /// </summary>
    public int? Brightness { get; set; }

    public override string ToString()
    {
        return $"{DeviceName} ({Manufacturer} {Model}) - {Width}x{Height}" +
               (IsPrimary ? " [Primary]" : "");
    }
}
