using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Management;
using MonitorTools.Core.Interfaces;

namespace MonitorTools.Core;

/// <summary>
/// Service for retrieving monitor information and controlling brightness
/// </summary>
[System.Runtime.Versioning.SupportedOSPlatform("windows")]
public class MonitorService : IMonitorService
{
    private readonly List<MonitorInfo> _monitors = new();
    private bool _detailsLoaded;

    /// <summary>
    /// Enumerates the connected monitors. Only basic data (index, device name, resolution)
    /// is read here; details such as WMI data, brightness and firmware are loaded on the
    /// first call to <see cref="GetMonitors"/>.
    /// </summary>
    public MonitorService()
    {
        EnumerateMonitors();
    }

    /// <summary>
    /// Gets information about all connected monitors, including WMI data, brightness and firmware
    /// </summary>
    public MonitorInfo[] GetMonitors()
    {
        EnsureDetailsLoaded();
        return _monitors.ToArray();
    }

    /// <summary>
    /// Gets the brightness level of a specific monitor
    /// </summary>
    public int GetBrightness(int monitorIndex = 0)
    {
        if (monitorIndex < 0 || monitorIndex >= _monitors.Count)
            throw new ArgumentOutOfRangeException(nameof(monitorIndex), "Invalid monitor index");

        var monitor = _monitors[monitorIndex];
        return GetMonitorBrightness(monitor);
    }

    /// <summary>
    /// Sets the brightness level of a specific monitor
    /// </summary>
    public void SetBrightness(int brightness, int monitorIndex = 0)
    {
        if (brightness < 0 || brightness > 100)
            throw new ArgumentOutOfRangeException(nameof(brightness), "Brightness must be between 0 and 100");

        if (monitorIndex < 0 || monitorIndex >= _monitors.Count)
            throw new ArgumentOutOfRangeException(nameof(monitorIndex), "Invalid monitor index");

        var monitor = _monitors[monitorIndex];
        SetMonitorBrightness(monitor, brightness);
    }

    /// <summary>
    /// Gets the contrast level of a specific monitor
    /// </summary>
    public int GetContrast(int monitorIndex = 0)
    {
        var (current, _) = GetVcpFeature(VcpCode.Contrast, monitorIndex);
        return (int)current;
    }

    /// <summary>
    /// Sets the contrast level of a specific monitor
    /// </summary>
    public void SetContrast(int contrast, int monitorIndex = 0)
    {
        if (contrast < 0 || contrast > 100)
            throw new ArgumentOutOfRangeException(nameof(contrast), "Contrast must be between 0 and 100");

        SetVcpFeature(VcpCode.Contrast, (uint)contrast, monitorIndex);
    }

    /// <summary>
    /// Gets the audio volume of a specific monitor
    /// </summary>
    public int GetVolume(int monitorIndex = 0)
    {
        var (current, _) = GetVcpFeature(VcpCode.AudioVolume, monitorIndex);
        return (int)current;
    }

    /// <summary>
    /// Sets the audio volume of a specific monitor
    /// </summary>
    public void SetVolume(int volume, int monitorIndex = 0)
    {
        if (volume < 0 || volume > 100)
            throw new ArgumentOutOfRangeException(nameof(volume), "Volume must be between 0 and 100");

        SetVcpFeature(VcpCode.AudioVolume, (uint)volume, monitorIndex);
    }

    /// <summary>
    /// Gets the audio mute state of a specific monitor
    /// </summary>
    public bool IsMuted(int monitorIndex = 0)
    {
        var (current, _) = GetVcpFeature(VcpCode.AudioMute, monitorIndex);
        return current == (uint)AudioMuteState.Muted;
    }

    /// <summary>
    /// Mutes the audio of a specific monitor
    /// </summary>
    public void Mute(int monitorIndex = 0)
    {
        SetVcpFeature(VcpCode.AudioMute, (uint)AudioMuteState.Muted, monitorIndex);
    }

    /// <summary>
    /// Unmutes the audio of a specific monitor
    /// </summary>
    public void Unmute(int monitorIndex = 0)
    {
        SetVcpFeature(VcpCode.AudioMute, (uint)AudioMuteState.Unmuted, monitorIndex);
    }

    /// <summary>
    /// Gets the current input source of a specific monitor
    /// </summary>
    public MonitorInput GetInput(int monitorIndex = 0)
    {
        var (current, _) = GetVcpFeature(VcpCode.InputSource, monitorIndex);
        
        // Some monitors return the value in the lower byte only
        // Extract the lower byte for proper enum matching
        byte inputValue = (byte)(current & 0xFF);
        
        return (MonitorInput)inputValue;
    }

    /// <summary>
    /// Sets the input source of a specific monitor
    /// </summary>
    public void SetInput(MonitorInput input, int monitorIndex = 0)
    {
        SetVcpFeature(VcpCode.InputSource, (uint)input, monitorIndex);
    }

    /// <summary>
    /// Sets the input source with smart PBP collision detection
    /// </summary>
    public void SetInputSmart(MonitorInput? leftInput = null, MonitorInput? rightInput = null, int monitorIndex = 0)
    {
        if (!leftInput.HasValue && !rightInput.HasValue)
            throw new ArgumentException("At least one input (left or right) must be specified");

        // Check if PBP is active
        bool pbpActive = IsPbpEnabled(monitorIndex);

        if (pbpActive && leftInput.HasValue && rightInput.HasValue)
        {
            // Get current inputs
            var currentLeft = GetInput(monitorIndex);
            var currentRight = GetPbpRightInput(monitorIndex);

            // Validate: Left and Right cannot be the same in PBP mode
            if (leftInput.Value == rightInput.Value)
            {
                throw new InvalidOperationException(
                    $"Invalid PBP Configuration: Left input ({leftInput.Value}) cannot be the same as right input ({rightInput.Value})");
            }

            // Smart ordering: Check for collision
            // If target left matches current right, we must switch right first
            // (Switching left first would conflict with current right)
            if (leftInput.Value == currentRight)
            {
                // Switch right first to free up the input for left
                SetPbpRightInput(rightInput.Value, monitorIndex);
                Thread.Sleep(2000);
                SetInput(leftInput.Value, monitorIndex);
                Thread.Sleep(2000);
            }
            else
            {
                // No collision: switch in normal order (left first, then right)
                // Note: If target right matches current left, this is NOT a problem
                // because we switch left first, which frees up the input for right
                SetInput(leftInput.Value, monitorIndex);
                Thread.Sleep(2000);
                SetPbpRightInput(rightInput.Value, monitorIndex);
                Thread.Sleep(2000);
            }
        }
        else
        {
            // PBP not active or single input switch
            if (leftInput.HasValue)
            {
                SetInput(leftInput.Value, monitorIndex);
                Thread.Sleep(2000);
            }
            if (rightInput.HasValue)
            {
                SetPbpRightInput(rightInput.Value, monitorIndex);
                Thread.Sleep(2000);
            }
        }
    }

    /// <summary>
    /// Checks if PBP (Picture-by-Picture) mode is enabled
    /// </summary>
    public bool IsPbpEnabled(int monitorIndex = 0)
    {
        var (current, _) = GetVcpFeature(VcpCode.PbpMode, monitorIndex);
        return current == PbpModeValue.On;
    }

    /// <summary>
    /// Enables PBP (Picture-by-Picture) mode
    /// </summary>
    public void EnablePbp(int monitorIndex = 0)
    {
        SetVcpFeature(VcpCode.PbpMode, PbpModeValue.On, monitorIndex);
    }

    /// <summary>
    /// Disables PBP (Picture-by-Picture) mode
    /// </summary>
    public void DisablePbp(int monitorIndex = 0)
    {
        SetVcpFeature(VcpCode.PbpMode, PbpModeValue.Off, monitorIndex);
    }

    /// <summary>
    /// Gets the right input source when PBP is enabled
    /// </summary>
    public MonitorInput GetPbpRightInput(int monitorIndex = 0)
    {
        var (current, _) = GetVcpFeature(VcpCode.PbpRightInput, monitorIndex);
        byte inputValue = (byte)(current & 0xFF);
        return (MonitorInput)inputValue;
    }

    /// <summary>
    /// Sets the right input source for PBP mode
    /// </summary>
    public void SetPbpRightInput(MonitorInput input, int monitorIndex = 0)
    {
        SetVcpFeature(VcpCode.PbpRightInput, (uint)input, monitorIndex);
    }

    /// <summary>
    /// Gets a VCP feature value
    /// </summary>
    public (uint currentValue, uint maximumValue) GetVcpFeature(byte vcpCode, int monitorIndex = 0)
    {
        ValidateMonitorIndex(monitorIndex);

        return WithPhysicalMonitor(monitorIndex, pm =>
        {
            if (!NativeMethods.GetVCPFeatureAndVCPFeatureReply(
                pm.hPhysicalMonitor,
                vcpCode,
                out _,
                out uint currentValue,
                out uint maximumValue))
            {
                throw CreateWin32Exception($"Could not retrieve VCP feature 0x{vcpCode:X2}");
            }

            return (currentValue, maximumValue);
        });
    }

    /// <summary>
    /// Sets a VCP feature value with retry logic
    /// </summary>
    public void SetVcpFeature(byte vcpCode, uint value, int monitorIndex = 0, int maxRetries = 5)
    {
        ValidateMonitorIndex(monitorIndex);

        WithPhysicalMonitor(monitorIndex, pm =>
        {
            // Retry logic - monitor might be busy/switching modes
            int lastError = 0;
            for (int attempt = 1; attempt <= maxRetries; attempt++)
            {
                if (NativeMethods.SetVCPFeature(pm.hPhysicalMonitor, vcpCode, value))
                    return true;

                lastError = Marshal.GetLastPInvokeError();

                if (attempt < maxRetries)
                {
                    Thread.Sleep(1000); // Wait 1 second before retry
                }
            }

            throw CreateWin32Exception(
                $"Failed to set VCP feature 0x{vcpCode:X2} after {maxRetries} attempts", lastError);
        });
    }

    private void ValidateMonitorIndex(int monitorIndex)
    {
        if (monitorIndex < 0 || monitorIndex >= _monitors.Count)
            throw new ArgumentOutOfRangeException(nameof(monitorIndex), "Invalid monitor index");
    }

    /// <summary>
    /// Resolves the physical monitor for a logical monitor index, runs <paramref name="action"/>
    /// on it and always releases all physical monitor handles afterwards.
    /// </summary>
    private T WithPhysicalMonitor<T>(int monitorIndex, Func<NativeMethods.PhysicalMonitor, T> action)
    {
        IntPtr monitorHandle = GetMonitorHandle(monitorIndex);
        if (monitorHandle == IntPtr.Zero)
            throw new InvalidOperationException($"Could not get monitor handle for monitor {monitorIndex}");

        return WithPhysicalMonitor(monitorHandle, action);
    }

    private static T WithPhysicalMonitor<T>(IntPtr monitorHandle, Func<NativeMethods.PhysicalMonitor, T> action)
    {
        if (!NativeMethods.GetNumberOfPhysicalMonitorsFromHMONITOR(monitorHandle, out uint monitorCount))
            throw CreateWin32Exception("Could not get number of physical monitors");

        if (monitorCount == 0)
            throw new InvalidOperationException("No physical monitor found for this display");

        var physicalMonitors = new NativeMethods.PhysicalMonitor[monitorCount];
        if (!NativeMethods.GetPhysicalMonitorsFromHMONITOR(monitorHandle, monitorCount, physicalMonitors))
            throw CreateWin32Exception("Could not get physical monitor handles");

        try
        {
            return action(physicalMonitors[0]);
        }
        finally
        {
            foreach (var pm in physicalMonitors)
            {
                NativeMethods.DestroyPhysicalMonitor(pm.hPhysicalMonitor);
            }
        }
    }

    /// <summary>
    /// Creates an exception that includes the Win32 error of the last failed P/Invoke call.
    /// Must be called directly after the failing call.
    /// </summary>
    private static InvalidOperationException CreateWin32Exception(string message)
        => CreateWin32Exception(message, Marshal.GetLastPInvokeError());

    private static InvalidOperationException CreateWin32Exception(string message, int win32Error)
    {
        if (win32Error == 0)
            return new InvalidOperationException(message);

        var inner = new Win32Exception(win32Error);
        return new InvalidOperationException($"{message} (Win32 error 0x{win32Error:X8}: {inner.Message})", inner);
    }

    [System.Runtime.Versioning.SupportedOSPlatform("windows")]
    private void EnumerateMonitors()
    {
        _monitors.Clear();
        _detailsLoaded = false;
        int index = 0;

        NativeMethods.MonitorEnumProc callback = (IntPtr hMonitor, IntPtr hdcMonitor, ref NativeMethods.Rect lprcMonitor, IntPtr dwData) =>
        {
            var monitorInfo = new NativeMethods.MonitorInfoEx
            {
                cbSize = (uint)Marshal.SizeOf(typeof(NativeMethods.MonitorInfoEx))
            };

            if (NativeMethods.GetMonitorInfo(hMonitor, ref monitorInfo))
            {
                _monitors.Add(new MonitorInfo
                {
                    Index = index++,
                    DeviceName = monitorInfo.szDevice,
                    Width = monitorInfo.rcMonitor.Right - monitorInfo.rcMonitor.Left,
                    Height = monitorInfo.rcMonitor.Bottom - monitorInfo.rcMonitor.Top,
                    IsPrimary = (monitorInfo.dwFlags & NativeMethods.MONITORINFOF_PRIMARY) != 0
                });
            }

            return true;
        };

        NativeMethods.EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, callback, IntPtr.Zero);
    }

    [System.Runtime.Versioning.SupportedOSPlatform("windows")]
    private void EnsureDetailsLoaded()
    {
        if (_detailsLoaded)
            return;

        List<WmiMonitorData> wmiMonitors;
        try
        {
            wmiMonitors = ReadWmiMonitors();
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Could not read WMI monitor data: {ex}");
            wmiMonitors = new List<WmiMonitorData>();
        }

        for (int i = 0; i < _monitors.Count; i++)
        {
            try
            {
                var hMonitor = GetMonitorHandle(i);
                if (hMonitor == IntPtr.Zero)
                    throw new InvalidOperationException("Monitor handle not found");

                EnrichMonitorInfo(_monitors[i], hMonitor, wmiMonitors);
            }
            catch (Exception ex)
            {
                // Continue even if enrichment fails
                Debug.WriteLine($"Could not enrich monitor {_monitors[i].DeviceName}: {ex}");
            }
        }

        _detailsLoaded = true;
    }

    [System.Runtime.Versioning.SupportedOSPlatform("windows")]
    private void EnrichMonitorInfo(MonitorInfo monitor, IntPtr hMonitor, List<WmiMonitorData> wmiMonitors)
    {
        // Assign the WMI entry belonging to this display (by device instance path)
        var wmi = FindWmiMonitor(monitor.DeviceName, wmiMonitors);
        if (wmi != null)
        {
            wmiMonitors.Remove(wmi);
            monitor.Manufacturer = wmi.Manufacturer;
            monitor.SerialNumber = wmi.SerialNumber;
            monitor.Model = wmi.Model;
            monitor.WeekOfManufacture = wmi.WeekOfManufacture;
            monitor.YearOfManufacture = wmi.YearOfManufacture;
        }

        WithPhysicalMonitor(hMonitor, physicalMonitor =>
        {
            // Set description from physical monitor
            monitor.Description = physicalMonitor.szPhysicalMonitorDescription;

            // If Model is still empty, use description
            if (string.IsNullOrEmpty(monitor.Model))
                monitor.Model = monitor.Description;

            // Try to get brightness
            if (NativeMethods.GetMonitorBrightness(
                physicalMonitor.hPhysicalMonitor,
                out _,
                out uint currentBrightness,
                out _))
            {
                monitor.Brightness = (int)currentBrightness;
            }
            else
            {
                Debug.WriteLine($"Could not read brightness for {monitor.DeviceName}: Win32 error 0x{Marshal.GetLastPInvokeError():X8}");
            }

            // Try to get firmware version
            try
            {
                var (fwValue, _) = GetVcpFeatureRaw(physicalMonitor.hPhysicalMonitor, (byte)VcpCode.Firmware);
                if (fwValue != 0)
                {
                    monitor.Firmware = $"{(fwValue & 0x7FF):x}";
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Could not read firmware version for {monitor.DeviceName}: {ex.Message}");
            }

            return true;
        });
    }

    /// <summary>
    /// Finds the WmiMonitorID entry for a display device (e.g. \\.\DISPLAY1).
    /// The device interface path (\\?\DISPLAY#HwId#InstanceId#{Guid}) is mapped to the
    /// WMI instance name DISPLAY\HwId\InstanceId (optionally with the suffix _0).
    /// </summary>
    private static WmiMonitorData? FindWmiMonitor(string deviceName, List<WmiMonitorData> wmiMonitors)
    {
        var instanceName = GetWmiInstanceName(deviceName);
        if (instanceName == null)
        {
            Debug.WriteLine($"Could not determine device path for {deviceName}");
            return null;
        }

        return wmiMonitors.FirstOrDefault(w => string.Equals(w.InstanceName, instanceName, StringComparison.OrdinalIgnoreCase))
            ?? wmiMonitors.FirstOrDefault(w => string.Equals(w.InstanceName, instanceName + "_0", StringComparison.OrdinalIgnoreCase));
    }

    private static string? GetWmiInstanceName(string deviceName)
    {
        var device = new NativeMethods.DisplayDevice { cb = Marshal.SizeOf<NativeMethods.DisplayDevice>() };
        if (!NativeMethods.EnumDisplayDevices(deviceName, 0, ref device, NativeMethods.EDD_GET_DEVICE_INTERFACE_NAME))
            return null;

        return ConvertDevicePathToWmiInstanceName(device.DeviceID);
    }

    /// <summary>
    /// Converts a device interface path (\\?\DISPLAY#DELA1A6#5&amp;1234&amp;0&amp;UID4352#{guid})
    /// to a WMI instance name (DISPLAY\DELA1A6\5&amp;1234&amp;0&amp;UID4352).
    /// </summary>
    internal static string? ConvertDevicePathToWmiInstanceName(string? devicePath)
    {
        if (string.IsNullOrEmpty(devicePath) || !devicePath.StartsWith(@"\\?\", StringComparison.Ordinal))
            return null;

        var parts = devicePath.Split('#');
        if (parts.Length < 3)
            return null;

        return $@"DISPLAY\{parts[1]}\{parts[2]}";
    }

    [System.Runtime.Versioning.SupportedOSPlatform("windows")]
    private static List<WmiMonitorData> ReadWmiMonitors()
    {
        var result = new List<WmiMonitorData>();
        using var searcher = new ManagementObjectSearcher("root\\WMI", "SELECT * FROM WmiMonitorID");
        foreach (ManagementObject obj in searcher.Get())
        {
            try
            {
                result.Add(new WmiMonitorData
                {
                    InstanceName = obj["InstanceName"] as string ?? string.Empty,
                    Manufacturer = ConvertWmiString(obj["ManufacturerName"]),
                    SerialNumber = ConvertWmiString(obj["SerialNumberID"]),
                    Model = ConvertWmiString(obj["UserFriendlyName"]),
                    WeekOfManufacture = ConvertWmiNumber(obj["WeekOfManufacture"]),
                    YearOfManufacture = ConvertWmiNumber(obj["YearOfManufacture"])
                });
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Could not read WmiMonitorID entry: {ex.Message}");
            }
        }

        return result;
    }

    private static string ConvertWmiString(object? value)
    {
        if (value is not ushort[] data || data.Length == 0)
            return string.Empty;

        return new string(data.Where(x => x != 0).Select(x => (char)x).ToArray()).Trim();
    }

    private static int? ConvertWmiNumber(object? value)
    {
        if (value == null)
            return null;

        var number = Convert.ToInt32(value);
        return number > 0 ? number : null;
    }

    private sealed class WmiMonitorData
    {
        public string InstanceName { get; init; } = string.Empty;
        public string Manufacturer { get; init; } = string.Empty;
        public string SerialNumber { get; init; } = string.Empty;
        public string Model { get; init; } = string.Empty;
        public int? WeekOfManufacture { get; init; }
        public int? YearOfManufacture { get; init; }
    }

    private (uint current, uint max) GetVcpFeatureRaw(IntPtr hPhysicalMonitor, byte vcpCode)
    {
        if (!NativeMethods.GetVCPFeatureAndVCPFeatureReply(
            hPhysicalMonitor,
            vcpCode,
            out uint _,
            out uint currentValue,
            out uint maxValue))
        {
            throw CreateWin32Exception($"Could not retrieve VCP feature 0x{vcpCode:X2}");
        }
        return (currentValue, maxValue);
    }

    private int GetMonitorBrightness(MonitorInfo monitor)
    {
        return WithPhysicalMonitor(monitor.Index, pm =>
        {
            if (!NativeMethods.GetMonitorBrightness(
                pm.hPhysicalMonitor,
                out _,
                out uint currentBrightness,
                out _))
            {
                throw CreateWin32Exception("Could not retrieve monitor brightness");
            }

            return (int)currentBrightness;
        });
    }

    private void SetMonitorBrightness(MonitorInfo monitor, int brightness)
    {
        WithPhysicalMonitor(monitor.Index, pm =>
        {
            if (!NativeMethods.SetMonitorBrightness(pm.hPhysicalMonitor, (uint)brightness))
            {
                throw CreateWin32Exception("Failed to set monitor brightness");
            }

            return true;
        });
    }

    /// <summary>
    /// Resolves the HMONITOR for an index. The handle is looked up on every call because Windows
    /// re-creates it when the display is re-enumerated (e.g. after switching PBP, which changes the EDID).
    /// </summary>
    private IntPtr GetMonitorHandle(int index)
    {
        IntPtr result = IntPtr.Zero;
        int currentIndex = 0;

        NativeMethods.MonitorEnumProc callback = (IntPtr hMonitor, IntPtr hdcMonitor, ref NativeMethods.Rect lprcMonitor, IntPtr dwData) =>
        {
            if (currentIndex == index)
            {
                result = hMonitor;
                return false; // Stop enumeration
            }
            currentIndex++;
            return true;
        };

        NativeMethods.EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, callback, IntPtr.Zero);
        return result;
    }
}
