using System.Runtime.InteropServices;
using MonitorTools.Core.Interfaces;

namespace MonitorTools.Core;

/// <summary>
/// Service for retrieving monitor information and controlling brightness
/// </summary>
public class MonitorService : IMonitorService
{
    private readonly List<MonitorInfo> _monitors = new();

    public MonitorService()
    {
        EnumerateMonitors();
    }

    /// <summary>
    /// Gets information about all connected monitors
    /// </summary>
    public MonitorInfo[] GetMonitors()
    {
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
        return (MonitorInput)current;
    }

    /// <summary>
    /// Sets the input source of a specific monitor
    /// </summary>
    public void SetInput(MonitorInput input, int monitorIndex = 0)
    {
        SetVcpFeature(VcpCode.InputSource, (uint)input, monitorIndex);
    }

    /// <summary>
    /// Gets a VCP feature value
    /// </summary>
    public (uint currentValue, uint maximumValue) GetVcpFeature(byte vcpCode, int monitorIndex = 0)
    {
        if (monitorIndex < 0 || monitorIndex >= _monitors.Count)
            throw new ArgumentOutOfRangeException(nameof(monitorIndex), "Invalid monitor index");

        IntPtr monitorHandle = GetMonitorHandle(monitorIndex);
        if (monitorHandle == IntPtr.Zero)
            throw new InvalidOperationException("Could not get monitor handle");

        if (NativeMethods.GetNumberOfPhysicalMonitorsFromHMONITOR(monitorHandle, out uint monitorCount) && monitorCount > 0)
        {
            var physicalMonitors = new NativeMethods.PhysicalMonitor[monitorCount];
            if (NativeMethods.GetPhysicalMonitorsFromHMONITOR(monitorHandle, monitorCount, physicalMonitors))
            {
                try
                {
                    if (NativeMethods.GetVCPFeatureAndVCPFeatureReply(
                        physicalMonitors[0].hPhysicalMonitor,
                        vcpCode,
                        out _,
                        out uint currentValue,
                        out uint maximumValue))
                    {
                        return (currentValue, maximumValue);
                    }
                }
                finally
                {
                    foreach (var pm in physicalMonitors)
                    {
                        NativeMethods.DestroyPhysicalMonitor(pm.hPhysicalMonitor);
                    }
                }
            }
        }

        throw new InvalidOperationException($"Could not retrieve VCP feature 0x{vcpCode:X2}");
    }

    /// <summary>
    /// Sets a VCP feature value
    /// </summary>
    public void SetVcpFeature(byte vcpCode, uint value, int monitorIndex = 0)
    {
        if (monitorIndex < 0 || monitorIndex >= _monitors.Count)
            throw new ArgumentOutOfRangeException(nameof(monitorIndex), "Invalid monitor index");

        IntPtr monitorHandle = GetMonitorHandle(monitorIndex);
        if (monitorHandle == IntPtr.Zero)
            throw new InvalidOperationException("Could not get monitor handle");

        if (NativeMethods.GetNumberOfPhysicalMonitorsFromHMONITOR(monitorHandle, out uint monitorCount) && monitorCount > 0)
        {
            var physicalMonitors = new NativeMethods.PhysicalMonitor[monitorCount];
            if (NativeMethods.GetPhysicalMonitorsFromHMONITOR(monitorHandle, monitorCount, physicalMonitors))
            {
                try
                {
                    if (!NativeMethods.SetVCPFeature(physicalMonitors[0].hPhysicalMonitor, vcpCode, value))
                    {
                        throw new InvalidOperationException($"Failed to set VCP feature 0x{vcpCode:X2}");
                    }
                }
                finally
                {
                    foreach (var pm in physicalMonitors)
                    {
                        NativeMethods.DestroyPhysicalMonitor(pm.hPhysicalMonitor);
                    }
                }
            }
        }
    }

    private void EnumerateMonitors()
    {
        _monitors.Clear();
        int index = 0;

        NativeMethods.MonitorEnumProc callback = (IntPtr hMonitor, IntPtr hdcMonitor, ref NativeMethods.Rect lprcMonitor, IntPtr dwData) =>
        {
            var monitorInfo = new NativeMethods.MonitorInfoEx
            {
                cbSize = (uint)Marshal.SizeOf(typeof(NativeMethods.MonitorInfoEx))
            };

            if (NativeMethods.GetMonitorInfo(hMonitor, ref monitorInfo))
            {
                var monitor = new MonitorInfo
                {
                    Index = index++,
                    DeviceName = monitorInfo.szDevice,
                    Width = monitorInfo.rcMonitor.Right - monitorInfo.rcMonitor.Left,
                    Height = monitorInfo.rcMonitor.Bottom - monitorInfo.rcMonitor.Top,
                    IsPrimary = (monitorInfo.dwFlags & NativeMethods.MONITORINFOF_PRIMARY) != 0
                };

                // Try to get additional information
                try
                {
                    EnrichMonitorInfo(monitor, hMonitor);
                }
                catch
                {
                    // Continue even if enrichment fails
                }

                _monitors.Add(monitor);
            }

            return true;
        };

        NativeMethods.EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, callback, IntPtr.Zero);
    }

    private void EnrichMonitorInfo(MonitorInfo monitor, IntPtr hMonitor)
    {
        if (NativeMethods.GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor, out uint monitorCount))
        {
            if (monitorCount > 0)
            {
                var physicalMonitors = new NativeMethods.PhysicalMonitor[monitorCount];
                if (NativeMethods.GetPhysicalMonitorsFromHMONITOR(hMonitor, monitorCount, physicalMonitors))
                {
                    // Use first physical monitor
                    monitor.Model = physicalMonitors[0].szPhysicalMonitorDescription;

                    // Try to get brightness
                    try
                    {
                        if (NativeMethods.GetMonitorBrightness(
                            physicalMonitors[0].hPhysicalMonitor,
                            out _,
                            out uint currentBrightness,
                            out _))
                        {
                            monitor.Brightness = (int)currentBrightness;
                        }
                    }
                    catch { }

                    // Cleanup
                    foreach (var pm in physicalMonitors)
                    {
                        NativeMethods.DestroyPhysicalMonitor(pm.hPhysicalMonitor);
                    }
                }
            }
        }
    }

    private int GetMonitorBrightness(MonitorInfo monitor)
    {
        // Re-enumerate to get handle
        IntPtr monitorHandle = GetMonitorHandle(monitor.Index);
        if (monitorHandle == IntPtr.Zero)
            throw new InvalidOperationException("Could not get monitor handle");

        if (NativeMethods.GetNumberOfPhysicalMonitorsFromHMONITOR(monitorHandle, out uint monitorCount) && monitorCount > 0)
        {
            var physicalMonitors = new NativeMethods.PhysicalMonitor[monitorCount];
            if (NativeMethods.GetPhysicalMonitorsFromHMONITOR(monitorHandle, monitorCount, physicalMonitors))
            {
                try
                {
                    if (NativeMethods.GetMonitorBrightness(
                        physicalMonitors[0].hPhysicalMonitor,
                        out _,
                        out uint currentBrightness,
                        out _))
                    {
                        return (int)currentBrightness;
                    }
                }
                finally
                {
                    foreach (var pm in physicalMonitors)
                    {
                        NativeMethods.DestroyPhysicalMonitor(pm.hPhysicalMonitor);
                    }
                }
            }
        }

        throw new InvalidOperationException("Could not retrieve monitor brightness");
    }

    private void SetMonitorBrightness(MonitorInfo monitor, int brightness)
    {
        IntPtr monitorHandle = GetMonitorHandle(monitor.Index);
        if (monitorHandle == IntPtr.Zero)
            throw new InvalidOperationException("Could not get monitor handle");

        if (NativeMethods.GetNumberOfPhysicalMonitorsFromHMONITOR(monitorHandle, out uint monitorCount) && monitorCount > 0)
        {
            var physicalMonitors = new NativeMethods.PhysicalMonitor[monitorCount];
            if (NativeMethods.GetPhysicalMonitorsFromHMONITOR(monitorHandle, monitorCount, physicalMonitors))
            {
                try
                {
                    if (!NativeMethods.SetMonitorBrightness(physicalMonitors[0].hPhysicalMonitor, (uint)brightness))
                    {
                        throw new InvalidOperationException("Failed to set monitor brightness");
                    }
                }
                finally
                {
                    foreach (var pm in physicalMonitors)
                    {
                        NativeMethods.DestroyPhysicalMonitor(pm.hPhysicalMonitor);
                    }
                }
            }
        }
    }

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
