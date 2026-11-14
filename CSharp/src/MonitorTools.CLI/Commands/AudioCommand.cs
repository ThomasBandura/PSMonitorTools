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

        command.Subcommands.Add(CreateSubcommand("mute", "Mute monitor audio", (service, monitorIndex) =>
        {
            service.Mute(monitorIndex);
            Console.WriteLine($"Monitor {monitorIndex} audio muted");
        }));

        command.Subcommands.Add(CreateSubcommand("unmute", "Unmute monitor audio", (service, monitorIndex) =>
        {
            service.Unmute(monitorIndex);
            Console.WriteLine($"Monitor {monitorIndex} audio unmuted");
        }));

        command.Subcommands.Add(CreateSubcommand("status", "Get monitor audio mute status", (service, monitorIndex) =>
        {
            var isMuted = service.IsMuted(monitorIndex);
            Console.WriteLine($"Monitor {monitorIndex} audio: {(isMuted ? "Muted" : "Unmuted")}");
        }));

        return command;
    }

    private static Command CreateSubcommand(string name, string description, Action<MonitorService, int> action)
    {
        var command = new Command(name, description);
        var monitorOption = CliCommon.CreateMonitorOption();
        command.Options.Add(monitorOption);

        command.SetAction(parseResult => CliCommon.Run(() =>
        {
            action(CliCommon.CreateService(), parseResult.GetValue(monitorOption));
            return CliCommon.Success;
        }));

        return command;
    }
}
