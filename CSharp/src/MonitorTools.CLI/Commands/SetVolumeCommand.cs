using System.CommandLine;
using MonitorTools.Core;

namespace MonitorTools.CLI.Commands;

/// <summary>
/// Command to set audio volume of a monitor
/// </summary>
public static class SetVolumeCommand
{
    public static Command Create()
    {
        var command = new Command("set-volume", "Set the audio volume level of a monitor");

        var volumeArgument = new Argument<int>(
            name: "volume",
            description: "Volume level (0-100)");

        var monitorOption = new Option<int>(
            aliases: new[] { "--monitor", "-m" },
            getDefaultValue: () => 0,
            description: "Monitor index (0-based, default: 0)");

        command.AddArgument(volumeArgument);
        command.AddOption(monitorOption);

        command.SetHandler((volume, monitorIndex) =>
        {
            try
            {
                if (volume < 0 || volume > 100)
                {
                    Console.Error.WriteLine("Error: Volume must be between 0 and 100");
                    Environment.Exit(1);
                    return;
                }

                var service = new MonitorService();
                service.SetVolume(volume, monitorIndex);
                
                Console.WriteLine($"Monitor {monitorIndex} volume set to {volume}%");
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
        }, volumeArgument, monitorOption);

        return command;
    }
}
