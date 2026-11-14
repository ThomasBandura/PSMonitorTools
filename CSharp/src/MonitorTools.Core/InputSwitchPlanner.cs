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
/// Why an input switch is rejected
/// </summary>
internal enum InputSwitchError
{
    None,

    /// <summary>Left and right would end up on the same input</summary>
    Conflict,

    /// <summary>Left and right should be swapped, which is not possible in one step</summary>
    Swap
}

/// <summary>
/// Result of <see cref="InputSwitchPlanner.Evaluate"/>
/// </summary>
internal sealed record InputSwitchPlan(IReadOnlyList<InputSwitchStep> Steps, InputSwitchError Error, string? Message);

/// <summary>
/// Plans the order of input switches and rejects combinations the monitor would ignore.
/// </summary>
/// <remarks>
/// While PBP is active, the monitor silently ignores a switch to the input the other side is
/// currently showing. Same rules as <c>Get-InputSwitchPlan</c> in the PowerShell module; both are
/// tested against spec/monitor-behavior.json (section inputSwitch).
/// </remarks>
internal static class InputSwitchPlanner
{
    /// <summary>
    /// Plans the steps and throws if the monitor would ignore the switch
    /// </summary>
    /// <exception cref="InvalidOperationException">Left and right would use the same input, or should be swapped.</exception>
    public static IReadOnlyList<InputSwitchStep> Plan(
        bool pbpActive,
        MonitorInput? currentLeft,
        MonitorInput? currentRight,
        MonitorInput? left,
        MonitorInput? right)
    {
        var plan = Evaluate(pbpActive, currentLeft, currentRight, left, right);
        if (plan.Error == InputSwitchError.Conflict && left.HasValue != right.HasValue)
            throw new InvalidOperationException($"{plan.Message} Switch both sides with 'input switch --left ... --right ...'.");
        if (plan.Error != InputSwitchError.None)
            throw new InvalidOperationException(plan.Message);
        return plan.Steps;
    }

    /// <summary>
    /// Plans the steps and returns the reason if the monitor would ignore the switch
    /// </summary>
    public static InputSwitchPlan Evaluate(
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
            return new InputSwitchPlan(steps, InputSwitchError.None, null);

        var targetLeft = left ?? currentLeft;
        var targetRight = right ?? currentRight;
        if (targetLeft.HasValue && targetLeft == targetRight)
        {
            var message = (left.HasValue, right.HasValue) switch
            {
                (true, true) => $"Invalid PBP configuration: left and right input cannot both be {targetLeft}.",
                (true, false) => $"Invalid PBP configuration: {targetLeft} is already used by the right side.",
                _ => $"Invalid PBP configuration: {targetLeft} is already used by the left side."
            };
            return new InputSwitchPlan(Array.Empty<InputSwitchStep>(), InputSwitchError.Conflict, message);
        }

        bool bothSides = left.HasValue && right.HasValue;
        if (bothSides && left == currentRight && right == currentLeft)
        {
            return new InputSwitchPlan(Array.Empty<InputSwitchStep>(), InputSwitchError.Swap,
                $"Swapping left ({currentLeft}) and right ({currentRight}) is not possible in one step: " +
                "the monitor ignores a switch to the input the other side is showing. " +
                "Switch one side to a free input first.");
        }

        // The new left input is still shown on the right: switch the right side first to free it
        if (bothSides && left == currentRight)
            steps.Reverse();

        return new InputSwitchPlan(steps, InputSwitchError.None, null);
    }
}
