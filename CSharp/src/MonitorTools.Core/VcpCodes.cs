namespace MonitorTools.Core;

/// <summary>
/// VCP (VESA Control Panel) feature codes for DDC/CI communication
/// </summary>
public static class VcpCode
{
    /// <summary>
    /// Brightness / Luminance (0x10)
    /// </summary>
    public const byte Brightness = 0x10;

    /// <summary>
    /// Contrast (0x12)
    /// </summary>
    public const byte Contrast = 0x12;

    /// <summary>
    /// Input Source - Primary/Left (0x60)
    /// </summary>
    public const byte InputSource = 0x60;

    /// <summary>
    /// Audio Volume (0x62)
    /// </summary>
    public const byte AudioVolume = 0x62;

    /// <summary>
    /// Audio Mute (0x8D)
    /// </summary>
    public const byte AudioMute = 0x8D;

    /// <summary>
    /// Firmware Version (0xC9)
    /// </summary>
    public const byte Firmware = 0xC9;

    /// <summary>
    /// PBP Right Input Source (0xE8)
    /// </summary>
    public const byte PbpRightInput = 0xE8;

    /// <summary>
    /// PBP/PIP Mode (0xE9)
    /// </summary>
    public const byte PbpMode = 0xE9;
}

/// <summary>
/// Monitor input sources
/// </summary>
public enum MonitorInput
{
    /// <summary>
    /// HDMI 1
    /// </summary>
    Hdmi1 = 0x11,

    /// <summary>
    /// HDMI 2
    /// </summary>
    Hdmi2 = 0x12,

    /// <summary>
    /// DisplayPort
    /// </summary>
    DisplayPort = 0x0F,

    /// <summary>
    /// USB-C
    /// </summary>
    UsbC = 0x1B
}

/// <summary>
/// PBP (Picture-by-Picture) mode values
/// </summary>
public static class PbpModeValue
{
    /// <summary>
    /// PBP Mode Off
    /// </summary>
    public const uint Off = 0x00;

    /// <summary>
    /// PBP Mode On
    /// </summary>
    public const uint On = 0x24;
}

/// <summary>
/// Audio mute states
/// </summary>
public enum AudioMuteState
{
    /// <summary>
    /// Audio is unmuted
    /// </summary>
    Unmuted = 0x01,

    /// <summary>
    /// Audio is muted
    /// </summary>
    Muted = 0x02
}
