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
