namespace MonitorTools.Core.Interfaces;

/// <summary>
/// Interface for monitor-related operations
/// </summary>
public interface IMonitorService
{
    /// <summary>
    /// Gets information about all connected monitors
    /// </summary>
    /// <returns>Array of monitor information</returns>
    MonitorInfo[] GetMonitors();

    /// <summary>
    /// Gets the brightness level of a specific monitor
    /// </summary>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    /// <returns>Brightness level (0-100)</returns>
    int GetBrightness(int monitorIndex = 0);

    /// <summary>
    /// Sets the brightness level of a specific monitor
    /// </summary>
    /// <param name="brightness">Brightness level (0-100)</param>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    void SetBrightness(int brightness, int monitorIndex = 0);

    /// <summary>
    /// Gets the contrast level of a specific monitor
    /// </summary>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    /// <returns>Contrast level (0-100)</returns>
    int GetContrast(int monitorIndex = 0);

    /// <summary>
    /// Sets the contrast level of a specific monitor
    /// </summary>
    /// <param name="contrast">Contrast level (0-100)</param>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    void SetContrast(int contrast, int monitorIndex = 0);

    /// <summary>
    /// Gets the audio volume of a specific monitor
    /// </summary>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    /// <returns>Volume level (0-100)</returns>
    int GetVolume(int monitorIndex = 0);

    /// <summary>
    /// Sets the audio volume of a specific monitor
    /// </summary>
    /// <param name="volume">Volume level (0-100)</param>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    void SetVolume(int volume, int monitorIndex = 0);

    /// <summary>
    /// Gets the audio mute state of a specific monitor
    /// </summary>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    /// <returns>True if muted, false otherwise</returns>
    bool IsMuted(int monitorIndex = 0);

    /// <summary>
    /// Mutes the audio of a specific monitor
    /// </summary>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    void Mute(int monitorIndex = 0);

    /// <summary>
    /// Unmutes the audio of a specific monitor
    /// </summary>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    void Unmute(int monitorIndex = 0);

    /// <summary>
    /// Gets the current input source of a specific monitor
    /// </summary>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    /// <returns>Current input source</returns>
    MonitorInput GetInput(int monitorIndex = 0);

    /// <summary>
    /// Sets the input source of a specific monitor
    /// </summary>
    /// <param name="input">Input source to switch to</param>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    void SetInput(MonitorInput input, int monitorIndex = 0);

    /// <summary>
    /// Sets the left and/or right input. When PBP is active, the switching order is chosen
    /// so that left and right never use the same input at the same time.
    /// </summary>
    /// <param name="leftInput">Left/primary input, or null to keep the current one</param>
    /// <param name="rightInput">Right (PBP) input, or null to keep the current one</param>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    void SetInputSmart(MonitorInput? leftInput = null, MonitorInput? rightInput = null, int monitorIndex = 0);

    /// <summary>
    /// Checks if PBP (Picture-by-Picture) mode is enabled
    /// </summary>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    bool IsPbpEnabled(int monitorIndex = 0);

    /// <summary>
    /// Enables PBP (Picture-by-Picture) mode
    /// </summary>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    void EnablePbp(int monitorIndex = 0);

    /// <summary>
    /// Disables PBP (Picture-by-Picture) mode
    /// </summary>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    void DisablePbp(int monitorIndex = 0);

    /// <summary>
    /// Gets the right input source when PBP is enabled
    /// </summary>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    MonitorInput GetPbpRightInput(int monitorIndex = 0);

    /// <summary>
    /// Sets the right input source for PBP mode
    /// </summary>
    /// <param name="input">Input source for the right side</param>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    void SetPbpRightInput(MonitorInput input, int monitorIndex = 0);

    /// <summary>
    /// Gets a VCP feature value
    /// </summary>
    /// <param name="vcpCode">VCP feature code</param>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    /// <returns>Tuple with current and maximum values</returns>
    (uint currentValue, uint maximumValue) GetVcpFeature(byte vcpCode, int monitorIndex = 0);

    /// <summary>
    /// Sets a VCP feature value with retry logic
    /// </summary>
    /// <param name="vcpCode">VCP feature code</param>
    /// <param name="value">Value to set</param>
    /// <param name="monitorIndex">Monitor index (0-based)</param>
    /// <param name="maxRetries">Maximum number of retry attempts</param>
    void SetVcpFeature(byte vcpCode, uint value, int monitorIndex = 0, int maxRetries = 5);
}
