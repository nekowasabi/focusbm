using System.Text.RegularExpressions;

namespace FocusBM.Core;

public static class Redactor
{
    private static readonly Regex Url = new(@"https?://[^\s""']+", RegexOptions.Compiled | RegexOptions.IgnoreCase);
    private static readonly Regex HomePath = new(@"[A-Za-z]:\\Users\\[^\\\s]+|/home/[^/\s]+", RegexOptions.Compiled | RegexOptions.IgnoreCase);
    public static string Mask(string? text)
    {
        if (string.IsNullOrEmpty(text)) return string.Empty;
        var s = Url.Replace(text, "<redacted-url>");
        s = HomePath.Replace(s, "<redacted-user-path>");
        return s;
    }
}
