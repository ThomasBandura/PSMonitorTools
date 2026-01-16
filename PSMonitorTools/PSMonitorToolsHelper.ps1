try { $null = [PSMonitorToolsHelper].Name } catch {
    Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

[StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
public struct PhysicalMonitor {
    public IntPtr Handle;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)]
    public string Description;
}

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct MONITORINFOEX
{
    public int cbSize;
    public RECT rcMonitor;
    public RECT rcWork;
    public int dwFlags;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
    public string szDevice;
}

[StructLayout(LayoutKind.Sequential)]
public struct RECT
{
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct DISPLAY_DEVICE
{
    public int cb;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
    public string DeviceName;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
    public string DeviceString;
    public int StateFlags;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
    public string DeviceID;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
    public string DeviceKey;
}

public delegate bool MonitorEnumDelegate(IntPtr hMonitor, IntPtr hdcMonitor, IntPtr lprcMonitor, IntPtr dwData);

public static class PSMonitorToolsHelper {
    [DllImport("user32.dll")]
    public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumDelegate lpfnEnum, IntPtr dwData);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFOEX lpmi);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, out uint pdwNumberOfPhysicalMonitors);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool GetPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, uint dwPhysicalMonitorArraySize, [Out] PhysicalMonitor[] pPhysicalMonitorArray);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool DestroyPhysicalMonitors(uint dwPhysicalMonitorArraySize, [In] PhysicalMonitor[] pPhysicalMonitorArray);

    [DllImport("dxva2.dll", SetLastError = true)]
    private static extern bool GetVCPFeatureAndVCPFeatureReply(IntPtr hMonitor, byte bVCPCode, out uint pvct, out uint pdwCurrentValue, out uint pdwMaximumValue);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool SetVCPFeature(IntPtr hMonitor, byte bVCPCode, uint dwNewValue);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool GetCapabilitiesStringLength(IntPtr hMonitor, out uint pdwCapabilitiesStringLengthInCharacters);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool CapabilitiesRequestAndCapabilitiesReply(IntPtr hMonitor, StringBuilder pszASCIICapabilitiesString, uint dwCapabilitiesStringLengthInCharacters);

    // --- Helper Methoden ---

    public static string GetMonitorCapabilities(IntPtr hMonitor) {
        uint length;
        if (GetCapabilitiesStringLength(hMonitor, out length)) {
            StringBuilder sb = new StringBuilder((int)length);
            if (CapabilitiesRequestAndCapabilitiesReply(hMonitor, sb, length)) {
                return sb.ToString();
            }
        }
        return null;
    }

    public static string GetMonitorDevicePath(IntPtr hMonitor) {
        MONITORINFOEX mi = new MONITORINFOEX();
        mi.cbSize = Marshal.SizeOf(mi);
        if (GetMonitorInfo(hMonitor, ref mi)) {
            DISPLAY_DEVICE dd = new DISPLAY_DEVICE();
            dd.cb = Marshal.SizeOf(dd);
            // 0x1 = EDD_GET_DEVICE_INTERFACE_NAME
            if (EnumDisplayDevices(mi.szDevice, 0, ref dd, 0x1)) {
                return dd.DeviceID;
            }
             // Fallback to default if interface name fails (though unlikely for active monitors)
            if (EnumDisplayDevices(mi.szDevice, 0, ref dd, 0)) {
                return dd.DeviceID;
            }
        }
        return null;
    }

    public static bool GetVcpFeature(IntPtr hMonitor, byte vcpCode, out uint currentValue, out uint maximumValue) {
        uint type;
        return GetVCPFeatureAndVCPFeatureReply(hMonitor, vcpCode, out type, out currentValue, out maximumValue);
    }

    public static IntPtr[] GetMonitorHandles() {
        List<IntPtr> handles = new List<IntPtr>();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (hMonitor, hdcMonitor, lprcMonitor, dwData) => {
            handles.Add(hMonitor);
            return true;
        }, IntPtr.Zero);
        return handles.ToArray();
    }

    public static PhysicalMonitor[] GetPhysicalMonitors(IntPtr hMonitor) {
        uint count;
        if (!GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor, out count) || count == 0) {
            return new PhysicalMonitor[0];
        }

        PhysicalMonitor[] monitors = new PhysicalMonitor[count];
        if (!GetPhysicalMonitorsFromHMONITOR(hMonitor, count, monitors)) {
            return new PhysicalMonitor[0];
        }
        return monitors;
    }
}
"@
}
