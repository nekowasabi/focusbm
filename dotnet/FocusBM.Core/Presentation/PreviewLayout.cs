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

    // Why: tmux capture-pane fills the pane height with blank rows below the prompt.
    //      Scrolling to the absolute bottom then shows an empty card.
    public static string TrimTrailingBlankLines(string? text)
    {
        if (string.IsNullOrEmpty(text)) return text ?? string.Empty;
        var lines = text.Split('\n');
        var end = lines.Length;
        while (end > 0 && string.IsNullOrWhiteSpace(lines[end - 1].TrimEnd('\r')))
            end--;
        if (end == 0) return string.Empty;
        return end == lines.Length ? text : string.Join('\n', lines, 0, end);
    }
}
