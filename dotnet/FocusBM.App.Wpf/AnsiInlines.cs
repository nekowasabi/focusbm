using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using FocusBM.Core;
using Color = System.Windows.Media.Color;

namespace FocusBM.App.Wpf;

/// <summary>Renders tmux <c>capture-pane -e</c> text as colored Runs. TextBlock.Inlines is not bindable, hence the attached property.</summary>
public static class AnsiInlines
{
    public static readonly DependencyProperty TextProperty = DependencyProperty.RegisterAttached(
        "Text", typeof(string), typeof(AnsiInlines), new PropertyMetadata(null, OnTextChanged));

    public static string? GetText(DependencyObject target) => (string?)target.GetValue(TextProperty);
    public static void SetText(DependencyObject target, string? value) => target.SetValue(TextProperty, value);

    private static void OnTextChanged(DependencyObject target, DependencyPropertyChangedEventArgs e)
    {
        if (target is not TextBlock block) return;
        block.Inlines.Clear();
        var defaultColor = (block.Foreground as SolidColorBrush)?.Color ?? Colors.White;
        foreach (var segment in AnsiText.Parse(e.NewValue as string ?? string.Empty))
        {
            var run = new Run(segment.Text);
            if (segment.Foreground is not null || segment.Dim)
                run.Foreground = Brush(segment.Foreground is { } fg ? Color.FromRgb(fg.R, fg.G, fg.B) : defaultColor, segment.Dim ? 0.6 : 1);
            if (segment.Background is { } bg) run.Background = Brush(Color.FromRgb(bg.R, bg.G, bg.B), 1);
            if (segment.Bold) run.FontWeight = FontWeights.Bold;
            block.Inlines.Add(run);
        }
    }

    private static SolidColorBrush Brush(Color color, double opacity)
    {
        var brush = new SolidColorBrush(color) { Opacity = opacity };
        brush.Freeze();
        return brush;
    }
}
