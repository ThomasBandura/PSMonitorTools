using System.CommandLine;
using MonitorTools.CLI.Commands;

namespace MonitorTools.CLI;

[System.Runtime.Versioning.SupportedOSPlatform("windows")]
class Program
{
    static int Main(string[] args)
    {
        var rootCommand = new RootCommand("MonitorTools - Monitor information and brightness control");

        rootCommand.Subcommands.Add(GetInfoCommand.Create());
        foreach (var command in LevelCommands.CreateAll())
        {
            rootCommand.Subcommands.Add(command);
        }
        rootCommand.Subcommands.Add(AudioCommand.Create());
        rootCommand.Subcommands.Add(InputCommand.Create());
        rootCommand.Subcommands.Add(PbpCommand.Create());
        rootCommand.Subcommands.Add(VcpCommand.Create());

        return rootCommand.Parse(args).Invoke();
    }
}
