using System.CommandLine;
using MonitorTools.Core;

namespace MonitorTools.CLI.Commands;

/// <summary>
/// Command to get information about all monitors
/// </summary>
public static class GetInfoCommand
{
    public static Command Create()
    {
        var command = new Command("get-info", "Get information about all connected monitors");

        var verboseOption = new Option<bool>(
            aliases: new[] { "--verbose", "-v" },
            description: "Show detailed information");

        command.AddOption(verboseOption);

        command.SetHandler((verbose) =>
        {
            try
            {
                var service = new MonitorService();
                var monitors = service.GetMonitors();

                if (monitors.Length == 0)
                {
                    Console.WriteLine("No monitors found.");
                    return;
                }

                Console.WriteLine($"Found {monitors.Length} monitor(s):\n");

                foreach (var monitor in monitors)
                {
                    Console.WriteLine($"Monitor {monitor.Index}:");
                    Console.WriteLine($"  Device:      {monitor.DeviceName}");
                    
                    if (!string.IsNullOrEmpty(monitor.Model))
                        Console.WriteLine($"  Model:       {monitor.Model}");
                    
                    if (!string.IsNullOrEmpty(monitor.Manufacturer))
                        Console.WriteLine($"  Manufacturer: {monitor.Manufacturer}");
                    
                    Console.WriteLine($"  Resolution:  {monitor.Width}x{monitor.Height}");
                    Console.WriteLine($"  Primary:     {(monitor.IsPrimary ? "Yes" : "No")}");
                    
                    if (monitor.Brightness.HasValue)
                        Console.WriteLine($"  Brightness:  {monitor.Brightness}%");
                    
                    if (verbose && !string.IsNullOrEmpty(monitor.SerialNumber))
                        Console.WriteLine($"  Serial:      {monitor.SerialNumber}");
                    
                    Console.WriteLine();
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, verboseOption);

        return command;
    }
}
