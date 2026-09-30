using System.Text;
using System.Text.RegularExpressions;

namespace FocusBM.Core;

/// <summary>A run of tmux <c>capture-pane -e</c> text sharing one SGR style. Null colors mean the terminal default.</summary>
public sealed record AnsiSegment(string Text, (byte R, byte G, byte B)? Foreground, (byte R, byte G, byte B)? Background, bool Bold, bool Dim);

/// <summary>Parses SGR escape sequences from tmux capture output (port of the macOS ANSIText).</summary>
public static class AnsiText
{
    private static readonly Regex Csi = new(@"\u001b\[[0-9;:?]*[ -/]*[@-~]", RegexOptions.Compiled);

    /// <summary>Text with every CSI escape sequence removed (for blank-line checks).</summary>
    public static string Strip(string text) => Csi.Replace(text, string.Empty);

    public static IReadOnlyList<AnsiSegment> Parse(string raw)
    {
        var segments = new List<AnsiSegment>();
        (byte R, byte G, byte B)? fg = null, bg = null;
        bool bold = false, dim = false;
        var buf = new StringBuilder();

        void Flush()
        {
            if (buf.Length == 0) return;
            segments.Add(new AnsiSegment(buf.ToString(), fg, bg, bold, dim));
            buf.Clear();
        }

        var i = 0;
        while (i < raw.Length)
        {
            if (raw[i] != '\u001b') { buf.Append(raw[i++]); continue; }
            i++;
            if (i >= raw.Length || raw[i] != '[') continue; // lone ESC: drop
            i++;
            var start = i;
            while (i < raw.Length && raw[i] is < '@' or > '~') i++;
            if (i >= raw.Length) break;
            var parameters = raw[start..i];
            var final = raw[i++];
            if (final != 'm') continue; // non-SGR CSI: drop
            Flush();
            var codes = parameters.Split(';').Select(p => int.TryParse(p, out var n) ? n : 0).ToArray();
            for (var k = 0; k < codes.Length;)
            {
                var c = codes[k++];
                switch (c)
                {
                    case 0: fg = null; bg = null; bold = false; dim = false; break;
                    case 1: bold = true; break;
                    case 2: dim = true; break;
                    case 22: bold = false; dim = false; break;
                    case >= 30 and <= 37: fg = Palette(c - 30); break;
                    case >= 90 and <= 97: fg = Palette(c - 90 + 8); break;
                    case >= 40 and <= 47: bg = Palette(c - 40); break;
                    case >= 100 and <= 107: bg = Palette(c - 100 + 8); break;
                    case 39: fg = null; break;
                    case 49: bg = null; break;
                    case 38 or 48:
                        (byte, byte, byte)? color = null;
                        if (k < codes.Length && codes[k] == 5 && k + 1 < codes.Length)
                        {
                            color = Palette(codes[k + 1]);
                            k += 2;
                        }
                        else if (k < codes.Length && codes[k] == 2 && k + 3 < codes.Length)
                        {
                            color = ((byte)codes[k + 1], (byte)codes[k + 2], (byte)codes[k + 3]);
                            k += 4;
                        }
                        if (c == 38) fg = color; else bg = color;
                        break;
                }
            }
        }
        Flush();
        return segments;
    }

    private static readonly (byte, byte, byte)[] Basic =
    [
        (0, 0, 0), (205, 0, 0), (0, 205, 0), (205, 205, 0), (0, 0, 238), (205, 0, 205), (0, 205, 205), (229, 229, 229),
        (127, 127, 127), (255, 0, 0), (0, 255, 0), (255, 255, 0), (92, 92, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255),
    ];

    private static readonly byte[] CubeLevels = [0, 95, 135, 175, 215, 255];

    /// <summary>xterm 256-color palette: 0-15 basic, 16-231 6x6x6 cube, 232-255 grayscale.</summary>
    public static (byte R, byte G, byte B)? Palette(int n) => n switch
    {
        >= 0 and < 16 => Basic[n],
        >= 16 and < 232 => (CubeLevels[(n - 16) / 36], CubeLevels[(n - 16) / 6 % 6], CubeLevels[(n - 16) % 6]),
        >= 232 and < 256 => ((byte)(8 + 10 * (n - 232)), (byte)(8 + 10 * (n - 232)), (byte)(8 + 10 * (n - 232))),
        _ => null
    };
}
