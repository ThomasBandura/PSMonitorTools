using System.CommandLine;
using MonitorTools.CLI.Commands;

namespace MonitorTools.CLI;

class Program
{
    static async Task<int> Main(string[] args)
    {
        var rootCommand = new RootCommand("MonitorTools - Monitor information and brightness control");

        // Add commands
        rootCommand.AddCommand(GetInfoCommand.Create());
        rootCommand.AddCommand(GetBrightnessCommand.Create());
        rootCommand.AddCommand(SetBrightnessCommand.Create());
        rootCommand.AddCommand(GetContrastCommand.Create());
        rootCommand.AddCommand(SetContrastCommand.Create());
        rootCommand.AddCommand(GetVolumeCommand.Create());
        rootCommand.AddCommand(SetVolumeCommand.Create());
        rootCommand.AddCommand(AudioCommand.Create());
        rootCommand.AddCommand(InputCommand.Create());
        rootCommand.AddCommand(PbpCommand.Create());
        rootCommand.AddCommand(VcpCommand.Create());

        return await rootCommand.InvokeAsync(args);
    }
}
