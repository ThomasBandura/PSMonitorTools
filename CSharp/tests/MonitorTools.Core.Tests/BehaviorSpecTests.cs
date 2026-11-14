using System.Globalization;
using System.Text.Json;
using MonitorTools.Core;

namespace MonitorTools.Core.Tests;

/// <summary>
/// Shared behavior cases (spec/monitor-behavior.json). The PowerShell module is tested with the
/// same file (PowerShell/Tests/Behavior.Spec.Tests.ps1), so both implementations follow the same rules.
/// </summary>
public class BehaviorSpecTests
{
    private static readonly Lazy<JsonElement> Spec = new(() =>
    {
        var path = Path.Combine(AppContext.BaseDirectory, "spec", "monitor-behavior.json");
        using var document = JsonDocument.Parse(File.ReadAllText(path));
        return document.RootElement.Clone();
    });

    private static IEnumerable<object[]> Cases(string section) =>
        Spec.Value.GetProperty(section).EnumerateArray().Select(c => new object[] { new SpecCase(c) });

    public static IEnumerable<object[]> PbpActiveCases => Cases("pbpActive");
    public static IEnumerable<object[]> LeftInputValueCases => Cases("leftInputValue");
    public static IEnumerable<object[]> ContinuousValueCases => Cases("continuousValue");
    public static IEnumerable<object[]> InputSwitchCases => Cases("inputSwitch");

    [Theory]
    [MemberData(nameof(PbpActiveCases))]
    public void PbpActive(SpecCase c)
    {
        Assert.Equal(c.Bool("active"), PbpModeValue.IsActive(c.Hex("value")));
    }

    [Theory]
    [MemberData(nameof(LeftInputValueCases))]
    public void LeftInputValue(SpecCase c)
    {
        var input = c.Input("input")!.Value;
        Assert.Equal(c.Hex("value"), PbpModeValue.GetLeftInputValue(input, c.Bool("pbpActive")));
    }

    [Theory]
    [MemberData(nameof(ContinuousValueCases))]
    public void ContinuousValue(SpecCase c)
    {
        uint maximum = c.UInt("maximum");
        Assert.Equal(c.UInt("limit"), MonitorService.GetContinuousLimit(maximum));

        var validate = () => MonitorService.ValidateContinuousValue((int)c.UInt("value"), maximum, "Brightness");
        if (c.Bool("valid"))
            validate();
        else
            Assert.Throws<ArgumentOutOfRangeException>(validate);
    }

    [Theory]
    [MemberData(nameof(InputSwitchCases))]
    public void InputSwitch(SpecCase c)
    {
        var plan = InputSwitchPlanner.Evaluate(
            c.Bool("pbpActive"), c.Input("currentLeft"), c.Input("currentRight"), c.Input("left"), c.Input("right"));

        var expectedError = c.String("error") is { } error
            ? Enum.Parse<InputSwitchError>(error)
            : InputSwitchError.None;
        Assert.Equal(expectedError, plan.Error);

        var expectedSteps = c.Element.GetProperty("steps").EnumerateArray().Select(s => s.GetString()).ToArray();
        var actualSteps = plan.Steps.Select(s => $"{s.Side}:{s.Input}").ToArray();
        Assert.Equal(expectedSteps, actualSteps);
    }

    /// <summary>
    /// One case from the spec file. ToString shows the name in the test explorer.
    /// </summary>
    public sealed class SpecCase
    {
        public SpecCase(JsonElement element) => Element = element;

        public JsonElement Element { get; }

        public bool Bool(string name) => Element.GetProperty(name).GetBoolean();

        public uint UInt(string name) => Element.GetProperty(name).GetUInt32();

        public string? String(string name) =>
            Element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;

        /// <summary>Hex string with 0x prefix, e.g. "0xF0F"</summary>
        public uint Hex(string name) =>
            uint.Parse(String(name)!.AsSpan(2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);

        public MonitorInput? Input(string name) =>
            String(name) is { } text ? Enum.Parse<MonitorInput>(text) : null;

        public override string ToString() =>
            String("name") ?? Element.GetRawText();
    }
}
