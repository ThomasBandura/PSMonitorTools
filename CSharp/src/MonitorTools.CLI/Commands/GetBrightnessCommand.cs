using System.CommandLine;
using MonitorTools.Core;

namespace MonitorTools.CLI.Commands;

/// <summary>
/// Command to get brightness of a monitor
/// </summary>
[System.Runtime.Versioning.SupportedOSPlatform("windows")]
public static class GetBrightnessCommand
{
    public static Command Create()
    {
        var command = new Command("get-brightness", "Get the brightness level of a monitor");

        var monitorOption = new Option<int>(
            aliases: new[] { "--monitor", "-m" },
            getDefaultValue: () => 0,
            description: "Monitor index (0-based, default: 0)");

        command.AddOption(monitorOption);

        command.SetHandler((monitorIndex) =>
        {
            try
            {
                var service = new MonitorService();
                var brightness = service.GetBrightness(monitorIndex);
                
                Console.WriteLine($"Monitor {monitorIndex} brightness: {brightness}%");
            }
            catch (ArgumentOutOfRangeException)
            {
                Console.Error.WriteLine($"Error: Invalid monitor index {monitorIndex}");
                Environment.Exit(1);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, monitorOption);

        return command;
    }
}
