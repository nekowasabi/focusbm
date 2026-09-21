namespace FocusBM.Core;

/// <summary>Mac SearchPanel.alphabetShortcutLabel 互換。Control+s → ^s。</summary>
public static class AlphabetShortcutLabel
{
    public static string? FromKey(string? letter, bool control, bool shift, bool alt, bool windows, bool command)
    {
        if (string.IsNullOrEmpty(letter) || letter.Length != 1 || !char.IsLetter(letter[0])) return null;
        var baseLetter = letter.ToLowerInvariant();
        if (control)
        {
            if (shift || alt || windows || command) return null;
            return "^" + baseLetter;
        }
        if (alt || windows) return null;
        return shift ? baseLetter.ToUpperInvariant() : baseLetter;
    }
}
