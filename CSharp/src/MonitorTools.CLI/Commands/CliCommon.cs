using System.CommandLine;
using MonitorTools.Core;

namespace MonitorTools.CLI.Commands;

/// <summary>
/// Shared options, input parsing and error handling for all CLI commands
/// </summary>
internal static class CliCommon
{
    public const int Success = 0;
    public const int Failure = 1;

    /// <summary>
    /// Creates the --monitor/-m option used by all monitor commands
    /// </summary>
    public static Option<int> CreateMonitorOption() => new("--monitor", "-m")
    {
        Description = "Monitor index (0-based, default: 0)",
        DefaultValueFactory = _ => 0
    };

    /// <summary>
    /// Creates an argument for an input source (Hdmi1, Hdmi2, DisplayPort, UsbC)
    /// </summary>
    public static Argument<string> CreateInputArgument(string name) => new(name)
    {
        Description = "Input source (Hdmi1, Hdmi2, DisplayPort, UsbC)"
    };

    /// <summary>
    /// Runs a command action with central error handling. Errors go to stderr and return exit code 1.
    /// </summary>
    public static int Run(Func<int> action)
    {
        try
        {
            return action();
        }
        catch (Exception ex)
        {
            return Fail(GetUserMessage(ex));
        }
    }

    /// <summary>
    /// Returns the message without the "(Parameter 'x')" / "Actual value was ..." suffixes that
    /// .NET appends to argument exceptions.
    /// </summary>
    internal static string GetUserMessage(Exception ex)
    {
        if (ex is not ArgumentException argumentException || argumentException.ParamName == null)
            return ex.Message;

        var message = ex.Message.Split('\n')[0].TrimEnd('\r');
        var suffix = $" (Parameter '{argumentException.ParamName}')";
        return message.EndsWith(suffix, StringComparison.Ordinal) ? message[..^suffix.Length] : message;
    }

    /// <summary>
    /// Writes an error message (and optional hints) to stderr and returns exit code 1
    /// </summary>
    public static int Fail(string message, params string[] hints)
    {
        Console.Error.WriteLine($"Error: {message}");
        foreach (var hint in hints)
        {
            Console.Error.WriteLine(hint);
        }
        return Failure;
    }

    /// <summary>
    /// Parses an input source name (case-insensitive). Numeric values are rejected.
    /// </summary>
    public static bool TryParseInput(string? value, out MonitorInput input)
    {
        input = default;
        return !string.IsNullOrWhiteSpace(value)
            && !char.IsDigit(value.Trim()[0])
            && Enum.TryParse(value, ignoreCase: true, out input)
            && Enum.IsDefined(input);
    }

    /// <summary>
    /// Error result for an invalid input source
    /// </summary>
    public static int InvalidInput(string? value) =>
        Fail($"Invalid input source '{value}'", "Valid sources: Hdmi1, Hdmi2, DisplayPort, UsbC");
}
