using System.CommandLine;
using MonitorTools.Core;

namespace MonitorTools.CLI.Commands;

[System.Runtime.Versioning.SupportedOSPlatform("windows")]
public static class PbpCommand
{
    public static Command Create()
    {
        var pbpCommand = new Command("pbp", "Manage PBP (Picture-by-Picture) mode");

        var statusCommand = new Command("status", "Get PBP status");
        var statusMonitorOption = CreateMonitorOption();
        statusCommand.AddOption(statusMonitorOption);
        statusCommand.SetHandler((int monitorIndex) =>
        {
            try
            {
                var service = new MonitorService();
                var isEnabled = service.IsPbpEnabled(monitorIndex);
                Console.WriteLine($"PBP Mode: {(isEnabled ? "Enabled" : "Disabled")}");

                if (isEnabled)
                {
                    try
                    {
                        var rightInput = service.GetPbpRightInput(monitorIndex);
                        Console.WriteLine($"Right Input: {rightInput}");
                    }
                    catch
                    {
                        Console.WriteLine("Right Input: Unknown");
                    }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, statusMonitorOption);

        var enableCommand = new Command("enable", "Enable PBP mode");
        var enableMonitorOption = CreateMonitorOption();
        enableCommand.AddOption(enableMonitorOption);
        enableCommand.SetHandler((int monitorIndex) =>
        {
            try
            {
                var service = new MonitorService();
                service.EnablePbp(monitorIndex);
                Console.WriteLine($"Monitor {monitorIndex} PBP mode enabled");
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, enableMonitorOption);

        var disableCommand = new Command("disable", "Disable PBP mode");
        var disableMonitorOption = CreateMonitorOption();
        disableCommand.AddOption(disableMonitorOption);
        disableCommand.SetHandler((int monitorIndex) =>
        {
            try
            {
                var service = new MonitorService();
                service.DisablePbp(monitorIndex);
                Console.WriteLine($"Monitor {monitorIndex} PBP mode disabled");
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, disableMonitorOption);

        var setLeftCommand = new Command("set-left", "Set left input source for PBP");
        var leftInputArg = CreateInputArgument();
        var leftMonitorOption = CreateMonitorOption();
        setLeftCommand.AddArgument(leftInputArg);
        setLeftCommand.AddOption(leftMonitorOption);
        setLeftCommand.SetHandler((string input, int monitorIndex) =>
        {
            try
            {
                if (!TryParseInput(input, out var inputEnum))
                    return;

                var service = new MonitorService();
                service.SetInput(inputEnum, monitorIndex);
                Console.WriteLine($"Monitor {monitorIndex} PBP left input set to {inputEnum}");
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, leftInputArg, leftMonitorOption);

        var setRightCommand = new Command("set-right", "Set right input source for PBP");
        var rightInputArg = CreateInputArgument();
        var rightMonitorOption = CreateMonitorOption();
        setRightCommand.AddArgument(rightInputArg);
        setRightCommand.AddOption(rightMonitorOption);
        setRightCommand.SetHandler((string input, int monitorIndex) =>
        {
            try
            {
                if (!TryParseInput(input, out var inputEnum))
                    return;

                var service = new MonitorService();
                service.SetPbpRightInput(inputEnum, monitorIndex);
                Console.WriteLine($"Monitor {monitorIndex} PBP right input set to {inputEnum}");
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, rightInputArg, rightMonitorOption);

        pbpCommand.AddCommand(statusCommand);
        pbpCommand.AddCommand(enableCommand);
        pbpCommand.AddCommand(disableCommand);
        pbpCommand.AddCommand(setLeftCommand);
        pbpCommand.AddCommand(setRightCommand);

        return pbpCommand;
    }

    private static Option<int> CreateMonitorOption() => new(
        aliases: new[] { "--monitor", "-m" },
        getDefaultValue: () => 0,
        description: "Monitor index (0-based, default: 0)");

    private static Argument<string> CreateInputArgument() => new(
        name: "input",
        description: "Input source (Hdmi1, Hdmi2, DisplayPort, UsbC)");

    private static bool TryParseInput(string input, out MonitorInput inputEnum)
    {
        if (Enum.TryParse(input, true, out inputEnum))
            return true;

        Console.Error.WriteLine($"Invalid input source: {input}");
        Console.Error.WriteLine("Valid values: Hdmi1, Hdmi2, DisplayPort, UsbC");
        Environment.Exit(1);
        return false;
    }
}
