using System.CommandLine;
using System.Globalization;
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
        var getCodeArgument = CreateCodeArgument();
        var getMonitorOption = CliCommon.CreateMonitorOption();
        getCommand.Arguments.Add(getCodeArgument);
        getCommand.Options.Add(getMonitorOption);
        getCommand.SetAction(parseResult => CliCommon.Run(() =>
        {
            byte code = ParseVcpCode(parseResult.GetValue(getCodeArgument));
            int monitorIndex = parseResult.GetValue(getMonitorOption);

            var service = CliCommon.CreateService();
            var (current, maximum) = service.GetVcpFeature(code, monitorIndex);

            Console.WriteLine($"Monitor {monitorIndex} VCP 0x{code:X2}:");
            Console.WriteLine($"  Current: {current}");
            Console.WriteLine($"  Maximum: {maximum}");
            return CliCommon.Success;
        }));

        // Set VCP feature subcommand
        var setCommand = new Command("set", "Set VCP feature value");
        var setCodeArgument = CreateCodeArgument();
        var valueArgument = new Argument<string>("value")
        {
            Description = "Value to set, decimal or hex with 0x prefix (e.g., 50 or 0xF12)"
        };
        var setMonitorOption = CliCommon.CreateMonitorOption();
        var forceOption = new Option<bool>("--force", "-f")
        {
            Description = "Required for critical codes that reset settings or change the power state (0x04, 0x05, 0x06, 0x08, 0x0A, 0xB0, 0xD6)"
        };
        setCommand.Arguments.Add(setCodeArgument);
        setCommand.Arguments.Add(valueArgument);
        setCommand.Options.Add(setMonitorOption);
        setCommand.Options.Add(forceOption);
        setCommand.SetAction(parseResult => CliCommon.Run(() =>
        {
            byte code = ParseVcpCode(parseResult.GetValue(setCodeArgument));
            uint value = ParseVcpValue(parseResult.GetValue(valueArgument));
            int monitorIndex = parseResult.GetValue(setMonitorOption);

            if (VcpCode.IsCritical(code) && !parseResult.GetValue(forceOption))
            {
                return CliCommon.Fail(
                    $"VCP 0x{code:X2} ({VcpCode.CriticalCodes[code]}) can reset monitor settings or change its power state.",
                    "Use --force to write it anyway.");
            }

            var service = CliCommon.CreateService();
            service.SetVcpFeature(code, value, monitorIndex);

            Console.WriteLine($"Monitor {monitorIndex} VCP 0x{code:X2} set to {value}");
            return CliCommon.Success;
        }));

        command.Subcommands.Add(getCommand);
        command.Subcommands.Add(setCommand);

        return command;
    }

    private static Argument<string> CreateCodeArgument() => new("code")
    {
        Description = "VCP code in hex (e.g., 0x10 or 10)"
    };

    /// <summary>
    /// Parses a VCP value: decimal, or hex with 0x prefix
    /// </summary>
    internal static uint ParseVcpValue(string? valueStr)
    {
        var text = (valueStr ?? string.Empty).Trim();
        bool parsed = text.StartsWith("0x", StringComparison.OrdinalIgnoreCase)
            ? uint.TryParse(text[2..], NumberStyles.HexNumber, CultureInfo.InvariantCulture, out uint value)
            : uint.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out value);

        if (parsed)
            return value;

        throw new FormatException($"Invalid VCP value: {valueStr}. Use a decimal number like 50 or hex like 0xF12");
    }

    internal static byte ParseVcpCode(string? codeStr)
    {
        var text = (codeStr ?? string.Empty).Trim();

        // Handle 0x prefix
        if (text.StartsWith("0x", StringComparison.OrdinalIgnoreCase))
        {
            text = text[2..];
        }

        if (byte.TryParse(text, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out byte code))
        {
            return code;
        }

        throw new FormatException($"Invalid VCP code format: {codeStr}. Use hex format like 0x10 or 10");
    }
}
