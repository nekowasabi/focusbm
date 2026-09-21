namespace FocusBM.Core;

public static class BrowserTabIndex
{
    public static int? ControlDigit(int tabIndex)
    {
        if (tabIndex <= 0) return null;
        return tabIndex >= 9 ? 9 : tabIndex;
    }
}

public static class BrowserOpenUrl
{
    public static string? Resolve(string? url, string? urlPattern)
    {
        var raw = !string.IsNullOrWhiteSpace(urlPattern) ? urlPattern : url;
        if (string.IsNullOrWhiteSpace(raw)) return null;
        raw = raw.Trim();
        if (raw.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
            raw.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
            return raw;
        return "https://" + raw;
    }
}
