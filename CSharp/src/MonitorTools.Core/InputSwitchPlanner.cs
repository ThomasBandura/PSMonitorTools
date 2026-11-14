namespace MonitorTools.Core;

/// <summary>
/// Side of the screen an input switch applies to
/// </summary>
internal enum InputSide
{
    Left,
    Right
}

/// <summary>
/// One step of an input switch
/// </summary>
internal readonly record struct InputSwitchStep(InputSide Side, MonitorInput Input);

/// <summary>
/// Plans the order of input switches and rejects combinations the monitor would ignore.
/// </summary>
/// <remarks>
/// While PBP is active, the monitor silently ignores a switch to the input the other side is
/// currently showing. Same rules as <c>Switch-MonitorInput</c> in the PowerShell module.
/// </remarks>
internal static class InputSwitchPlanner
{
    public static IReadOnlyList<InputSwitchStep> Plan(
        bool pbpActive,
        MonitorInput? currentLeft,
        MonitorInput? currentRight,
        MonitorInput? left,
        MonitorInput? right)
    {
        if (!left.HasValue && !right.HasValue)
            throw new ArgumentException("At least one input (left or right) must be specified");

        var steps = new List<InputSwitchStep>(2);
        if (left.HasValue)
            steps.Add(new InputSwitchStep(InputSide.Left, left.Value));
        if (right.HasValue)
            steps.Add(new InputSwitchStep(InputSide.Right, right.Value));

        if (!pbpActive)
            return steps;

        var targetLeft = left ?? currentLeft;
        var targetRight = right ?? currentRight;
        if (targetLeft.HasValue && targetLeft == targetRight)
        {
            throw new InvalidOperationException(left.HasValue && right.HasValue
                ? $"Invalid PBP configuration: left and right input cannot both be {targetLeft}."
                : $"Invalid PBP configuration: {targetLeft} is already used by the {(left.HasValue ? "right" : "left")} side. " +
                  "Switch both sides with 'input switch --left ... --right ...'.");
        }

        if (left.HasValue && right.HasValue && left == currentRight && right == currentLeft)
        {
            throw new InvalidOperationException(
                $"Swapping left ({currentLeft}) and right ({currentRight}) is not possible in one step: " +
                "the monitor ignores a switch to the input the other side is showing. " +
                "Switch one side to a free input first.");
        }

        // Target left is still shown on the right: switch the right side first to free it
        if (left.HasValue && right.HasValue && left == currentRight)
            steps.Reverse();

        return steps;
    }
}
