using System.CommandLine;
using MonitorTools.Core;

namespace MonitorTools.CLI.Commands;

/// <summary>
/// Command to get and set VCP features
/// </summary>
[System.Runtime.Versioning.SupportedOSPlatform("windows")]
public static class VcpCommand
{
    public static Command Create()
    {
        var command = new Command("vcp", "Get or set VCP feature codes");

        // Get VCP feature subcommand
        var getCommand = new Command("get", "Get VCP feature value");
        var getCodeArgument = new Argument<string>(
            name: "code",
            description: "VCP code in hex (e.g., 0x10 or 10)");
        var getMonitorOption = new Option<int>(
            aliases: new[] { "--monitor", "-m" },
            getDefaultValue: () => 0,
            description: "Monitor index (0-based, default: 0)");
        getCommand.AddArgument(getCodeArgument);
        getCommand.AddOption(getMonitorOption);
        getCommand.SetHandler((codeStr, monitorIndex) =>
        {
            try
            {
                byte code = ParseVcpCode(codeStr);
                var service = new MonitorService();
                var (current, maximum) = service.GetVcpFeature(code, monitorIndex);
                
                Console.WriteLine($"Monitor {monitorIndex} VCP 0x{code:X2}:");
                Console.WriteLine($"  Current: {current}");
                Console.WriteLine($"  Maximum: {maximum}");
            }
            catch (FormatException ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, getCodeArgument, getMonitorOption);

        // Set VCP feature subcommand
        var setCommand = new Command("set", "Set VCP feature value");
        var setCodeArgument = new Argument<string>(
            name: "code",
            description: "VCP code in hex (e.g., 0x10 or 10)");
        var valueArgument = new Argument<uint>(
            name: "value",
            description: "Value to set");
        var setMonitorOption = new Option<int>(
            aliases: new[] { "--monitor", "-m" },
            getDefaultValue: () => 0,
            description: "Monitor index (0-based, default: 0)");
        setCommand.AddArgument(setCodeArgument);
        setCommand.AddArgument(valueArgument);
        setCommand.AddOption(setMonitorOption);
        setCommand.SetHandler((codeStr, value, monitorIndex) =>
        {
            try
            {
                byte code = ParseVcpCode(codeStr);
                var service = new MonitorService();
                service.SetVcpFeature(code, value, monitorIndex);
                
                Console.WriteLine($"Monitor {monitorIndex} VCP 0x{code:X2} set to {value}");
            }
            catch (FormatException ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, setCodeArgument, valueArgument, setMonitorOption);

        command.AddCommand(getCommand);
        command.AddCommand(setCommand);

        return command;
    }

    private static byte ParseVcpCode(string codeStr)
    {
        codeStr = codeStr.Trim();
        
        // Handle 0x prefix
        if (codeStr.StartsWith("0x", StringComparison.OrdinalIgnoreCase))
        {
            codeStr = codeStr.Substring(2);
        }

        if (byte.TryParse(codeStr, System.Globalization.NumberStyles.HexNumber, null, out byte code))
        {
            return code;
        }

        throw new FormatException($"Invalid VCP code format: {codeStr}. Use hex format like 0x10 or 10");
    }
}
