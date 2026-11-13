namespace MonitorTools.IntegrationTests;

/// <summary>
/// Hardware tests switch real monitor inputs and PBP modes. They only run when
/// the environment variable <c>MONITORTOOLS_HARDWARE_TESTS</c> is set to <c>1</c>.
/// </summary>
internal static class HardwareTestGate
{
    public const string EnvironmentVariable = "MONITORTOOLS_HARDWARE_TESTS";

    public static string? SkipReason =>
        Environment.GetEnvironmentVariable(EnvironmentVariable) == "1"
            ? null
            : $"Hardware test. Set {EnvironmentVariable}=1 to run against a connected monitor.";
}

/// <summary>
/// A <see cref="FactAttribute"/> that is skipped unless hardware tests are enabled.
/// </summary>
public sealed class HardwareFactAttribute : FactAttribute
{
    public HardwareFactAttribute()
    {
        Skip = HardwareTestGate.SkipReason;
    }
}

/// <summary>
/// A <see cref="TheoryAttribute"/> that is skipped unless hardware tests are enabled.
/// </summary>
public sealed class HardwareTheoryAttribute : TheoryAttribute
{
    public HardwareTheoryAttribute()
    {
        Skip = HardwareTestGate.SkipReason;
    }
}
