try { $null = [PSMonitorToolsHelper].Name } catch {
    Add-Type -TypeDefinition @"
using System; using System.Collections.Generic; using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
public struct PhysicalMonitor {
    public IntPtr Handle;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)]
    public string Description;
}

public delegate bool MonitorEnumDelegate(IntPtr hMonitor, IntPtr hdcMonitor, IntPtr lprcMonitor, IntPtr dwData);

public static class PSMonitorToolsHelper {
    [DllImport("user32")]
    public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumDelegate lpfnEnum, IntPtr dwData);

    [DllImport("dxva2")]
    public static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, out uint pdwNumberOfPhysicalMonitors);

    [DllImport("dxva2")]
    public static extern bool GetPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, uint dwPhysicalMonitorArraySize, [Out] PhysicalMonitor[] pPhysicalMonitorArray);

    [DllImport("dxva2")]
    public static extern bool DestroyPhysicalMonitors(uint dwPhysicalMonitorArraySize, [In] PhysicalMonitor[] pPhysicalMonitorArray);

    [DllImport("dxva2")]
    static extern bool GetVCPFeatureAndVCPFeatureReply(IntPtr hMonitor, byte bVCPCode, out uint pvct, out uint pdwCurrentValue, out uint pdwMaximumValue);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool SetVCPFeature(IntPtr hMonitor, byte bVCPCode, uint dwNewValue);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool GetCapabilitiesStringLength(IntPtr hMonitor, out uint pdwCapabilitiesStringLengthInCharacters);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool CapabilitiesRequestAndCapabilitiesReply(IntPtr hMonitor, System.Text.StringBuilder pszASCIICapabilitiesString, uint dwCapabilitiesStringLengthInCharacters);

    public static string GetMonitorCapabilities(IntPtr hMonitor) {
        uint length;
        if (GetCapabilitiesStringLength(hMonitor, out length)) {
            var sb = new System.Text.StringBuilder((int)length);
            if (CapabilitiesRequestAndCapabilitiesReply(hMonitor, sb, length)) {
                return sb.ToString();
            }
        }
        return null;
    }

    public static bool GetVcpFeature(IntPtr hMonitor, byte vcpCode, out uint currentValue, out uint maximumValue) {
        uint type;
        return GetVCPFeatureAndVCPFeatureReply(hMonitor, vcpCode, out type, out currentValue, out maximumValue);
    }

    public static IntPtr[] GetMonitorHandles() {
        var handles = new List<IntPtr>();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (hMonitor, hdcMonitor, lprcMonitor, dwData) => {
            handles.Add(hMonitor);
            return true;
        }, IntPtr.Zero);
        return handles.ToArray();
    }

    public static PhysicalMonitor[] GetPhysicalMonitors(IntPtr hMonitor) {
        uint count;
        GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor, out count);
        var monitors = new PhysicalMonitor[count];
        if (count > 0) {
            GetPhysicalMonitorsFromHMONITOR(hMonitor, count, monitors);
        }
        return monitors;
    }
}
"@
}
