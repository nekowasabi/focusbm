namespace FocusBM.Core;

public static class GitHubPullRequest
{
    public const string SupportedHost = "github.com";

    public static bool SupportsAgent(string? command) =>
        string.Equals(command, "claude", StringComparison.OrdinalIgnoreCase)
        || string.Equals(command, "codex", StringComparison.OrdinalIgnoreCase);

    public static Uri? Unique(IEnumerable<string?> values)
    {
        var urls = values.Select(Validate).Where(url => url is not null).Cast<Uri>().DistinctBy(url => url.AbsoluteUri).ToArray();
        return urls.Length == 1 ? urls[0] : null;
    }

    public static Uri? Validate(string? value)
    {
        var trimmed = value?.Trim();
        if (!Uri.TryCreate(trimmed, UriKind.Absolute, out var uri)
            || !string.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase)
            || !string.Equals(uri.Host, SupportedHost, StringComparison.OrdinalIgnoreCase)
            || !string.Equals(uri.Authority, uri.Host, StringComparison.OrdinalIgnoreCase)
            || !string.IsNullOrEmpty(uri.UserInfo)
            || !string.IsNullOrEmpty(uri.Query)
            || !string.IsNullOrEmpty(uri.Fragment)) return null;
        var authority = trimmed![(trimmed.IndexOf("://", StringComparison.Ordinal) + 3)..].Split('/', '?', '#')[0];
        if (authority.Contains(':')) return null;

        var parts = uri.AbsolutePath.Split('/');
        if (parts.Length != 5
            || parts[0].Length != 0
            || string.IsNullOrWhiteSpace(parts[1])
            || string.IsNullOrWhiteSpace(parts[2])
            || !string.Equals(parts[3], "pull", StringComparison.OrdinalIgnoreCase)
            || !int.TryParse(parts[4], out var number)
            || number <= 0) return null;
        return uri;
    }
}
