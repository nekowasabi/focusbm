using System.Text.RegularExpressions;

namespace FocusBM.Core;

public static class Redactor
{
    // Why: Instead of redacting escape-free text only, adopted stopping matches at ESC. Reason: preview captures carry SGR codes (capture-pane -e) and a swallowed reset would bleed color into the rest of the pane.
    private static readonly Regex Url = new(@"https?://[^\s""'\u001b]+", RegexOptions.Compiled | RegexOptions.IgnoreCase);
    private static readonly Regex HomePath = new(@"[A-Za-z]:\\Users\\[^\\\s\u001b]+|/home/[^/\s\u001b]+", RegexOptions.Compiled | RegexOptions.IgnoreCase);
    public static string Mask(string? text)
    {
        if (string.IsNullOrEmpty(text)) return string.Empty;
        var s = Url.Replace(text, "<redacted-url>");
        s = HomePath.Replace(s, "<redacted-user-path>");
        return s;
    }
}
