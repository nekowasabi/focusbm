namespace FocusBM.Core;

/// <summary>
/// Visibility rules for the search panel. Hide-on-deactivate must not run
/// while the panel is being presented, or Show immediately undoes itself.
/// </summary>
public static class PanelVisibility
{
    public static bool ShouldHideOnDeactivate(bool isVisible, bool allowClose, bool suppressDeactivate) =>
        isVisible && !allowClose && !suppressDeactivate;
}

/// <summary>
/// WSL/tmux discovery is too slow to run on Present(). Poll in the background
/// instead: faster while the panel is up, slower while it is hidden.
/// </summary>
public static class AgentRefreshSchedule
{
    public static readonly TimeSpan VisibleInterval = TimeSpan.FromSeconds(3);
    public static readonly TimeSpan HiddenInterval = TimeSpan.FromSeconds(15);

    public static TimeSpan Interval(bool panelVisible) =>
        panelVisible ? VisibleInterval : HiddenInterval;
}
