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
        statusCommand.SetHandler(() =>
        {
            var service = new MonitorService();
            try
            {
                var isEnabled = service.IsPbpEnabled();
                Console.WriteLine($"PBP Mode: {(isEnabled ? "Enabled" : "Disabled")}");

                if (isEnabled)
                {
                    try
                    {
                        var rightInput = service.GetPbpRightInput();
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
                Console.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        });

        var enableCommand = new Command("enable", "Enable PBP mode");
        enableCommand.SetHandler(() =>
        {
            var service = new MonitorService();
            try
            {
                service.EnablePbp();
                Console.WriteLine("PBP mode enabled");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        });

        var disableCommand = new Command("disable", "Disable PBP mode");
        disableCommand.SetHandler(() =>
        {
            var service = new MonitorService();
            try
            {
                service.DisablePbp();
                Console.WriteLine("PBP mode disabled");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        });

        var setRightCommand = new Command("set-right", "Set right input source for PBP");
        var inputArg = new Argument<string>(
            name: "input",
            description: "Input source (Hdmi1, Hdmi2, DisplayPort, UsbC)");
        setRightCommand.AddArgument(inputArg);
        setRightCommand.SetHandler((string input) =>
        {
            var service = new MonitorService();
            try
            {
                if (!Enum.TryParse<MonitorInput>(input, true, out var inputEnum))
                {
                    Console.WriteLine($"Invalid input source: {input}");
                    Console.WriteLine("Valid values: Hdmi1, Hdmi2, DisplayPort, UsbC");
                    Environment.Exit(1);
                    return;
                }

                service.SetPbpRightInput(inputEnum);
                Console.WriteLine($"PBP right input set to {inputEnum}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, inputArg);

        pbpCommand.AddCommand(statusCommand);
        pbpCommand.AddCommand(enableCommand);
        pbpCommand.AddCommand(disableCommand);
        pbpCommand.AddCommand(setRightCommand);

        return pbpCommand;
    }
}
