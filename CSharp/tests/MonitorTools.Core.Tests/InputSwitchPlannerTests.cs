using MonitorTools.Core;

namespace MonitorTools.Core.Tests;

public class InputSwitchPlannerTests
{
    private const MonitorInput Dp = MonitorInput.DisplayPort;
    private const MonitorInput Hdmi1 = MonitorInput.Hdmi1;
    private const MonitorInput Hdmi2 = MonitorInput.Hdmi2;
    private const MonitorInput UsbC = MonitorInput.UsbC;

    [Fact]
    public void Plan_RequiresAtLeastOneInput()
    {
        Assert.Throws<ArgumentException>(() => InputSwitchPlanner.Plan(true, Dp, Hdmi1, null, null));
    }

    [Fact]
    public void Plan_WithoutPbp_SwitchesLeftThenRightWithoutChecks()
    {
        var steps = InputSwitchPlanner.Plan(false, null, null, Hdmi1, Hdmi1);

        Assert.Equal(new[]
        {
            new InputSwitchStep(InputSide.Left, Hdmi1),
            new InputSwitchStep(InputSide.Right, Hdmi1)
        }, steps);
    }

    [Fact]
    public void Plan_WithPbp_RejectsLeftUsedByRight()
    {
        // Left = current right: the monitor would ignore the switch
        var ex = Assert.Throws<InvalidOperationException>(() => InputSwitchPlanner.Plan(true, Dp, Hdmi1, Hdmi1, null));
        Assert.Contains("already used by the right side", ex.Message);
    }

    [Fact]
    public void Plan_WithPbp_RejectsRightUsedByLeft()
    {
        var ex = Assert.Throws<InvalidOperationException>(() => InputSwitchPlanner.Plan(true, Dp, Hdmi1, null, Dp));
        Assert.Contains("already used by the left side", ex.Message);
    }

    [Fact]
    public void Plan_WithPbp_RejectsSameTargetOnBothSides()
    {
        var ex = Assert.Throws<InvalidOperationException>(() => InputSwitchPlanner.Plan(true, Dp, Hdmi1, UsbC, UsbC));
        Assert.Contains("cannot both be UsbC", ex.Message);
    }

    [Fact]
    public void Plan_WithPbp_RejectsSwap()
    {
        var ex = Assert.Throws<InvalidOperationException>(() => InputSwitchPlanner.Plan(true, Dp, Hdmi1, Hdmi1, Dp));
        Assert.Contains("Swapping", ex.Message);
    }

    [Fact]
    public void Plan_WithPbp_SwitchesRightFirstWhenTargetLeftIsCurrentRight()
    {
        var steps = InputSwitchPlanner.Plan(true, Dp, UsbC, UsbC, Hdmi1);

        Assert.Equal(new[]
        {
            new InputSwitchStep(InputSide.Right, Hdmi1),
            new InputSwitchStep(InputSide.Left, UsbC)
        }, steps);
    }

    [Fact]
    public void Plan_WithPbp_SwitchesLeftFirstWhenTargetRightIsCurrentLeft()
    {
        var steps = InputSwitchPlanner.Plan(true, Dp, UsbC, Hdmi1, Dp);

        Assert.Equal(new[]
        {
            new InputSwitchStep(InputSide.Left, Hdmi1),
            new InputSwitchStep(InputSide.Right, Dp)
        }, steps);
    }

    [Fact]
    public void Plan_WithPbp_AllowsFreeInputs()
    {
        var steps = InputSwitchPlanner.Plan(true, Dp, Hdmi1, Hdmi2, null);

        Assert.Equal(new[] { new InputSwitchStep(InputSide.Left, Hdmi2) }, steps);
    }

    [Fact]
    public void Plan_WithPbp_AllowsSettingTheCurrentValueAgain()
    {
        var steps = InputSwitchPlanner.Plan(true, Dp, Hdmi1, Dp, null);

        Assert.Equal(new[] { new InputSwitchStep(InputSide.Left, Dp) }, steps);
    }
}
