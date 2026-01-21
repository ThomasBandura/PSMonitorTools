using System.CommandLine;
using MonitorTools.Core;

namespace MonitorTools.CLI.Commands;

/// <summary>
/// Command to control audio mute state
/// </summary>
[System.Runtime.Versioning.SupportedOSPlatform("windows")]
public static class AudioCommand
{
    public static Command Create()
    {
        var command = new Command("audio", "Control monitor audio (mute/unmute)");

        // Mute subcommand
        var muteCommand = new Command("mute", "Mute monitor audio");
        var muteMonitorOption = new Option<int>(
            aliases: new[] { "--monitor", "-m" },
            getDefaultValue: () => 0,
            description: "Monitor index (0-based, default: 0)");
        muteCommand.AddOption(muteMonitorOption);
        muteCommand.SetHandler((monitorIndex) =>
        {
            try
            {
                var service = new MonitorService();
                service.Mute(monitorIndex);
                Console.WriteLine($"Monitor {monitorIndex} audio muted");
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, muteMonitorOption);

        // Unmute subcommand
        var unmuteCommand = new Command("unmute", "Unmute monitor audio");
        var unmuteMonitorOption = new Option<int>(
            aliases: new[] { "--monitor", "-m" },
            getDefaultValue: () => 0,
            description: "Monitor index (0-based, default: 0)");
        unmuteCommand.AddOption(unmuteMonitorOption);
        unmuteCommand.SetHandler((monitorIndex) =>
        {
            try
            {
                var service = new MonitorService();
                service.Unmute(monitorIndex);
                Console.WriteLine($"Monitor {monitorIndex} audio unmuted");
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, unmuteMonitorOption);

        // Status subcommand
        var statusCommand = new Command("status", "Get monitor audio mute status");
        var statusMonitorOption = new Option<int>(
            aliases: new[] { "--monitor", "-m" },
            getDefaultValue: () => 0,
            description: "Monitor index (0-based, default: 0)");
        statusCommand.AddOption(statusMonitorOption);
        statusCommand.SetHandler((monitorIndex) =>
        {
            try
            {
                var service = new MonitorService();
                var isMuted = service.IsMuted(monitorIndex);
                Console.WriteLine($"Monitor {monitorIndex} audio: {(isMuted ? "Muted" : "Unmuted")}");
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }, statusMonitorOption);

        command.AddCommand(muteCommand);
        command.AddCommand(unmuteCommand);
        command.AddCommand(statusCommand);

        return command;
    }
}
