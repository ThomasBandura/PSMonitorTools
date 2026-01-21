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

        command.AddCommand(getCommand);
        command.AddCommand(setCommand);

        return command;
    }
}
