using FocusBM.Core;
using Xunit;

namespace FocusBM.Core.Tests;

public sealed class GitHubPullRequestTests
{
    [Fact]
    public void Validate_AcceptsOnlyCanonicalPullRequestUrl()
    {
        var url = GitHubPullRequest.Validate("https://github.com/org/repo/pull/42");

        Assert.NotNull(url);
        Assert.Equal("https://github.com/org/repo/pull/42", url!.AbsoluteUri);
    }

    [Theory]
    [InlineData("http://github.com/org/repo/pull/42")]
    [InlineData("https://gitlab.com/org/repo/pull/42")]
    [InlineData("https://github.com:443/org/repo/pull/42")]
    [InlineData("https://github.com/org/repo/pull/42?tab=files")]
    [InlineData("https://github.com/org/repo/pull/42/")]
    [InlineData("https://github.com/org/repo/issues/42")]
    public void Validate_RejectsNonCanonicalUrl(string value) => Assert.Null(GitHubPullRequest.Validate(value));

    [Theory]
    [InlineData("claude", true)]
    [InlineData("codex", true)]
    [InlineData("opencode", false)]
    public void SupportsAgent_UsesOnlyAgentsWithStablePrResolution(string command, bool expected) =>
        Assert.Equal(expected, GitHubPullRequest.SupportsAgent(command));

    [Fact]
    public void Unique_RejectsConflictingCandidates()
    {
        const string first = "https://github.com/org/repo/pull/42";
        Assert.Equal(first, GitHubPullRequest.Unique(new[] { first, first })!.AbsoluteUri);
        Assert.Null(GitHubPullRequest.Unique(new[] { first, "https://github.com/org/repo/pull/43" }));
    }
}
