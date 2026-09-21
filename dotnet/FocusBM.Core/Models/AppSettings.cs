namespace FocusBM.Core;

public enum CmdMapping
{
    Undecided,
    MacCommandToControl,
    MacCommandToWindows
}

public sealed record HotkeySettings(string Key = "Space", HotkeyModifiers Modifiers = HotkeyModifiers.Control | HotkeyModifiers.Alt);

public sealed record BrowserCdpSettings(
    bool Enabled = false,
    string? Endpoint = null,
    string? ProfilePath = null,
    bool RequireLoopback = true,
    bool RequireProfileMarker = true,
    string MarkerFileName = ".focusbm-cdp-profile",
    bool RequireKnownBrowserOwner = true);

public sealed record WslSettings(
    bool Enabled = false,
    string? Distribution = null,
    string? User = null,
    IReadOnlyList<string>? AllowedDistributions = null,
    IReadOnlyList<string>? AllowedUsers = null);

public sealed record AppSettings(
    HotkeySettings? Hotkey = null,
    CmdMapping CmdMapping = CmdMapping.Undecided,
    bool? ShowTmuxAgents = null,
    bool? ShowWslAgents = null,
    bool? ShowAIAgentShortcut = null,
    int BookmarkListColumns = 1,
    bool ImeRestoreEnabled = false,
    bool VirtuaWinEnabled = true,
    BrowserCdpSettings? BrowserCdp = null,
    WslSettings? Wsl = null,
    string OpenSessionPullRequestHotkey = "ctrl+p",
    string ForceReloadAgentsHotkey = "ctrl+alt+r",
    string PreviewHoveredAgentHotkey = "ctrl+p",
    string PreviewAllAgentsHotkey = "ctrl+v",
    double? PanelWidth = null,
    double? PanelHeight = null,
    double? ListFontSize = null,
    string? FontName = null,
    double? PreviewWidth = null,
    double? PreviewHeight = null,
    double? PreviewFontSize = null,
    string? PreviewFontName = null,
    int? DisplayNumber = null,
    bool? AutoExecuteOnSingleResult = null,
    double? AutoExecuteDelay = null,
    bool? DirectNumberKeys = null)
{
    public HotkeySettings EffectiveHotkey => Hotkey ?? new HotkeySettings();
    public int NormalizedColumns => BookmarkListColumns <= 1 ? 1 : 2;
    public double EffectivePanelWidth => PanelWidth is > 0 ? PanelWidth.Value : NormalizedColumns == 2 ? 800 : 500;
    public double EffectivePanelHeight => PanelHeight is > 0 ? PanelHeight.Value : 400;
    public double EffectiveListFontSize => ListFontSize is > 0 ? ListFontSize.Value : 14;
    public double EffectivePreviewFontSize => PreviewFontSize is > 0 ? PreviewFontSize.Value : 14;
    public string? EffectivePreviewFontName =>
        !string.IsNullOrWhiteSpace(PreviewFontName) ? PreviewFontName
        : !string.IsNullOrWhiteSpace(FontName) ? FontName
        : null;
    public double EffectiveAutoExecuteDelay => AutoExecuteDelay is > 0 ? AutoExecuteDelay.Value : 0.3;
    public bool EffectiveDirectNumberKeys => DirectNumberKeys ?? true;
    public bool EffectiveShowAIAgentShortcut => ShowAIAgentShortcut ?? true;
    public bool EffectiveShowTmuxAgents => ShowTmuxAgents ?? true;
    public bool EffectiveShowWslAgents => ShowWslAgents ?? true;
}

[Flags]
public enum HotkeyModifiers
{
    None = 0,
    Command = 1 << 0,
    Control = 1 << 1,
    Option = 1 << 2,
    Shift = 1 << 3,
    Alt = Option,
    Windows = 1 << 4
}
