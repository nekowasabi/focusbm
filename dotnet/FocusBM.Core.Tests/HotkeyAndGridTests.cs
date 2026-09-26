using FocusBM.Core;
using Xunit;

namespace FocusBM.Core.Tests;

public class HotkeyAndGridTests
{
    [Fact] public void CmdMappingUndecided_PreservesCommandModifier()
    {
        var hk = HotkeyParser.Parse("cmd+shift+k", CmdMapping.Undecided);
        Assert.True(hk.Modifiers.HasFlag(HotkeyModifiers.Command));
        Assert.Equal("K", hk.Key);
    }
    [Fact] public void CmdMappingControl_MapsCommandToControl()
    {
        var hk = HotkeyParser.Parse("cmd space", CmdMapping.MacCommandToControl);
        Assert.True(hk.Modifiers.HasFlag(HotkeyModifiers.Control));
        Assert.False(hk.Modifiers.HasFlag(HotkeyModifiers.Command));
    }
    [Fact] public void GridNavigation_TwoColumnsMovesByRows()
    {
        Assert.Equal(2, GridNavigator.Move(0, 5, 2, NavigationCommand.Down));
        Assert.Equal(0, GridNavigator.Move(1, 5, 2, NavigationCommand.Up));
    }

    [Theory]
    [InlineData(0, 5, 1, true)]
    [InlineData(1, 5, 1, false)]
    [InlineData(0, 5, 2, true)]
    [InlineData(1, 5, 2, true)]
    [InlineData(2, 5, 2, false)]
    [InlineData(0, 0, 1, true)]
    public void FirstRow_IsTheSearchBoxReturnBoundary(int index, int count, int columns, bool expected) =>
        Assert.Equal(expected, GridNavigator.IsOnFirstRow(index, count, columns));
    [Fact] public void ShortcutDuplicate_FirstExplicitWins()
    {
        var items = new [] { new Bookmark("a", "App", "", Shortcut:"g"), new Bookmark("b", "App", "", Shortcut:"g") };
        var assigned = ShortcutAssigner.Assign(items);
        Assert.Equal("g", assigned[0].Shortcut);
        Assert.NotEqual("g", assigned[1].Shortcut);
    }
    [Fact] public void Parse_CtrlComma_UsesCommaKey()
    {
        var hk = HotkeyParser.Parse("ctrl+,");
        Assert.Equal(",", hk.Key);
        Assert.True(hk.Modifiers.HasFlag(HotkeyModifiers.Control));
    }

    [Fact] public void AlphabetShortcutLabel_ControlLetterIsCaret()
    {
        Assert.Equal("^s", AlphabetShortcutLabel.FromKey("s", control: true, shift: false, alt: false, windows: false, command: false));
        Assert.Equal("s", AlphabetShortcutLabel.FromKey("s", control: false, shift: false, alt: false, windows: false, command: false));
        Assert.Null(AlphabetShortcutLabel.FromKey("s", control: true, shift: true, alt: false, windows: false, command: false));
    }

    [Fact] public void Assign_YamlCaretShortcut_KeepsLabelAndSkipsAiNumbers()
    {
        var ghost = new Bookmark("ghostty", "Ghostty", "dev", Shortcut: "^s");
        var agent = new Bookmark("wsl:1", "claude @ WezTerm", "", new WslProcessState(1, "claude"));
        var listed = new Bookmark("docs", "Firefox", "dev");
        var assigned = ShortcutAssigner.Assign(new[] { ghost, agent, listed }, new AppSettings(ShowAIAgentShortcut: false));
        Assert.Equal("^s", assigned[0].Shortcut);
        Assert.Equal("⌃s", assigned[0].DisplayLabel);
        Assert.Null(assigned[1].Shortcut);
        Assert.Equal("1", assigned[2].Shortcut);
        Assert.DoesNotContain("1", assigned.Where(a => a.Bookmark == ghost).Select(a => a.Shortcut));
    }

    [Fact] public void Assign_ReservedDigit_SkipsThatNumber()
    {
        var pinned = new Bookmark("one", "App", "", Shortcut: "1");
        var listed = new Bookmark("two", "App", "");
        var assigned = ShortcutAssigner.Assign(new[] { pinned, listed });
        Assert.Equal("1", assigned[0].Shortcut);
        Assert.Equal("2", assigned[1].Shortcut);
    }
}

public class BrowserTabIndexTests
{
    [Theory]
    [InlineData(2, 2)]
    [InlineData(1, 1)]
    [InlineData(8, 8)]
    [InlineData(9, 9)]
    [InlineData(10, 9)]
    public void ControlDigit_MapsFirefoxChromeShortcuts(int tabIndex, int expected) =>
        Assert.Equal(expected, BrowserTabIndex.ControlDigit(tabIndex));

    [Fact] public void ControlDigit_RejectsZeroOrNegative()
    {
        Assert.Null(BrowserTabIndex.ControlDigit(0));
        Assert.Null(BrowserTabIndex.ControlDigit(-1));
    }
}

public class BrowserOpenUrlTests
{
    [Fact] public void PrefersUrlPatternOverNonUrlFallback() =>
        Assert.Equal("https://github.com", BrowserOpenUrl.Resolve("dev", "github.com"));

    [Fact] public void KeepsAbsoluteUrl() =>
        Assert.Equal("https://example.test/a", BrowserOpenUrl.Resolve("https://example.test/a", null));

    [Fact] public void ReturnsNullWhenMissing() =>
        Assert.Null(BrowserOpenUrl.Resolve("", null));
}
