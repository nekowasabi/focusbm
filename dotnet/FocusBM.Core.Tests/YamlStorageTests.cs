using FocusBM.Core;
using Xunit;

namespace FocusBM.Core.Tests;

public class YamlStorageTests
{
    [Fact] public void RoundTrip_PreservesBookmarksAndSettings()
    {
        var serializer = new BookmarkYamlSerializer();
        var store = new BookmarkStore(new AppSettings(BookmarkListColumns:2), new [] { new Bookmark("docs", "Chrome", "https://example.test", new BrowserAppState("https://example.test"), Shortcut:"d", ExecuteOnToggleRepress: true) });
        var yaml = serializer.Serialize(store);
        var round = serializer.Deserialize(yaml);
        Assert.Single(round.Bookmarks);
        Assert.Equal("docs", round.Bookmarks[0].Id);
        Assert.IsType<BrowserAppState>(round.Bookmarks[0].State);
        Assert.True(round.Bookmarks[0].ExecuteOnToggleRepress);
        Assert.Equal(2, round.Settings!.NormalizedColumns);
    }
    [Fact] public void LegacyTitleUrl_MigratesWithoutDroppingValues()
    {
        var store = new BookmarkYamlSerializer().Deserialize("bookmarks:\n  - title: docs\n    appName: Browser\n    url: https://example.test\n");
        Assert.Equal("docs", store.Bookmarks[0].Id);
        Assert.Equal("https://example.test", store.Bookmarks[0].Context);
    }
}

public class SettingsRoundTripTests
{
    [Fact] public void CdpAndWslSettings_RoundTrip()
    {
        var serializer = new BookmarkYamlSerializer();
        var store = new BookmarkStore(new AppSettings(
            BrowserCdp: new BrowserCdpSettings(Enabled: true, Endpoint: "http://127.0.0.1:9222", ProfilePath: "C:/tmp/focusbm-cdp", RequireKnownBrowserOwner: true),
            Wsl: new WslSettings(Enabled: true, Distribution: "Ubuntu", User: "takets"),
            ShowWslAgents: false,
            VirtuaWinEnabled: true,
            OpenSessionPullRequestHotkey: "alt+p",
            ForceReloadAgentsHotkey: "ctrl+shift+r"), Array.Empty<Bookmark>());
        var yaml = serializer.Serialize(store);
        var round = serializer.Deserialize(yaml);
        Assert.True(round.Settings!.BrowserCdp!.Enabled);
        Assert.True(round.Settings.VirtuaWinEnabled);
        Assert.Equal("http://127.0.0.1:9222", round.Settings.BrowserCdp.Endpoint);
        Assert.True(round.Settings.BrowserCdp.RequireKnownBrowserOwner);
        Assert.True(round.Settings.Wsl!.Enabled);
        Assert.Equal("Ubuntu", round.Settings.Wsl.Distribution);
        Assert.False(round.Settings.EffectiveShowWslAgents);
        Assert.Equal("alt+p", round.Settings.OpenSessionPullRequestHotkey);
        Assert.Equal("ctrl+shift+r", round.Settings.ForceReloadAgentsHotkey);
    }
    [Fact]
    public void WslProcessState_RoundTripsAndPreservesVisibilityFlag()
    {
        var store = new BookmarkStore(
            new AppSettings(ShowWslAgents: false),
            new[] { new Bookmark("wsl:42", "wsl", "claude --project", new WslProcessState(42, "claude --project", "WezTerm", "%7", "dev", "3", "/home/takets/project"), LowPriority: true) });

        var serializer = new BookmarkYamlSerializer();
        var yaml = serializer.Serialize(store);
        var round = serializer.Deserialize(yaml);

        Assert.Contains("showWslAgents: false", yaml);
        var state = Assert.IsType<WslProcessState>(Assert.Single(round.Bookmarks).State);
        Assert.Equal(42, state.Pid);
        Assert.Equal("claude --project", state.Command);
        Assert.Equal("WezTerm", state.Terminal);
        Assert.Equal("%7", state.TmuxPaneId);
        Assert.Equal("dev", state.TmuxSession);
        Assert.Equal("3", state.TmuxWindow);
        Assert.Equal("/home/takets/project", state.WorkingDirectory);
        Assert.True(round.Bookmarks[0].LowPriority);
    }

    [Fact]
    public void WslNvimState_RoundTripsItsValidatedFields()
    {
        var store = new BookmarkStore(new AppSettings(), new[]
        {
            new Bookmark("nvim", "tmux", "editor", new WslNvimState("/home/takets/project", "write"))
        });

        var round = new BookmarkYamlSerializer().Deserialize(new BookmarkYamlSerializer().Serialize(store));
        var state = Assert.IsType<WslNvimState>(Assert.Single(round.Bookmarks).State);

        Assert.Equal("/home/takets/project", state.WorkingDirectory);
        Assert.Equal("write", state.ExCommand);
    }

    [Fact]
    public void LegacyMigration_RenamesV1Keys()
    {
        var migrated = new BookmarkYamlSerializer().MigrateV1Yaml("- title: docs\n  url: https://example.test\n");

        Assert.Contains("- id: docs", migrated);
        Assert.Contains("context: https://example.test", migrated);
    }
}

public class UnknownFieldPreservationTests
{
    [Fact] public void BookmarkUnknownFields_RoundTrip()
    {
        var yaml = "bookmarks:\n  - id: docs\n    appName: Browser\n    context: work\n    customOptional: keep-me\n    state:\n      type: mystery\n      customState: keep-state\n";
        var serializer = new BookmarkYamlSerializer();
        var store = serializer.Deserialize(yaml);
        Assert.Equal("keep-me", store.Bookmarks[0].UnknownFields!["customOptional"]);
        var unknown = Assert.IsType<UnknownAppState>(store.Bookmarks[0].State);
        Assert.Equal("keep-state", unknown.Fields["customState"]);
        var output = serializer.Serialize(store);
        Assert.Contains("customOptional: keep-me", output);
        Assert.Contains("customState: keep-state", output);
    }
}

public class HotkeySettingsRoundTripTests
{
    [Fact] public void HotkeySettings_RoundTrip()
    {
        var serializer = new BookmarkYamlSerializer();
        var store = new BookmarkStore(new AppSettings(Hotkey: new HotkeySettings("F8", HotkeyModifiers.Control | HotkeyModifiers.Shift)), Array.Empty<Bookmark>());
        var yaml = serializer.Serialize(store);
        var round = serializer.Deserialize(yaml);
        Assert.Equal("F8", round.Settings!.EffectiveHotkey.Key);
        Assert.True(round.Settings.EffectiveHotkey.Modifiers.HasFlag(HotkeyModifiers.Control));
        Assert.True(round.Settings.EffectiveHotkey.Modifiers.HasFlag(HotkeyModifiers.Shift));
        Assert.Contains("togglePanel:", yaml);
        Assert.DoesNotContain("hotkeyKey:", yaml);
    }

    [Fact]
    public void PreviewHotkeys_NestedYaml_AreReadAndSerialized()
    {
        var yaml = "settings:\n  hotkey:\n    togglePanel: \"ctrl+alt+space\"\n    previewHoveredAgent: \"ctrl+shift+p\"\n    previewAllAgents: \"ctrl+shift+g\"\nbookmarks: []\n";
        var store = new BookmarkYamlSerializer().Deserialize(yaml);
        Assert.Equal("ctrl+shift+p", store.Settings!.PreviewHoveredAgentHotkey);
        Assert.Equal("ctrl+shift+g", store.Settings.PreviewAllAgentsHotkey);

        var round = new BookmarkYamlSerializer().Serialize(store);
        Assert.Contains("previewHoveredAgent:", round);
        Assert.Contains("ctrl+shift+p", round);
        Assert.Contains("previewAllAgents:", round);
        Assert.Contains("ctrl+shift+g", round);
    }

    [Fact] public void TogglePanel_NestedYaml_IsRead()
    {
        var yaml = "settings:\n  hotkey:\n    togglePanel: \"ctrl+shift+f8\"\nbookmarks: []\n";
        var store = new BookmarkYamlSerializer().Deserialize(yaml);
        Assert.Equal("F8", store.Settings!.EffectiveHotkey.Key, ignoreCase: true);
        Assert.True(store.Settings.EffectiveHotkey.Modifiers.HasFlag(HotkeyModifiers.Control));
        Assert.True(store.Settings.EffectiveHotkey.Modifiers.HasFlag(HotkeyModifiers.Shift));
    }

    [Fact] public void TogglePanel_CtrlComma_IsRead()
    {
        var yaml = "settings:\n  hotkey:\n    togglePanel: \"ctrl+,\"\nbookmarks: []\n";
        var store = new BookmarkYamlSerializer().Deserialize(yaml);
        Assert.Equal(",", store.Settings!.EffectiveHotkey.Key);
        Assert.True(store.Settings.EffectiveHotkey.Modifiers.HasFlag(HotkeyModifiers.Control));
        Assert.False(store.Settings.EffectiveHotkey.Modifiers.HasFlag(HotkeyModifiers.Alt));
    }

    [Fact] public void FirefoxTabIndex_RoundTrips()
    {
        var yaml = "bookmarks:\n  - id: firefox-tab-2\n    appName: Firefox\n    context: tab\n    state:\n      type: browser\n      url: \"\"\n      tabIndex: 2\n";
        var store = new BookmarkYamlSerializer().Deserialize(yaml);
        var state = Assert.IsType<BrowserAppState>(Assert.Single(store.Bookmarks).State);
        Assert.Equal(2, state.TabIndex);
        Assert.Equal("Firefox", store.Bookmarks[0].AppName);
    }

    [Fact] public void LegacyHotkeyKeyAndModifiers_StillRead()
    {
        var yaml = "settings:\n  hotkeyKey: Space\n  hotkeyModifiers: Control, Alt\nbookmarks: []\n";
        var store = new BookmarkYamlSerializer().Deserialize(yaml);
        Assert.Equal("Space", store.Settings!.EffectiveHotkey.Key);
        Assert.True(store.Settings.EffectiveHotkey.Modifiers.HasFlag(HotkeyModifiers.Control));
        Assert.True(store.Settings.EffectiveHotkey.Modifiers.HasFlag(HotkeyModifiers.Alt));
    }

    [Fact] public void MacPrivateYamlSettings_AreRead()
    {
        var yaml = """
            settings:
              hotkey:
                togglePanel: ctrl+,
              listFontSize: 18.0
              displayNumber: 1
              panelWidth: 1000
              panelHeight: 1000
              bookmarkListColumns: 2
              fontName: "RuikaMono07 Nerd Font"
              autoExecuteOnSingleResult: true
              autoExecuteDelay: 0.3
              directNumberKeys: true
              showAIAgentShortcut: false
            bookmarks:
              - id: ghostty
                appName: Ghostty
                context: dev
                shortcut: "^s"
                state:
                  type: app
                  windowTitle: ""
              - id: focusbm-nvim
                appName: Windows Terminal
                context: dev
                state:
                  type: itermNvim
              - id: firefox-2
                appName: Firefox
                context: dev
                state:
                  type: browser
                  urlPattern: github.com
                  title: GitHub
                  tabIndex: 2
            """;
        var store = new BookmarkYamlSerializer().Deserialize(yaml);
        var s = store.Settings!;
        Assert.Equal(1000, s.PanelWidth);
        Assert.Equal(1000, s.PanelHeight);
        Assert.Equal(2, s.NormalizedColumns);
        Assert.Equal(18, s.ListFontSize);
        Assert.Equal(22, new AppSettings(ListFontSize: 22.0).EffectiveListFontSize);
        Assert.Equal("RuikaMono07 Nerd Font", s.FontName);
        Assert.True(s.AutoExecuteOnSingleResult);
        Assert.Equal(0.3, s.AutoExecuteDelay);
        Assert.True(s.EffectiveDirectNumberKeys);
        Assert.False(s.EffectiveShowAIAgentShortcut);
        Assert.Equal(",", s.EffectiveHotkey.Key);
        Assert.Equal("^s", store.Bookmarks[0].Shortcut);
        Assert.IsType<WslNvimState>(store.Bookmarks[1].State);
        Assert.Equal(2, Assert.IsType<BrowserAppState>(store.Bookmarks[2].State).TabIndex);
    }

    [Fact] public void PreviewOverlayYamlSettings_AreReadAndSerialized()
    {
        var yaml = """
            settings:
              fontName: "Fira Code"
              previewWidth: 1200
              previewHeight: 800
              previewFontSize: 16
              previewFontName: "JetBrains Mono"
            bookmarks: []
            """;
        var store = new BookmarkYamlSerializer().Deserialize(yaml);
        var s = store.Settings!;
        Assert.Equal(1200, s.PreviewWidth);
        Assert.Equal(800, s.PreviewHeight);
        Assert.Equal(16, s.PreviewFontSize);
        Assert.Equal("Fira Code", s.FontName);
        Assert.Equal("JetBrains Mono", s.PreviewFontName);

        var alias = new BookmarkYamlSerializer().Deserialize("settings:\n  previewHight: 640\nbookmarks: []\n");
        Assert.Equal(640, alias.Settings!.PreviewHeight);

        var round = new BookmarkYamlSerializer().Serialize(store);
        Assert.Contains("previewWidth: 1200", round);
        Assert.Contains("previewHeight: 800", round);
        Assert.Contains("previewFontSize: 16", round);
        Assert.Contains("previewFontName:", round);
        Assert.Contains("JetBrains Mono", round);
        Assert.Contains("fontName:", round);
    }
}
