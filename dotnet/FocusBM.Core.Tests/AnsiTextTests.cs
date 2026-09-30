using FocusBM.Core;
using Xunit;

namespace FocusBM.Core.Tests;

public class AnsiTextTests
{
    [Fact]
    public void PlainTextPassthrough()
    {
        var segment = Assert.Single(AnsiText.Parse("hello\nworld"));
        Assert.Equal("hello\nworld", segment.Text);
        Assert.Null(segment.Foreground);
    }

    [Fact]
    public void Color256RunAndReset()
    {
        var segments = AnsiText.Parse("\u001b[38;5;174mred\u001b[0m plain");
        Assert.Equal(new[] { "red", " plain" }, segments.Select(s => s.Text));
        Assert.Equal(AnsiText.Palette(174), segments[0].Foreground);
        Assert.Null(segments[1].Foreground);
    }

    [Fact]
    public void DropsNonSgrAndLeavesNoEscape()
    {
        var segment = Assert.Single(AnsiText.Parse("\u001b[2K\u001b[1;38;2;1;2;3mx\u001b[m"));
        Assert.Equal("x", segment.Text);
        Assert.True(segment.Bold);
        Assert.Equal(((byte)1, (byte)2, (byte)3), segment.Foreground);
    }

    [Fact]
    public void Strip_RemovesCsiSequences() =>
        Assert.Equal("ok  ", AnsiText.Strip("\u001b[32mok\u001b[0m \u001b[2K "));

    [Fact]
    public void TrimTrailingBlankLines_TreatsEscapeOnlyLinesAsBlank() =>
        Assert.Equal("\u001b[32mok\u001b[0m", PreviewLayout.TrimTrailingBlankLines("\u001b[32mok\u001b[0m\n\u001b[0m\n\u001b[49m  \n"));

    [Fact]
    public void Redactor_KeepsEscapeAfterUrlAndHomePath() =>
        Assert.Equal(
            "\u001b[4m<redacted-url>\u001b[0m <redacted-user-path>\u001b[0m",
            Redactor.Mask("\u001b[4mhttps://example.test/x\u001b[0m /home/alice\u001b[0m"));
}
