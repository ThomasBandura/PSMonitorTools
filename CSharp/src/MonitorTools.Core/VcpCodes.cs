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

    /// <summary>
    /// VCP codes that reset settings or change the power state. Writing them can have
    /// effects that are hard to undo, so the CLI requires an explicit confirmation.
    /// </summary>
    public static IReadOnlyDictionary<byte, string> CriticalCodes { get; } = new Dictionary<byte, string>
    {
        [0x04] = "Restore factory defaults",
        [0x05] = "Restore factory brightness/contrast defaults",
        [0x06] = "Restore factory geometry defaults",
        [0x08] = "Restore factory color defaults",
        [0x0A] = "Restore factory TV defaults",
        [0xB0] = "Settings store/restore",
        [0xD6] = "Power mode"
    };

    /// <summary>
    /// Returns true if writing the given VCP code can reset settings or change the power state
    /// </summary>
    public static bool IsCritical(byte vcpCode) => CriticalCodes.ContainsKey(vcpCode);
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

    /// <summary>
    /// Added to the left input value (VCP 0x60) while PBP is active, so that switching the
    /// left input never turns PBP off. Same behavior as the PowerShell module.
    /// </summary>
    public const uint LeftInputMask = 0xF00;

    /// <summary>
    /// Returns true if a VCP 0xE9 value means PBP/PIP is active. Every value other than
    /// <see cref="Off"/> counts as active, same as the PowerShell module.
    /// </summary>
    public static bool IsActive(uint value) => value != Off;

    /// <summary>
    /// Returns the VCP 0x60 value for the left input, masked with <see cref="LeftInputMask"/> while PBP is active
    /// </summary>
    public static uint GetLeftInputValue(MonitorInput input, bool pbpActive)
        => pbpActive ? LeftInputMask | (uint)input : (uint)input;
}

/// <summary>
/// Audio mute states for VCP 0x8D.
/// </summary>
/// <remarks>
/// This is a device-specific encoding (verified on Dell U4924DW): 0x00 = muted, 0x01 = unmuted.
/// The Dell ignores the MCCS values (writing 0x02 leaves the value unchanged).
/// The MCCS standard defines 0x01 = muted, 0x02 = unmuted. On an MCCS-compliant monitor
/// <see cref="Unmuted"/> (0x01) would therefore mute the audio. Use <c>vcp set 0x8D</c> with the
/// MCCS values for such monitors.
/// </remarks>
public enum AudioMuteState
{
    /// <summary>
    /// Audio is muted
    /// </summary>
    Muted = 0x00,

    /// <summary>
    /// Audio is unmuted
    /// </summary>
    Unmuted = 0x01
}
