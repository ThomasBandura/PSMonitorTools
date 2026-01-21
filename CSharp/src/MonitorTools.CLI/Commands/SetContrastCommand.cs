using System.CommandLine;
using MonitorTools.Core;

namespace MonitorTools.CLI.Commands;

/// <summary>
/// Command to set contrast of a monitor
/// </summary>
public static class SetContrastCommand
{
    public static Command Create()
    {
        var command = new Command("set-contrast", "Set the contrast level of a monitor");

        var contrastArgument = new Argument<int>(
            name: "contrast",
            description: "Contrast level (0-100)");

        var monitorOption = new Option<int>(
            aliases: new[] { "--monitor", "-m" },
            getDefaultValue: () => 0,
            description: "Monitor index (0-based, default: 0)");

        command.AddArgument(contrastArgument);
        command.AddOption(monitorOption);

        command.SetHandler((contrast, monitorIndex) =>
        {
            try
            {
                if (contrast < 0 || contrast > 100)
                {
                    Console.Error.WriteLine("Error: Contrast must be between 0 and 100");
                    Environment.Exit(1);
                    return;
                }

                var service = new MonitorService();
                service.SetContrast(contrast, monitorIndex);
                
                Console.WriteLine($"Monitor {monitorIndex} contrast set to {contrast}%");
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
        }, contrastArgument, monitorOption);

        return command;
    }
}
