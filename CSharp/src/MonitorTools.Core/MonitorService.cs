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
    /// Sets a VCP feature value with retry logic
    /// </summary>
    public void SetVcpFeature(byte vcpCode, uint value, int monitorIndex = 0, int maxRetries = 5)
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
                    // Retry logic - monitor might be busy/switching modes
                    bool success = false;
                    for (int attempt = 1; attempt <= maxRetries; attempt++)
                    {
                        if (NativeMethods.SetVCPFeature(physicalMonitors[0].hPhysicalMonitor, vcpCode, value))
                        {
                            success = true;
                            break;
                        }
                        
                        if (attempt < maxRetries)
                        {
                            Thread.Sleep(1000); // Wait 1 second before retry
                        }
                    }
                    
                    if (!success)
                    {
                        throw new InvalidOperationException($"Failed to set VCP feature 0x{vcpCode:X2} after {maxRetries} attempts");
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

    [System.Runtime.Versioning.SupportedOSPlatform("windows")]
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

    [System.Runtime.Versioning.SupportedOSPlatform("windows")]
    private void EnrichMonitorInfo(MonitorInfo monitor, IntPtr hMonitor)
    {
        if (NativeMethods.GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor, out uint monitorCount))
        {
            if (monitorCount > 0)
            {
                var physicalMonitors = new NativeMethods.PhysicalMonitor[monitorCount];
                if (NativeMethods.GetPhysicalMonitorsFromHMONITOR(hMonitor, monitorCount, physicalMonitors))
                {
                    var physicalMonitor = physicalMonitors[0];
                    
                    // Set description from physical monitor
                    monitor.Description = physicalMonitor.szPhysicalMonitorDescription;
                    
                    // Try to get WMI information
                    try
                    {
                        EnrichFromWmi(monitor);
                    }
                    catch { }
                    
                    // If Model is still empty, use description
                    if (string.IsNullOrEmpty(monitor.Model))
                        monitor.Model = monitor.Description;

                    // Try to get brightness
                    try
                    {
                        if (NativeMethods.GetMonitorBrightness(
                            physicalMonitor.hPhysicalMonitor,
                            out _,
                            out uint currentBrightness,
                            out _))
                        {
                            monitor.Brightness = (int)currentBrightness;
                        }
                    }
                    catch { }
                    
                    // Try to get firmware version
                    try
                    {
                        var (fwValue, _) = GetVcpFeatureRaw(physicalMonitor.hPhysicalMonitor, (byte)VcpCode.Firmware);
                        if (fwValue != 0)
                        {
                            monitor.Firmware = $"{(fwValue & 0x7FF):x}";
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
    
    [System.Runtime.Versioning.SupportedOSPlatform("windows")]
    private void EnrichFromWmi(MonitorInfo monitor)
    {
        using var searcher = new ManagementObjectSearcher("root\\WMI", "SELECT * FROM WmiMonitorID");
        foreach (ManagementObject obj in searcher.Get())
        {
            try
            {
                // Get manufacturer name
                if (obj["ManufacturerName"] is ushort[] manuData && manuData.Length > 0)
                {
                    var manuName = new string(manuData.Where(x => x != 0).Select(x => (char)x).ToArray()).Trim();
                    if (!string.IsNullOrEmpty(manuName) && string.IsNullOrEmpty(monitor.Manufacturer))
                        monitor.Manufacturer = manuName;
                }
                
                // Get serial number
                if (obj["SerialNumberID"] is ushort[] serialData && serialData.Length > 0)
                {
                    var serial = new string(serialData.Where(x => x != 0).Select(x => (char)x).ToArray()).Trim();
                    if (!string.IsNullOrEmpty(serial) && string.IsNullOrEmpty(monitor.SerialNumber))
                        monitor.SerialNumber = serial;
                }
                
                // Get user-friendly name (model)
                if (obj["UserFriendlyName"] is ushort[] nameData && nameData.Length > 0)
                {
                    var model = new string(nameData.Where(x => x != 0).Select(x => (char)x).ToArray()).Trim();
                    if (!string.IsNullOrEmpty(model))
                        monitor.Model = model;
                }
                
                // Get week and year of manufacture  
                try
                {
                    if (obj["WeekOfManufacture"] != null)
                    {
                        var week = Convert.ToUInt16(obj["WeekOfManufacture"]);
                        if (week > 0)
                            monitor.WeekOfManufacture = week;
                    }
                }
                catch { }
                
                try
                {
                    if (obj["YearOfManufacture"] != null)
                    {
                        var year = Convert.ToUInt16(obj["YearOfManufacture"]);
                        if (year > 0)
                            monitor.YearOfManufacture = year;
                    }
                }
                catch { }
                
                // Usually only one monitor match, but we take the first one
                break;
            }
            catch { }
        }
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
            throw new InvalidOperationException($"Could not retrieve VCP feature 0x{vcpCode:X2}");
        }
        return (currentValue, maxValue);
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
