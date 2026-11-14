using System.CommandLine;
using MonitorTools.Core;

namespace MonitorTools.CLI.Commands;

/// <summary>
/// Command to manage PBP (Picture-by-Picture) mode
/// </summary>
[System.Runtime.Versioning.SupportedOSPlatform("windows")]
public static class PbpCommand
{
    public static Command Create()
    {
        var pbpCommand = new Command("pbp", "Manage PBP (Picture-by-Picture) mode");

        // status
        var statusCommand = new Command("status", "Get PBP status");
        var statusMonitorOption = CliCommon.CreateMonitorOption();
        statusCommand.Options.Add(statusMonitorOption);
        statusCommand.SetAction(parseResult => CliCommon.Run(() =>
        {
            int monitorIndex = parseResult.GetValue(statusMonitorOption);
            var service = new MonitorService();
            var isEnabled = service.IsPbpEnabled(monitorIndex);
            Console.WriteLine($"PBP Mode: {(isEnabled ? "Enabled" : "Disabled")}");

            if (isEnabled)
            {
                try
                {
                    Console.WriteLine($"Right Input: {service.GetPbpRightInput(monitorIndex)}");
                }
                catch
                {
                    Console.WriteLine("Right Input: Unknown");
                }
            }
            return CliCommon.Success;
        }));

        // enable / disable
        var enableCommand = CreateSimpleCommand("enable", "Enable PBP mode", (service, monitorIndex) =>
        {
            service.EnablePbp(monitorIndex);
            Console.WriteLine($"Monitor {monitorIndex} PBP mode enabled");
        });
        var disableCommand = CreateSimpleCommand("disable", "Disable PBP mode", (service, monitorIndex) =>
        {
            service.DisablePbp(monitorIndex);
            Console.WriteLine($"Monitor {monitorIndex} PBP mode disabled");
        });

        // set-left / set-right
        var setLeftCommand = CreateInputCommand("set-left", "Set left input source for PBP", (service, input, monitorIndex) =>
        {
            service.SetInput(input, monitorIndex);
            Console.WriteLine($"Monitor {monitorIndex} PBP left input set to {input}");
        });
        var setRightCommand = CreateInputCommand("set-right", "Set right input source for PBP", (service, input, monitorIndex) =>
        {
            service.SetPbpRightInput(input, monitorIndex);
            Console.WriteLine($"Monitor {monitorIndex} PBP right input set to {input}");
        });

        pbpCommand.Subcommands.Add(statusCommand);
        pbpCommand.Subcommands.Add(enableCommand);
        pbpCommand.Subcommands.Add(disableCommand);
        pbpCommand.Subcommands.Add(setLeftCommand);
        pbpCommand.Subcommands.Add(setRightCommand);

        return pbpCommand;
    }

    private static Command CreateSimpleCommand(string name, string description, Action<MonitorService, int> action)
    {
        var command = new Command(name, description);
        var monitorOption = CliCommon.CreateMonitorOption();
        command.Options.Add(monitorOption);
        command.SetAction(parseResult => CliCommon.Run(() =>
        {
            action(new MonitorService(), parseResult.GetValue(monitorOption));
            return CliCommon.Success;
        }));
        return command;
    }

    private static Command CreateInputCommand(string name, string description, Action<MonitorService, MonitorInput, int> action)
    {
        var command = new Command(name, description);
        var inputArgument = CliCommon.CreateInputArgument("input");
        var monitorOption = CliCommon.CreateMonitorOption();
        command.Arguments.Add(inputArgument);
        command.Options.Add(monitorOption);
        command.SetAction(parseResult => CliCommon.Run(() =>
        {
            string? source = parseResult.GetValue(inputArgument);
            if (!CliCommon.TryParseInput(source, out var input))
                return CliCommon.InvalidInput(source);

            action(new MonitorService(), input, parseResult.GetValue(monitorOption));
            return CliCommon.Success;
        }));
        return command;
    }
}
