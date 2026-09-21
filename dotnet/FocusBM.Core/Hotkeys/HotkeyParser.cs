namespace FocusBM.Core;

public sealed record ParsedHotkey(string Key, HotkeyModifiers Modifiers);

public static class HotkeyParser
{
    private static readonly Dictionary<string, HotkeyModifiers> ModifierAliases = new(StringComparer.OrdinalIgnoreCase)
    {
        ["cmd"] = HotkeyModifiers.Command,
        ["command"] = HotkeyModifiers.Command,
        ["ctrl"] = HotkeyModifiers.Control,
        ["control"] = HotkeyModifiers.Control,
        ["alt"] = HotkeyModifiers.Option,
        ["option"] = HotkeyModifiers.Option,
        ["opt"] = HotkeyModifiers.Option,
        ["shift"] = HotkeyModifiers.Shift,
        ["win"] = HotkeyModifiers.Windows,
        ["windows"] = HotkeyModifiers.Windows,
    };

    public static ParsedHotkey Parse(string text, CmdMapping mapping = CmdMapping.Undecided)
    {
        if (string.IsNullOrWhiteSpace(text)) throw new ArgumentException("Hotkey must not be empty", nameof(text));
        var parts = text.Split(new[] {'+', '-', ' '}, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (parts.Length == 0) throw new ArgumentException("Hotkey must contain a key", nameof(text));
        HotkeyModifiers modifiers = HotkeyModifiers.None;
        string? key = null;
        foreach (var part in parts)
        {
            if (ModifierAliases.TryGetValue(part, out var mod))
            {
                if (mod == HotkeyModifiers.Command)
                {
                    mod = mapping switch
                    {
                        CmdMapping.MacCommandToControl => HotkeyModifiers.Control,
                        CmdMapping.MacCommandToWindows => HotkeyModifiers.Windows,
                        _ => HotkeyModifiers.Command
                    };
                }
                modifiers |= mod;
            }
            else
            {
                if (key is not null) throw new ArgumentException($"Hotkey contains multiple keys: {text}", nameof(text));
                key = NormalizeKey(part);
            }
        }
        if (key is null) throw new ArgumentException("Hotkey must contain a non-modifier key", nameof(text));
        return new ParsedHotkey(key, modifiers);
    }

    public static string Format(HotkeySettings settings)
    {
        var parts = new List<string>();
        if (settings.Modifiers.HasFlag(HotkeyModifiers.Command)) parts.Add("cmd");
        if (settings.Modifiers.HasFlag(HotkeyModifiers.Control)) parts.Add("ctrl");
        if (settings.Modifiers.HasFlag(HotkeyModifiers.Option)) parts.Add("alt");
        if (settings.Modifiers.HasFlag(HotkeyModifiers.Shift)) parts.Add("shift");
        if (settings.Modifiers.HasFlag(HotkeyModifiers.Windows)) parts.Add("win");
        parts.Add(settings.Key);
        return string.Join("+", parts);
    }

    private static string NormalizeKey(string key) => key.Length == 1 ? key.ToUpperInvariant() : key;
}
