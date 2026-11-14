using System.CommandLine;
using MonitorTools.Core;

namespace MonitorTools.CLI.Commands;

/// <summary>
/// get-/set- commands for continuous values: brightness, contrast and volume
/// </summary>
[System.Runtime.Versioning.SupportedOSPlatform("windows")]
internal static class LevelCommands
{
    public static IEnumerable<Command> CreateAll()
    {
        yield return CreateGet("get-brightness", "brightness", "%", (s, m) => s.GetBrightness(m));
        yield return CreateSet("set-brightness", "brightness", "%", (s, v, m) => s.SetBrightness(v, m));
        yield return CreateGet("get-contrast", "contrast", "%", (s, m) => s.GetContrast(m));
        yield return CreateSet("set-contrast", "contrast", "%", (s, v, m) => s.SetContrast(v, m));
        yield return CreateGet("get-volume", "volume", "%", (s, m) => s.GetVolume(m));
        yield return CreateSet("set-volume", "volume", "%", (s, v, m) => s.SetVolume(v, m));
    }

    private static Command CreateGet(string name, string feature, string unit, Func<MonitorService, int, int> getter)
    {
        var command = new Command(name, $"Get the {feature} level of a monitor");
        var monitorOption = CliCommon.CreateMonitorOption();
        command.Options.Add(monitorOption);

        command.SetAction(parseResult => CliCommon.Run(() =>
        {
            int monitorIndex = parseResult.GetValue(monitorOption);
            var service = CliCommon.CreateService();
            int value = getter(service, monitorIndex);

            Console.WriteLine($"Monitor {monitorIndex} {feature}: {value}{unit}");
            return CliCommon.Success;
        }));

        return command;
    }

    private static Command CreateSet(string name, string feature, string unit, Action<MonitorService, int, int> setter)
    {
        var command = new Command(name, $"Set the {feature} level of a monitor");
        var valueArgument = new Argument<int>(feature)
        {
            Description = $"{char.ToUpperInvariant(feature[0])}{feature[1..]} level (0 to the maximum reported by the monitor, usually 100)"
        };
        var monitorOption = CliCommon.CreateMonitorOption();
        command.Arguments.Add(valueArgument);
        command.Options.Add(monitorOption);

        command.SetAction(parseResult => CliCommon.Run(() =>
        {
            int value = parseResult.GetValue(valueArgument);
            int monitorIndex = parseResult.GetValue(monitorOption);

            var service = CliCommon.CreateService();
            setter(service, value, monitorIndex);

            Console.WriteLine($"Monitor {monitorIndex} {feature} set to {value}{unit}");
            return CliCommon.Success;
        }));

        return command;
    }
}
