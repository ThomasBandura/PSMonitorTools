using MonitorTools.Core;

namespace MonitorTools.Core.Tests;

/// <summary>
/// C#-specific parts of <see cref="InputSwitchPlanner"/>. The switching rules themselves are
/// covered by the shared cases in spec/monitor-behavior.json (<see cref="BehaviorSpecTests"/>).
/// </summary>
public class InputSwitchPlannerTests
{
    [Fact]
    public void Evaluate_RequiresAtLeastOneInput()
    {
        Assert.Throws<ArgumentException>(
            () => InputSwitchPlanner.Evaluate(true, MonitorInput.DisplayPort, MonitorInput.Hdmi1, null, null));
    }

    [Fact]
    public void Plan_ThrowsWithCliHintForSingleSideConflict()
    {
        var ex = Assert.Throws<InvalidOperationException>(
            () => InputSwitchPlanner.Plan(true, MonitorInput.DisplayPort, MonitorInput.Hdmi1, MonitorInput.Hdmi1, null));

        Assert.Contains("Hdmi1 is already used by the right side", ex.Message);
        Assert.Contains("input switch --left", ex.Message);
    }

    [Fact]
    public void Plan_ThrowsForSwap()
    {
        var ex = Assert.Throws<InvalidOperationException>(
            () => InputSwitchPlanner.Plan(true, MonitorInput.DisplayPort, MonitorInput.Hdmi1, MonitorInput.Hdmi1, MonitorInput.DisplayPort));

        Assert.StartsWith("Swapping left (DisplayPort) and right (Hdmi1)", ex.Message);
    }

    [Fact]
    public void Plan_ReturnsStepsWhenAllowed()
    {
        var steps = InputSwitchPlanner.Plan(true, MonitorInput.DisplayPort, MonitorInput.UsbC, MonitorInput.UsbC, MonitorInput.Hdmi1);

        Assert.Equal(new[]
        {
            new InputSwitchStep(InputSide.Right, MonitorInput.Hdmi1),
            new InputSwitchStep(InputSide.Left, MonitorInput.UsbC)
        }, steps);
    }
}
