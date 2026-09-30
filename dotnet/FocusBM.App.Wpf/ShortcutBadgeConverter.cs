using System.Globalization;
using System.Windows.Data;
using FocusBM.Core;

namespace FocusBM.App.Wpf;

/// <summary>Bookmark と Shortcuts コレクションから、その Bookmark に割り当てられたショートカット文字列を解決する。</summary>
public sealed class ShortcutBadgeConverter : IMultiValueConverter
{
    public object Convert(object[] values, Type targetType, object parameter, CultureInfo culture)
    {
        if (values.Length < 2 || values[0] is not Bookmark bookmark || values[1] is not IEnumerable<ShortcutAssignment> shortcuts)
            return string.Empty;
        return shortcuts.FirstOrDefault(a => a.Bookmark == bookmark)?.DisplayLabel ?? string.Empty;
    }

    public object[] ConvertBack(object value, Type[] targetTypes, object parameter, CultureInfo culture) => throw new NotSupportedException();
}

public sealed class AgentStatusDisplayConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (string.Equals(parameter?.ToString(), "label", StringComparison.OrdinalIgnoreCase))
        {
            return value is not TmuxAgentStatus labelStatus ? "—" : AgentStatusText.Label(labelStatus);
        }
        if (value is not TmuxAgentStatus status)
        {
            return string.Equals(parameter?.ToString(), "color", StringComparison.OrdinalIgnoreCase)
                ? new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(34, 34, 34))
                : string.Empty;
        }
        if (string.Equals(parameter?.ToString(), "color", StringComparison.OrdinalIgnoreCase))
        {
            return status switch
            {
                TmuxAgentStatus.Running => new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(77, 242, 115)),
                TmuxAgentStatus.PlanMode or TmuxAgentStatus.AcceptEdits => new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(255, 204, 51)),
                _ => new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(255, 115, 115))
            };
        }
        return status switch
        {
            TmuxAgentStatus.Running => "●",
            TmuxAgentStatus.PlanMode => "⏸",
            TmuxAgentStatus.AcceptEdits => "⏵",
            _ => "○"
        };
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => throw new NotSupportedException();
}

public sealed class NullToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var empty = value is null || value is string s && string.IsNullOrEmpty(s);
        if (string.Equals(parameter?.ToString(), "invert", StringComparison.OrdinalIgnoreCase)) empty = !empty;
        return empty ? System.Windows.Visibility.Collapsed : System.Windows.Visibility.Visible;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => throw new NotSupportedException();
}

public sealed class AppIconConverter : IValueConverter
{
    private static readonly FocusBM.Infrastructure.Windows.Icons.WindowsIconProvider Provider = new();

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var name = value as string ?? string.Empty;
        var result = Provider.GetIconAsync(name).GetAwaiter().GetResult();
        if (result.PngBytes is not { Length: > 0 }) return System.Windows.DependencyProperty.UnsetValue;
        var bitmap = new System.Windows.Media.Imaging.BitmapImage();
        using var stream = new System.IO.MemoryStream(result.PngBytes);
        bitmap.BeginInit();
        bitmap.StreamSource = stream;
        bitmap.CacheOption = System.Windows.Media.Imaging.BitmapCacheOption.OnLoad;
        bitmap.EndInit();
        bitmap.Freeze();
        return bitmap;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => throw new NotSupportedException();
}

/// <summary>Returns min(value × factor, cap) for ConverterParameter "factor,cap"; sizes the preview index rail from the pane height.</summary>
public sealed class FractionCapConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var parts = (parameter as string ?? "1,1").Split(',');
        var factor = double.Parse(parts[0], CultureInfo.InvariantCulture);
        var cap = double.Parse(parts[1], CultureInfo.InvariantCulture);
        var size = value is double d ? Math.Min(d * factor, cap) : cap;
        // Why: FontSize must be > 0; a collapsed pane reports 0 height.
        return Math.Max(size, 1);
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => throw new NotSupportedException();
}

/// <summary>Preview index font size from the pane body height (<see cref="PreviewLayout.IndexNumberFontSize"/>).</summary>
public sealed class IndexNumberFontSizeConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        PreviewLayout.IndexNumberFontSize(value is double height ? height : 0);

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => throw new NotSupportedException();
}

/// <summary>Top margin of the preview index: values are max line count, preview font size, pane body height.</summary>
public sealed class IndexNumberTopConverter : IMultiValueConverter
{
    public object Convert(object[] values, Type targetType, object parameter, CultureInfo culture)
    {
        var lines = values.Length > 0 && values[0] is int count ? count : 0;
        var fontSize = values.Length > 1 && values[1] is double size ? size : 14;
        var body = values.Length > 2 && values[2] is double height ? height : 0;
        // Why: 1.5 matches the capture TextBlock LineHeight.
        return new System.Windows.Thickness(0, PreviewLayout.IndexNumberTop(lines, fontSize * 1.5, body), 0, 0);
    }

    public object[] ConvertBack(object value, Type[] targetTypes, object parameter, CultureInfo culture) => throw new NotSupportedException();
}

/// <summary>Scales <see cref="AppSettings.EffectiveListFontSize"/> for list rows; optional ConverterParameter is a scale (e.g. 0.85 for captions).</summary>
public sealed class ScaledListFontConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var size = value is double d && d > 0 ? d : new AppSettings().EffectiveListFontSize;
        if (parameter is string scaleText
            && double.TryParse(scaleText, NumberStyles.Float, CultureInfo.InvariantCulture, out var scale))
        {
            size *= scale;
        }
        return size;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => throw new NotSupportedException();
}
