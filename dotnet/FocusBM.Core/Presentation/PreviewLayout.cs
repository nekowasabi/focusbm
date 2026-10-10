using System.Text.RegularExpressions;

namespace FocusBM.Core;

/// <summary>
/// Preview overlay size in the same coordinate space as the target monitor.
/// Omitted YAML width/height means the monitor maximum. Ctrl+P centers a single card.
/// </summary>
public static class PreviewLayout
{
    public static (double Width, double Height) SizeOnMonitor(
        double monitorWidth,
        double monitorHeight,
        double? previewWidth,
        double? previewHeight,
        bool fillMonitor = false)
    {
        if (fillMonitor)
            return (Math.Max(0, monitorWidth), Math.Max(0, monitorHeight));
        var width = previewWidth is > 0 ? Math.Min(previewWidth.Value, monitorWidth) : monitorWidth;
        var height = previewHeight is > 0 ? Math.Min(previewHeight.Value, monitorHeight) : monitorHeight;
        if (width < 0) width = 0;
        if (height < 0) height = 0;
        return (width, height);
    }

    public static (double X, double Y) CenterOrigin(
        double monitorWidth,
        double monitorHeight,
        double cardWidth,
        double cardHeight)
    {
        return ((monitorWidth - cardWidth) / 2, (monitorHeight - cardHeight) / 2);
    }

    public static int MaxLineCount(IEnumerable<string> texts) =>
        texts.Select(text => string.IsNullOrEmpty(text) ? 0 : text.Split('\n').Length).DefaultIfEmpty(0).Max();

    public static double IndexNumberFontSize(double bodyHeight) => Math.Max(1, Math.Min(96, bodyHeight * 0.4));

    // Why: every tile puts its index at the same height, level with the end of the longest output,
    //      so the numbers line up across panes yet stay next to where reading ends.
    public static double IndexNumberTop(int maxLineCount, double lineHeight, double bodyHeight)
    {
        const double textInset = 10;
        const double bottomInset = 8;
        var number = IndexNumberFontSize(bodyHeight);
        var top = textInset + maxLineCount * lineHeight - number;
        return Math.Max(0, Math.Min(top, bodyHeight - number - bottomInset));
    }

    // Why: the preview shows the conversation, not the input box and footer below it.
    //      Claude: `───` / `❯` / `───`. Grok Build: `╭──╮` / `│ ❯ │` / `╰──╯`.
    //      Codex has no border; its composer is a `›` line after a blank line.
    //      `❯ 1.` / `› 1.` are approval choices, not the input box, so they are never cut.
    public static string TextAbovePrompt(string? text)
    {
        if (string.IsNullOrEmpty(text)) return TrimTrailingBlankLines(text);
        var lines = text.Split('\n').Where(line =>
        {
            var stripped = AnsiText.Strip(line).Trim();
            return !stripped.StartsWith("jev gate:", StringComparison.Ordinal)
                && !stripped.StartsWith("[-] jev gate:", StringComparison.Ordinal);
        }).ToArray();
        var plain = lines.Select(line => AnsiText.Strip(line).Trim()).ToArray();
        static bool IsRule(string line) => line.Length > 0 && line.All(c => c is '─' or '╭' or '╮');
        var prompt = Array.FindLastIndex(plain, line =>
        {
            var body = line.Trim('│', ' ', '\t');
            return (body.StartsWith('❯') || body.StartsWith('›')) && !Regex.IsMatch(body, @"^[❯›]\s*\d+\.");
        });
        var all = TrimTrailingBlankLines(string.Join('\n', lines));
        if (prompt < 0) return all;
        var cut = prompt;
        while (cut > 0 && IsRule(plain[cut - 1])) cut--;
        var isCodexComposer = plain[prompt].StartsWith('›') && (prompt == 0 || plain[prompt - 1].Length == 0);
        if ((cut == prompt && !isCodexComposer) || plain.Take(cut).All(line => line.Length == 0)) return all;
        return TrimTrailingBlankLines(string.Join('\n', lines, 0, cut));
    }

    // Why: tmux capture-pane fills the pane height with blank rows below the prompt.
    //      Scrolling to the absolute bottom then shows an empty card.
    public static string TrimTrailingBlankLines(string? text)
    {
        if (string.IsNullOrEmpty(text)) return text ?? string.Empty;
        var lines = text.Split('\n');
        var end = lines.Length;
        while (end > 0 && string.IsNullOrWhiteSpace(AnsiText.Strip(lines[end - 1])))
            end--;
        if (end == 0) return string.Empty;
        return end == lines.Length ? text : string.Join('\n', lines, 0, end);
    }
}
