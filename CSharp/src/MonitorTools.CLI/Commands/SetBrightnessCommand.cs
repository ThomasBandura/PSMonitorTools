using System.CommandLine;
using MonitorTools.Core;

namespace MonitorTools.CLI.Commands;

/// <summary>
/// Command to set brightness of a monitor
/// </summary>
public static class SetBrightnessCommand
{
    public static Command Create()
    {
        var command = new Command("set-brightness", "Set the brightness level of a monitor");

        var brightnessArgument = new Argument<int>(
            name: "brightness",
            description: "Brightness level (0-100)");

        var monitorOption = new Option<int>(
            aliases: new[] { "--monitor", "-m" },
            getDefaultValue: () => 0,
            description: "Monitor index (0-based, default: 0)");

        command.AddArgument(brightnessArgument);
        command.AddOption(monitorOption);

        command.SetHandler((brightness, monitorIndex) =>
        {
            try
            {
                if (brightness < 0 || brightness > 100)
                {
                    Console.Error.WriteLine("Error: Brightness must be between 0 and 100");
                    Environment.Exit(1);
                    return;
                }

                var service = new MonitorService();
                service.SetBrightness(brightness, monitorIndex);
                
                Console.WriteLine($"Monitor {monitorIndex} brightness set to {brightness}%");
            }
            catch (ArgumentOutOfRangeException ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, brightnessArgument, monitorOption);

        return command;
    }
}
