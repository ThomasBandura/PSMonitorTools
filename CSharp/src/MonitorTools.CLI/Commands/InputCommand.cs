using System.CommandLine;
using MonitorTools.Core;

namespace MonitorTools.CLI.Commands;

/// <summary>
/// Command to get and set monitor input source
/// </summary>
[System.Runtime.Versioning.SupportedOSPlatform("windows")]
public static class InputCommand
{
    public static Command Create()
    {
        var command = new Command("input", "Get or set monitor input source");

        // Get input subcommand
        var getCommand = new Command("get", "Get current input source");
        var getMonitorOption = CliCommon.CreateMonitorOption();
        getCommand.Options.Add(getMonitorOption);
        getCommand.SetAction(parseResult => CliCommon.Run(() =>
        {
            int monitorIndex = parseResult.GetValue(getMonitorOption);
            var service = CliCommon.CreateService();
            var input = service.GetInput(monitorIndex);

            Console.WriteLine(Enum.IsDefined(input)
                ? $"Monitor {monitorIndex} input: {input}"
                : $"Monitor {monitorIndex} input: Unknown (0x{(int)input:X2})");
            return CliCommon.Success;
        }));

        // Set input subcommand
        var setCommand = new Command("set", "Set input source");
        var inputArgument = CliCommon.CreateInputArgument("source");
        var setMonitorOption = CliCommon.CreateMonitorOption();
        setCommand.Arguments.Add(inputArgument);
        setCommand.Options.Add(setMonitorOption);
        setCommand.SetAction(parseResult => CliCommon.Run(() =>
        {
            string? source = parseResult.GetValue(inputArgument);
            int monitorIndex = parseResult.GetValue(setMonitorOption);
            if (!CliCommon.TryParseInput(source, out var input))
                return CliCommon.InvalidInput(source);

            var service = CliCommon.CreateService();
            service.SetInput(input, monitorIndex);
            Console.WriteLine($"Monitor {monitorIndex} input switched to {input}");
            return CliCommon.Success;
        }));

        // Switch subcommand (left and/or right input with PBP collision handling)
        var switchCommand = new Command("switch",
            "Switch left and/or right (PBP) input. When PBP is active, the switching order is chosen so that left and right never use the same input.");
        var leftOption = new Option<string?>("--left", "-l")
        {
            Description = "Left/primary input source (Hdmi1, Hdmi2, DisplayPort, UsbC)"
        };
        var rightOption = new Option<string?>("--right", "-r")
        {
            Description = "Right input source in PBP mode (Hdmi1, Hdmi2, DisplayPort, UsbC)"
        };
        var switchMonitorOption = CliCommon.CreateMonitorOption();
        switchCommand.Options.Add(leftOption);
        switchCommand.Options.Add(rightOption);
        switchCommand.Options.Add(switchMonitorOption);
        switchCommand.SetAction(parseResult => CliCommon.Run(() =>
        {
            string? leftSource = parseResult.GetValue(leftOption);
            string? rightSource = parseResult.GetValue(rightOption);
            int monitorIndex = parseResult.GetValue(switchMonitorOption);

            if (leftSource == null && rightSource == null)
                return CliCommon.Fail("Specify at least one of --left or --right");

            MonitorInput? left = null;
            MonitorInput? right = null;
            if (leftSource != null)
            {
                if (!CliCommon.TryParseInput(leftSource, out var value))
                    return CliCommon.InvalidInput(leftSource);
                left = value;
            }
            if (rightSource != null)
            {
                if (!CliCommon.TryParseInput(rightSource, out var value))
                    return CliCommon.InvalidInput(rightSource);
                right = value;
            }

            var service = CliCommon.CreateService();
            service.SetInputSmart(left, right, monitorIndex);

            if (left.HasValue)
                Console.WriteLine($"Monitor {monitorIndex} left input switched to {left}");
            if (right.HasValue)
                Console.WriteLine($"Monitor {monitorIndex} right input switched to {right}");
            return CliCommon.Success;
        }));

        command.Subcommands.Add(getCommand);
        command.Subcommands.Add(setCommand);
        command.Subcommands.Add(switchCommand);

        return command;
    }
}
