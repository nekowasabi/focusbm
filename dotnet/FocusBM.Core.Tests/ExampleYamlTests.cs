using FocusBM.Core;
using Xunit;

namespace FocusBM.Core.Tests;

public class ExampleYamlTests
{
    [Fact]
    public void WindowsExample_DeserializesRealSchema()
    {
        var yaml = File.ReadAllText(Path.Combine(RepoRoot(), "bookmarks.example.windows.yml"));
        var store = new BookmarkYamlSerializer().Deserialize(yaml);
        Assert.True(store.Bookmarks.Count >= 3, $"windows example bookmark count {store.Bookmarks.Count}");
        Assert.Contains(store.Bookmarks, b => b.State is BrowserAppState);
        Assert.Contains(store.Bookmarks, b => b.State is AppOnlyState);
        Assert.Contains(store.Bookmarks, b => b.State is WslNvimState);
        var browser = Assert.IsType<BrowserAppState>(store.Bookmarks.First(b => b.State is BrowserAppState).State);
        Assert.Equal("github.com", browser.UrlPattern);
        Assert.Equal("GitHub", browser.Title);
        Assert.True(store.Settings!.EffectiveHotkey.Modifiers.HasFlag(HotkeyModifiers.Control));
        Assert.True(store.Settings.EffectiveHotkey.Modifiers.HasFlag(HotkeyModifiers.Alt));
    }

    [Fact]
    public void MacExample_DeserializesSharedAndItermNvimStates()
    {
        var yaml = File.ReadAllText(Path.Combine(RepoRoot(), "bookmarks.example.yml"));
        var store = new BookmarkYamlSerializer().Deserialize(yaml);
        Assert.True(store.Bookmarks.Count >= 3, $"mac example bookmark count {store.Bookmarks.Count}");
        Assert.Contains(store.Bookmarks, b => b.State is BrowserAppState);
        Assert.Contains(store.Bookmarks, b => b.State is AppOnlyState);
        Assert.Contains(store.Bookmarks, b => b.State is WslNvimState);
        Assert.DoesNotContain(yaml.Split('\n'), line => line.TrimStart().StartsWith("- title:"));
    }

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var makefile = Path.Combine(dir.FullName, "Makefile");
            var example = Path.Combine(dir.FullName, "bookmarks.example.yml");
            if (File.Exists(makefile) && File.Exists(example)) return dir.FullName;
            dir = dir.Parent;
        }
        throw new DirectoryNotFoundException("focusbm repo root (Makefile + bookmarks.example.yml)");
    }
}
