using System.CommandLine;
using MonitorTools.Core;

namespace MonitorTools.CLI.Commands;

/// <summary>
/// Command to get information about all monitors
/// </summary>
[System.Runtime.Versioning.SupportedOSPlatform("windows")]
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
                    
                    if (!string.IsNullOrEmpty(monitor.Description))
                        Console.WriteLine($"  Name:              {monitor.Description}");
                    
                    if (!string.IsNullOrEmpty(monitor.Model))
                        Console.WriteLine($"  Model:             {monitor.Model}");
                    
                    if (!string.IsNullOrEmpty(monitor.SerialNumber))
                        Console.WriteLine($"  SerialNumber:      {monitor.SerialNumber}");
                    
                    if (!string.IsNullOrEmpty(monitor.Manufacturer))
                        Console.WriteLine($"  Manufacturer:      {monitor.Manufacturer}");
                    
                    if (!string.IsNullOrEmpty(monitor.Firmware))
                        Console.WriteLine($"  Firmware:          {monitor.Firmware}");
                    
                    if (monitor.WeekOfManufacture.HasValue)
                        Console.WriteLine($"  WeekOfManufacture: {monitor.WeekOfManufacture}");
                    
                    if (monitor.YearOfManufacture.HasValue)
                        Console.WriteLine($"  YearOfManufacture: {monitor.YearOfManufacture}");
                    
                    if (verbose)
                        Console.WriteLine($"  Device:            {monitor.DeviceName}");
                    
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
