using FocusBM.Core;
using Xunit;

namespace FocusBM.Core.Tests;

public class BookmarkPathsTests
{
    [Fact]
    public void ResolveDefaultYamlPath_PrefersExistingYamlBesideExecutable()
    {
        var directory = Path.Combine(Path.GetTempPath(), "focusbm-paths-" + Guid.NewGuid());
        Directory.CreateDirectory(directory);
        var yaml = Path.Combine(directory, "bookmarks.yml");
        File.WriteAllText(yaml, "bookmarks:\n");
        try
        {
            Assert.Equal(yaml, BookmarkPaths.ResolveDefaultYamlPath(directory));
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    [Fact]
    public void ResolveDefaultLogPath_SitsBesideYaml()
    {
        var directory = Path.Combine(Path.GetTempPath(), "focusbm-paths-" + Guid.NewGuid());
        Directory.CreateDirectory(directory);
        var yaml = Path.Combine(directory, "bookmarks.yml");
        File.WriteAllText(yaml, "bookmarks:\n");
        try
        {
            Assert.Equal(Path.Combine(directory, "focusbm.log"), BookmarkPaths.ResolveDefaultLogPath(directory));
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }
}
