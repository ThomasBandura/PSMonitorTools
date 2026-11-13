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
        var getMonitorOption = new Option<int>(
            aliases: new[] { "--monitor", "-m" },
            getDefaultValue: () => 0,
            description: "Monitor index (0-based, default: 0)");
        getCommand.AddOption(getMonitorOption);
        getCommand.SetHandler((monitorIndex) =>
        {
            try
            {
                var service = new MonitorService();
                var input = service.GetInput(monitorIndex);
                
                // Check if the value is a valid enum
                if (Enum.IsDefined(typeof(MonitorInput), input))
                {
                    Console.WriteLine($"Monitor {monitorIndex} input: {input}");
                }
                else
                {
                    Console.WriteLine($"Monitor {monitorIndex} input: Unknown (0x{(int)input:X2})");
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, getMonitorOption);

        // Set input subcommand
        var setCommand = new Command("set", "Set input source");
        var inputArgument = new Argument<string>(
            name: "source",
            description: "Input source (Hdmi1, Hdmi2, DisplayPort, UsbC)");
        var setMonitorOption = new Option<int>(
            aliases: new[] { "--monitor", "-m" },
            getDefaultValue: () => 0,
            description: "Monitor index (0-based, default: 0)");
        setCommand.AddArgument(inputArgument);
        setCommand.AddOption(setMonitorOption);
        setCommand.SetHandler((inputSource, monitorIndex) =>
        {
            try
            {
                if (!Enum.TryParse<MonitorInput>(inputSource, true, out var input))
                {
                    Console.Error.WriteLine($"Error: Invalid input source '{inputSource}'");
                    Console.Error.WriteLine("Valid sources: Hdmi1, Hdmi2, DisplayPort, UsbC");
                    Environment.Exit(1);
                    return;
                }

                var service = new MonitorService();
                service.SetInput(input, monitorIndex);
                Console.WriteLine($"Monitor {monitorIndex} input switched to {input}");
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, inputArgument, setMonitorOption);

        // Switch subcommand (left and/or right input with PBP collision handling)
        var switchCommand = new Command("switch",
            "Switch left and/or right (PBP) input. When PBP is active, the switching order is chosen so that left and right never use the same input.");
        var leftOption = new Option<string?>(
            aliases: new[] { "--left", "-l" },
            description: "Left/primary input source (Hdmi1, Hdmi2, DisplayPort, UsbC)");
        var rightOption = new Option<string?>(
            aliases: new[] { "--right", "-r" },
            description: "Right input source in PBP mode (Hdmi1, Hdmi2, DisplayPort, UsbC)");
        var switchMonitorOption = new Option<int>(
            aliases: new[] { "--monitor", "-m" },
            getDefaultValue: () => 0,
            description: "Monitor index (0-based, default: 0)");
        switchCommand.AddOption(leftOption);
        switchCommand.AddOption(rightOption);
        switchCommand.AddOption(switchMonitorOption);
        switchCommand.SetHandler((leftSource, rightSource, monitorIndex) =>
        {
            try
            {
                if (leftSource == null && rightSource == null)
                {
                    Console.Error.WriteLine("Error: Specify at least one of --left or --right");
                    Environment.Exit(1);
                    return;
                }

                MonitorInput? left = null;
                MonitorInput? right = null;
                if (leftSource != null)
                {
                    if (!TryParseInput(leftSource, out var value))
                        return;
                    left = value;
                }
                if (rightSource != null)
                {
                    if (!TryParseInput(rightSource, out var value))
                        return;
                    right = value;
                }

                var service = new MonitorService();
                service.SetInputSmart(left, right, monitorIndex);

                if (left.HasValue)
                    Console.WriteLine($"Monitor {monitorIndex} left input switched to {left}");
                if (right.HasValue)
                    Console.WriteLine($"Monitor {monitorIndex} right input switched to {right}");
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, leftOption, rightOption, switchMonitorOption);

        command.AddCommand(getCommand);
        command.AddCommand(setCommand);
        command.AddCommand(switchCommand);

        return command;
    }

    private static bool TryParseInput(string inputSource, out MonitorInput input)
    {
        if (Enum.TryParse(inputSource, true, out input) && Enum.IsDefined(input))
            return true;

        Console.Error.WriteLine($"Error: Invalid input source '{inputSource}'");
        Console.Error.WriteLine("Valid sources: Hdmi1, Hdmi2, DisplayPort, UsbC");
        Environment.Exit(1);
        return false;
    }
}
