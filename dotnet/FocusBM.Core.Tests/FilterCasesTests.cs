using System.Text.Json;
using FocusBM.Core;
using Xunit;

namespace FocusBM.Core.Tests;

// Shared with Tests/focusbmTests/FilterCasesTests.swift via spec/filter-cases.json.
public class FilterCasesTests
{
    private sealed record FuzzyCase(string Name, string Text, string Query, int? Expected);
    private sealed record RowCase(string Name, string[] Texts, string Query, int? Expected);
    private sealed record RenumberCase(string Name, string Query, int Count, string?[]? Labels);
    private sealed record Cases(FuzzyCase[] Fuzzy, RowCase[] Rows, RenumberCase[] Renumber);

    private static readonly Cases All = JsonSerializer.Deserialize<Cases>(
        File.ReadAllText(FixturePath()),
        new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;

    // Why: Instead of a csproj <None> link, adopted the repo-root walk-up. Reason: matches ExampleYamlTests and needs no build change.
    private static string FixturePath()
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
        {
            var path = Path.Combine(dir.FullName, "spec", "filter-cases.json");
            if (File.Exists(path)) return path;
        }
        throw new FileNotFoundException("spec/filter-cases.json not found above " + AppContext.BaseDirectory);
    }

    [Fact]
    public void FuzzyScore_MatchesSharedCases()
    {
        foreach (var c in All.Fuzzy)
            Assert.True(BookmarkSearcher.FuzzyScore(c.Text, c.Query) == c.Expected, c.Name);
    }

    [Fact]
    public void ScoreTexts_MatchesSharedCases()
    {
        foreach (var c in All.Rows)
            Assert.True(BookmarkSearcher.ScoreTexts(c.Texts, c.Query) == c.Expected, c.Name);
    }

    [Fact]
    public void FilteredNumberLabels_MatchesSharedCases()
    {
        foreach (var c in All.Renumber)
        {
            var actual = ShortcutAssigner.FilteredNumberLabels(c.Query, c.Count);
            Assert.True(c.Labels is null ? actual is null : actual is not null && actual.SequenceEqual(c.Labels), c.Name);
        }
    }
}
