using FocusBM.Core;
using Xunit;

namespace FocusBM.Core.Tests;

// Tier-A: pure logic — zero Win32/P-Invoke. Runnable in WSL2 via dotnet.exe.
// Parity oracle derived from Swift Models.swift L251-270 algorithm.

/// <summary>
/// FuzzyScore branch-coverage + ordering oracle (AC-3a, AC-3b).
/// </summary>
public class FuzzyScoreTests
{
    // AC-3a case 1: empty query → 0 (not null) — L254
    [Fact]
    public void EmptyQuery_Returns0()
    {
        var result = BookmarkSearcher.FuzzyScore("anything", "");
        Assert.Equal(0, result);
    }

    // AC-3a case 2: char not found in order → null — L259
    [Fact]
    public void NoMatch_ReturnsNull()
    {
        var result = BookmarkSearcher.FuzzyScore("abc", "zz");
        Assert.Null(result);
    }

    // AC-3a case 3: first char at startIndex → +10 bonus — L261
    // "document" with query "doc": d is at index 0 → +10 + 3 chars = 13
    [Fact]
    public void StartOfText_ScoreAtLeast11()
    {
        var result = BookmarkSearcher.FuzzyScore("document", "doc");
        Assert.NotNull(result);
        Assert.True(result >= 11, $"Expected >= 11 (start-of-text bonus), got {result}");
    }

    // AC-3a case 4: preceding char ∈ {space,'-','_'} → +5 word-boundary bonus — L264
    // "swift-lang" with query "l": 'l' follows '-' → +5 + 1 = 6
    [Fact]
    public void WordBoundaryAfterDash_IncludesBonus()
    {
        var result = BookmarkSearcher.FuzzyScore("swift-lang", "l");
        Assert.NotNull(result);
        Assert.True(result >= 6, $"Expected >= 6 (word-boundary bonus after '-'), got {result}");
    }

    // AC-3a case 5: case-insensitive match (both lowercased) — L252-253
    [Fact]
    public void CaseInsensitive_UpperQueryMatchesLowerText()
    {
        var result = BookmarkSearcher.FuzzyScore("Document", "DOC");
        Assert.NotNull(result);
    }

    // AC-3b: relative ordering — start/word-boundary match must score strictly
    // higher than scattered mid-word match for the same query.
    // "document" vs "xdyozc": both contain 'd','o','c' as subsequence but
    // "document" starts at index 0 (+10), "xdyozc" does not.
    [Fact]
    public void Ordering_StartMatchScoresHigherThanScattered()
    {
        var scoreA = BookmarkSearcher.FuzzyScore("document", "doc");
        var scoreB = BookmarkSearcher.FuzzyScore("xdyozc", "doc");
        Assert.NotNull(scoreA);
        Assert.NotNull(scoreB);
        Assert.True(scoreA > scoreB,
            $"Expected FuzzyScore(\"document\",\"doc\") > FuzzyScore(\"xdyozc\",\"doc\"), got {scoreA} vs {scoreB}");
    }
}

/// <summary>
/// Filter parity oracle: 5 cases transcribed from Swift BookmarkRestorerTests.swift L17-76 (AC-3c).
/// Also satisfies AC-4 (FuzzyScore exercised through Filter) and AC-3d (order assertion).
/// </summary>
public class FilterTests
{
    // Helpers to build test Bookmarks with the 3 relevant fields
    private static Bookmark B(string id, string appName, string context)
        => new Bookmark(id, appName, context);

    // AC-3c case 1 (L17-27): empty query → all bookmarks returned
    [Fact]
    public void EmptyQuery_ReturnsAll()
    {
        var bookmarks = new[]
        {
            B("work", "iTerm2", "dev"),
            B("docs", "Safari", "work"),
        };
        var result = BookmarkSearcher.Filter(bookmarks, "");
        Assert.Equal(2, result.Count);
    }

    // AC-3c case 2 (L29-40): query "doc" matches id "docs" — AC-4 satisfied
    [Fact]
    public void FilterById_ReturnsMatchingBookmark()
    {
        var bookmarks = new[]
        {
            B("work-term", "iTerm2", "dev"),
            B("docs", "Safari", "work"),
        };
        var result = BookmarkSearcher.Filter(bookmarks, "doc");
        var only = Assert.Single(result);
        Assert.Equal("docs", only.Id);
    }

    // AC-3c case 3 (L42-53): query "safari" matches appName "Safari"
    [Fact]
    public void FilterByAppName_ReturnsMatchingBookmark()
    {
        var bookmarks = new[]
        {
            B("work", "iTerm2", "dev"),
            B("docs", "Safari", "work"),
        };
        var result = BookmarkSearcher.Filter(bookmarks, "safari");
        var only = Assert.Single(result);
        Assert.Equal("docs", only.Id);
    }

    // AC-3c case 4 (L55-66): query "dev" matches context "dev"
    [Fact]
    public void FilterByContext_ReturnsMatchingBookmark()
    {
        var bookmarks = new[]
        {
            B("work", "iTerm2", "dev"),
            B("docs", "Safari", "work"),
        };
        var result = BookmarkSearcher.Filter(bookmarks, "dev");
        var only = Assert.Single(result);
        Assert.Equal("work", only.Id);
    }

    // AC-3c case 5 (L68-76): case-insensitive — "SAFARI" matches appName "Safari"
    [Fact]
    public void FilterCaseInsensitive_UpperQueryMatchesLowerAppName()
    {
        var bookmarks = new[]
        {
            B("docs", "Safari", "work"),
        };
        var result = BookmarkSearcher.Filter(bookmarks, "SAFARI");
        Assert.Single(result);
    }

    // AC-3d: result ORDER — higher-scoring match appears at index 0
    // "document" with "doc" starts at index 0 (+10 bonus) → higher score than "xdyozc"
    [Fact]
    public void FilterOrder_HigherScoreFirst()
    {
        var bookmarks = new[]
        {
            B("xdyozc", "app", "ctx"),  // scattered match — lower score
            B("document", "app", "ctx"), // start match — higher score
        };
        var result = BookmarkSearcher.Filter(bookmarks, "doc");
        Assert.Equal(2, result.Count);
        Assert.Equal("document", result[0].Id); // highest-scoring must be first
    }

    // Regression: agent Context packs diagnostics (window name, masked cwd, masked
    // command line) whose scattered tokens false-positive — "claudoctrine" kept a
    // "changelog" pane via window claude + repos/changelog + <redacted-user-path>/bin/claude.
    // macOS searches the display name only for tmux agents, so Context is not scored.
    [Fact]
    public void Filter_TmuxAgent_NoiseInContextDoesNotMatch()
    {
        var changelog = new Bookmark(
            "tmux:12:1:%40",
            "claude @ WezTerm — changelog",
            "12:1.%40 · window claude · cwd <redacted-user-path>/repos/changelog · process node <redacted-user-path>/.local/bin/claude",
            new WslProcessState(42, "claude", "WezTerm", "%40", "12", "1", "/home/takets/repos/changelog"));
        var doctrine = new Bookmark(
            "tmux:12:1:%41",
            "claude @ WezTerm — doctrine-mcp",
            "12:1.%41 · window claude · cwd <redacted-user-path>/repos/doctrine-mcp · process node <redacted-user-path>/.local/bin/claude",
            new WslProcessState(43, "claude", "WezTerm", "%41", "12", "1", "/home/takets/repos/doctrine-mcp"));
        var result = BookmarkSearcher.Filter(new[] { changelog, doctrine }, "claudoctrine");
        var only = Assert.Single(result);
        Assert.Equal("tmux:12:1:%41", only.Id);
    }

    // Standalone (non-tmux) agents search "command cwd terminal" like macOS aiProcess,
    // so a path fragment absent from AppName still matches.
    [Fact]
    public void Filter_StandaloneWslAgent_MatchesWorkingDirectoryPath()
    {
        var agent = new Bookmark(
            "wsl:42",
            "claude @ WezTerm — changelog",
            "no tmux · cwd <redacted-user-path>/repos/changelog · process node <redacted-user-path>/.local/bin/claude · PID 42",
            new WslProcessState(42, "claude", "WezTerm", WorkingDirectory: "/home/takets/repos/changelog"));
        var result = BookmarkSearcher.Filter(new[] { agent }, "takets/chang");
        Assert.Single(result);
    }

    // The same Context noise must not match standalone agents either: "process"
    // appears only in the diagnostic Context.
    [Fact]
    public void Filter_StandaloneWslAgent_ContextOnlyNoiseDoesNotMatch()
    {
        var agent = new Bookmark(
            "wsl:42",
            "claude @ WezTerm — changelog",
            "no tmux · cwd <redacted-user-path>/repos/changelog · process node <redacted-user-path>/.local/bin/claude · PID 42",
            new WslProcessState(42, "claude", "WezTerm", WorkingDirectory: "/home/takets/repos/changelog"));
        var result = BookmarkSearcher.Filter(new[] { agent }, "process");
        Assert.Empty(result);
    }
}
