namespace FocusBM.Core;

public sealed record ShortcutAssignment(Bookmark Bookmark, string? Shortcut, bool IsDirectNumber)
{
    public string DisplayLabel =>
        Shortcut is { Length: > 1 } && Shortcut[0] == '^' ? "⌃" + Shortcut[1..] : Shortcut ?? string.Empty;
}

public static class ShortcutAssigner
{
    public static IReadOnlyList<ShortcutAssignment> Assign(IReadOnlyList<Bookmark> bookmarks, AppSettings? settings = null)
    {
        var skipAI = settings?.ShowAIAgentShortcut == false;
        var reserved = bookmarks
            .Where(bm => !bm.NoShortcut && !string.IsNullOrWhiteSpace(bm.Shortcut))
            .Select(bm => bm.Shortcut!)
            .ToHashSet(StringComparer.Ordinal);
        var usedYaml = new HashSet<string>(StringComparer.Ordinal);
        var results = new List<ShortcutAssignment>();
        var number = 1;
        foreach (var bm in bookmarks)
        {
            if (bm.NoShortcut)
            {
                results.Add(new ShortcutAssignment(bm, null, false));
                continue;
            }
            if (skipAI && bm.IsAIAgent)
            {
                results.Add(new ShortcutAssignment(bm, null, false));
                continue;
            }
            if (!string.IsNullOrWhiteSpace(bm.Shortcut))
            {
                var label = bm.Shortcut!;
                if (!usedYaml.Add(label)) results.Add(new ShortcutAssignment(bm, null, false));
                else results.Add(new ShortcutAssignment(bm, label, false));
                continue;
            }
            while (number <= 9 && reserved.Contains(number.ToString())) number++;
            if (number <= 9)
            {
                var label = number.ToString();
                number++;
                results.Add(new ShortcutAssignment(bm, label, true));
            }
            else results.Add(new ShortcutAssignment(bm, null, false));
        }
        return results;
    }
}
